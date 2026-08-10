# B2 — Spike: detección de pose para collares

**Frente:** B — Spikes de investigación · **Prioridad:** Alta · **Alimenta:** `NecklaceStrategy`, `PoseDetectorDataSource`, C-collares
**Tipo:** Técnica (POC de geometría + nota de viabilidad) · **Estado:** Resuelto con recomendación · **Última actualización:** 2026-08-09

> Los collares no los cubren MediaPipe Hands ni Face Mesh: requieren **detección de pose** (hombros 11 y 12) para estimar el punto de anclaje. Este spike evalúa la alternativa de Flutter para la detección y desarrolla la **estimación del anclaje** a partir de los hombros.

---

## 1. Qué contiene

- **POC de geometría (Dart puro, ejecutable):** `lib/necklace_anchor.dart` estima el punto de anclaje del collar (posición, inclinación y ancho de hombros) a partir de los landmarks de pose; `bin/b2_anchor_demo.dart` lo valida con poses sintéticas.
- **Integración real en la app** (ver §5): `PoseDetectorDataSource` con `google_mlkit_pose_detection` y `NecklaceStrategy` con esta misma lógica, cubierta por pruebas unitarias.

### Cómo reproducir
```bash
cd spikes/B2-pose-collares
dart pub get
dart run bin/b2_anchor_demo.dart
```

---

## 2. Resultados de la estimación de anclaje

| Pose | Resultado |
|---|---|
| Frontal erguido | anclaje centrado (x=0.500), roll=0.0°, por debajo de los hombros, ancho=0.200 |
| Hombros inclinados | roll=21.8° (sigue la inclinación) |
| Persona girada | ancho=0.080 (menor → sirve para escalar la pieza) |
| Baja confianza (<0.5) | sin anclaje (`null`) |
| Sin hombros | sin anclaje (`null`) |

La lógica: anclaje = punto medio de los hombros **desplazado hacia abajo** una fracción del ancho de hombros (el collar reposa sobre el pecho); `roll` de la línea de hombros; descarte por baja confianza. Todos los chequeos pasan.

---

## 3. Nota de viabilidad: ML Kit Pose vs. MediaPipe Pose nativo

| Criterio | `google_mlkit_pose_detection` | MediaPipe Pose nativo (platform channel) |
|---|---|---|
| Disponibilidad en Flutter | Paquete publicado, **ya en el stack** | Requiere puente nativo propio (Android + iOS) |
| Cross-platform | **Sí** (Android e iOS con la misma API) | Hay que implementar cada plataforma por separado |
| Landmarks | 33 (incluye hombros 11/12 con `likelihood`) | 33 (BlazePose); más opciones de configuración |
| Esfuerzo de integración | **Bajo** (API Dart directa) | **Alto** (código nativo, serialización, mantenimiento) |
| Rendimiento / control | Bueno; menos ajuste fino | Potencialmente mejor, con más control (delegado GPU, resolución) |
| Coordenadas | Píxeles de imagen (se normalizan) | Normalizadas |
| Riesgo | Bajo | Medio-alto (más superficie nativa que mantener) |

**Recomendación: usar `google_mlkit_pose_detection`.** Ya está en el stack, es cross-platform con una sola API, entrega los hombros con `likelihood` y su integración desde Flutter es directa. Cubre el requisito de estimar el anclaje del collar con esfuerzo bajo. Dejar **MediaPipe Pose nativo como optimización futura** solo si el rendimiento o la precisión en dispositivo resultan insuficientes.

---

## 4. Pendiente de validar en dispositivo

- **Cámara frontal** (los collares se prueban de frente), con la conversión `CameraImage → InputImage` por plataforma: Android en `nv21`, iOS en `bgra8888`; rotación según `sensorOrientation`.
- Ejecutar la detección dentro del **isolate dedicado** (spike B5) para no bloquear la UI.
- Afinar el umbral de `likelihood` (inicial 0.5) y el `neckDropFactor` (inicial 0.2) con personas reales y distintas distancias.
- Estabilizar el anclaje con el **One Euro Filter** (spike B4).

---

## 5. Integración en el proyecto (ya incorporada)

- `lib/features/tracking/data/datasources/pose_detector_datasource.dart`: detector ML Kit Pose, conversión de frame y mapeo de `Pose` a `Landmark` normalizado (hombros en índices 11/12), pendiente de validación en dispositivo.
- `lib/features/tracking/domain/strategies/necklace_strategy.dart`: estima la `AnchorPose` con la lógica de este spike; cubierta por `test/necklace_strategy_test.dart`.

---

## 6. Criterio de cierre (según TAREAS_PENDIENTES)

> «Existe una prueba de concepto de detección de hombros y una nota de viabilidad con la opción recomendada.» — **Cubierto:** POC de estimación de anclaje ejecutable y con pruebas, código de detección ML Kit Pose integrado, y nota de viabilidad con recomendación (ML Kit Pose). Pendiente la validación end-to-end en dispositivo (§4).
