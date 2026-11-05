import 'dart:math' as math;

import 'geometry.dart';

/// Medidas de un collar sacadas de sus vértices.
class NecklaceMeasure {
  /// Centro del hueco por el que pasa el cuello, a la altura de la vuelta
  /// trasera de la cadena. Es el punto del modelo que se hace coincidir con la
  /// base del cuello.
  final Vec3 neckCenter;

  /// Ancho del hueco de lado a lado (eje x), en unidades del modelo. Es lo que
  /// tiene que encajar con el ancho del cuello.
  final double holeWidth;

  /// Altura de la parte más baja de la vuelta trasera. Por debajo de ella la
  /// cadena ya no rodea el cuello sino que cae sobre el pecho.
  final double backBottomY;

  /// Punto más bajo de la pieza: el extremo de la caída (o el dije).
  final Vec3 lowest;

  const NecklaceMeasure({
    required this.neckCenter,
    required this.holeWidth,
    required this.backBottomY,
    required this.lowest,
  });

  /// La caída queda por delante del cuello (+z). Si no, el modelo viene con el
  /// frente hacia atrás y hay que corregirlo con `orientacion_yaw_deg`.
  bool get facesFront => lowest.z > neckCenter.z;

  @override
  String toString() => 'NecklaceMeasure(cuello: $neckCenter, '
      'hueco: ${holeWidth.toStringAsFixed(4)}, '
      'base trasera: ${backBottomY.toStringAsFixed(4)}, '
      'punto bajo: $lowest)';
}

/// Mide el hueco del cuello de un collar a partir de sus vértices, ya
/// orientados con +y arriba y la caída hacia +z.
///
/// **Qué forma supone.** Un collar modelado puesto: la mitad trasera rodea el
/// cuello casi horizontal, en lo alto de la pieza, y la delantera baja hacia el
/// pecho. Así vienen los del catálogo (medido 2026-10-28): en `Collar1` la
/// franja superior ocupa z ∈ [−2,53; −0,04] —solo la mitad de atrás— y el
/// resto de la cadena cae hasta 2,7 unidades por delante.
///
/// **Cómo se mide.** Se toma la franja de vértices más alta, un [topBand] de
/// la altura total. Su extensión en x es el ancho del hueco; su borde trasero
/// marca la nuca, así que el centro del cuello queda medio ancho por delante.
/// Los extremos se toman con cuantiles y no con mínimo y máximo, para que un
/// cierre o un eslabón suelto no los mueva.
///
/// Devuelve `null` si los puntos no tienen altura o la franja queda vacía.
NecklaceMeasure? measureNecklace(
  List<Vec3> points, {
  double topBand = 0.1,
}) {
  if (points.length < 8) return null;

  var minY = double.infinity, maxY = -double.infinity;
  var lowest = points.first;
  for (final p in points) {
    if (p.y > maxY) maxY = p.y;
    if (p.y < minY) {
      minY = p.y;
      lowest = p;
    }
  }
  final alto = maxY - minY;
  if (alto <= 0) return null;

  final corte = maxY - topBand * alto;
  final franja = [
    for (final p in points)
      if (p.y >= corte) p,
  ];
  if (franja.length < 4) return null;

  final xs = [for (final p in franja) p.x]..sort();
  final zs = [for (final p in franja) p.z]..sort();
  final izquierda = _cuantil(xs, 0.005);
  final derecha = _cuantil(xs, 0.995);
  final ancho = derecha - izquierda;
  if (ancho <= 0) return null;
  final nuca = _cuantil(zs, 0.005);

  final ysFranja = [for (final p in franja) p.y]..sort();

  return NecklaceMeasure(
    neckCenter: Vec3(
      (izquierda + derecha) / 2,
      _cuantil(ysFranja, 0.5),
      nuca + ancho / 2,
    ),
    holeWidth: ancho,
    backBottomY: corte,
    lowest: lowest,
  );
}

double _cuantil(List<double> ordenados, double q) {
  final i = (q * (ordenados.length - 1)).round();
  return ordenados[math.max(0, math.min(ordenados.length - 1, i))];
}
