/// Punto anatómico donde se ancla la pieza.
enum AnchorType { earlobe, wrist, neck }

/// Categorías de piezas dentro del alcance del producto: aretes, pulseras y
/// collares. Cada una determina la técnica de anclaje (y por tanto el detector
/// y la estrategia de tracking correspondientes).
enum JewelryCategory {
  earring, // arete  → lóbulo
  bracelet, // pulsera → muñeca (WRIST)
  necklace; // collar  → cuello / hombros

  /// Identificador tal como aparece en `catalog.json`.
  String get id => switch (this) {
        JewelryCategory.earring => 'arete',
        JewelryCategory.bracelet => 'pulsera',
        JewelryCategory.necklace => 'collar',
      };

  AnchorType get anchorType => switch (this) {
        JewelryCategory.earring => AnchorType.earlobe,
        JewelryCategory.bracelet => AnchorType.wrist,
        JewelryCategory.necklace => AnchorType.neck,
      };

  static JewelryCategory fromId(String id) => switch (id) {
        'arete' => JewelryCategory.earring,
        'pulsera' => JewelryCategory.bracelet,
        'collar' => JewelryCategory.necklace,
        _ => throw ArgumentError('Categoría desconocida: $id'),
      };
}
