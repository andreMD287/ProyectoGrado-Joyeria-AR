# B6 — Nota de análisis: oclusión por segmentación

**Frente:** B — Investigación y decisiones técnicas (spikes) · **Prioridad:** Baja · **Corresponde a:** Sprint 5
**Tipo:** Análisis (sin implementación) · **Estado:** Borrador · **Última actualización:** 2026-08-09

> Documento interno de trabajo. Panorama previo de las alternativas para resolver la **oclusión** de las piezas virtuales, es decir, que partes del cuerpo del usuario (una mano, el cabello, la mandíbula) tapen correctamente la joya cuando pasan por delante, en lugar de que la joya se dibuje siempre encima. Esta tarea es solo análisis; **no incluye implementación**.

---

## 1. Problema

La aplicación superpone un modelo 3D sobre un punto anatómico (muñeca, lóbulo, cuello). Sin manejo de oclusión, la pieza se renderiza **siempre por delante** de la imagen de cámara, lo que rompe la ilusión cuando algo del cuerpo debería quedar delante de la joya (p. ej. el cabello sobre un arete, los dedos sobre una pulsera, la barbilla sobre un collar). Resolver la oclusión es lo que hace que la pieza «se sienta» puesta sobre el cuerpo.

---

## 2. Alternativas evaluadas

### 2.1 Segmentación de persona (MediaPipe Selfie Segmentation / ML Kit Selfie Segmentation)
Genera una **máscara** que separa a la persona del fondo (y, en variantes multiclase, cabello/piel). Con esa máscara se puede recortar/ocultar la parte de la pieza que cae sobre la persona según la profundidad esperada.

- **A favor:** funciona con **cámara frontal 2D** (aretes y collares usan cámara frontal); ya hay ecosistema en Flutter (`google_mlkit_selfie_segmentation`); no depende de sensores especiales; coherente con el stack de ML Kit ya presente.
- **En contra:** entrega una máscara 2D, **no profundidad real**; decidir «delante/detrás» requiere heurísticas (p. ej. asumir que el cabello siempre ocluye el arete); bordes con *jitter*; costo de cómputo adicional por frame (se suma al presupuesto ya ajustado de detección — ver B5).

### 2.2 API de profundidad de ARCore / ARKit (Depth)
ARCore **Depth API** y ARKit (scene depth / LiDAR en dispositivos con sensor) entregan un **mapa de profundidad** que permite oclusión geométrica real contra el entorno y, en cierto grado, contra el usuario.

- **A favor:** oclusión **físicamente correcta** basada en profundidad; ARKit con LiDAR da resultados de alta calidad; se integra con la escena AR ya usada para pulseras (colocación sobre superficie).
- **En contra:** la mejor calidad depende de **hardware con sensor de profundidad** (LiDAR solo en iPhone Pro / iPad Pro); la Depth API de ARCore no está en todos los dispositivos; **la cámara frontal (aretes/collares) tiene soporte de profundidad muy limitado**, justo donde más se necesita la oclusión de cabello/mandíbula; mayor complejidad de integración con el pipeline actual.

---

## 3. Lectura preliminar por categoría

| Categoría | Cámara | Oclusión más problemática | Alternativa preliminar |
|---|---|---|---|
| Aretes | Frontal | Cabello sobre el lóbulo | Segmentación (2.1) + heurística "cabello ocluye" |
| Collares | Frontal | Barbilla / cabello sobre la clavícula | Segmentación (2.1) |
| Pulseras | Trasera | Dedos/otra mano sobre la muñeca | Depth API (2.2) donde exista; si no, segmentación |

La cámara frontal (aretes y collares) es donde la profundidad de AR es más débil, y es justo donde la **segmentación** es más aplicable. Para pulseras (cámara trasera) la **Depth API** es más natural cuando el dispositivo la soporta.

---

## 4. Recomendación preliminar

Para el alcance del semestre, **priorizar segmentación de persona (MediaPipe / ML Kit Selfie Segmentation)** como enfoque base y transversal a las tres categorías, por su independencia de hardware especial y su compatibilidad con cámara frontal. Considerar la **Depth API (ARCore/ARKit)** como mejora opcional para pulseras en dispositivos que la soporten. Medir siempre el **impacto en FPS** (relacionado con B5): la segmentación añade carga por frame y podría requerir el isolate dedicado ya previsto.

> Recomendación **preliminar y sujeta a spike de implementación en Sprint 5**. Esta nota no implica desarrollo.

---

## 5. Criterio de cierre de la tarea (según TAREAS_PENDIENTES)

> «Existe una nota técnica con las alternativas evaluadas y una recomendación preliminar.» — Cubierto por este documento.
