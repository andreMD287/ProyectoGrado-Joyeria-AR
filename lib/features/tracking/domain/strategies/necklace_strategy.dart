import 'dart:math' as math;

import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../../../core/math/geometry.dart';
import '../entities/anchor_pose.dart';
import '../entities/landmark.dart';
import '../entities/landmark_frame.dart';
import '../entities/neck_observation.dart';
import 'tracking_strategy.dart';

/// Collares: ancla en la **base del cuello**.
///
/// Hay dos caminos según lo que entregue el detector:
///
/// - **Cuello medido** ([LandmarkFrame.neck], Android): ver [_fromNeck]. Es el
///   principal.
/// - **Hombros de ML Kit Pose** (iOS): lo que sigue, validado en el spike B2.
///   El cuello se deduce con proporciones fijas.
///
/// - **Posición:** a lo largo de la línea de hombros, en el eje del cuello,
///   promediando lo que indican las orejas y la nariz (ver [neckBehindEars] y
///   [noseAhead]). En altura, subido [neckRaise] anchos de hombros sobre esa
///   línea: los landmarks de hombro caen en la articulación, más abajo que la
///   base del cuello por donde pasa la cadena.
///
///   Ni los hombros ni las orejas solos sirven de referencia: quieto y de
///   frente, ML Kit dejaba las orejas 17 px y los hombros 30 px a un lado de
///   la nariz aunque en la imagen estaban centrados, y el collar salía corrido
///   (medido 2026-10-29). La nariz es el landmark más preciso de frente.
/// - **Inclinación (`roll`):** la de la línea de hombros.
/// - **Escala:** el ancho de hombros en pantalla; quien renderiza deduce de él
///   el ancho del cuello.
/// - **Giro del torso (`yaw`):** de la diferencia de profundidad entre hombros
///   que da ML Kit. Sin ella el collar no gira cuando la persona se pone de
///   tres cuartos y la cadena trasera queda donde no debe.
///
/// Devuelve `null` si la confianza de algún hombro es menor a [minConfidence].
class NecklaceStrategy implements TrackingStrategy {
  static const int leftShoulder = 11;
  static const int rightShoulder = 12;
  static const int nose = 0;
  static const int leftEar = 7;
  static const int rightEar = 8;

  final double minConfidence;

  /// Altura de la base del cuello sobre la línea de hombros, en anchos de
  /// hombros. **Medido sobre captura** (2026-10-28): con 0,12 la cadena salía
  /// de detrás del cuello unos 60 px por debajo de donde el cuello se une a
  /// los hombros, con 694 px de ancho de hombros.
  final double neckRaise;

  /// Cuánto de la diferencia de profundidad entre hombros se cree.
  ///
  /// La `z` de ML Kit exagera el giro unas tres veces. Medido en el Galaxy
  /// A15 (2026-10-28): con el torso girado, el ancho de hombros bajaba de
  /// 0,69 a ~0,55 del frame (cos θ = 0,8, unos 37°, tan θ = 0,75) mientras
  /// `Δz/ancho` daba ~2,5; de frente, 0,1 ± 0,2. Eso sugería 0,3-0,35, pero
  /// con 0,35 la punta de la caída se pasaba del centro del pecho en los dos
  /// sentidos (25-45 px más allá del cierre de la prenda): el escorzo de los
  /// hombros sobreestima el giro. Con 0,28 el ruido de frente queda en ±3°.
  final double yawGain;

  /// Cuánto se corre el cuello respecto al punto medio de los hombros al
  /// girar el torso, en anchos de hombros (vistos) por `tan θ`. Solo se usa
  /// cuando no se ven ni las orejas ni la nariz.
  ///
  /// **Medido en dispositivo** (2026-10-28): girado −37°, el cuello quedaba a
  /// 0,2 anchos del punto medio, hacia donde mira el pecho; en el registro de
  /// 170 muestras, el punto medio de las orejas —que queda sobre el eje del
  /// cuello aunque gire la cabeza— se corre igual (0,24 a −41°, 0,13-0,19 a
  /// +43°, 0,11-0,13 a −31°). Con 0,25 el hueco seguía quedando ~20 px
  /// corrido hacia la espalda en los dos sentidos; con 0,30 no. Sin esto el
  /// collar quedaba corrido del cuello en cuanto la persona se ponía de tres
  /// cuartos.
  final double neckShift;

  /// Cuánto queda la base del cuello por detrás del punto medio de las
  /// orejas, en anchos de hombros (vistos). Con el torso girado `θ` se ve como
  /// un corrimiento de `neckBehindEars · ancho · sin θ` hacia la espalda.
  ///
  /// **Medido en dispositivo** (2026-10-29): girado +24°, el cuello iba de la
  /// nuca a la garganta entre ~100 y ~295 px (centro ~200) y el ancla bajo las
  /// orejas caía en ~232, corrida hacia la garganta. La cadena arrancaba a un
  /// cuarto de vuelta del cuello en vez de cerca de la nuca.
  final double neckBehindEars;

  /// Cuánto queda la nariz por delante del eje del cuello, en anchos de
  /// hombros (vistos): con el torso girado `θ` se ve corrida
  /// `noseAhead · ancho · sin θ` hacia donde mira. Sale de los mismos giros
  /// que [neckBehindEars]: a −38°, la nariz quedaba 0,21 anchos más allá de
  /// las orejas, y el cuello 0,14 detrás de ellas.
  final double noseAhead;

  /// Giro por debajo del cual las correcciones de posición no actúan. De
  /// frente la estimación oscila ±1° alrededor de un sesgo de unos +3,6°.
  final double yawDeadZone;

  /// Cuánto se corre el punto medio de las orejas respecto al de los hombros,
  /// en anchos de hombros (vistos) por `sin θ`. Medido en el registro de 170
  /// muestras (2026-10-28), con el giro sacado del escorzo de los hombros: a
  /// unos 37–43° las orejas se corrían 0,13–0,20 anchos.
  final double earsAhead;

  /// Tope del giro del torso. Más allá de unos 50° un hombro tapa al otro y
  /// ML Kit adivina su profundidad.
  final double maxYaw;

  /// Cuánto queda el centro del escote por delante del eje del cuello, en
  /// radios de la base del cuello, cuando el escote está a la altura de la
  /// base. Con 1,0 el giro salía ~25° con el torso a unos 40° y el collar
  /// seguía mirando a la cámara (medido en dispositivo, 2026-11-05): de lado
  /// se ve poco del frente y el corrimiento se subestima. Con el torso girado `θ` se ve corrido `d · sin θ` respecto al eje
  /// (ver [_fromNeck]).
  final double frontAhead;

  /// Cuánto avanza el pecho por cada unidad que el escote cae por debajo de la
  /// base del cuello: el centro de un escote en V queda sobre el esternón, más
  /// adelante que la garganta.
  final double chestSlope;

  /// Fracción del giro de la cabeza que se toma como giro del torso cuando no
  /// se ve el escote. La cabeza suele girar más que el cuerpo, y al mirar la
  /// pantalla vuelve hacia la cámara.
  final double headYawFollow;

  /// Columna del cuello respecto a su base cuando la mandíbula no deja medir
  /// la columna. La base se abre hacia los trapecios.
  final double columnToBase;

  /// Giro de cabeza a partir del cual se confía en el centro de la columna
  /// del cuello como eje (ver [_fromNeck]).
  final double minHeadYawForColumn;

  /// Base del cuello supuesta mientras la segmentación no da la primera
  /// medida: su ancho en anchos de cara y su altura bajo el mentón.
  final double defaultBaseToFace;
  final double defaultBaseBelowChin;

  const NecklaceStrategy({
    this.minConfidence = 0.5,
    this.neckRaise = 0.18,
    this.maxYaw = 50 * math.pi / 180,
    this.yawGain = 0.28,
    this.earsAhead = 0.27,
    this.neckShift = 0.30,
    this.neckBehindEars = 0.22,
    this.noseAhead = 0.56,
    this.yawDeadZone = 5 * math.pi / 180,
    this.frontAhead = 0.75,
    this.chestSlope = 0.3,
    this.headYawFollow = 0.6,
    this.columnToBase = 0.87,
    this.minHeadYawForColumn = 8 * math.pi / 180,
    this.defaultBaseToFace = 0.85,
    this.defaultBaseBelowChin = 0.25,
  });

  @override
  JewelryCategory get category => JewelryCategory.necklace;

  @override
  DetectorKind get detectorKind => DetectorKind.neck;

  @override
  void reset() {}

  @override
  AnchorPose? computeAnchor(
    LandmarkFrame frame, {
    double imageAspect = 1.0,
  }) {
    final cuello = frame.neck;
    if (cuello != null) return _fromNeck(cuello, imageAspect);

    // ML Kit Pose no entrega reconstruccion metrica: solo landmarks de imagen.
    final landmarks = frame.landmarks;
    if (landmarks.length <= rightShoulder || imageAspect <= 0) return null;
    final l = landmarks[leftShoulder];
    final r = landmarks[rightShoulder];
    final lv = l.visibility ?? 1.0;
    final rv = r.visibility ?? 1.0;
    if (lv < minConfidence || rv < minConfidence) return null;

    // Se trabaja en un espacio isotropo (y dividido por el aspecto), donde
    // una misma distancia mide lo mismo en horizontal y en vertical. Sin esto
    // la subida hacia el cuello saldría distinta en un frame vertical que en
    // uno horizontal.
    final dx = r.x - l.x;
    final dyIso = (r.y - l.y) / imageAspect;
    final width = math.sqrt(dx * dx + dyIso * dyIso);
    if (width <= 0) return null;

    // Hacia el cuello: perpendicular a la línea de hombros y hacia arriba en
    // la imagen (y negativa).
    var upX = -dyIso / width, upY = dx / width;
    if (upY > 0) {
      upX = -upX;
      upY = -upY;
    }
    // Dirección de la línea de hombros, de izquierda a derecha de la pantalla.
    final haciaDerecha = dx >= 0 ? 1.0 : -1.0;
    final alongX = haciaDerecha * dx / width;
    final alongY = haciaDerecha * dyIso / width;

    final centroX = (l.x + r.x) / 2;
    final centroYIso = (l.y + r.y) / 2 / imageAspect;
    // Sobre la línea de hombros, desde su punto medio.
    double? along(Landmark? p) => p == null
        ? null
        : (p.x - centroX) * alongX +
            (p.y / imageAspect - centroYIso) * alongY;

    final orejas = _midEars(landmarks);
    final yaw = orejas != null
        ? _yawFromEars(along(orejas)!, width)
        : _torsoYaw(l, r, width);

    // Las correcciones por giro usan el giro sin su zona muerta: de frente la
    // estimación queda sesgada unos +3,6° y corría el cuello hacia un lado
    // con la persona quieta (medido 2026-10-29).
    final giro = math.sin(_sinZonaMuerta(yaw ?? 0));

    // Dos referencias, cada una llevada al eje del cuello según el giro (ver
    // [neckBehindEars] y [noseAhead]), y se promedian: las orejas aguantan
    // mejor los giros y la nariz es la más precisa de frente.
    final porOrejas = along(orejas);
    final porNariz = along(_visible(landmarks, nose));
    final estimaciones = [
      if (porOrejas != null) porOrejas - neckBehindEars * width * giro,
      if (porNariz != null) porNariz - noseAhead * width * giro,
    ];
    final corrimiento = estimaciones.isEmpty
        ? neckShift * width * math.tan(yaw ?? 0)
        : estimaciones.reduce((a, b) => a + b) / estimaciones.length;

    final midX = centroX + alongX * corrimiento;
    final midYIso = centroYIso + alongY * corrimiento;
    final anchorX = midX + upX * neckRaise * width;
    final anchorY = (midYIso + upY * neckRaise * width) * imageAspect;

    // Eje de los hombros: su inclinación no depende del sentido en que se
    // recorra, y con la cámara frontal el vector viene invertido.
    final roll = normalizeAxisAngle(math.atan2(r.y - l.y, dx * imageAspect));

    return AnchorPose(
      position: Vec3(anchorX, anchorY, (l.z + r.z) / 2),
      rollRadians: roll,
      scale: width,
      yawRadians: yaw,
      confidence: math.min(lv, rv),
    );
  }

  /// Ancla a partir del cuello **medido** sobre la imagen.
  ///
  /// La forma del cuello llega unas cuatro veces por segundo y la cara en cada
  /// frame, así que la forma se expresa respecto a la cara del frame en que se
  /// midió (mentón y ancho de cara) y se lleva a la cara actual. Así el collar
  /// sigue a la persona sin esperar a la segmentación.
  ///
  /// - **Posición:** el punto medio entre los dos lados donde el cuello toca la
  ///   ropa, que es por donde sale la cadena de detrás del cuello. Es el eje
  ///   del cuello: la silueta de un cilindro queda centrada en su eje aunque
  ///   gire.
  /// - **Escala ([AnchorPose.scale]):** el ancho de esa base, al que se ajusta
  ///   el hueco del collar. **[AnchorPose.limbWidth]:** el de la columna del
  ///   cuello, más delgada, que es lo que ocluye.
  /// - **Giro del torso:** el centro del escote está en la línea media del
  ///   pecho, por delante del eje del cuello una distancia `d`; con el torso
  ///   girado `θ` se ve corrido `d · sin θ`. Mide el cuerpo, no la cabeza, que
  ///   al mirar la pantalla vuelve hacia la cámara. Sin escote a la vista se
  ///   usa una fracción del giro de la cabeza ([headYawFollow]).
  /// - **Inclinación:** la de la cara; quien renderiza solo sigue una fracción.
  ///
  /// Se trabaja en el espacio isótropo (y dividido por el aspecto).
  AnchorPose? _fromNeck(NeckObservation o, double imageAspect) {
    final caraW = o.faceWidth;
    if (caraW <= 0 || imageAspect <= 0) return null;
    final menX = o.chin.x, menY = o.chin.y / imageAspect;

    final dxMejillas = o.cheekRight.x - o.cheekLeft.x;
    // Mismo convenio que la escena: positivo cuando el frente gira hacia la
    // derecha de la pantalla, o sea cuando la mejilla de la derecha se aleja
    // (la `z` de la malla crece al alejarse).
    final giroCabeza =
        math.atan2(o.cheekRight.z - o.cheekLeft.z, dxMejillas);
    final roll = normalizeAxisAngle(math.atan2(
      (o.cheekRight.y - o.cheekLeft.y) / imageAspect,
      dxMejillas,
    ));

    final forma = o.neck;
    double izqX, izqY, derX, derY, columna;
    double? frenteX, frenteY, ejeX;
    if (forma != null && forma.refFaceWidth > 0) {
      final k = caraW / forma.refFaceWidth;
      final refX = forma.refChinX, refY = forma.refChinY / imageAspect;
      double llevarX(double x) => menX + (x - refX) * k;
      double llevarY(double y) => menY + (y / imageAspect - refY) * k;
      izqX = llevarX(forma.leftX);
      izqY = llevarY(forma.leftY);
      derX = llevarX(forma.rightX);
      derY = llevarY(forma.rightY);
      columna = forma.narrowWidth * k;
      final cx = forma.columnX;
      if (cx != null) ejeX = llevarX(cx);
      final fx = forma.frontX, fy = forma.frontY;
      if (fx != null && fy != null) {
        frenteX = llevarX(fx);
        frenteY = llevarY(fy);
      }
    } else {
      final medio = defaultBaseToFace * caraW / 2;
      izqX = menX - medio;
      derX = menX + medio;
      izqY = derY = menY + defaultBaseBelowChin * caraW;
      columna = 0;
    }

    final base = (derX - izqX).abs();
    if (base <= 0) return null;
    final centroX = (izqX + derX) / 2;
    final centroY = (izqY + derY) / 2;
    // La columna medida solo vale si es coherente con la base.
    final col = columna >= 0.6 * base && columna <= base
        ? columna
        : columnToBase * base;

    // El giro se mide desde el eje del cuello. De lado, la base arrastra el
    // trapecio de la nuca y su punto medio queda corrido hacia atrás; el
    // centro de la columna no. Pero de frente la mandíbula deja ver muy poca
    // columna y su centro salía hasta un tercio de la base corrido, lo que
    // hacía saltar el giro entre 0° y ±30° con la persona quieta (medido en
    // dispositivo, 2026-11-05). Solo se usa con la cabeza girada, corrido
    // hacia la nuca —opuesto al giro— y dentro de un margen.
    var eje = centroX;
    if (ejeX != null) {
      final corrido = ejeX - centroX;
      if (giroCabeza.abs() >= minHeadYawForColumn &&
          corrido * giroCabeza < 0 &&
          corrido.abs() <= 0.25 * base) {
        eje = ejeX;
      }
    }
    final porCabeza = giroCabeza * headYawFollow;
    double yaw;
    double? porEscote;
    if (frenteX != null && frenteY != null) {
      final caida = math.max(0.0, frenteY - centroY);
      final d = frontAhead * base / 2 + chestSlope * caida;
      porEscote = math.asin(((frenteX - eje) / d).clamp(-0.9, 0.9));
      // El escote subestima los giros grandes: de lado se ve poco del frente.
      // Si la cabeza gira hacia el mismo lado y más, se toma esa fracción.
      yaw = porEscote.sign == porCabeza.sign &&
              porCabeza.abs() > porEscote.abs()
          ? porCabeza
          : porEscote;
    } else {
      yaw = porCabeza;
    }

    return AnchorPose(
      position: Vec3(centroX, centroY * imageAspect, 0),
      rollRadians: roll,
      scale: base,
      limbWidth: col,
      yawRadians: yaw.clamp(-maxYaw, maxYaw),
      confidence: 1,
    );
  }

  /// Punto medio de las orejas, o `null` si no se ven.
  ///
  /// **Por qué las orejas y no solo los hombros.** Con el torso girado el
  /// cuello deja de verse en el punto medio de los hombros, y corregirlo solo
  /// con el giro estimado no funcionó: en dispositivo (2026-10-28) el collar
  /// quedó corrido a un lado, luego al otro y luego hacia el pecho según la
  /// constante, porque el hombro lejano y la `z` de ML Kit son inestables. El
  /// punto medio de las orejas queda sobre el eje del cuello aunque la cabeza
  /// gire, y en el registro de 170 muestras se corría lo mismo que el cuello.
  Landmark? _midEars(List<Landmark> landmarks) {
    final a = _visible(landmarks, leftEar);
    final b = _visible(landmarks, rightEar);
    if (a == null || b == null) return null;
    return Landmark((a.x + b.x) / 2, (a.y + b.y) / 2, 0);
  }

  Landmark? _visible(List<Landmark> landmarks, int i) {
    if (landmarks.length <= i) return null;
    final p = landmarks[i];
    return (p.visibility ?? 1.0) < minConfidence ? null : p;
  }

  /// El giro sin los primeros [yawDeadZone] radianes, con su signo.
  double _sinZonaMuerta(double yaw) =>
      yaw.sign * math.max(0.0, yaw.abs() - yawDeadZone);

  /// Giro del torso alrededor de la vertical, en el convenio de la escena:
  /// positivo cuando el hombro de la **derecha de la pantalla** se aleja.
  ///
  /// Con los hombros separados `L` y el torso girado `θ`, en la imagen se ven
  /// separados `L·cos θ` y su diferencia de profundidad es `L·sin θ`, así que
  /// `θ = atan2(Δz, ancho)`. La `z` de ML Kit crece al alejarse y viene en la
  /// misma escala que `x` (ver `PoseDetectorDataSource`).
  ///
  /// Signo verificado en dispositivo (2026-10-28) contra la posición de la
  /// nariz, que se corre hacia donde mira el pecho: en 170 muestras con giros
  /// a ambos lados, el giro y el desvío de la nariz respecto al centro de los
  /// hombros salen siempre con el mismo signo.
  ///
  /// `null` si el detector no dio profundidad (los dos hombros en 0).
  /// Giro del torso a partir de cuánto se corren las orejas respecto al punto
  /// medio de los hombros: `θ = asin(corrimiento / (earsAhead · ancho))`.
  ///
  /// **Por qué no la profundidad de ML Kit.** La `z` de los hombros no es
  /// consistente entre sesiones: con giros parecidos de unos 30° dio
  /// `Δz/ancho` ≈ 2,5 un día y ≈ 0,4 otro, así que ninguna ganancia servía y
  /// el collar se quedaba de frente con la persona girada (medido
  /// 2026-10-29: 6–7° estimados). El corrimiento de las orejas es geométrico,
  /// tiembla ±2° de frente —un tercio que la `z`— y en 170 muestras siguió al
  /// giro de forma consistente.
  double _yawFromEars(double corrimiento, double width) {
    final s = (corrimiento / (earsAhead * width)).clamp(-1.0, 1.0);
    return math.asin(s).clamp(-maxYaw, maxYaw);
  }

  /// Giro por la profundidad de los hombros; solo de respaldo cuando no se ven
  /// las orejas (ver [_yawFromEars]).
  double? _torsoYaw(Landmark l, Landmark r, double width) {
    if (l.z == 0 && r.z == 0) return null;
    final (izquierda, derecha) = r.x >= l.x ? (l, r) : (r, l);
    final dz = derecha.z - izquierda.z;
    return math.atan2(yawGain * dz, width).clamp(-maxYaw, maxYaw);
  }
}
