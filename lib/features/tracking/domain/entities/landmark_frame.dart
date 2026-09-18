import '../../../../core/math/geometry.dart';
import 'landmark.dart';

/// Lo que un detector entrega para un frame.
///
/// Son **dos espacios de coordenadas distintos**, no dos vistas del mismo, y de
/// ahí que viajen juntos pero separados:
///
/// - [landmarks] está normalizado al frame ya rotado a vertical (x, y ∈ [0,1]).
///   Es el espacio en el que se ancla la joya sobre la imagen, y su `z` es una
///   profundidad **relativa** en unidades de imagen: sirve para comparar dos
///   puntos entre sí, no para medir.
/// - [worldLandmarks] es una reconstrucción **métrica** (metros) del mismo
///   conjunto de puntos, con origen en el centro del cuerpo detectado. No sirve
///   para posicionar sobre la imagen, pero es la única fuente con la que se
///   puede recuperar una orientación 3D real.
///
/// [worldLandmarks] queda vacía cuando el detector no la provee: hoy solo la
/// entrega MediaPipe manos en Android. Quien la consuma debe tratar la lista
/// vacía como "no disponible" y degradar, nunca asumir que está.
class LandmarkFrame {
  final List<Landmark> landmarks;
  final List<Vec3> worldLandmarks;

  const LandmarkFrame({
    this.landmarks = const [],
    this.worldLandmarks = const [],
  });

  static const empty = LandmarkFrame();

  bool get isEmpty => landmarks.isEmpty;
}
