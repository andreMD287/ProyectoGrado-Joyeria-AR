import 'package:flutter_test/flutter_test.dart';

import 'package:jewelry_ar/core/di/providers.dart';

/// Parámetro `ear` de `/try-on/:pieceId` → lado que recibe `EarringStrategy`
/// (0 = oreja izquierda de la persona, 1 = derecha, `null` = automático).
void main() {
  test("'left' fuerza la oreja izquierda (0)", () {
    expect(earringSideFromQuery('left'), 0);
  });

  test("'right' fuerza la oreja derecha (1)", () {
    expect(earringSideFromQuery('right'), 1);
  });

  test('sin parámetro queda en automático (null)', () {
    expect(earringSideFromQuery(null), isNull);
  });

  test('un valor inválido queda en automático (null)', () {
    expect(earringSideFromQuery('center'), isNull);
    expect(earringSideFromQuery('LEFT'), isNull);
    expect(earringSideFromQuery(''), isNull);
  });
}
