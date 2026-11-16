import 'dart:math' as math;

import 'geometry.dart';

/// Lo que hace falta saber de un modelo de arete para colgarlo del lóbulo.
///
/// Todo va en el espacio del modelo **ya girado** con `orientacion_yaw_deg`,
/// en las unidades del GLB.
class EarringMeasure {
  /// `true` si pivota en el lóbulo y cuelga (colgante o aro); `false` si va
  /// pegado a él (botón).
  final bool hangs;

  /// Punto del modelo que va en el lóbulo: el respaldo del adorno en un botón
  /// (donde nace la aguja) o lo más alto del gancho en un colgante.
  final Vec3 pivot;

  /// Unitario: hacia dónde mira el adorno. Puesto, apunta hacia afuera de la
  /// oreja. En un botón es el sentido contrario a la aguja.
  final Vec3 front;

  /// Unitario y perpendicular a [front]: lo que queda arriba con la pieza
  /// puesta. En un colgante es el sentido contrario a [hang].
  final Vec3 up;

  /// Unitario: del [pivot] hacia el centro de la pieza. Un colgante lo alinea
  /// con la gravedad; en un botón no se usa.
  final Vec3 hang;

  /// Lo que mide la pieza en la dirección que corresponde a
  /// `dimensiones_mm.alto`: el alto del adorno en un botón y el largo que
  /// cuelga en un colgante o aro.
  final double length;

  /// Distancia del [pivot] al centro de la pieza: el largo del péndulo.
  final double hangLength;

  const EarringMeasure({
    required this.hangs,
    required this.pivot,
    required this.front,
    required this.up,
    required this.hang,
    required this.length,
    required this.hangLength,
  });
}

/// Mide un arete sobre los vértices de cada una de sus mallas ([parts]).
///
/// [hangs] dice si cuelga (colgante o aro, del `tipo_arete` del catálogo); si
/// falta, se deduce: si el modelo tiene aguja es un botón; si no, una pieza
/// claramente más alta que ancha y profunda cuelga. Un aro no se distingue de
/// un botón por la forma: hay que declararlo.
///
/// [pivot] fuerza el punto de sujeción (catálogo o nodo `sujecion` del GLB).
///
/// - **Botón con aguja:** la aguja es la malla más alargada, y puede ir en
///   cualquier dirección: en `arete_perla` sale hacia +z, en `Aretes_Juanes`
///   casi vertical, con el cierre de mariposa ensartado. El adorno es lo que
///   tapa uno de sus extremos (el cierre va a lo largo de ella, sin pasarla),
///   y mira hacia afuera por ese extremo. El punto de sujeción es su respaldo,
///   sobre la aguja, que es lo que queda apoyado en el lóbulo.
/// - **Botón sin aguja como malla aparte:** se supone que el adorno mira a +z,
///   la convención del catálogo, y se busca el poste a lo largo de z.
/// - **Colgante y aro:** cuelgan de lo más alto. El frente es +z, enderezado
///   para que quede perpendicular a la dirección en que cuelga.
///
/// `null` si no hay vértices.
EarringMeasure? measureEarring(
  List<List<Vec3>> parts, {
  bool? hangs,
  Vec3? pivot,
}) {
  final vertices = [for (final p in parts) ...p];
  if (vertices.isEmpty) return null;

  var minX = double.infinity, minY = double.infinity, minZ = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity, maxZ = -double.infinity;
  for (final p in vertices) {
    minX = math.min(minX, p.x);
    minY = math.min(minY, p.y);
    minZ = math.min(minZ, p.z);
    maxX = math.max(maxX, p.x);
    maxY = math.max(maxY, p.y);
    maxZ = math.max(maxZ, p.z);
  }
  final ancho = maxX - minX, alto = maxY - minY, fondo = maxZ - minZ;

  final aguja = hangs == true ? null : _findPost(parts);
  final cuelgaDelLobulo =
      hangs ?? (aguja == null && alto > 1.3 * math.max(ancho, fondo));

  if (!cuelgaDelLobulo) {
    if (aguja != null) {
      final medida = _studWithPost(parts, aguja, pivot);
      if (medida != null) return medida;
    }
    return _studAlongZ(vertices, pivot, minX, maxX, minY, maxY, fondo, alto);
  }
  return _drop(vertices, pivot, maxY, alto);
}

/// Una malla alargada y delgada: la aguja de un botón.
class _Post {
  final int index;
  final Vec3 center;
  final Vec3 axis;
  final double t0, t1;

  const _Post(this.index, this.center, this.axis, this.t0, this.t1);

  double get length => t1 - t0;
}

/// Cuánto más larga que gruesa tiene que ser una malla para tomarla por
/// aguja. Una aguja real pasa de 10; los adornos y el cierre quedan en 1–3.
const double _minPostElongation = 4;

/// La malla más alargada, si lo es lo bastante para ser una aguja.
_Post? _findPost(List<List<Vec3>> parts) {
  _Post? mejor;
  var mejorRazon = _minPostElongation;
  for (var i = 0; i < parts.length; i++) {
    final part = parts[i];
    if (part.length < 6) continue;
    final c = _mean(part);
    final eje = _principalAxis(part, c);
    var t0 = double.infinity, t1 = -double.infinity, radio = 0.0;
    for (final p in part) {
      final d = p - c;
      final t = d.dot(eje);
      t0 = math.min(t0, t);
      t1 = math.max(t1, t);
      radio = math.max(radio, (d - eje * t).length);
    }
    final razon = (t1 - t0) / math.max(2 * radio, 1e-9);
    if (razon >= mejorRazon) {
      mejorRazon = razon;
      mejor = _Post(i, c, eje, t0, t1);
    }
  }
  return mejor;
}

EarringMeasure? _studWithPost(
  List<List<Vec3>> parts,
  _Post aguja,
  Vec3? pivot,
) {
  final otros = [
    for (var i = 0; i < parts.length; i++)
      if (i != aguja.index) ...parts[i],
  ];
  if (otros.isEmpty) return null;

  // El adorno tapa un extremo de la aguja y sobresale más allá de él; el
  // cierre va ensartado a lo largo, sin pasar la punta.
  var eje = aguja.axis;
  var t0 = aguja.t0, t1 = aguja.t1;
  var maxOtro = -double.infinity, minOtro = double.infinity;
  for (final p in otros) {
    final t = (p - aguja.center).dot(eje);
    maxOtro = math.max(maxOtro, t);
    minOtro = math.min(minOtro, t);
  }
  if (math.max(0.0, t0 - minOtro) > math.max(0.0, maxOtro - t1)) {
    eje = -eje;
    (t0, t1) = (-t1, -t0);
  }
  double t(Vec3 p) => (p - aguja.center).dot(eje);

  // El adorno: lo que queda delante del mayor hueco a lo largo de la aguja,
  // que es el que deja el lóbulo entre el adorno y el cierre. Si no hay un
  // hueco claro (sin cierre en el modelo), todo lo que no es aguja.
  final ts = [for (final p in otros) t(p)]..sort((a, b) => b.compareTo(a));
  var respaldo = ts.last;
  var mayorHueco = 0.15 * (t1 - t0);
  for (var i = 1; i < ts.length; i++) {
    final hueco = ts[i - 1] - ts[i];
    if (hueco > mayorHueco) {
      mayorHueco = hueco;
      respaldo = ts[i - 1];
    }
  }

  var radio = 0.0;
  for (final p in otros) {
    final tp = t(p);
    if (tp < respaldo) continue;
    radio = math.max(radio, ((p - aguja.center) - eje * tp).length);
  }

  return EarringMeasure(
    hangs: false,
    pivot: pivot ?? aguja.center + eje * respaldo,
    front: eje,
    up: _perpendicularUp(eje),
    hang: -_perpendicularUp(eje),
    length: radio > 0 ? 2 * radio : t1 - t0,
    hangLength: 0,
  );
}

EarringMeasure _studAlongZ(
  List<Vec3> vertices,
  Vec3? pivot,
  double minX,
  double maxX,
  double minY,
  double maxY,
  double fondo,
  double alto,
) {
  final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
  double radio(Vec3 p) => math.sqrt(
        (p.x - cx) * (p.x - cx) + (p.y - cy) * (p.y - cy),
      );
  var rMax = 0.0;
  for (final p in vertices) {
    rMax = math.max(rMax, radio(p));
  }
  // El adorno: todo lo que se aparta del eje del poste.
  var z0 = double.infinity, z1 = -double.infinity;
  for (final p in vertices) {
    if (radio(p) > 0.5 * rMax) {
      z0 = math.min(z0, p.z);
      z1 = math.max(z1, p.z);
    }
  }
  if (!z0.isFinite) {
    z0 = vertices.map((p) => p.z).reduce(math.min);
    z1 = vertices.map((p) => p.z).reduce(math.max);
  }
  // El poste: un hilo cerca del eje, fuera del adorno.
  final margen = 0.02 * fondo;
  var delante = 0, detras = 0;
  for (final p in vertices) {
    if (radio(p) >= 0.25 * rMax) continue;
    if (p.z > z1 + margen) delante++;
    if (p.z < z0 - margen) detras++;
  }
  final Vec3 frente;
  final double zSujecion;
  if (delante > detras) {
    frente = const Vec3(0, 0, -1);
    zSujecion = z1;
  } else {
    frente = const Vec3(0, 0, 1);
    zSujecion = z0;
  }
  return EarringMeasure(
    hangs: false,
    pivot: pivot ?? Vec3(cx, cy, zSujecion),
    front: frente,
    up: const Vec3(0, 1, 0),
    hang: const Vec3(0, -1, 0),
    length: alto,
    hangLength: 0,
  );
}

EarringMeasure _drop(
  List<Vec3> vertices,
  Vec3? pivot,
  double maxY,
  double alto,
) {
  Vec3 sujecion;
  if (pivot != null) {
    sujecion = pivot;
  } else {
    final corte = maxY - 0.04 * alto;
    var tx = 0.0, tz = 0.0, k = 0;
    for (final p in vertices) {
      if (p.y >= corte) {
        tx += p.x;
        tz += p.z;
        k++;
      }
    }
    sujecion = Vec3(tx / k, maxY, tz / k);
  }

  final haciaCentro = _mean(vertices) - sujecion;
  final cuelga = haciaCentro.length > 1e-9
      ? haciaCentro.normalized()
      : const Vec3(0, -1, 0);

  // +z sin su componente a lo largo de la caída.
  const z = Vec3(0, 0, 1);
  var frente = z - cuelga * z.dot(cuelga);
  if (frente.length < 1e-6) {
    const x = Vec3(1, 0, 0);
    frente = x - cuelga * x.dot(cuelga);
  }
  frente = frente.normalized();

  var largo = 0.0;
  for (final p in vertices) {
    largo = math.max(largo, (p - sujecion).dot(cuelga));
  }

  return EarringMeasure(
    hangs: true,
    pivot: sujecion,
    front: frente,
    up: -cuelga,
    hang: cuelga,
    length: largo > 0 ? largo : alto,
    hangLength: haciaCentro.length,
  );
}

Vec3 _mean(List<Vec3> ps) {
  var s = Vec3.zero;
  for (final p in ps) {
    s = s + p;
  }
  return s * (1 / ps.length);
}

/// Dirección de mayor varianza de [ps] alrededor de [c] (iteración de
/// potencia sobre la covarianza).
Vec3 _principalAxis(List<Vec3> ps, Vec3 c) {
  var xx = 0.0, xy = 0.0, xz = 0.0, yy = 0.0, yz = 0.0, zz = 0.0;
  for (final p in ps) {
    final d = p - c;
    xx += d.x * d.x;
    xy += d.x * d.y;
    xz += d.x * d.z;
    yy += d.y * d.y;
    yz += d.y * d.z;
    zz += d.z * d.z;
  }
  // Se arranca por el eje con más varianza: converge en pocas vueltas y nunca
  // empieza perpendicular al resultado.
  var v = xx >= yy && xx >= zz
      ? const Vec3(1, 0, 0)
      : (yy >= zz ? const Vec3(0, 1, 0) : const Vec3(0, 0, 1));
  for (var i = 0; i < 50; i++) {
    final w = Vec3(
      xx * v.x + xy * v.y + xz * v.z,
      xy * v.x + yy * v.y + yz * v.z,
      xz * v.x + yz * v.y + zz * v.z,
    );
    if (w.length < 1e-12) break;
    v = w.normalized();
  }
  return v;
}

/// "Arriba" para un adorno que mira hacia [front]: +y del modelo sin su
/// componente a lo largo de [front], o -z si el adorno mira casi hacia
/// arriba o abajo (como en `Aretes_Juanes`).
Vec3 _perpendicularUp(Vec3 front) {
  const y = Vec3(0, 1, 0);
  var up = y - front * y.dot(front);
  if (up.length < 0.3) {
    const z = Vec3(0, 0, -1);
    up = z - front * z.dot(front);
  }
  return up.normalized();
}
