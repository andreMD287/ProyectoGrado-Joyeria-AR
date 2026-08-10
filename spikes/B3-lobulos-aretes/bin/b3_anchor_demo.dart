// Banco B3: valida la estimación del anclaje del arete (lóbulo) a partir de los
// landmarks de rostro, con muestras sintéticas. La detección facial (ML Kit) se
// corre en dispositivo; aquí se verifica la geometría del anclaje, que es la
// parte independiente del hardware.
//
//   dart run bin/b3_anchor_demo.dart

import 'package:b3_lobulos_aretes/earring_anchor.dart';

EarringAnchor? _bySide(List<EarringAnchor> anchors, String side) {
  for (final a in anchors) {
    if (a.side == side) return a;
  }
  return null;
}

void main() {
  print('B3 — Estimación del anclaje del arete (lóbulo)\n');

  var ok = true;

  // ── 1. Frontal, ambas orejas ────────────────────────────────────────────
  const frontal = FaceSample(
    leftEye: FacePoint(0.42, 0.50),
    rightEye: FacePoint(0.58, 0.50),
    leftEar: FacePoint(0.34, 0.52),
    rightEar: FacePoint(0.66, 0.52),
    confidence: 0.95,
  );
  final f = estimateEarringAnchors(frontal);
  print('■ Frontal (2 orejas):');
  for (final a in f) {
    print('    $a');
  }
  ok &= _check('detecta 2 anclajes', f.length == 2);
  final fl = _bySide(f, 'left');
  final fr = _bySide(f, 'right');
  ok &= _check('lóbulo izq por debajo de la oreja', fl != null && fl.y > 0.52);
  ok &= _check('lóbulo der por debajo de la oreja', fr != null && fr.y > 0.52);
  ok &= _check('roll ≈ 0°', fl != null && fl.rollRadians.abs() < 0.05);
  ok &= _check('x del lóbulo ≈ x de la oreja (frontal)',
      fl != null && (fl.x - 0.34).abs() < 1e-6);

  // ── 2. Cabeza inclinada ─────────────────────────────────────────────────
  const tilted = FaceSample(
    leftEye: FacePoint(0.42, 0.48),
    rightEye: FacePoint(0.58, 0.54),
    leftEar: FacePoint(0.34, 0.50),
    rightEar: FacePoint(0.66, 0.56),
    confidence: 0.9,
  );
  final t = estimateEarringAnchors(tilted);
  print('■ Cabeza inclinada:');
  for (final a in t) {
    print('    $a');
  }
  ok &= _check('roll positivo (sigue la inclinación)',
      t.isNotEmpty && t.first.rollRadians > 0.05);

  // ── 3. Cabeza girada (solo una oreja visible) ───────────────────────────
  const turned = FaceSample(
    leftEye: FacePoint(0.45, 0.50),
    rightEye: FacePoint(0.57, 0.50),
    leftEar: FacePoint(0.36, 0.52),
    confidence: 0.85,
  );
  final tu = estimateEarringAnchors(turned);
  print('■ Girada (1 oreja):           ${tu.map((a) => a.side).toList()}');
  ok &= _check('un solo anclaje (oreja izquierda)',
      tu.length == 1 && tu.first.side == 'left');

  // ── 4. Baja confianza → sin anclaje ─────────────────────────────────────
  const lowConf = FaceSample(
    leftEye: FacePoint(0.42, 0.50),
    rightEye: FacePoint(0.58, 0.50),
    leftEar: FacePoint(0.34, 0.52),
    rightEar: FacePoint(0.66, 0.52),
    confidence: 0.3,
  );
  ok &= _check('sin anclaje con baja confianza',
      estimateEarringAnchors(lowConf).isEmpty);

  // ── 5. Sin ojos → sin anclaje (no hay escala ni inclinación) ────────────
  const noEyes = FaceSample(
    leftEar: FacePoint(0.34, 0.52),
    rightEar: FacePoint(0.66, 0.52),
    confidence: 0.95,
  );
  ok &= _check('sin anclaje si faltan los ojos',
      estimateEarringAnchors(noEyes).isEmpty);

  print('\n${ok ? "TODOS LOS CHEQUEOS PASARON" : "FALLÓ ALGÚN CHEQUEO"}');
  if (!ok) throw StateError('B3: la estimación de anclaje no cumplió lo esperado.');
}

bool _check(String desc, bool pass) {
  print('  [${pass ? "OK" : "FALLA"}] $desc');
  return pass;
}
