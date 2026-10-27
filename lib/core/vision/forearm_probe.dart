import 'dart:math' as math;

import '../../features/tracking/domain/entities/forearm_observation.dart';
import '../../features/tracking/domain/entities/landmark.dart';

/// Color de un píxel en YUV (BT.601, 0–255), el formato de la cámara.
class Yuv {
  final int y, u, v;
  const Yuv(this.y, this.u, this.v);
}

/// Lee el color en un punto del frame vertical, en coordenadas normalizadas
/// (`x`, `y` ∈ [0,1]). Devuelve `null` fuera de la imagen.
typedef YuvSampler = Yuv? Function(double x, double y);

/// Busca el antebrazo en la imagen a partir de la mano detectada.
///
/// **Por qué funciona donde la medición sobre capturas falló.** Al medir sobre
/// capturas de pantalla, los bordes se fragmentaban justo donde la pieza cruza
/// el brazo. Aquí se lee el frame **crudo** de la cámara, que no lleva ni la
/// joya ni el overlay, y solo hacen falta unas pocas líneas cerca de la muñeca.
///
/// **Cómo.**
/// 1. El color de piel de referencia se toma **de la propia palma** en cada
///    frame, así que se adapta a la luz y al tono de piel sin calibración.
/// 2. Se trazan [_scanDistances] líneas perpendiculares al eje de la mano, a
///    distintas alturas por debajo de la muñeca, y en cada una se busca el
///    tramo de piel continuo que pasa por el eje: sus extremos son los bordes.
/// 3. Con los puntos medios se ajusta una recta. Su pendiente respecto al eje
///    de la mano **es** la desviación de la muñeca que antes se ignoraba.
///
/// Devuelve `null` si no hay evidencia suficiente —fondo del mismo color que
/// la piel, brazo fuera de cuadro, manga— y entonces se sigue usando el eje
/// de la mano, que es el comportamiento anterior.
ForearmObservation? probeForearm({
  required List<Landmark> landmarks,
  required YuvSampler sample,
  required double imageAspect,
}) {
  if (landmarks.length <= 17 || imageAspect <= 0) return null;

  // Espacio isótropo: y dividido por el aspecto.
  ({double x, double y}) iso(Landmark l) => (x: l.x, y: l.y / imageAspect);
  Yuv? at(double x, double y) => sample(x, y * imageAspect);

  final w = iso(landmarks[0]);
  final i = iso(landmarks[5]);
  final p = iso(landmarks[17]);
  final c = (x: (i.x + p.x) / 2, y: (i.y + p.y) / 2);

  final palmW = math.sqrt(math.pow(i.x - p.x, 2) + math.pow(i.y - p.y, 2));
  var ax = w.x - c.x, ay = w.y - c.y;
  final axLen = math.sqrt(ax * ax + ay * ay);
  if (palmW <= 0 || axLen <= 0) return null;

  // Regla de medida de la sonda. El ancho de palma solo no sirve: con la mano
  // de canto se reduce a casi nada (medido: 0,055 del frame frente a ~0,25 de
  // frente) mientras el brazo sigue igual de ancho, y las líneas quedaban
  // enteras dentro de él. El largo palma→muñeca no se escorza con ese giro;
  // el mayor de los dos aguanta tanto el giro de la muñeca como la inclinación.
  final mano = math.max(palmW, axLen);
  ax /= axLen;
  ay /= axLen;
  // Perpendicular al eje de la mano: la dirección de las líneas.
  final nx = -ay, ny = ax;

  final piel = _skinReference(at, [
    for (final t in const [0.25, 0.5, 0.75])
      (x: c.x + (w.x - c.x) * t, y: c.y + (w.y - c.y) * t),
    (x: (w.x + i.x) / 2, y: (w.y + i.y) / 2),
    (x: (w.x + p.x) / 2, y: (w.y + p.y) / 2),
  ], mano * 0.04);
  if (piel == null) return null;

  final distancias = <double>[];
  final centros = <double>[];
  final anchos = <double>[];
  final paso = mano / _samplesPerPalm;
  final alcance = mano * _scanHalfWidth;
  final n = (alcance / paso).round();

  for (final f in _scanDistances) {
    final d = mano * f;
    final bx = w.x + ax * d, by = w.y + ay * d;

    // Clasificación de cada muestra de la línea: null = fuera de la imagen.
    final clase = <bool?>[
      for (var k = -n; k <= n; k++)
        _isSkin(at(bx + nx * k * paso, by + ny * k * paso), piel),
    ];
    final tramo = _runThroughCenter(clase, n);
    if (tramo == null) continue;
    final (izq, der) = tramo;

    final ancho = (der - izq) * paso;
    if (ancho < mano * _minWidth || ancho > mano * _maxWidth) continue;

    distancias.add(d);
    centros.add(((izq + der) / 2 - n) * paso);
    anchos.add(ancho);
  }

  if (distancias.length < _minValidScans) return null;

  // Recta centro = a + b·d por mínimos cuadrados.
  final m = distancias.length;
  final md = distancias.reduce((a, b) => a + b) / m;
  final mc = centros.reduce((a, b) => a + b) / m;
  var sxy = 0.0, sxx = 0.0;
  for (var k = 0; k < m; k++) {
    sxy += (distancias[k] - md) * (centros[k] - mc);
    sxx += (distancias[k] - md) * (distancias[k] - md);
  }
  if (sxx <= 0) return null;
  final b = sxy / sxx;
  final a = mc - b * md;

  // Si los centros no caen en una recta, lo que se encontró no es un brazo
  // (o hay dos objetos de color piel uno junto a otro).
  for (var k = 0; k < m; k++) {
    if ((centros[k] - (a + b * distancias[k])).abs() > mano * _maxResidual) {
      return null;
    }
  }
  if (b.abs() > math.tan(_maxDeviationDeg * math.pi / 180)) return null;

  var dx = ax + nx * b, dy = ay + ny * b;
  final dLen = math.sqrt(dx * dx + dy * dy);
  dx /= dLen;
  dy /= dLen;

  final ordenados = [...anchos]..sort();
  final mediana = ordenados[ordenados.length ~/ 2];

  return ForearmObservation(
    originX: w.x + nx * a,
    originY: w.y + ny * a,
    dirX: dx,
    dirY: dy,
    // Las líneas cruzan el brazo en diagonal cuando hay desviación: se
    // proyecta sobre la perpendicular verdadera.
    width: mediana / math.sqrt(1 + b * b),
    validScans: m,
  );
}

/// Alturas de las líneas, en tamaños de mano (ver `mano`) desde la muñeca hacia el codo.
/// La primera evita la base del pulgar; la última no se aleja tanto como para
/// salir de cuadro con la mano cerca de la cámara.
const _scanDistances = [0.35, 0.55, 0.75, 0.95, 1.15];

const _minValidScans = 3;

/// Semiancho explorado a cada lado del eje, en tamaños de mano. El antebrazo
/// mide ~1,1 palmas; con 1,3 a cada lado cabe aunque el eje de la mano esté
/// bastante desviado.
const _scanHalfWidth = 1.3;
const _samplesPerPalm = 40;

/// Ancho plausible del brazo, en tamaños de mano. El mínimo es bajo porque,
/// con la mano de canto, la regla pasa a ser el largo palma→muñeca y el brazo
/// visto de lado mide ~0,55 de él (medido en dispositivo).
const _minWidth = 0.35;
const _maxWidth = 1.7;

/// Desviación máxima de un centro respecto a la recta ajustada.
const _maxResidual = 0.08;

/// La desviación radial/cubital de la muñeca no pasa de ~35°.
const _maxDeviationDeg = 35.0;

/// Tolerancia de crominancia respecto a la piel de referencia.
const _chromaTolerance = 14;

/// Una sombra sobre el brazo oscurece la luminancia, no la crominancia; se
/// acepta hasta este factor por debajo de la referencia.
const _minLumaRatio = 0.35;

/// Huecos tolerados dentro del tramo de piel (pecas, vello, reflejos).
const _maxGap = 2;

bool? _isSkin(Yuv? px, Yuv ref) {
  if (px == null) return null;
  return (px.u - ref.u).abs() <= _chromaTolerance &&
      (px.v - ref.v).abs() <= _chromaTolerance &&
      px.y >= ref.y * _minLumaRatio;
}

/// Mediana del color en unos puntos de la palma, cada uno con un pequeño
/// vecindario para no depender de un solo píxel.
Yuv? _skinReference(
  Yuv? Function(double x, double y) at,
  List<({double x, double y})> puntos,
  double radio,
) {
  final ys = <int>[], us = <int>[], vs = <int>[];
  for (final pt in puntos) {
    for (final ox in const [-1, 0, 1]) {
      for (final oy in const [-1, 0, 1]) {
        final px = at(pt.x + ox * radio, pt.y + oy * radio);
        if (px == null) continue;
        ys.add(px.y);
        us.add(px.u);
        vs.add(px.v);
      }
    }
  }
  if (ys.length < 9) return null;
  int med(List<int> l) => (l..sort())[l.length ~/ 2];
  return Yuv(med(ys), med(us), med(vs));
}

/// Extremos del tramo de piel que pasa por el centro de la línea (índice
/// [centro]), tolerando huecos de [_maxGap] muestras. `null` si el centro no
/// es piel o si el tramo toca el final de la línea o el borde de la imagen:
/// entonces un borde no se vio y el ancho no es fiable.
(int, int)? _runThroughCenter(List<bool?> clase, int centro) {
  // El eje de la mano puede caer algo fuera del brazo: se busca la muestra de
  // piel más cercana al centro, dentro de un cuarto del alcance.
  int? inicio;
  for (var o = 0; o <= centro ~/ 4; o++) {
    if (clase[centro - o] == true) {
      inicio = centro - o;
      break;
    }
    if (clase[centro + o] == true) {
      inicio = centro + o;
      break;
    }
  }
  if (inicio == null) return null;

  int? extremo(int paso) {
    var ultimo = inicio!;
    var hueco = 0;
    for (var k = inicio + paso; k >= 0 && k < clase.length; k += paso) {
      final c = clase[k];
      if (c == null) return null;
      if (c) {
        ultimo = k;
        hueco = 0;
      } else if (++hueco > _maxGap) {
        return ultimo;
      }
    }
    return null; // Llegó al final de la línea sin encontrar el borde.
  }

  final izq = extremo(-1);
  final der = extremo(1);
  if (izq == null || der == null) return null;
  return (izq, der);
}
