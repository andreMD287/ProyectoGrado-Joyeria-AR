import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/jewelry_piece_model.dart';

/// Fuente de datos local del catálogo: lee `catalog.json` empaquetado como
/// asset. Para migrar a catálogo remoto bastaría con crear una
/// `CatalogRemoteDataSource` y ajustar el repositorio, sin tocar dominio ni UI.
class CatalogLocalDataSource {
  final String assetPath;
  const CatalogLocalDataSource({this.assetPath = 'assets/catalog/catalog.json'});

  Future<List<JewelryPieceModel>> loadPieces() async {
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final piezas = (json['piezas'] as List).cast<Map<String, dynamic>>();
    return piezas.map(JewelryPieceModel.fromJson).toList();
  }
}
