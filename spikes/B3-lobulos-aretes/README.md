# B3 — Spike: detección de lóbulos para aretes

**Frente:** B — Spikes de investigación · **Prioridad:** Alta · **Alimenta:** `EarringStrategy`, `FaceDetectorDataSource`, C1
**Tipo:** Técnica (POC de geometría + decisión documentada) · **Estado:** Resuelto con recomendación · **Última actualización:** 2026-08-10

> Determinar si `google_mlkit_face_detection` tiene precisión suficiente para ubicar los lóbulos con la exactitud que exige un arete, o si se requiere Face Mesh (468 puntos).

---

## 1. Hallazgo central

**ML Kit Face Detection no expone un landmark de "lóbulo".** Entrega la posición de la **oreja** (`leftEar`/`rightEar`), los ojos, la nariz y la boca, más los ángulos de cabeza (Euler X/Y/Z). El lóbulo, por tanto, **se estima**: se desplaza la posición de la oreja hacia abajo a lo largo del eje vertical del rostro (perpendicular a la línea de ojos) una fracción de la distancia interocular. Esta es la misma situación que con la muñeca o los hombros: el anclaje es un punto **derivado**, no un landmark directo.

Face Mesh (468 puntos) **tampoco** tiene un vértice etiquetado como "lóbulo", pero da una malla densa de la región de la oreja y una estimación de pose más estable.

---

## 2. Qué contiene

- **POC de geometría (Dart puro, ejecutable):** `lib/earring_anchor.dart` estima el/los anclaje(s) de arete a partir de orejas + ojos; `bin/b3_anchor_demo.dart` lo valida con rostros sintéticos.
- **Integración real en la app** (§5): `FaceDetectorDataSource` con ML Kit y `EarringStrategy` con esta lógica, cubierta por pruebas.

```bash
cd spikes/B3-lobulos-aretes
dart pub get
dart run bin/b3_anchor_demo.dart
```

---

## 3. Resultados de la estimación de anclaje

| Rostro | Resultado |
|---|---|
| Frontal (2 orejas) | 2 anclajes, cada lóbulo por debajo de su oreja (y=0.592), roll=0° |
| Cabeza inclinada | roll=20.6°; el anclaje se desplaza por el eje vertical rotado |
| Cabeza girada (1 oreja) | 1 anclaje (oreja visible) |
| Baja confianza | sin anclaje |
| Sin ojos | sin anclaje (no hay escala ni inclinación) |

Todos los chequeos pasan. La geometría degrada de forma segura: sin ojos o baja confianza, no inventa un anclaje.

---

## 4. Decisión documentada: ML Kit Face Detection vs. Face Mesh

| Criterio | `google_mlkit_face_detection` | Face Mesh (468 puntos) |
|---|---|---|
| Landmark de lóbulo | No (se estima desde la oreja) | No (se estima desde la región de la oreja, con más densidad) |
| Precisión de la región de oreja | Media (1 punto de oreja + Euler) | Alta (malla densa) |
| Cross-platform | **Sí** (Android e iOS) | **No con ML Kit** (`google_mlkit_face_mesh_detection` es Android-only); en iOS habría que usar ARKit Face (requiere cámara TrueDepth) |
| Esfuerzo de integración | **Bajo** (ya en el stack) | Alto (Android-only + solución nativa iOS distinta) |
| Robustez ante giro/inclinación | Media (Euler ayuda) | Alta |

**Decisión: empezar con `google_mlkit_face_detection`.** Da la posición de la oreja, los ojos y los ángulos de cabeza —suficiente para estimar el lóbulo, como demuestra el POC— es cross-platform y de bajo esfuerzo. **Escalar a Face Mesh solo si las pruebas en dispositivo muestran precisión insuficiente**, asumiendo su costo: en Android `google_mlkit_face_mesh_detection`, y en iOS una vía nativa distinta (ARKit Face), lo que reintroduce el problema de paridad entre plataformas (como en el tracking de manos, B1).

---

## 5. Integración en el proyecto (ya incorporada)

- `lib/features/tracking/data/datasources/face_detector_datasource.dart`: detector ML Kit Face con landmarks, entrega oreja/ojos normalizados en el orden que espera la estrategia.
- `lib/features/tracking/domain/strategies/earring_strategy.dart`: estima la `AnchorPose` del lóbulo con la lógica de este spike; cubierta por `test/earring_strategy_test.dart`.

> Limitación actual: la interfaz devuelve **un** anclaje (la oreja disponible). Anclar los **dos** aretes a la vez requerirá un resultado con múltiples anclajes.

---

## 6. Evidencia pendiente de recoger en dispositivo (protocolo de prueba)

La decisión "ML Kit basta" debe confirmarse con estas pruebas de cámara frontal, midiendo el error del anclaje respecto al lóbulo real:

1. **Frontal**, a ~40–60 cm.
2. **Ángulos de cabeza**: giro (yaw) ±15°/±30°, inclinación (roll) ±15°, cabeceo (pitch) ±15°.
3. **Cabello suelto vs. recogido** — caso crítico: con el cabello cubriendo la oreja, ML Kit puede **no** devolver el landmark de oreja. Registrar la tasa de detección en ambos casos.
4. Afinar `dropFactor` (inicial 0.45 de la interocular) para que el anclaje caiga sobre el lóbulo.

Si con cabello suelto la detección de oreja falla con frecuencia o el error supera el tamaño del arete, ese es el disparador para pasar a Face Mesh.

---

## 7. Criterio de cierre (según TAREAS_PENDIENTES)

> «Existe una decisión documentada (suficiencia de ML Kit o necesidad de Face Mesh) respaldada por evidencia de las pruebas realizadas.» — **Cubierto** en cuanto a la decisión (ML Kit Face Detection, con estimación del lóbulo) y la evidencia de la geometría (POC con pruebas). **Pendiente** la evidencia de precisión en dispositivo (§6), que puede confirmar la decisión o disparar el cambio a Face Mesh.
