# B5 — Spike: rendimiento de la detección (isolate dedicado)

**Frente:** B — Spikes de investigación · **Prioridad:** Media · **Alimenta:** `core/isolate/`, C2/C3
**Tipo:** Técnica (prueba de concepto ejecutable) · **Estado:** Prototipo con métricas · **Última actualización:** 2026-08-09

> `detect()` es síncrono y bloquea el isolate principal (~15–40 ms/frame), lo que en la validación previa obligó a limitar la detección a ≤10 FPS para que la UI siguiera usable. Este spike prototipa la solución documentada —un **isolate dedicado** con su propia instancia del detector, recibiendo los bytes del frame por `SendPort`— y **mide** el efecto.

---

## 1. Qué contiene

Paquete Dart **puro y sin dependencias externas**:

```
spikes/B5-isolate/
├── lib/
│   ├── detection_workload.dart   # detección simulada (CPU-bound ~25 ms) + calibración
│   └── detection_isolate.dart    # isolate dedicado reusable (espejo del de core/)
└── bin/
    └── b5_isolate_demo.dart      # banco de comparación + chequeos
```

### Cómo reproducir
```bash
cd spikes/B5-isolate
dart pub get
dart run bin/b5_isolate_demo.dart
```

El banco mide, en una ventana fija de 2 s, cuántas **detecciones** se completan y cuántos **ticks de UI** (un `Timer` a 60 FPS) alcanza a ejecutar el event loop del isolate principal, en dos escenarios: detección síncrona (baseline) vs. isolate dedicado.

---

## 2. Resultados (ejecución en esta máquina)

Detección simulada ≈ **42.5 ms/frame** (techo teórico ~24 FPS de detección con un core).

| Escenario | Detección | UI (event loop) |
|---|---|---|
| Baseline (síncrono en el isolate principal) | 24.5 FPS | **0.0 FPS** (congelada) |
| **Isolate dedicado** | 24.4 FPS | **61.8 FPS** (fluida) |

> Los milisegundos por frame dependen de la máquina (aquí la detección simulada quedó en ~42 ms); lo relevante es la **comparación relativa**, que es independiente del costo absoluto.

---

## 3. Análisis

- Con detección **síncrona**, el bucle de detección no cede el event loop: la UI queda **totalmente bloqueada** (0 FPS). Es exactamente el problema que forzó el throttle a ≤10 FPS en la validación previa.
- Con el **isolate dedicado**, el trabajo pesado corre en otro core: la UI recupera **~60 FPS** mientras la detección **mantiene su throughput** (~24 FPS, sin degradación por el paso de mensajes).
- El throughput de detección con un solo isolate está acotado por un core (~24 FPS a 42 ms/frame). Subirlo más no depende de añadir isolates para un detector serial, sino de acelerar la detección en sí (delegado GPU de MediaPipe, menor resolución) o de segmentar el pipeline. La ganancia central de B5 es **liberar la UI**, no multiplicar el FPS de detección.

---

## 4. Recomendación

**Adoptar el isolate dedicado de detección.** Permite que la detección corra a su ritmo natural y que la UI (preview de cámara + overlay + render AR) se mantenga fluida, en lugar de sacrificar FPS de detección para no congelar la interfaz.

### Restricciones a tener en cuenta en la integración real
- **`CameraImage` no es transferible** entre isolates directamente: se envían sus **bytes** (planos YUV) por `SendPort`. El plugin debe aceptar bytes + orientación del sensor.
- Detectores por **platform channel (ML Kit)**: requieren `BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken)` **dentro** del isolate. Por eso la decisión isolate/hilo-principal se toma por detector.
- **`hand_landmarker` (JNI)** es más autónomo, buen primer candidato para correr en el isolate.
- Conviene un **pipeline con como máximo 1–2 frames en vuelo** (backpressure) para no acumular latencia; descartar frames viejos si el isolate va por detrás.

---

## 5. Integración en el proyecto

`detection_isolate.dart` de este spike es el espejo de `lib/core/isolate/detection_isolate.dart`. En el proyecto real:
- El isolate aloja la instancia del detector (Android: `hand_landmarker`).
- `TrackingRepositoryImpl` envía los bytes del frame y recibe landmarks, aplica la estrategia de anclaje y la estabilización (B4) antes de emitir la `AnchorPose`.

---

## 6. Criterio de cierre (según TAREAS_PENDIENTES)

> «Existe una prueba de concepto con métricas de FPS que confirme o descarte la mejora de rendimiento.» — **Cubierto:** el banco confirma que el isolate preserva el throughput de detección y libera la UI (0 → ~60 FPS).

**Pendiente de validación en dispositivo (C2/C3):** repetir la medición con el detector real (`hand_landmarker`) y frames de cámara reales en un Android, confirmando la mejora end-to-end.
