import 'dart:math' as math;

import 'geometry.dart';

/// Orientación de la cabeza como sus ejes locales x e y, unitarios y
/// perpendiculares, expresados en el marco de la escena: x hacia la derecha de
/// la pantalla, y hacia arriba, z hacia quien mira.
///
/// Con la cabeza de frente a la cámara, x va de una mejilla a la otra
/// (izquierda a derecha de la pantalla), y de la barbilla a la frente y z sale
/// por la nariz.
class HeadAxes {
  final Vec3 x, y;

  const HeadAxes(this.x, this.y);

  /// Hacia donde mira la cara.
  Vec3 get z => x.cross(y);

  /// Lleva un punto del espacio de la cabeza al de la escena (sin escalar ni
  /// trasladar).
  Vec3 apply(Vec3 local) => x * local.x + y * local.y + z * local.z;

  /// Ejes ortonormales a partir de dos direcciones aproximadas: se conserva
  /// [x] y se endereza [y]. `null` si son paralelas o nulas.
  static HeadAxes? orthonormal(Vec3 x, Vec3 y) {
    if (x.length < 1e-9) return null;
    final ux = x.normalized();
    final yPerp = y - ux * y.dot(ux);
    if (yPerp.length < 1e-6) return null;
    return HeadAxes(ux, yPerp.normalized());
  }

  /// La misma pose vista en un espejo vertical (x → -x de la pantalla).
  ///
  /// El espejo no es una rotación, pero conjugarla con él sí lo es: `M·R·M`
  /// con `M = diag(-1, 1, 1)`. El precio es que el +x local pasa a ser el
  /// otro lado de la cara (ver `HeadObservation.mirrored`).
  HeadAxes mirrored() => HeadAxes(
        Vec3(x.x, -x.y, -x.z),
        Vec3(-y.x, y.y, y.z),
      );
}

/// Extrae la rotación de la matriz de transformación facial de MediaPipe
/// (`facialTransformationMatrixes`), una 4×4 rígida de 16 valores.
///
/// MediaPipe la entrega **por columnas** (la traslación en 12–14), igual que la
/// lee three.js; por si alguna versión la diera por filas, se reconoce por
/// dónde está la traslación, que nunca es nula porque la cara está a decenas de
/// centímetros. El marco es el de la cámara de MediaPipe sobre la imagen sin
/// espejar: x a la derecha, y arriba, z hacia la cámara.
///
/// `null` si no tiene 16 valores o la rotación es degenerada.
HeadAxes? headAxesFromMatrix(List<double> m) {
  if (m.length != 16) return null;
  final porColumnas = m[12].abs() + m[13].abs() + m[14].abs() >=
      m[3].abs() + m[7].abs() + m[11].abs();
  // Elemento (fila r, columna c) de la parte 3×3.
  double e(int r, int c) => porColumnas ? m[c * 4 + r] : m[r * 4 + c];
  return HeadAxes.orthonormal(
    Vec3(e(0, 0), e(1, 0), e(2, 0)),
    Vec3(e(0, 1), e(1, 1), e(2, 1)),
  );
}

/// Un punto normalizado de la imagen (x al ancho, y al alto, z de MediaPipe en
/// la escala de x) en el marco de la escena, con unidades del ancho del frame.
///
/// [aspect] es ancho/alto del frame vertical. La `z` de MediaPipe crece al
/// alejarse y la `y` de la imagen hacia abajo: las dos cambian de signo.
Vec3 imageToScene(Vec3 p, double aspect) => Vec3(p.x, -p.y / aspect, -p.z);

/// Inversa de [imageToScene].
Vec3 sceneToImage(Vec3 p, double aspect) => Vec3(p.x, -p.y * aspect, -p.z);

/// La cabeza invisible de la que cuelgan los aretes, en su propio espacio.
///
/// **Unidades:** el ancho de la cara entre los puntos 234 y 454 de la malla
/// (de mejilla a mejilla, delante de cada oreja) vale 1. El origen es el punto
/// medio entre los dos; x va hacia cada oreja, y hacia arriba y z hacia la
/// nariz. Como el render escala todo junto con el ancho medido, un error en
/// [faceWidthMm] no desalinea la oclusión: solo cambia el tamaño real del
/// arete.
///
/// **Todas las medidas son de partida**, sacadas de proporciones adultas
/// promedio y no medidas en dispositivo. Se calibran con el alambre de
/// diagnóstico (botón de diana): los lóbulos se dibujan como puntos amarillos
/// y los oclusores en rojo.
abstract final class HeadModel {
  /// Ancho real supuesto entre los puntos 234 y 454, en milímetros. Están
  /// delante del trago, así que es algo menos que el ancho bitragial adulto
  /// (~14–15 cm).
  static const double faceWidthMm = 145;

  /// Punto de perforación del lóbulo del lado +x: a la altura de la base de la
  /// nariz, por debajo de los puntos 234/454 y apenas por detrás.
  ///
  /// **Medido en dispositivo** (2026-11-08, Galaxy A15, una persona, contra
  /// una argolla real, con capturas del overlay de diagnóstico):
  ///
  /// - Con el valor de partida `(0.52, -0.19, -0.05)`, de frente, el punto
  ///   quedaba ~3–4 mm por fuera del lóbulo y a la altura de la perforación.
  /// - Se bajó a -0,235 por una captura de lado, y de frente el botón quedó
  ///   ~7 mm por debajo de la perforación, en la unión con la mandíbula. La
  ///   captura de lado engañaba: el punto amarillo se dibujaba sin
  ///   perspectiva, y con la cabeza girada el lóbulo cercano cae más abajo
  ///   en la imagen de lo que marcaba. Se volvió a -0,19, la medida de
  ///   frente, donde la perspectiva casi no influye.
  /// - De lado (girado ~32°), con los ejes de la matriz, el botón quedaba
  ///   ~9 mm hacia la nuca de la perforación. Desde que la x sale de las
  ///   mejillas medidas (ver `EarringStrategy._headAxes`), el ±0,5 cae en
  ///   ellas: eso solo adelantó el botón unos 5 mm.
  /// - Se probó z = -0,13 suponiendo que 234/454 quedaban 1 cm por delante
  ///   de la oreja, y el botón se fue ~12 mm atrás. De lado, los puntos caen
  ///   en el borde delantero de la oreja, a la altura del trago: la
  ///   perforación queda prácticamente a su misma profundidad.
  static const Vec3 lobe = Vec3(0.50, -0.19, 0.0);

  /// Campo de visión vertical que supone MediaPipe para el frame que recibe
  /// (el entorno por defecto de su geometría facial). La rotación de la
  /// cabeza viene ajustada con él, y el render lo usa para que la cabeza
  /// tenga la misma perspectiva que en la imagen (ver `_applyHeadAnchor`).
  static const double cameraVerticalFovDeg = 63;

  /// Cuánto se abre la oreja hacia adelante: la cara externa del lóbulo no
  /// mira justo de lado sino algo hacia la nariz.
  static const double earFlareDeg = 15;

  /// Cráneo: elipsoide (centro y semiejes). Tapa el arete del lado lejano al
  /// girar la cabeza. A la altura del lóbulo mide 0,40 de ancho a cada lado:
  /// el lóbulo sobresale de él y el arete cercano no se tapa.
  static const Vec3 craniumCenter = Vec3(0, 0.18, -0.12);
  static const Vec3 craniumRadii = Vec3(0.47, 0.72, 0.66);

  /// Cara y mandíbula: elipsoide hasta la barbilla y la nariz.
  static const Vec3 faceCenter = Vec3(0, -0.30, 0.18);
  static const Vec3 faceRadii = Vec3(0.40, 0.58, 0.48);

  /// Cuello: cilindro vertical (radio, eje en z, alto de arriba y de abajo).
  /// Un colgante largo se esconde detrás de él de perfil.
  static const double neckRadius = 0.36;
  static const double neckAxisZ = -0.18;
  static const double neckTop = -0.35;
  static const double neckBottom = -1.9;

  /// Disco del lóbulo: lo bastante grande para que el poste o el gancho lo
  /// atraviesen, y no tanto como para tapar el adorno. Su cara externa queda
  /// en el punto de perforación; el centro, un poco más arriba, porque la
  /// perforación va en la parte baja del lóbulo.
  static const double lobeDiscRadius = 0.06;
  static const double lobeDiscThickness = 0.03;
  static const double lobeDiscRaise = 0.012;

  /// Lóbulo del lado [side] (+1 o -1 en x).
  static Vec3 lobeFor(int side) => Vec3(side * lobe.x, lobe.y, lobe.z);

  /// Normal hacia afuera de la cara externa del lóbulo del lado [side].
  static Vec3 earNormal(int side) {
    final a = earFlareDeg * math.pi / 180;
    return Vec3(side * math.cos(a), 0, math.sin(a));
  }
}

/// Dónde cae en la imagen un punto del espacio de la cabeza.
///
/// [origin] es el origen de la cabeza en coordenadas normalizadas de imagen,
/// [width] el ancho de cara en fracciones del ancho del frame y [aspect] el
/// ancho/alto del frame. Es lo que dibuja el overlay de diagnóstico para
/// calibrar el lóbulo.
///
/// Con [tanHalfFrameWidth] (la tangente de medio campo de visión horizontal
/// del frame) se aplica la perspectiva: un punto que queda hacia la cámara
/// respecto al origen se ve más lejos del centro de la imagen, en la razón
/// de las distancias. Sin él la proyección es ortográfica, como la `z`
/// relativa de la malla, y con la cabeza girada el lóbulo cercano se
/// dibujaba más alto y más adentro de lo que se ve.
Vec3 headPointToImage({
  required Vec3 local,
  required Vec3 origin,
  required double width,
  required HeadAxes axes,
  required double aspect,
  double? tanHalfFrameWidth,
}) {
  final o = imageToScene(origin, aspect);
  final desplazamiento = axes.apply(local);
  final p = sceneToImage(o + desplazamiento * width, aspect);
  if (tanHalfFrameWidth == null) return p;

  // Cuánto se acerca a la cámara respecto al origen, en distancias de este:
  // el ancho de cara mide `width · 2 · tan` de la distancia.
  final acercamiento = desplazamiento.z * width * 2 * tanHalfFrameWidth;
  final k = 1 / math.max(1 - acercamiento, 0.2);
  return Vec3(0.5 + (p.x - 0.5) * k, 0.5 + (p.y - 0.5) * k, p.z);
}

/// Tangente de medio campo de visión horizontal que supone MediaPipe para un
/// frame de [aspect] ancho/alto (ver [HeadModel.cameraVerticalFovDeg]).
double mediapipeTanHalfWidth(double aspect) =>
    math.tan(HeadModel.cameraVerticalFovDeg * math.pi / 360) * aspect;
