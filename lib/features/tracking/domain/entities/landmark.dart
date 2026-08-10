/// Punto detectado por un detector de landmarks, en coordenadas normalizadas.
/// x, y ∈ [0,1] (posición en la imagen); z es profundidad relativa. `visibility`
/// (confianza) la proveen algunos detectores como ML Kit Pose; MediaPipe no.
class Landmark {
  final double x, y, z;
  final double? visibility;
  const Landmark(this.x, this.y, this.z, {this.visibility});
}
