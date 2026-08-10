// Banco B2: valida la estimación del punto de anclaje del collar a partir de
// los landmarks de hombros, con poses sintéticas representativas. La detección
// en cámara (ML Kit Pose) se corre en dispositivo; aquí se verifica la
// geometría del anclaje, que es la parte independiente del hardware.
//
//   dart run bin/b2_anchor_demo.dart

import 'package:b2_pose_collares/necklace_anchor.dart';

/// Construye una pose con solo los hombros definidos (el resto, baja confianza).
List<PoseLandmark> _pose(PoseLandmark left, PoseLandmark right) {
  final list =
      List<PoseLandmark>.filled(13, const PoseLandmark(0, 0, 0, visibility: 0));
  list[kLeftShoulder] = left;
  list[kRightShoulder] = right;
  return list;
}

void main() {
  print('B2 — Estimación del anclaje del collar (hombros 11/12)\n');

  var ok = true;

  // ── 1. Frontal y erguido ────────────────────────────────────────────────
  final frontal = estimateNecklaceAnchor(
    _pose(const PoseLandmark(0.40, 0.50, 0.0, visibility: 0.96),
        const PoseLandmark(0.60, 0.50, 0.0, visibility: 0.95)),
  );
  print('■ Frontal erguido:            $frontal');
  ok &= _check('anclaje centrado (x≈0.5)',
      frontal != null && (frontal.x - 0.5).abs() < 1e-9);
  ok &= _check('roll ≈ 0°',
      frontal != null && frontal.rollRadians.abs() < 0.05);
  ok &= _check('anclaje por debajo de los hombros',
      frontal != null && frontal.y > 0.50);
  ok &= _check('ancho de hombros ≈ 0.20',
      frontal != null && (frontal.shoulderWidth - 0.20).abs() < 1e-6);

  // ── 2. Hombros inclinados (derecho más abajo) ───────────────────────────
  final tilted = estimateNecklaceAnchor(
    _pose(const PoseLandmark(0.40, 0.48, 0.0, visibility: 0.9),
        const PoseLandmark(0.60, 0.56, 0.0, visibility: 0.9)),
  );
  print('■ Hombros inclinados:         $tilted');
  ok &= _check('roll positivo (sigue la inclinación)',
      tilted != null && tilted.rollRadians > 0.05);

  // ── 3. Persona girada (hombros más juntos en la imagen) ─────────────────
  final turned = estimateNecklaceAnchor(
    _pose(const PoseLandmark(0.46, 0.50, 0.0, visibility: 0.8),
        const PoseLandmark(0.54, 0.50, 0.0, visibility: 0.8)),
  );
  print('■ Girada (hombros juntos):    $turned');
  ok &= _check('ancho menor al frontal',
      turned != null && turned.shoulderWidth < 0.20);

  // ── 4. Baja confianza → sin anclaje ─────────────────────────────────────
  final lowConf = estimateNecklaceAnchor(
    _pose(const PoseLandmark(0.40, 0.50, 0.0, visibility: 0.3),
        const PoseLandmark(0.60, 0.50, 0.0, visibility: 0.3)),
  );
  print('■ Baja confianza:             $lowConf');
  ok &= _check('sin anclaje cuando la confianza es baja', lowConf == null);

  // ── 5. Sin hombros detectados → sin anclaje ─────────────────────────────
  final missing = estimateNecklaceAnchor(const []);
  ok &= _check('sin anclaje cuando faltan los hombros', missing == null);

  print('\n${ok ? "TODOS LOS CHEQUEOS PASARON" : "FALLÓ ALGÚN CHEQUEO"}');
  if (!ok) throw StateError('B2: la estimación de anclaje no cumplió lo esperado.');
}

bool _check(String desc, bool pass) {
  print('  [${pass ? "OK" : "FALLA"}] $desc');
  return pass;
}
