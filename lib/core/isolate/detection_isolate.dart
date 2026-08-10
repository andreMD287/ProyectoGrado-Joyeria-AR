/// Infraestructura del isolate de detección (spike B5).
///
/// `detect()` es síncrono y bloquea el isolate principal (~15–40 ms/frame,
/// ≤10 FPS). La solución es un isolate dedicado con su propia instancia del
/// detector, transfiriendo los bytes del frame por `SendPort`.
///
/// Restricción: los detectores basados en platform channels (ML Kit) requieren
/// inicializar `BackgroundIsolateBinaryMessenger` con el `RootIsolateToken`
/// dentro del isolate; `hand_landmarker` (JNI) es más autónomo. Por eso el
/// repositorio de tracking decide, según el detector, si corre en isolate o en
/// el hilo principal con throttling.
///
/// TODO(B5): implementar el isolate dedicado y medir FPS antes/después.
class DetectionIsolate {
  const DetectionIsolate();
}
