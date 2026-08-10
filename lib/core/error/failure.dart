/// Jerarquía de fallos del dominio. Cada capa mapea sus errores a un [Failure]
/// concreto; la presentación decide cómo mostrarlo.
sealed class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => '$runtimeType($message)';
}

class CatalogFailure extends Failure {
  const CatalogFailure(super.message);
}

class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}

class TrackingFailure extends Failure {
  const TrackingFailure(super.message);
}

class PlatformUnsupportedFailure extends Failure {
  const PlatformUnsupportedFailure(super.message);
}
