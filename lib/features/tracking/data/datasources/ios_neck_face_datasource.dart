import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../domain/entities/landmark.dart';
import '../../domain/entities/landmark_frame.dart';
import '../../domain/entities/neck_observation.dart';
import 'face_detector_datasource.dart' show mlKitInputImage;
import 'landmark_detector.dart';

/// Cara para collares en iOS con ML Kit Face (contorno de la cara).
///
/// En Android la cara de los collares sale del Face Landmarker de MediaPipe
/// (`NeckTracker`), pero en iOS MediaPipe choca con ANGLE, el motor GL de
/// `three_js` (ver `docs/IOS_SEGUIMIENTO_CUELLO.md`). ML Kit Face sí convive
/// con él: es el detector de los aretes.
///
/// Entrega lo mismo que el camino de Android ([NeckObservation]: mentón,
/// mejillas, nariz y ancho de cara), así que `NecklaceStrategy._fromNeck` no
/// cambia. Por ahora **sin forma del cuello** ([NeckObservation.neck] nulo):
/// el collar se cuelga con la base supuesta a partir de la cara, como en
/// Android mientras la segmentación no da su primera medida.
class IosNeckFaceDataSource implements LandmarkDetector {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(enableContours: true, enableLandmarks: true),
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<LandmarkFrame> detect(CameraImage frame, int sensorOrientation) async {
    final input = mlKitInputImage(frame, sensorOrientation);
    if (input == null) return LandmarkFrame.empty;

    final faces = await _detector.processImage(input);
    if (faces.isEmpty) return LandmarkFrame.empty;
    final face = faces.first;
    final contorno = face.contours[FaceContourType.face]?.points;
    if (contorno == null || contorno.length < 8) return LandmarkFrame.empty;

    // En iOS la cámara entrega el frame ya vertical y espejado como la vista
    // previa: basta normalizar (igual que `normalizeMlKitLandmarkToPreview`).
    final w = frame.width.toDouble(), h = frame.height.toDouble();
    Pt pt(math.Point<int> p) => (x: p.x / w, y: p.y / h);
    Pt? marca(FaceLandmarkType t) {
      final p = face.landmarks[t]?.position;
      return p == null ? null : pt(p);
    }

    final puente = face.contours[FaceContourType.noseBridge]?.points;
    final ojoI = marca(FaceLandmarkType.leftEye);
    final ojoD = marca(FaceLandmarkType.rightEye);
    return neckFrameFromFaceContour(
      contour: contorno.map(pt).toList(),
      nose: puente != null && puente.isNotEmpty
          ? pt(puente.last)
          : marca(FaceLandmarkType.noseBase),
      eyes: ojoI != null && ojoD != null
          ? (x: (ojoI.x + ojoD.x) / 2, y: (ojoI.y + ojoD.y) / 2)
          : null,
      mouth: marca(FaceLandmarkType.bottomMouth),
      headYawDegrees: face.headEulerAngleY ?? 0,
      frameAspect: h / w,
    );
  }

  @override
  Future<void> dispose() => _detector.close();
}

/// Punto normalizado al frame (x al ancho, y al alto).
typedef Pt = ({double x, double y});

/// Cuánto se corrige el ancho de la cara por el giro: `ancho / cos(giro)^k`.
///
/// En Android el ancho sale en 3D y no cambia al girar. Aquí se mide en la
/// imagen, entre los extremos del contorno, que de lado es la silueta: se
/// encoge menos que `cos(giro)` porque la cabeza es casi un cilindro. 0,5 es
/// un punto de partida **sin medir**: si al girar la cabeza el collar se
/// agranda, bajarlo; si se encoge, subirlo.
const double faceWidthYawExponent = 0.5;

/// Arma la observación de collar a partir del contorno de ML Kit.
///
/// Todo se calcula en el espacio isótropo (y multiplicada por
/// [frameAspect] = alto/ancho), donde una distancia mide lo mismo en las dos
/// direcciones, y se devuelve normalizado al frame.
///
/// - **Abajo de la cara:** de los ojos a la boca; sin ellos, abajo de la
///   imagen. Así el mentón y las mejillas siguen bien con la cabeza ladeada.
/// - **Mentón:** el punto del contorno más abajo en esa dirección.
/// - **Mejillas:** los extremos del contorno a lo ancho.
/// - **Giro de cabeza:** la magnitud de [headYawDegrees] (ML Kit) y el signo
///   de hacia dónde se corre la nariz respecto al centro de las mejillas, que
///   está en el espacio de la vista previa y no depende de cómo ML Kit defina
///   su ángulo. Convenio de la escena: positivo hacia la derecha de la
///   pantalla.
/// - **Profundidad:** ML Kit no la da. Se le pone a la mejilla derecha la `z`
///   que reproduce ese giro en `NecklaceStrategy._fromNeck`
///   (`atan2(Δz, Δx)`).
@visibleForTesting
LandmarkFrame neckFrameFromFaceContour({
  required List<Pt> contour,
  required Pt? nose,
  required Pt? eyes,
  required Pt? mouth,
  required double headYawDegrees,
  required double frameAspect,
}) {
  if (contour.length < 3 || frameAspect <= 0) return LandmarkFrame.empty;
  Pt iso(Pt p) => (x: p.x, y: p.y * frameAspect);
  Landmark normal(Pt p, [double z = 0]) => Landmark(p.x, p.y / frameAspect, z);
  double dot(Pt p, Pt d) => p.x * d.x + p.y * d.y;

  var abajo = (x: 0.0, y: 1.0);
  if (eyes != null && mouth != null) {
    final a = iso(eyes), b = iso(mouth);
    final dx = b.x - a.x, dy = b.y - a.y;
    final n = math.sqrt(dx * dx + dy * dy);
    if (n > 0 && dy > 0) abajo = (x: dx / n, y: dy / n);
  }
  final derecha = (x: abajo.y, y: -abajo.x);

  final puntos = contour.map(iso).toList();
  Pt extremo(Pt d, {bool max = true}) => puntos.reduce((a, b) {
        final mayor = dot(b, d) > dot(a, d);
        return mayor == max ? b : a;
      });
  final menton = extremo(abajo);
  final mejI = extremo(derecha, max: false);
  final mejD = extremo(derecha);

  final ddx = mejD.x - mejI.x, ddy = mejD.y - mejI.y;
  final ancho2d = math.sqrt(ddx * ddx + ddy * ddy);
  if (ancho2d <= 0) return LandmarkFrame.empty;

  final narizIso = nose == null ? null : iso(nose);
  final centro = (x: (mejI.x + mejD.x) / 2, y: (mejI.y + mejD.y) / 2);
  final lado = narizIso == null
      ? 0.0
      : dot((x: narizIso.x - centro.x, y: narizIso.y - centro.y), derecha);
  final giro = (headYawDegrees.abs() * math.pi / 180).clamp(0.0, 1.0) *
      (lado >= 0 ? 1 : -1);

  final caraW =
      ancho2d / math.pow(math.cos(giro), faceWidthYawExponent).toDouble();

  final cheekLeft = normal(mejI);
  final cheekRight = normal(mejD, ddx * math.tan(giro));
  final chin = normal(menton);
  final nariz = narizIso == null ? chin : normal(narizIso);

  return LandmarkFrame(
    landmarks: [chin, cheekLeft, cheekRight, if (narizIso != null) nariz],
    neck: NeckObservation(
      chin: chin,
      cheekLeft: cheekLeft,
      cheekRight: cheekRight,
      nose: nariz,
      faceWidth: caraW,
    ),
  );
}
