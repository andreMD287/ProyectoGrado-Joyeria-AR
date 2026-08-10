import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jewelry_ar/features/catalog/presentation/screens/catalog_screen.dart';

void main() {
  testWidgets('El catálogo muestra su título', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CatalogScreen()),
      ),
    );

    // Estado inicial: título visible mientras carga el catálogo.
    expect(find.text('Catálogo de joyería'), findsOneWidget);
  });
}
