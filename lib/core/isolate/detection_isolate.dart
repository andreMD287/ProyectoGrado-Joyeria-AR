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
/// El spike B5 (`spikes/B5-isolate/`) ya prototipó y midió este patrón: el
/// isolate dedicado preserva el throughput de detección (~24 FPS) y libera la
/// UI (0 → ~60 FPS). Aquí se implementará la versión que aloja el detector real
/// (`hand_landmarker`), recibiendo los bytes del frame por `SendPort`.
///
/// TODO(C2/C3): portar `DetectionIsolate` del spike B5 con el detector real.
class DetectionIsolate {
  const DetectionIsolate();
}
