import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jewelry_ar/core/di/providers.dart';
import 'package:jewelry_ar/core/error/result.dart';
import 'package:jewelry_ar/features/catalog/domain/entities/jewelry_category.dart';
import 'package:jewelry_ar/features/catalog/domain/entities/jewelry_piece.dart';
import 'package:jewelry_ar/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:jewelry_ar/features/catalog/presentation/screens/catalog_screen.dart';

/// Repositorio de prueba: evita depender del asset `catalog.json` para que el
/// test valide la pantalla y no la carga del archivo.
class _FakeCatalogRepository implements CatalogRepository {
  static const _piece = JewelryPiece(
    id: 'test-001',
    nombre: 'Pulsera de prueba',
    categoria: JewelryCategory.bracelet,
    modeloGlb: 'assets/models/_placeholder.glb',
    foto: 'assets/catalog/test.jpg',
    dimensionesMm: Dimensions(alto: 10, ancho: 60, profundidad: 60),
  );

  @override
  Future<Result<List<JewelryPiece>>> getAll() async => const Ok([_piece]);

  @override
  Future<Result<List<JewelryPiece>>> getByCategory(
    JewelryCategory category,
  ) async =>
      Ok([if (_piece.categoria == category) _piece]);
}

void main() {
  testWidgets('El catálogo renderiza su encabezado al cargar las piezas', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(
            _FakeCatalogRepository(),
          ),
        ],
        child: const MaterialApp(home: CatalogScreen()),
      ),
    );

    // Primer frame: el catálogo aún resuelve su future.
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pumpAndSettle();

    expect(find.text('Descubre tu\npróxima joya'), findsOneWidget);
    expect(find.text('Pulsera de prueba'), findsOneWidget);
  });
}
