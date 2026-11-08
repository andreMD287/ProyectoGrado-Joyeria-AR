/// Cómo se sujeta un arete al lóbulo. Decide de dónde cuelga el modelo y cómo
/// se mueve con la cabeza.
///
/// - [stud] (botón): el adorno va pegado al lóbulo y un poste lo atraviesa.
///   Gira rígido con la cabeza.
/// - [drop] (colgante): cuelga de un gancho o argolla y pivota en el lóbulo,
///   así que cae por gravedad y se balancea.
/// - [hoop] (aro): el aro pasa por el lóbulo por su parte de arriba; también
///   cuelga y se balancea.
enum EarringType {
  stud,
  drop,
  hoop;

  /// Identificador tal como aparece en `catalog.json` (`tipo_arete`).
  String get id => switch (this) {
        EarringType.stud => 'boton',
        EarringType.drop => 'colgante',
        EarringType.hoop => 'aro',
      };

  /// `true` si pivota en el lóbulo y cuelga por gravedad.
  bool get hangs => this != EarringType.stud;

  /// `null` si [id] es nulo o no es un tipo conocido: entonces se deduce de la
  /// forma del modelo (ver `measureEarring`).
  static EarringType? tryFromId(String? id) => switch (id) {
        'boton' => EarringType.stud,
        'colgante' => EarringType.drop,
        'aro' => EarringType.hoop,
        _ => null,
      };
}
