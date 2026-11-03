import 'dart:math' as math;

import 'geometry.dart';

/// Medidas de una pieza con forma de aro, sacadas de sus vértices.
class RingMeasure {
  /// Eje por el que entra el miembro: 0 = x, 1 = y, 2 = z del modelo.
  final int axis;

  /// Diámetro del hueco, en unidades del modelo.
  final double holeDiameter;

  /// Diámetro exterior, en unidades del modelo.
  final double outerDiameter;

  const RingMeasure({
    required this.axis,
    required this.holeDiameter,
    required this.outerDiameter,
  });

  @override
  String toString() => 'RingMeasure(eje: $axis, '
      'hueco: ${holeDiameter.toStringAsFixed(4)}, '
      'exterior: ${outerDiameter.toStringAsFixed(4)})';
}

/// Mide el hueco y el diámetro exterior de un aro a partir de sus vértices.
///
/// **Por qué no basta la caja envolvente.** Antes el hueco se estimaba como
/// `diámetro − 2·grosor`, tomando como grosor la menor extensión de la caja.
/// Eso supone que la banda es tan ancha en el plano del aro como alta a lo
/// largo del brazo, y casi nunca es así. Medido sobre los GLB del catálogo
/// (2026-10-13): en `pulsera_perlas_basica` el hueco real es 0,845 del
/// diámetro y la caja daba 0,68 —la pieza salía un 24 % más grande de lo que
/// pedían las constantes—; en `cartier`, 0,909 contra 0,847.
///
/// **Cómo se mide.** El eje del aro es la dirección de menor extensión de la
/// caja. Alrededor de él se reparten los vértices en [sectores] angulares y en
/// cada uno se toma la distancia radial mínima (el borde interior) y la máxima
/// (el exterior). El hueco es la **mediana** de los mínimos: un cierre, un dije
/// que cuelga hacia dentro o una cuenta suelta afectan a uno o dos sectores y
/// no la mueven, cosa que sí haría el mínimo absoluto.
///
/// Devuelve `null` si los puntos no describen un aro: menos de la mitad de los
/// sectores con vértices, o un hueco menor que [minHoleRatio] del exterior.
RingMeasure? measureRing(
  List<Vec3> points, {
  int sectores = 36,
  double minHoleRatio = 0.3,
}) {
  if (points.length < sectores) return null;

  final min = [double.infinity, double.infinity, double.infinity];
  final max = [-double.infinity, -double.infinity, -double.infinity];
  for (final p in points) {
    final c = [p.x, p.y, p.z];
    for (var i = 0; i < 3; i++) {
      if (c[i] < min[i]) min[i] = c[i];
      if (c[i] > max[i]) max[i] = c[i];
    }
  }
  final size = [for (var i = 0; i < 3; i++) max[i] - min[i]];
  final centro = [for (var i = 0; i < 3; i++) (max[i] + min[i]) / 2];

  var axis = 0;
  if (size[1] < size[axis]) axis = 1;
  if (size[2] < size[axis]) axis = 2;
  // Los otros dos ejes forman el plano del aro.
  final u = (axis + 1) % 3;
  final v = (axis + 2) % 3;

  final interior = List<double>.filled(sectores, double.infinity);
  final exterior = List<double>.filled(sectores, 0);
  for (final p in points) {
    final c = [p.x, p.y, p.z];
    final du = c[u] - centro[u];
    final dv = c[v] - centro[v];
    final r = math.sqrt(du * du + dv * dv);
    final angulo = math.atan2(dv, du) + math.pi;
    final s = (angulo / (2 * math.pi) * sectores).floor() % sectores;
    if (r < interior[s]) interior[s] = r;
    if (r > exterior[s]) exterior[s] = r;
  }

  final ocupados = [
    for (var s = 0; s < sectores; s++)
      if (interior[s].isFinite) s,
  ];
  if (ocupados.length < sectores / 2) return null;

  final hueco = 2 * _mediana([for (final s in ocupados) interior[s]]);
  final exteriorD = 2 * _mediana([for (final s in ocupados) exterior[s]]);
  if (exteriorD <= 0 || hueco < exteriorD * minHoleRatio) return null;

  return RingMeasure(
    axis: axis,
    holeDiameter: hueco,
    outerDiameter: exteriorD,
  );
}

double _mediana(List<double> valores) {
  final ordenados = [...valores]..sort();
  final mitad = ordenados.length ~/ 2;
  return ordenados.length.isOdd
      ? ordenados[mitad]
      : (ordenados[mitad - 1] + ordenados[mitad]) / 2;
}
