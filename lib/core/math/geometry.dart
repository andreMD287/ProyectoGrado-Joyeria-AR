/// Vector 3D mínimo y puro (sin dependencias), usado por el dominio y los
/// filtros de estabilización. Compatible con las coordenadas (x, y, z) que
/// entregan los detectores de landmarks: x,y normalizados [0,1] y z como
/// profundidad relativa.
class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);

  static const zero = Vec3(0, 0, 0);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  @override
  String toString() =>
      'Vec3(${x.toStringAsFixed(4)}, ${y.toStringAsFixed(4)}, ${z.toStringAsFixed(4)})';
}
