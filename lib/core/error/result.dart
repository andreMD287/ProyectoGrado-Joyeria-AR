import 'failure.dart';

/// Resultado explícito de una operación que puede fallar, sin lanzar
/// excepciones a través de las capas. Se consume con `switch` exhaustivo:
///
/// ```dart
/// switch (result) {
///   Ok(:final value) => usar(value),
///   Err(:final failure) => mostrar(failure),
/// }
/// ```
sealed class Result<T> {
  const Result();
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

class Err<T> extends Result<T> {
  final Failure failure;
  const Err(this.failure);
}
