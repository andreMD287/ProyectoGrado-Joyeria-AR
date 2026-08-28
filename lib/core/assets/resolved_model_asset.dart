import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
