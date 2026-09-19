import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'glb_normalizer.dart';

const placeholderModelAsset = 'assets/models/_placeholder.glb';

/// Resuelve la ruta del modelo de una pieza. Si el archivo no está en el
/// paquete, devuelve el modelo de referencia (ADR-11).
final resolvedModelAssetProvider =
    FutureProvider.family<String, String>((ref, assetPath) async {
  try {
    await rootBundle.load(assetPath);
    return assetPath;
  } catch (_) {
    return placeholderModelAsset;
  }
});

/// Bytes del modelo listos para el motor 3D: resuelve la ruta (con el
/// *placeholder* de ADR-11 si falta) y normaliza el GLB para el cargador.
///
/// El motor se alimenta con bytes y no con la ruta porque entre medio hay que
/// corregir el archivo: ver [normalizeGlbForLoader].
final modelBytesProvider =
    FutureProvider.family<Uint8List, String>((ref, assetPath) async {
  final resolved = await ref.watch(resolvedModelAssetProvider(assetPath).future);
  final data = await rootBundle.load(resolved);
  return normalizeGlbForLoader(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
});
