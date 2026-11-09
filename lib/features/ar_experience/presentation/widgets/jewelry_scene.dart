import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_advanced_loaders/rgbe_loader.dart' show RGBELoader;

import '../../../../core/math/earring_geometry.dart';
import '../../../../core/math/geometry.dart';
import '../../../../core/math/head_geometry.dart';
import '../../../../core/math/necklace_geometry.dart';
import '../../../../core/math/pendulum.dart';
import '../../../../core/math/ring_geometry.dart';
import '../../../tracking/domain/entities/anchor_pose.dart';

/// Lo que la escena necesita de un arete para colgarlo de la cabeza.
class EarringSetup {
  /// Si cuelga del lóbulo (colgante o aro) o va pegado (botón). `null` para
  /// deducirlo de la forma del modelo.
  final bool? hangs;

  /// Alto real de la pieza en milímetros (`dimensiones_mm.alto`). Con 0 se usa
  /// un tamaño típico.
  final double heightMm;

  /// Punto de sujeción del catálogo, en unidades del GLB y ya girado con
  /// `orientacion_yaw_deg`, o `null`.
  final Vec3? attachPoint;

  const EarringSetup({this.hangs, required this.heightMm, this.attachPoint});
}

/// Escena 3D que cubre toda el área de cámara y coloca la joya dentro (ADR-16).
///
/// **En qué se diferencia del overlay anterior.** `model_viewer_plus` dibujaba
/// el modelo desde su propia cámara dentro de una caja pequeña que se movía por
/// la pantalla: un *sprite*. Aquí la escena ocupa toda el área, la cámara es
/// una cámara en perspectiva, y la joya es un objeto **situado en el espacio**
/// cuya proyección cae sobre el punto de anclaje. Esa diferencia es la que
/// permite, más adelante, que un *occluder* de la extremidad la tape por el
/// buffer de profundidad.
///
/// El sistema de la cámara mira hacia -Z, con +Y hacia arriba; la pantalla
/// tiene +Y hacia abajo, de ahí los signos invertidos al convertir.
class JewelryScene extends StatefulWidget {
  /// GLB ya normalizado (ver `glb_normalizer.dart`).
  final Uint8List modelBytes;

  /// Pose de anclaje, o `null` si se perdió el tracking.
  final AnchorPose? anchor;

  /// Mapeo `cover` entre el frame de cámara y el área de dibujo; es el mismo
  /// que usa la vista previa, así que la joya cae donde el usuario la ve.
  final PreviewFit fit;

  /// Giro fijo del catálogo para corregir modelos mal orientados al exportar.
  final double staticYawDeg;

  /// Rotación extra sobre el ángulo que reporta la estrategia (una pulsera se
  /// lleva perpendicular al eje del antebrazo).
  final double rollOffset;

  /// Diámetro **exterior** que debe aparentar la pieza, en píxeles del área.
  final double targetSizePx;

  /// Diámetro del miembro que la pieza rodea, en píxeles del área. Es lo que
  /// ocluye, y **no se deduce del modelo**: la caja envolvente no da el hueco
  /// del aro. En una pieza de cuentas su dimensión más delgada es el grosor de
  /// la cuenta, pero en un brazalete es el ancho de la banda a lo largo del
  /// brazo, que no guarda relación con el radio interior. Se estima por
  /// anatomía a partir de la medida que reporta la estrategia.
  ///
  /// `null` en piezas que no rodean nada (aretes): entonces no hay oclusión.
  final double? limbDiameterPx;

  /// Dibuja el proxy de oclusión en alambre rojo. Es la herramienta para
  /// juzgar en dispositivo si el proxy calza con el brazo real: sin verlo, un
  /// proxy demasiado fino o grueso solo se nota como cuentas que aparecen o
  /// desaparecen donde no deben.
  final bool showOccluder;

  /// La pieza es un collar: se ajusta por el hueco del cuello en vez de por
  /// un aro, y se ocluye con un proxy de cuello (ver `_setupNecklace`).
  final bool necklace;

  /// Ancho de la columna del cuello en píxeles del área, para collares. Es lo
  /// que reproduce el proxy de cuello.
  final double? neckDiameterPx;

  /// Ancho de la base del cuello en píxeles del área, donde apoya la cadena:
  /// el hueco del collar se ajusta a ella. `null` si no se midió; entonces se
  /// deduce de [neckDiameterPx].
  final double? neckBasePx;

  /// La pieza es un arete que se cuelga de la cabeza medida con la malla
  /// facial (Android, ver `_setupHead`): los dos aretes, cada uno en su
  /// lóbulo, con la cabeza invisible como oclusor. `null` en el resto de casos
  /// —incluidos los aretes en iOS—, que siguen dibujando una sola pieza en el
  /// ancla.
  final EarringSetup? earring;

  const JewelryScene({
    super.key,
    required this.modelBytes,
    required this.anchor,
    required this.fit,
    required this.targetSizePx,
    this.limbDiameterPx,
    this.staticYawDeg = 0,
    this.rollOffset = 0,
    this.showOccluder = false,
    this.necklace = false,
    this.neckDiameterPx,
    this.neckBasePx,
    this.earring,
  });

  @override
  State<JewelryScene> createState() => _JewelrySceneState();
}

class _JewelrySceneState extends State<JewelryScene> {
  /// Campo de visión **horizontal** del área visible, en grados.
  ///
  /// Da a la cámara virtual una perspectiva comparable a la del objetivo, que
  /// es lo que hace que un objeto girado en 3D se escorce como es debido. No se
  /// puede leer del plugin de cámara (no expone la óptica) y la vista previa
  /// recorta el frame con `cover`, así que corresponde al **área visible**.
  static const double _hfovDeg = 65;

  /// Distancia a la que se sitúa la joya.
  ///
  /// Es fija a propósito. Se intentó deducir la distancia real comparando el
  /// tamaño métrico de la mano con su tamaño aparente, y **no funciona**: la
  /// reconstrucción métrica de MediaPipe subestima la escala absoluta (mide
  /// unos 4,5 cm entre nudillos donde una mano adulta tiene ~8), así que la
  /// mano se interpreta como cercana y la pieza sale hasta tres veces más
  /// grande. Verificado en dispositivo el 2026-09-18.
  ///
  /// De esa reconstrucción se usa lo que sí es fiable —las **direcciones**,
  /// que no dependen de la escala— para orientar la pieza; el tamaño se sigue
  /// midiendo sobre la imagen, que es lo que se observa directamente.
  static const double _depth = 1.0;

  /// El visor **cachea su tamaño en el primer build**, así que no puede crearse
  /// hasta conocer las restricciones reales. Con arranque en frío el primer
  /// build llega antes que las medidas de la ventana y la textura se crearía de
  /// 0x0 (ver `spikes/B7-motor-render`).
  three.ThreeJS? _viewer;
  Size? _area;

  three.Object3D? _jewel;

  /// Cilindro que representa la extremidad. No se pinta: solo escribe
  /// profundidad, de modo que el arco de la pieza que pasa por detrás queda
  /// tapado por el propio buffer. Es la oclusión real, con silueta curva, en
  /// lugar de un recorte plano sobre la imagen.
  three.Object3D? _occluder;

  /// Silueta visible del proxy, solo para diagnóstico (ver
  /// [JewelryScene.showOccluder]). Es hija del proxy, así que hereda su pose.
  three.Object3D? _occluderWire;

  /// Largo del proxy en diámetros: basta con que sobresalga por ambos lados
  /// para tapar en cualquier inclinación.
  static const double _occluderLengthRatio = 3.0;

  /// Cuánto se estrecha el proxy hacia la mano respecto al lado del codo.
  static const double _occluderTaper = 0.85;

  /// Tope de metalicidad de los materiales. Un metal puro no tiene color
  /// difuso: solo refleja el entorno, y esta escena no tiene mapa de entorno
  /// (solo luz ambiental y direccional), así que sale negro. `cartier` lo
  /// mostró en dispositivo: oro rosa con `metallicFactor` 10000 y 6 de 10
  /// materiales sin factor, que glTF toma como 1. Con el tope se ve el color
  /// base a costa de parte del brillo metálico.
  static const double _metalnessMax = 0.35;

  /// Grosor del antebrazo respecto a su ancho. No es redondo: es bastante más
  /// ancho de lado a lado que de dorso a palma. Con un proxy circular hay que
  /// elegir entre taparlo de más en profundidad o de menos a lo ancho.
  static const double _occluderFlatness = 0.75;

  /// Margen por debajo del hueco del aro. El brazo tiene que **caber** dentro
  /// de la pieza: si el proxy es más ancho que el hueco, la atraviesa y se come
  /// cuentas que deberían verse.
  static const double _occluderHoleMargin = 0.96;

  /// Holgura del aro sobre el miembro: una pulsera no va a presión sobre la
  /// piel, queda algo suelta.
  static const double _holguraDelAro = 1.12;

  /// Diámetro exterior del modelo: su mayor extensión.
  double _modelDiameter = 1;

  /// Hueco y eje del aro medidos sobre los vértices, o `null` si la pieza no
  /// tiene forma de aro reconocible (ver `ring_geometry.dart`).
  RingMeasure? _aro;

  /// Hueco del aro ya renderizado, en unidades de mundo, o 0 si la pieza no
  /// tiene forma de aro reconocible. Acota cuánto puede engordar el proxy.
  double _huecoWorld = 0;


  /// Eje del aro en el espacio del modelo: la dirección **de menor extensión**.
  /// Una pieza que rodea un miembro es ancha en dos ejes y delgada en el
  /// tercero, y ese tercero es por donde entra el brazo. Deducirlo de la malla
  /// evita una constante por modelo y funciona con piezas que aún no existen.
  three.Vector3 _ringAxisLocal = three.Vector3(0, 0, 1);

  /// Hueco del cuello del collar, medido sobre los vértices ya girados con
  /// `orientacion_yaw_deg`. `null` si la pieza no es un collar.
  NecklaceMeasure? _collar;

  /// Alambre de diagnóstico del proxy de cuello del collar.
  three.Object3D? _necklaceWire;

  /// Proxy de cuello del collar; se ajusta en cada pose a la columna medida.
  three.Object3D? _necklaceNeck;

  /// Holgura del hueco del collar sobre la **base** del cuello medida. La base
  /// es justo donde la cadena sale de detrás del cuello, así que el hueco
  /// apenas la supera.
  static const double _holguraSobreBase = 1.05;

  /// Radio del proxy de cuello respecto al del hueco del collar, cuando la
  /// base del cuello está medida.
  ///
  /// Con la columna medida (~0,87 de la base) el proxy quedaba más angosto
  /// que el aro, y el tramo que va de los costados hacia la nuca —que en los
  /// modelos sube— asomaba a los lados del cuello como dos cuernos hasta la
  /// mandíbula, sobre todo de cerca (visto en dispositivo, 2026-11-05). Con
  /// 0,94 la cadena se escondía demasiado pronto a los costados; 0,88 queda
  /// entre las dos y fue lo que se prefirió en dispositivo.
  ///
  /// Con el eje del cuello corrido hacia la nuca, un radio así cumple las dos
  /// cosas: de frente tapa la cadena desde unos 20° más allá del costado, y
  /// girado deja ver la del lado de la cámara hasta unos 50° más allá, porque
  /// ese tramo queda por fuera del proxy y no dentro.
  static const double _proxySobreHueco = 0.88;

  /// Holgura del hueco del collar sobre el cuello. El proxy de cuello mide el
  /// hueco dividido por esto.
  ///
  /// El proxy es la **columna** del cuello, más delgada que la base sobre la
  /// que apoya la cadena (que se abre hacia los trapecios). Con 1,05 la cadena
  /// desaparecía justo al tocar el borde del cuello y se veían dos cortes
  /// verticales; con la columna más delgada, la cadena sube por los costados
  /// curvándose hacia la nuca antes de esconderse, que es lo que se ve como
  /// rodear el cuello (simulado y visto en dispositivo, 2026-10-29). Con 1,25
  /// y el ancla aún mal centrada, girado se salía hacia el hombro.
  static const double _holguraDelCollar = 1.2;

  /// Dónde va la columna del cuello entre el centro del aro (0) y su borde
  /// trasero (1). La cadena cuelga apoyada en la nuca y lo que sobra cae hacia
  /// adelante, así que el cuello no está en el centro del aro; pero tampoco
  /// pegado del todo a la cadena, que por detrás descansa sobre la base.
  static const double _cuelloHaciaNuca = 0.5;

  /// Inclinación del collar hacia adelante: la nuca queda más alta que el
  /// frente, como cae una cadena real sobre la pendiente de los trapecios.
  /// Los modelos vienen con la vuelta trasera horizontal; sin inclinarla, al
  /// girar la cadena del lado de la cámara llega al borde del cuello y se
  /// corta en vez de subir por el costado hacia la nuca. Solo se inclina la
  /// pieza: el cuello sigue vertical.
  ///
  /// **Poca a propósito.** La inclinación gira la pieza entera, y además de
  /// subir la nuca mueve la caída del frente hacia atrás: con 35° la punta
  /// quedaba debajo del cuello en vez de sobre el pecho, el collar era un aro
  /// casi vertical en el plano de la cámara y se veía siempre de frente a ella
  /// aunque la persona girara (visto en dispositivo y simulado, 2026-10-29).
  /// La cámara frontal ya mira el cuello algo desde arriba, lo que aporta el
  /// resto del efecto.
  static const double _necklaceTiltDeg = 10;

  /// Qué fracción de la inclinación de los hombros sigue el collar.
  ///
  /// Un collar **cuelga por gravedad**: si los hombros quedan algo desnivelados
  /// la caída sigue apuntando hacia abajo. Girándolo con toda la línea de
  /// hombros —que además tiembla ±3° con ML Kit— la V quedaba torcida respecto
  /// al eje mentón-garganta: medido de frente, 11 px de desvío entre el centro
  /// de la cadena y la punta (2026-10-29). Una fracción lo deja acompañar una
  /// inclinación real del cuerpo sin torcerse con el ruido.
  static const double _necklaceRollFollow = 0.3;

  /// Giro del torso por debajo del cual el collar se queda de frente.
  ///
  /// La zona muerta es **suave**: entre una y dos veces este valor el giro
  /// crece del 0 al valor medido, y por encima pasa entero. Restarla siempre
  /// le quitaba esos grados a los giros grandes, y girado el collar seguía
  /// mirando a la cámara. De frente la estimación queda en unos ±10°
  /// estables según la prenda (medido en dispositivo, 2026-11-05).
  static const double _necklaceYawDeadZoneDeg = 10;

  /// Alto del proxy de cuello, en anchos del hueco: debe llegar hasta la
  /// barbilla para tapar la vuelta trasera en cualquier inclinación.
  static const double _neckOccluderHeight = 1.5;

  /// Medidas del arete sobre su modelo, en modo cabeza.
  EarringMeasure? _earMeasure;

  /// Los dos aretes, uno por lóbulo, en modo cabeza.
  final List<_Ear> _ears = [];

  /// La cabeza invisible, en modo cabeza: rotada y escalada al ancho de la
  /// cara. Cuelga de [_jewel], que la sitúa y le corrige la perspectiva.
  three.Object3D? _headGroup;

  /// Siluetas de diagnóstico de los oclusores de la cabeza.
  final List<three.Object3D> _headWires = [];

  /// Ancho de la cara en unidades de mundo en la última pose, o 0 si todavía
  /// no hubo. Pasa las posiciones de la escena a metros para el péndulo.
  double _headWorldWidth = 0;

  /// Alto supuesto de un arete cuando el catálogo no trae `alto`.
  static const double _defaultEarringMm = 20;


  void _createViewer(Size area) {
    _area = area;
    _viewer = three.ThreeJS(
      size: area,
      settings: three.Settings(
        // Sin esto el render tapa la cámara con un rectángulo negro.
        alpha: true,
        clearAlpha: 0.0,
        clearColor: 0x000000,
        antialias: true,
        // Solo los aretes en modo cabeza recortan la parte de detrás del
        // lóbulo (ver `_setupHead`).
        localClippingEnabled: widget.earring != null,
      ),
      onSetupComplete: () {
        if (mounted) setState(() {});
      },
      setup: _setup,
    );
    setState(() {});
  }

  @override
  void dispose() {
    _viewer?.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    final viewer = _viewer!;
    viewer.scene = three.Scene();

    // Reflejos PBR de estudio, manteniendo transparente el fondo AR.
    var hasEnvironment = false;
    final hdrLoader = RGBELoader();

    try {
      final hdr = await hdrLoader.fromAsset(
        'assets/environments/cartier_studio.hdr',
      );

      if (hdr != null) {
        hdr.mapping = three.EquirectangularReflectionMapping;
        viewer.scene.environment = hdr;
        viewer.scene.environmentIntensity = 0.8;
        hasEnvironment = true;
        debugPrint('HDR AR cargado correctamente');
      }
    } catch (error) {
      debugPrint('Error cargando HDR AR: $error');
    } finally {
      hdrLoader.dispose();
    }
    final aspect = viewer.width / viewer.height;
    viewer.camera = three.PerspectiveCamera(
      _fovYFor(aspect),
      aspect,
      0.01,
      100,
    );
    viewer.camera.position.setValues(0, 0, 0);

    // Iluminación provisional de estudio. La coherencia con la luz real de la
    // escena es la fase siguiente, y es la última pista que delata el montaje.
    viewer.scene.add(three.AmbientLight(0xffffff, 1.4));
    final key = three.DirectionalLight(0xffffff, 2.2);
    key.position.setValues(1, 2, 1);
    viewer.scene.add(key);

    // Se dibuja antes que la joya (renderOrder menor) para que su profundidad
    // ya esté en el buffer cuando se pinte la pieza.
    final occluder = three.Mesh(
      // Tronco de cono, no cilindro: el antebrazo se estrecha hacia la
      // muneca. El extremo +Y mira al codo, que es el ancho.
      three.CylinderGeometry(0.5, 0.5 * _occluderTaper, 1, 48),
      three.MeshBasicMaterial.fromMap({'colorWrite': false}),
    )..renderOrder = -1;
    viewer.scene.add(occluder);
    _occluder = occluder;

    // Sin prueba de profundidad y dibujada al final: tiene que verse aunque la
    // pieza o el propio proxy estén delante.
    final wire = three.Mesh(
      occluder.geometry,
      three.MeshBasicMaterial.fromMap({
        'color': 0xff2020,
        'wireframe': true,
        'transparent': true,
        'opacity': 0.55,
        'depthTest': false,
        'depthWrite': false,
      }),
    )
      ..renderOrder = 10
      ..visible = widget.showOccluder;
    occluder.add(wire);
    _occluderWire = wire;

    final gltf = await three.GLTFLoader().fromBytes(widget.modelBytes);
    final model = gltf?.scene;
    if (model == null) return;

    // El GLB viene en la escala y el origen que le dio el exportador: se
    // centra y se mide para poder pedirle después un tamaño aparente concreto.
    //
    // La caja se calcula **sobre los vértices**, no con `BoundingBox`: esa
    // transforma la caja de cada malla por la matriz de su nodo, y con nodos
    // rotados la infla. En `cartier` daba 3,50 de diámetro donde los vértices
    // miden 2,53, con el centro desplazado: la pieza quedaba corrida unos
    // 15 px del eje del brazo (medido en dispositivo, 2026-10-13).
    final puntos = _vertices(model);
    if (puntos.isEmpty) return;

    if (widget.necklace) {
      _limitarMetalicidad(model, hasEnvironment: hasEnvironment);
      _setupNecklace(viewer, model, puntos);
      _applyAnchor();
      return;
    }

    final earring = widget.earring;
    if (earring != null) {
      await _setupHead(viewer, model, earring, hasEnvironment);
      _applyAnchor();
      return;
    }

    final (min, max) = _limites(puntos);
    final size = three.Vector3(max.x - min.x, max.y - min.y, max.z - min.z);
    final center = three.Vector3(
      (max.x + min.x) / 2,
      (max.y + min.y) / 2,
      (max.z + min.z) / 2,
    );

    // Se **resta**, no se asigna: la caja viene en coordenadas de mundo, o sea
    // que su centro ya incluye la traslacion que el modelo trae del exportador.
    // Asignar `-centro` la descartaba, y la pieza quedaba desplazada de la
    // muneca justo esa cantidad (visto en dispositivo: se iba hacia un lado).
    model.position.sub(center);
    _modelDiameter = math.max(math.max(size.x, size.y), math.max(size.z, 1e-6));
    _aro = measureRing(puntos);
    _ringAxisLocal = switch (_aro?.axis) {
      0 => three.Vector3(1, 0, 0),
      1 => three.Vector3(0, 1, 0),
      2 => three.Vector3(0, 0, 1),
      _ => _menorExtension(size),
    };

    // Un contenedor propio evita pelear con la transformación que el modelo ya
    // trae: el hijo centra, el padre posiciona y orienta.
    _limitarMetalicidad(model, hasEnvironment: hasEnvironment);

    final holder = three.Object3D()..add(model);
    viewer.scene.add(holder);
    _jewel = holder;

    _applyAnchor();
  }

  /// Monta un collar: lo orienta, lo sitúa sobre el cuello y le pone el proxy
  /// de oclusión.
  ///
  /// Los collares del catálogo vienen modelados **puestos**: la mitad trasera
  /// rodea el cuello casi horizontal y la delantera cae sobre el pecho. Lo que
  /// se mide es ese hueco (ver `necklace_geometry.dart`), y todo se cuelga de
  /// él: la escala hace que el hueco abrace el cuello y el proxy se define en
  /// sus mismas unidades, así que la oclusión calza con la cadena por
  /// construcción, sin constantes por modelo.
  ///
  /// **El cuello va pegado a la nuca, no en el centro del aro.** Una cadena
  /// cuelga apoyada en la parte de atrás del cuello y lo que le sobra cae hacia
  /// adelante. Con el cuello en el centro, al girar el torso la cadena se
  /// escondía a mitad del costado del cuello —a un cuarto de vuelta— en vez de
  /// recorrerlo hasta cerca de la nuca, y el collar no parecía rodearlo. Antes
  /// había además un proxy de torso; cortaba la cadena en el aire sobre el
  /// pecho y con el cuello en su sitio ya no hace falta (visto en dispositivo,
  /// 2026-10-29).
  void _setupNecklace(
    three.ThreeJS viewer,
    three.Object3D model,
    List<Vec3> puntos,
  ) {
    // El giro del catálogo se aplica antes de medir: la medida supone la caída
    // hacia +z, que es hacia la cámara.
    final yaw = widget.staticYawDeg * math.pi / 180;
    final c = math.cos(yaw), s = math.sin(yaw);
    final girados = [
      for (final p in puntos) Vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z),
    ];
    final collar = measureNecklace(girados);
    if (collar == null) return;
    // El proxy de las pulseras no aplica: se deja apagado.
    _occluder?.visible = false;
    _collar = collar;
    _modelDiameter = collar.holeWidth;
    assert(
      collar.facesFront,
      'El collar cae hacia atrás: revisar orientacion_yaw_deg del catálogo.',
    );

    final girado = three.Object3D()
      ..rotation.y = yaw
      ..add(model);
    // El origen de la pieza es el eje del cuello, corrido desde el centro del
    // hueco hacia la nuca (ver [_cuelloHaciaNuca]).
    final ancho = collar.holeWidth;
    final radioCuello = ancho / _holguraDelCollar / 2;
    final centro = collar.neckCenter;
    final ejeZ = centro.z - (ancho / 2 - radioCuello) * _cuelloHaciaNuca;
    final centrado = three.Object3D()
      ..position.setValues(-centro.x, -centro.y, -ejeZ)
      ..add(girado);
    final tilt = _necklaceTiltDeg * math.pi / 180;
    final inclinado = three.Object3D()
      ..rotation.x = tilt
      ..add(centrado);

    final holder = three.Object3D()..add(inclinado);

    // Proxy de cuello: cilindro vertical desde la parte más baja de la cadena
    // que pasa por detrás del cuello, hacia arriba. Si arrancara más arriba, la
    // vuelta trasera se vería a través del cuello por debajo de él; más abajo,
    // taparía el arranque de la caída, que va por delante y debe verse.
    //
    // Solo cuenta la cadena **claramente** detrás del eje (medio radio): con
    // el collar inclinado, el arranque de la caída queda justo en el eje, y
    // contarlo bajaba la base hasta tapar los costados de la caída: el collar
    // se veía partido (visto en dispositivo, 2026-10-29).
    final ct = math.cos(tilt), st = math.sin(tilt);
    var base = double.infinity;
    for (final p in girados) {
      final y = p.y - centro.y, z = p.z - ejeZ;
      // Misma rotación que `inclinado`.
      if (st * y + ct * z < -radioCuello / 2) {
        base = math.min(base, ct * y - st * z);
      }
    }
    if (!base.isFinite) base = collar.backBottomY - centro.y;
    final altoCuello = ancho * _neckOccluderHeight;
    final cuello = three.Mesh(
      three.CylinderGeometry(radioCuello * 0.92, radioCuello, altoCuello, 48),
      three.MeshBasicMaterial.fromMap({'colorWrite': false}),
    )
      ..renderOrder = -1
      ..position.setValues(0, base + altoCuello / 2, 0);
    holder.add(cuello);
    _necklaceNeck = cuello;

    final wire = three.Mesh(
      cuello.geometry,
      three.MeshBasicMaterial.fromMap({
        'color': 0xff2020,
        'wireframe': true,
        'transparent': true,
        'opacity': 0.55,
        'depthTest': false,
        'depthWrite': false,
      }),
    )
      ..renderOrder = 10
      ..visible = widget.showOccluder;
    cuello.add(wire);
    _necklaceWire = wire;

    viewer.scene.add(holder);
    _jewel = holder;
  }

  /// Dimensiona y orienta el collar para la pose actual (la posición ya la
  /// puso `_applyAnchor`).
  ///
  /// El tamaño sale del cuello: el hueco del modelo se escala para que mida
  /// el cuello más la holgura. Escalarla por el ancho de hombros, que es lo
  /// que mide la estrategia, la dejaba unas tres veces más grande.
  void _applyNecklaceAnchor(
    three.Object3D jewel,
    AnchorPose anchor,
    double pxToWorld,
  ) {
    final collar = _collar;
    final cuelloPx = widget.neckDiameterPx;
    if (collar == null || cuelloPx == null) {
      jewel.visible = false;
      return;
    }

    // Sin base medida (iOS) se conserva el ajuste anterior: hueco igual a la
    // columna por [_holguraDelCollar].
    final basePx = widget.neckBasePx ??
        cuelloPx * _holguraDelCollar / _holguraSobreBase;
    final factor = basePx * pxToWorld * _holguraSobreBase / collar.holeWidth;
    jewel.scale.setValues(factor, factor, factor);

    // Con la base medida, el proxy se lleva a [_proxySobreHueco] del hueco.
    // Sin ella (iOS) se queda como se construyó.
    if (widget.neckBasePx != null) {
      const k = _proxySobreHueco * _holguraDelCollar;
      _necklaceNeck?.scale.setValues(k, 1, k);
    }

    // Primero el giro del torso alrededor de su vertical y después la
    // inclinación de los hombros en el plano de la imagen.
    final yaw = anchor.yawRadians ?? 0;
    final zonaMuerta = _necklaceYawDeadZoneDeg * math.pi / 180;
    final yawUtil = yaw.abs() <= zonaMuerta
        ? 0.0
        : yaw.abs() >= 2 * zonaMuerta
            ? yaw
            : yaw.sign * 2 * (yaw.abs() - zonaMuerta);
    // El giro se mide sobre la imagen: es relativo a la línea de visión hacia
    // el cuello, no al eje de la cámara. La cámara virtual vuelve a aplicar la
    // perspectiva, que con el cuello a un lado del centro empuja el frente del
    // collar hacia afuera; sin descontarla, ese empuje anulaba el giro medido
    // y el collar quedaba mirando a la cámara en vez de hacia donde mira el
    // cuerpo (visto en dispositivo, 2026-11-05: girado, con el cuello a la
    // izquierda, la caída quedaba recta).
    final linea = math.atan2(jewel.position.x, -jewel.position.z);
    final giroTorso = three.Quaternion()
      ..setFromAxisAngle(three.Vector3(0, 1, 0), yawUtil - linea);
    final inclinacion = three.Quaternion()
      ..setFromAxisAngle(
        three.Vector3(0, 0, 1),
        -anchor.rollRadians * _necklaceRollFollow,
      );
    inclinacion.multiply(giroTorso);

    jewel.quaternion.setFrom(inclinacion);
  }

  /// Monta los aretes colgados de una cabeza invisible (modo cabeza).
  ///
  /// Igual que la pulsera tiene un antebrazo invisible, el arete tiene una
  /// cabeza: un grupo en el espacio de la cabeza (ver `HeadModel`) que lleva
  /// el oclusor —cráneo, cara, cuello y un disco en cada lóbulo— y los dos
  /// aretes, cada uno colgado de su lóbulo. Los oclusores solo escriben
  /// profundidad, como el proxy de las pulseras (ADR-17):
  ///
  /// - la cara y el cráneo tapan el arete del lado lejano al girar la cabeza;
  /// - el cuello tapa un colgante largo de perfil;
  /// - el disco del lóbulo esconde el poste o el gancho detrás del lóbulo, que
  ///   es lo que hace que el arete se vea atravesándolo y no pegado encima.
  ///
  /// Todo se escala junto con el ancho de la cara medido, así que la oclusión
  /// calza con los aretes por construcción. El arete se escala con sus
  /// milímetros del catálogo contra [HeadModel.faceWidthMm] y se cuelga de su
  /// punto de sujeción (ver `measureEarring`), no del centro de su caja.
  Future<void> _setupHead(
    three.ThreeJS viewer,
    three.Object3D model,
    EarringSetup setup,
    bool hasEnvironment,
  ) async {
    // El giro del catálogo se aplica antes de medir, como en los collares.
    final yaw = widget.staticYawDeg * math.pi / 180;
    final c = math.cos(yaw), s = math.sin(yaw);
    Vec3 girar(Vec3 p) => Vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
    // Por malla: la aguja de un botón se reconoce como una malla aparte.
    final partes = [
      for (final malla in _verticesPorMalla(model))
        [for (final p in malla) girar(p)],
    ];

    final medida = measureEarring(
      partes,
      hangs: setup.hangs,
      pivot: setup.attachPoint ?? _sujecionDelModelo(model, girar),
    );
    if (medida == null || medida.length <= 0) return;
    _earMeasure = medida;

    // El proxy de las pulseras no aplica: se deja apagado.
    _occluder?.visible = false;

    final head = three.Object3D();
    _addHeadOccluder(
      head,
      three.SphereGeometry(1, 32, 24),
      position: HeadModel.craniumCenter,
      scale: HeadModel.craniumRadii,
    );
    _addHeadOccluder(
      head,
      three.SphereGeometry(1, 32, 24),
      position: HeadModel.faceCenter,
      scale: HeadModel.faceRadii,
    );
    const altoCuello = HeadModel.neckTop - HeadModel.neckBottom;
    _addHeadOccluder(
      head,
      three.CylinderGeometry(
        HeadModel.neckRadius,
        HeadModel.neckRadius,
        altoCuello,
        32,
      ),
      position: const Vec3(
        0,
        (HeadModel.neckTop + HeadModel.neckBottom) / 2,
        HeadModel.neckAxisZ,
      ),
    );

    final alto = setup.heightMm > 0 ? setup.heightMm : _defaultEarringMm;
    // De unidades del modelo a anchos de cara, que es la unidad de la cabeza.
    final k = alto / HeadModel.faceWidthMm / medida.length;
    final largoPendulo = medida.hangLength * k * HeadModel.faceWidthMm / 1000;

    for (final side in const [-1, 1]) {
      final lobulo = HeadModel.lobeFor(side);
      final normal = HeadModel.earNormal(side);

      // El grupo del lóbulo se mueve en cada pose al lóbulo medido (ver
      // `_applyHeadAnchor`); el disco y el arete van dentro.
      final enLobulo = three.Object3D()
        ..position.setValues(lobulo.x, lobulo.y, lobulo.z);
      head.add(enLobulo);

      // Disco del lóbulo: su eje (el +y del cilindro) va por la normal de la
      // cara externa, y esa cara queda en el punto de perforación.
      final disco = const Vec3(0, HeadModel.lobeDiscRaise, 0) -
          normal * (HeadModel.lobeDiscThickness / 2);
      _addHeadOccluder(
        enLobulo,
        three.CylinderGeometry(
          HeadModel.lobeDiscRadius,
          HeadModel.lobeDiscRadius,
          HeadModel.lobeDiscThickness,
          24,
        ),
        position: disco,
        rotation: three.Quaternion()
          ..setFromUnitVectors(three.Vector3(0, 1, 0), _v3(normal)),
      );

      // El segundo arete es otra carga del mismo GLB: clonar copia geometrías
      // y materiales de todos modos, y así sale por el mismo camino probado.
      final instancia = side == -1
          ? model
          : (await three.GLTFLoader().fromBytes(widget.modelBytes))?.scene;
      if (instancia == null) continue;
      _limitarMetalicidad(instancia, hasEnvironment: hasEnvironment);
      _gemasSinTransmision(instancia);

      final girado = three.Object3D()
        ..rotation.y = yaw
        ..add(instancia);
      final centrado = three.Object3D()
        ..position.setValues(-medida.pivot.x, -medida.pivot.y, -medida.pivot.z)
        ..add(girado);
      final escalado = three.Object3D()
        ..scale.setValues(k, k, k)
        ..add(centrado);
      final orientado = three.Object3D()..add(escalado);
      enLobulo.add(orientado);

      // Un botón va fijo al lóbulo: el adorno mira hacia afuera de la oreja
      // y la aguja entra por la cara externa del lóbulo.
      if (!medida.hangs) {
        orientado.quaternion.setFrom(_basisRotation(
          fromY: medida.up,
          fromZ: medida.front,
          toY: const Vec3(0, 1, 0),
          toZ: normal,
        ));
      }

      // En un botón, lo que queda detrás de la cara externa del lóbulo (la
      // aguja y el cierre) está dentro del lóbulo o detrás de él, y no se ve
      // desde ningún ángulo. El disco del lóbulo lo tapa de lado, pero de
      // frente queda casi de canto y el cierre asomaba junto a la mejilla
      // (visto en dispositivo, 2026-11-08). Un plano de recorte en esa cara lo
      // quita siempre. A un colgante o aro no se le aplica: parte de él cuelga
      // de verdad por detrás del lóbulo.
      three.Plane? recorte;
      if (!medida.hangs) {
        recorte = three.Plane(three.Vector3(1, 0, 0), 0);
        _recortar(instancia, recorte);
      }

      _ears.add(_Ear(
        side: side,
        holder: enLobulo,
        orient: orientado,
        pendulum: medida.hangs ? Pendulum(length: largoPendulo) : null,
        clip: recorte,
      ));
    }

    // La cabeza va dentro de un grupo que la sitúa en pantalla y le comprime
    // la profundidad (ver `_headDepthScale`). La compresión va por fuera de la
    // rotación: es a lo largo de la línea de visión, no del eje de la cara.
    final profundidad = three.Object3D()..add(head);
    viewer.scene.add(profundidad);
    _jewel = profundidad;
    _headGroup = head;

    // El balanceo va al ritmo del render, no del tracking: entre dos poses el
    // arete sigue oscilando.
    if (medida.hangs) viewer.addAnimationEvent(_swing);
  }

  /// Punto de sujeción marcado en el GLB con un nodo vacío llamado
  /// `sujecion` (ver D1), ya girado con el giro del catálogo, o `null`.
  static Vec3? _sujecionDelModelo(
    three.Object3D model,
    Vec3 Function(Vec3) girar,
  ) {
    final nodo = model.getObjectByName('sujecion');
    if (nodo == null) return null;
    model.updateMatrixWorld(true);
    final p = three.Vector3().setFromMatrixPosition(nodo.matrixWorld);
    return girar(Vec3(p.x, p.y, p.z));
  }

  /// Añade a [head] (la cabeza o el grupo de un lóbulo) un sólido que solo
  /// escribe profundidad, con su silueta de diagnóstico.
  void _addHeadOccluder(
    three.Object3D head,
    three.BufferGeometry geometry, {
    required Vec3 position,
    Vec3 scale = const Vec3(1, 1, 1),
    three.Quaternion? rotation,
  }) {
    final mesh = three.Mesh(
      geometry,
      three.MeshBasicMaterial.fromMap({'colorWrite': false}),
    )
      ..renderOrder = -1
      ..position.setValues(position.x, position.y, position.z)
      ..scale.setValues(scale.x, scale.y, scale.z);
    if (rotation != null) mesh.quaternion.setFrom(rotation);

    final wire = three.Mesh(
      geometry,
      three.MeshBasicMaterial.fromMap({
        'color': 0xff2020,
        'wireframe': true,
        'transparent': true,
        'opacity': 0.35,
        'depthTest': false,
        'depthWrite': false,
      }),
    )
      ..renderOrder = 10
      ..visible = widget.showOccluder;
    mesh.add(wire);
    _headWires.add(wire);
    head.add(mesh);
  }

  /// Sitúa y orienta la cabeza para la pose actual (la posición del grupo
  /// exterior ya la puso `_applyAnchor`).
  void _applyHeadAnchor(
    three.Object3D jewel,
    AnchorPose anchor,
    double pxToWorld,
    Size area,
  ) {
    final head = _headGroup;
    final axes = anchor.headAxes;
    final ancho = anchor.scale;
    if (head == null || axes == null || ancho == null || ancho <= 0) {
      jewel.visible = false;
      return;
    }

    final anchoWorld = widget.fit.lengthOf(ancho) * pxToWorld;
    head.scale.setValues(anchoWorld, anchoWorld, anchoWorld);
    _headWorldWidth = anchoWorld;

    // La rotación de la malla ya es la de la cámara: el render en perspectiva
    // con la cabeza en su sitio de la pantalla la ve desde el mismo ángulo.
    final base = three.Matrix4()
      ..makeBasis(_v3(axes.x), _v3(axes.y), _v3(axes.z));
    head.quaternion.setFromRotationMatrix(base);
    final compresion = _headDepthScale(area);
    jewel.scale.setValues(1, 1, compresion);

    final lado = anchor.earringSide;
    for (final ear in _ears) {
      ear.holder.visible = lado == null || lado == ear.side;
      // El lóbulo medido en este frame, o el fijo del modelo si no se midió.
      final lobulo = anchor.lobeFor(ear.side) ?? HeadModel.lobeFor(ear.side);
      ear.holder.position.setValues(lobulo.x, lobulo.y, lobulo.z);
      final recorte = ear.clip;
      if (recorte != null) {
        _ubicarRecorte(
          recorte,
          ear.side,
          lobulo,
          head,
          jewel,
          anchoWorld,
          compresion,
        );
      }
    }
  }

  /// Cuánto por dentro de la cara del lóbulo va el plano de recorte, en
  /// anchos de cara (~0,6 mm): lo justo para no comerse el respaldo del
  /// adorno.
  static const double _clipInset = 0.004;

  /// Lleva el plano de recorte de un botón a la cara externa de su lóbulo, en
  /// coordenadas de mundo (que es donde los evalúa el render).
  ///
  /// La cabeza se escala y se gira dentro de un grupo que comprime la
  /// profundidad ([compresion] en z): el punto sigue la transformación entera
  /// y la normal la inversa transpuesta, que con la compresión ya no es la
  /// misma.
  static void _ubicarRecorte(
    three.Plane recorte,
    int side,
    Vec3 lobulo,
    three.Object3D head,
    three.Object3D grupo,
    double anchoWorld,
    double compresion,
  ) {
    final n = HeadModel.earNormal(side);
    final l = lobulo - n * _clipInset;
    final punto = three.Vector3(l.x, l.y, l.z)
      ..scale(anchoWorld)
      ..applyQuaternion(head.quaternion);
    punto.z *= compresion;
    punto.add(grupo.position);
    final normal = three.Vector3(n.x, n.y, n.z)..applyQuaternion(head.quaternion);
    normal.z /= compresion;
    normal.normalize();
    recorte.setFromNormalAndCoplanarPoint(normal, punto);
  }

  /// Cambia la transmisión de las gemas (`KHR_materials_transmission`) por un
  /// material opaco y muy pulido, la aproximación que fija D1 §4.4.
  ///
  /// `three_js` no dibuja bien la transmisión: en dispositivo (2026-11-08) la
  /// misma piedra salía casi negra en un arete y blanca en el otro. Opaca y
  /// sin metalicidad se veía como un disco blanco plano, saturada por las
  /// luces de la escena. Como un espejo pulido refleja el entorno HDR, con
  /// sus luces y sombras, que es lo que se lee como el brillo de una gema
  /// tallada.
  static void _gemasSinTransmision(three.Object3D model) {
    void ajustar(three.Material? material) {
      if (material is three.GroupMaterial) {
        material.children.forEach(ajustar);
        return;
      }
      if (material == null || material.transmission <= 0) return;
      material.transmission = 0;
      if (material is three.MeshStandardMaterial) {
        material.metalness = 1;
        material.roughness = 0.02;
      }
    }

    model.traverse((object) => ajustar(object.material));
  }

  /// Pone [recorte] en todos los materiales de [model]: se dibuja solo lo que
  /// queda del lado al que apunta su normal.
  static void _recortar(three.Object3D model, three.Plane recorte) {
    void aplicar(three.Material? material) {
      if (material is three.GroupMaterial) {
        material.children.forEach(aplicar);
      } else if (material != null) {
        material.clippingPlanes = [recorte];
      }
    }

    model.traverse((object) => aplicar(object.material));
  }

  /// Cuánto se comprime la profundidad de la cabeza a lo largo de la línea de
  /// visión para que tenga la perspectiva de la imagen.
  ///
  /// La cámara virtual abre [_hfovDeg] sobre el área visible, más que la
  /// cámara que supone MediaPipe ([HeadModel.cameraVerticalFovDeg] en vertical,
  /// ~44° en horizontal para un frame de 480×720). Con la cara escalada a su
  /// tamaño en pantalla, eso pone la cabeza virtual relativamente más cerca
  /// que la real y exagera la perspectiva: girada, el lóbulo cercano se
  /// dibujaba ~20 mm más afuera que donde caía en la imagen, y de frente la
  /// cara tapaba el arete del otro lado (visto en dispositivo, 2026-11-08).
  /// Lo que la perspectiva desplaza es proporcional a la profundidad dividida
  /// por la distancia, así que comprimir la profundidad en la razón de los
  /// dos campos de visión la iguala sin mover nada en el plano de la imagen.
  double _headDepthScale(Size area) {
    final fit = widget.fit;
    final mostrado = fit.imageWidth * fit.scale;
    if (mostrado <= 0 || fit.imageHeight <= 0) return 1;
    final tanReal = mediapipeTanHalfWidth(fit.imageWidth / fit.imageHeight) *
        (area.width / mostrado);
    final tanVirtual = math.tan(_hfovDeg * math.pi / 360);
    return (tanReal / tanVirtual).clamp(0.3, 1.5);
  }

  /// Avanza el péndulo de cada arete que cuelga y lo orienta según él.
  ///
  /// Se simula en metros: con la cabeza a escala real ([HeadModel.faceWidthMm])
  /// la gravedad y el largo del arete dan la frecuencia natural de un arete de
  /// verdad. La profundidad del origen de la cabeza se descuenta: es fija en la
  /// escena, y con ella cada cambio de tamaño de la cara movería el lóbulo
  /// hacia la cámara y lo haría balancearse.
  void _swing(double dt) {
    final grupo = _jewel;
    final head = _headGroup;
    final medida = _earMeasure;
    if (grupo == null || head == null || medida == null) return;
    if (_headWorldWidth <= 0 || !grupo.visible) return;

    final metros = HeadModel.faceWidthMm / 1000 / _headWorldWidth;
    final aLocal = head.quaternion.clone()..invert();

    for (final ear in _ears) {
      final pendulo = ear.pendulum;
      if (pendulo == null) continue;
      // En el espacio real, sin la compresión de profundidad del render: el
      // péndulo simula la física, no lo que se dibuja.
      final w = ear.holder.position.clone()
        ..scale(_headWorldWidth)
        ..applyQuaternion(head.quaternion)
        ..add(grupo.position);
      final sujecion = Vec3(w.x, w.y, w.z + _depth) * metros;
      final d = pendulo.step(sujecion, dt);
      final dLocal = three.Vector3(d.x, d.y, d.z)..applyQuaternion(aLocal);
      final abajo = Vec3(dLocal.x, dLocal.y, dLocal.z).normalized();

      // La cara del adorno sigue mirando hacia afuera de la oreja, todo lo
      // que permite la dirección en que cuelga.
      final normal = HeadModel.earNormal(ear.side);
      var frente = normal - abajo * normal.dot(abajo);
      if (frente.length < 1e-6) frente = const Vec3(0, 0, 1);

      ear.orient.quaternion.setFrom(_basisRotation(
        fromY: medida.up,
        fromZ: medida.front,
        toY: -abajo,
        toZ: frente.normalized(),
      ));
    }
  }

  /// Rotación que lleva una base (y, z) del modelo a otra (y, z) de destino.
  /// En las dos se conserva la `y` y se endereza la `z`.
  static three.Quaternion _basisRotation({
    required Vec3 fromY,
    required Vec3 fromZ,
    required Vec3 toY,
    required Vec3 toZ,
  }) {
    three.Quaternion base(Vec3 y, Vec3 z) {
      final ejes = HeadAxes.orthonormal(y, z);
      // `orthonormal` conserva su primer argumento: aquí la y.
      final uy = ejes?.x ?? const Vec3(0, 1, 0);
      final uz = ejes?.y ?? const Vec3(0, 0, 1);
      final ux = uy.cross(uz);
      final m = three.Matrix4()..makeBasis(_v3(ux), _v3(uy), _v3(uz));
      return three.Quaternion()..setFromRotationMatrix(m);
    }

    final desde = base(fromY, fromZ);
    final hacia = base(toY, toZ);
    return hacia..multiply(desde..invert());
  }

  static three.Vector3 _v3(Vec3 v) => three.Vector3(v.x, v.y, v.z);

  /// Recorta la metalicidad de los materiales a [_metalnessMax].
  static void _limitarMetalicidad(
    three.Object3D model, {
    required bool hasEnvironment,
  }) {
    void limitar(three.Material? material) {
      if (material is three.GroupMaterial) {
        material.children.forEach(limitar);
      } else if (material is three.MeshStandardMaterial) {
        // Con HDR, conservamos la metalicidad PBR del archivo.
        // Sin HDR, mantenemos el limite anterior para evitar metal negro.
        if (!hasEnvironment) {
          material.metalness = math.min(material.metalness, _metalnessMax);
        }
      }
    }

    model.traverse((object) => limitar(object.material));
  }

  /// Vértices del modelo en su espacio, con las transformaciones de sus nodos
  /// aplicadas — el mismo recorrido que hace la caja envolvente.
  static List<Vec3> _vertices(three.Object3D model) {
    model.updateMatrixWorld(true);
    final puntos = <Vec3>[];
    final v = three.Vector3();
    model.traverse((object) {
      final position = object.geometry?.attributes['position'];
      if (position is! three.BufferAttribute) return;
      for (var i = 0; i < position.count; i++) {
        v.fromBuffer(position, i).applyMatrix4(object.matrixWorld);
        puntos.add(Vec3(v.x, v.y, v.z));
      }
    });
    return puntos;
  }

  /// Igual que [_vertices], pero separados por malla.
  static List<List<Vec3>> _verticesPorMalla(three.Object3D model) {
    model.updateMatrixWorld(true);
    final mallas = <List<Vec3>>[];
    final v = three.Vector3();
    model.traverse((object) {
      final position = object.geometry?.attributes['position'];
      if (position is! three.BufferAttribute) return;
      mallas.add([
        for (var i = 0; i < position.count; i++)
          () {
            v.fromBuffer(position, i).applyMatrix4(object.matrixWorld);
            return Vec3(v.x, v.y, v.z);
          }(),
      ]);
    });
    return mallas;
  }

  static (Vec3, Vec3) _limites(List<Vec3> puntos) {
    var minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity, maxZ = -double.infinity;
    for (final p in puntos) {
      minX = math.min(minX, p.x);
      minY = math.min(minY, p.y);
      minZ = math.min(minZ, p.z);
      maxX = math.max(maxX, p.x);
      maxY = math.max(maxY, p.y);
      maxZ = math.max(maxZ, p.z);
    }
    return (Vec3(minX, minY, minZ), Vec3(maxX, maxY, maxZ));
  }

  @override
  void didUpdateWidget(covariant JewelryScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _occluderWire?.visible = widget.showOccluder;
    _necklaceWire?.visible = widget.showOccluder;
    for (final wire in _headWires) {
      wire.visible = widget.showOccluder;
    }
    _applyAnchor();
  }

  /// Campo de visión vertical que corresponde a [_hfovDeg] con este aspecto.
  static double _fovYFor(double aspect) {
    final halfH = math.tan(_hfovDeg * math.pi / 180 / 2) / aspect;
    return 2 * math.atan(halfH) * 180 / math.pi;
  }

  /// Dirección del eje de menor extensión de una caja.
  static three.Vector3 _menorExtension(three.Vector3 size) {
    if (size.x <= size.y && size.x <= size.z) return three.Vector3(1, 0, 0);
    if (size.y <= size.z) return three.Vector3(0, 1, 0);
    return three.Vector3(0, 0, 1);
  }

  /// Sitúa, dimensiona y orienta la joya para la pose actual.
  ///
  /// Hay dos caminos. Con reconstrucción métrica la pieza se coloca a su
  /// **distancia real** y se dimensiona con los milímetros del catálogo, así
  /// que su tamaño en pantalla sale de la geometría; sin ella se cae al
  /// comportamiento anterior, con el tamaño pedido en píxeles.
  void _applyAnchor() {
    final jewel = _jewel;
    final area = _area;
    final anchor = widget.anchor;
    if (jewel == null || area == null) return;

    // Sin pose no se dibuja, en vez de dejarla clavada donde estaba. El proxy
    // tampoco: no tapa nada, pero su silueta de diagnóstico quedaba flotando.
    jewel.visible = anchor != null;
    if (anchor == null) {
      _occluder?.visible = false;
      // La cabeza puede reaparecer en otro sitio: los aretes vuelven a colgar
      // en reposo en vez de salir disparados hacia allá.
      for (final ear in _ears) {
        ear.pendulum?.clear();
      }
      return;
    }

    final aspect = area.width / area.height;
    final tanHalfV = math.tan(_fovYFor(aspect) * math.pi / 180 / 2);

    final halfHeight = _depth * tanHalfV;
    final halfWidth = halfHeight * aspect;

    // El ancla llega normalizada al frame; se pasa por el mismo mapeo `cover`
    // que la vista previa y de ahí a coordenadas de la cámara virtual.
    final screenX = widget.fit.xOf(anchor.position.x);
    final screenY = widget.fit.yOf(anchor.position.y);
    final ndcX = screenX / area.width * 2 - 1;
    final ndcY = 1 - screenY / area.height * 2;

    jewel.position.setValues(ndcX * halfWidth, ndcY * halfHeight, -_depth);

    if (widget.necklace) {
      _applyNecklaceAnchor(jewel, anchor, 2 * halfWidth / area.width);
      return;
    }

    if (widget.earring != null) {
      _applyHeadAnchor(jewel, anchor, 2 * halfWidth / area.width, area);
      return;
    }

    // El tamaño se pide en píxeles y se traduce al ancho de mundo que ocupan a
    // esta distancia.
    final targetWorld = widget.targetSizePx / area.width * (2 * halfWidth);

    final limbPx = widget.limbDiameterPx;
    // Lo que llega es el ancho de la **silueta** del brazo, tal como se ve.
    // Se pasa al eje mayor de su sección, que es lo que el aro debe rodear.
    final limbWorld = limbPx == null
        ? 0.0
        : limbPx /
            area.width *
            (2 * halfWidth) /
            _silhouetteRatio(anchor, jewel.position);

    // Hueco del aro en unidades del modelo, medido sobre los vértices. Antes
    // se deducía de la caja (exterior menos dos veces su menor extensión) y
    // subestimaba el hueco hasta un 20 %, lo que agrandaba la pieza en la
    // misma proporción y de forma distinta en cada modelo.
    final aro = _aro;
    final huecoModelo = aro?.holeDiameter ?? 0;
    final esAro = aro != null;

    // **Lo que tiene que encajar es el hueco alrededor del brazo**, no el
    // diámetro exterior contra una medida cualquiera. Escalando por el exterior
    // el hueco salía más estrecho que el antebrazo —medido: 192 px de hueco
    // para 228 de brazo—, o sea que la pieza era fisicamente incapaz de
    // rodearlo, y eso es lo que se veía como que no cierra.
    //
    // Sin forma de aro reconocible no hay hueco que ajustar y se cae al
    // comportamiento anterior.
    final factor = (esAro && limbWorld > 0)
        ? limbWorld * _holguraDelAro / huecoModelo
        : targetWorld / _modelDiameter;

    jewel.scale.setValues(factor, factor, factor);
    _huecoWorld = esAro ? huecoModelo * factor : 0;

    _applyOrientation(jewel, anchor);
    _applyOccluder(anchor, jewel, limbWorld);
  }

  /// Silueta visible de la sección del brazo respecto a su eje mayor.
  ///
  /// La sección no es redonda ([_occluderFlatness]) y gira con la palma. De
  /// frente se ve el lado ancho y la relación es 1; con la mano de canto se ve
  /// el angosto y baja a 0,75. Sin esta corrección, en esa pose el proxy y el
  /// hueco del aro salían un 25 % más estrechos que el brazo medido (165 px de
  /// brazo contra 125 de proxy, en dispositivo el 2026-10-13).
  double _silhouetteRatio(AnchorPose anchor, three.Vector3 position) {
    final axis = anchor.axis3D;
    final palma = anchor.palmNormal3D;
    if (axis == null || palma == null) return 1;

    final n = three.Vector3(axis.x, -axis.y, -axis.z)..normalize();
    final normalPalma = three.Vector3(-palma.x, palma.y, palma.z)..normalize();
    final ancho = n.clone()..cross(normalPalma);
    // Dirección en la que se mide la silueta: perpendicular al eje del brazo
    // y a la línea de visión hacia la pieza.
    final vista = position.clone()..normalize();
    final silueta = n.clone()..cross(vista);
    if (ancho.length < 1e-6 || silueta.length < 1e-6) return 1;
    ancho.normalize();
    silueta.normalize();
    final grosor = n.clone()..cross(ancho);

    final c = ancho.dot(silueta);
    final g = grosor.dot(silueta) * _occluderFlatness;
    return math.sqrt(c * c + g * g).clamp(_occluderFlatness, 1.0);
  }

  /// Sitúa el cilindro de oclusión sobre la extremidad.
  ///
  /// Solo se activa cuando hay eje 3D: sin él no se sabe hacia dónde va el
  /// miembro, y un cilindro mal orientado taparía lo que no debe. Sin oclusión
  /// la pieza se ve entera, que es el comportamiento anterior — peor, pero no
  /// erróneo.
  void _applyOccluder(
    AnchorPose anchor,
    three.Object3D jewel,
    double limbDiameterWorld,
  ) {
    final occluder = _occluder;
    final axis = anchor.axis3D;
    if (occluder == null) return;

    // Sin eje 3D no se sabe hacia donde va el miembro; sin hueco, la pieza no
    // rodea nada y no hay nada que ocluir.
    occluder.visible = axis != null && limbDiameterWorld > 0;
    if (axis == null || limbDiameterWorld <= 0) return;

    occluder.position.setFrom(jewel.position);

    // El brazo no puede ser más ancho que el hueco por el que pasa la pieza.
    // La estimación anatómica ignora la pieza, así que puede pedir un proxy
    // más gordo que el aro; entonces lo atraviesa y tapa lo que sí debe verse.
    final ancho = _huecoWorld > 0
        ? math.min(limbDiameterWorld, _huecoWorld * _occluderHoleMargin)
        : limbDiameterWorld;

    occluder.scale.setValues(
      ancho,
      ancho * _occluderLengthRatio,
      ancho * _occluderFlatness,
    );

    // El proxy nace con su eje en +Y. Se alinea con el antebrazo y además se
    // gira sobre ese eje para que su lado ancho quede de lado a lado del brazo
    // —perpendicular a la normal de la palma—, que es como está achatado de
    // verdad. Sin ese giro, el achatamiento caería en una dirección arbitraria.
    final n = three.Vector3(axis.x, -axis.y, -axis.z)..normalize();
    final alinear = three.Quaternion()
      ..setFromUnitVectors(three.Vector3(0, 1, 0), n);

    final palma = anchor.palmNormal3D;
    if (palma == null) {
      occluder.quaternion.setFrom(alinear);
      return;
    }

    final normalPalma = three.Vector3(-palma.x, palma.y, palma.z)..normalize();
    final ancho3D = (n.clone()..cross(normalPalma));
    if (ancho3D.length < 1e-6) {
      occluder.quaternion.setFrom(alinear);
      return;
    }
    ancho3D.normalize();

    final xTrasAlinear = three.Vector3(1, 0, 0)..applyQuaternion(alinear);
    final cos = xTrasAlinear.dot(ancho3D).clamp(-1.0, 1.0);
    final sin = (xTrasAlinear.clone()..cross(ancho3D)).dot(n);
    final girar = three.Quaternion()
      ..setFromAxisAngle(n, math.atan2(sin, cos));

    occluder.quaternion.setFrom(girar..multiply(alinear));
  }

  void _applyOrientation(three.Object3D jewel, AnchorPose anchor) {
    final axis = anchor.axis3D;

    if (axis == null) {
      // Sin eje real solo queda girar en el plano de la pantalla, mas el yaw
      // y el cabeceo que reporte la estrategia (aretes: angulos de cabeza de
      // ML Kit Face, ver EarringStrategy).
      jewel.rotation.z = -(anchor.rollRadians + widget.rollOffset);
      jewel.rotation.y =
          widget.staticYawDeg * math.pi / 180 + (anchor.yawRadians ?? 0);
      jewel.rotation.x = anchor.pitchRadians ?? 0;
      return;
    }

    // El eje llega en el marco del detector (y hacia abajo, z alejándose) y la
    // escena usa el de la cámara (y hacia arriba, z hacia el espectador).
    final n = three.Vector3(axis.x, -axis.y, -axis.z)..normalize();

    // Primero se alinea el eje del aro con el del antebrazo. Queda libre el
    // giro **alrededor** de ese eje, que es el que decide qué parte de la
    // pieza mira al usuario.
    final alinear = three.Quaternion()..setFromUnitVectors(_ringAxisLocal, n);

    // Ese giro libre se ata al **dorso de la mano**, no a la cámara. Atarlo a
    // la cámara mantiene el detalle siempre de frente, pero entonces la pieza
    // contrarrota al girar la muñeca y parece congelada, perdiendo justo la
    // señal de que está puesta en el brazo (visto en dispositivo). Siguiendo la
    // palma, la pieza gira con la muñeca y el detalle queda arriba con la palma
    // apoyada, que es la pose natural.
    final refWorld = _perpendicularTo(_ringAxisLocal)..applyQuaternion(alinear);

    final palma = anchor.palmNormal3D;
    var giroRadianes = widget.staticYawDeg * math.pi / 180;

    if (palma != null) {
      // Signo invertido: se apunta al **dorso** de la mano, no a la palma.
      // Es el lado que queda arriba con la palma apoyada en la mesa, que es
      // como se lleva una pulsera y como el usuario espera ver el detalle.
      final referencia = three.Vector3(-palma.x, palma.y, palma.z)
        ..normalize();

      // Solo interesa su componente dentro del plano del aro.
      final proyeccion = n.clone()..scale(referencia.dot(n));
      final destino = referencia.clone()..sub(proyeccion);

      if (destino.length > 1e-6) {
        destino.normalize();
        // Ángulo con signo de `refWorld` a `destino`, medido alrededor de `n`.
        final cos = destino.dot(refWorld).clamp(-1.0, 1.0);
        final sin = (refWorld.clone()..cross(destino)).dot(n);
        giroRadianes += math.atan2(sin, cos);
      }
    } else if (anchor.yawRadians != null) {
      // Sin normal de palma (eje 3D aproximado sin reconstrucción métrica —
      // ver `BraceletStrategy._planarAxis`, hoy el caso de iOS) no hay con qué
      // calcular el giro por geometría. Un valor fijo de referencia (p. ej. la
      // cámara) deja la pieza sin girar con la muñeca — visto en dispositivo:
      // "no rota cuando giro la muñeca". Se usa en cambio el yaw 2D que la
      // estrategia sí calcula siempre (aproximado, sin profundidad real, pero
      // responde al giro real de la muñeca en vez de ignorarlo).
      //
      // Signo invertido respecto a como se usaba antes (`jewel.rotation.y +=
      // yawRadians` directo sobre el eje Y del mundo): aquí el giro es
      // alrededor de `n` (el eje real del antebrazo), no de Y, y around un eje
      // distinto la misma magnitud puede verse al revés. Confirmado al revés
      // en dispositivo (2026-10-23): girar la muñeca hacia adentro giraba la
      // pulsera hacia afuera.
      giroRadianes -= anchor.yawRadians!;
    }
    // Sin palma ni yaw, se queda solo con el yaw estático del catálogo: la
    // pieza no gira con la muñeca, pero tampoco salta a un valor inventado.

    // El giro es alrededor de un eje ya en coordenadas de mundo, así que se
    // aplica después de la alineación.
    final girar = three.Quaternion()..setFromAxisAngle(n, giroRadianes);
    jewel.quaternion.setFrom(girar..multiply(alinear));
  }

  /// Un unitario cualquiera perpendicular a [v]. Sirve de referencia para
  /// medir el giro alrededor del eje del aro; cuál de todos los
  /// perpendiculares sea da igual, porque el desfase hasta el detalle de la
  /// pieza lo aporta `orientacion_yaw_deg` del catálogo.
  static three.Vector3 _perpendicularTo(three.Vector3 v) {
    final auxiliar =
        v.x.abs() < 0.9 ? three.Vector3(1, 0, 0) : three.Vector3(0, 1, 0);
    return (auxiliar..cross(v)).normalize();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = Size(constraints.maxWidth, constraints.maxHeight);
        if (_viewer == null && area.width > 0 && area.height > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _viewer == null) _createViewer(area);
          });
        }
        return IgnorePointer(
          child: _viewer?.build() ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Un arete colgado de su lóbulo, en modo cabeza.
class _Ear {
  /// Lado de la cabeza: -1 o +1 en x local.
  final int side;

  /// Grupo en el lóbulo, hijo de la cabeza.
  final three.Object3D holder;

  /// Orientación del arete respecto a la cabeza: fija en un botón, la del
  /// péndulo en uno que cuelga.
  final three.Object3D orient;

  /// `null` en un botón, que no cuelga.
  final Pendulum? pendulum;

  /// Plano que recorta lo que queda detrás del lóbulo, solo en un botón.
  final three.Plane? clip;

  const _Ear({
    required this.side,
    required this.holder,
    required this.orient,
    required this.pendulum,
    this.clip,
  });
}
