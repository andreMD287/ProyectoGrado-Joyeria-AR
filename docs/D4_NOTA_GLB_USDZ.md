# D4 — Nota de evaluación: conversión GLB → USDZ

**Frente:** D — Modelos 3D y catálogo · **Prioridad:** Baja · **Dependencias:** D2
**Tipo:** Evaluación (sin implementación) · **Estado:** Borrador · **Última actualización:** 2026-08-09

> Documento interno de trabajo. Evalúa el costo de convertir los modelos GLB a **USDZ**, formato que exige el botón de realidad aumentada nativo de `model-viewer` en iOS (**Quick Look**). Esta tarea es solo evaluación; **no incluye implementación**.

---

## 1. Contexto y por qué NO es crítico

El flujo principal de colocación en realidad aumentada del proyecto usa **`ar_flutter_plugin_2` sobre ARKit**, y **funciona con archivos GLB** en iOS. Ese camino es independiente y no necesita USDZ.

USDZ solo hace falta para un elemento secundario: el **botón AR nativo de `<model-viewer>`** (modo *Quick Look* de iOS), que requiere un archivo `.usdz` provisto vía `iosSrc`. Con solo GLB, ese botón nativo no abre Quick Look en iPhone. Dado que el proyecto ya tiene AR funcional por otra vía, **USDZ es opcional** y se documenta aquí únicamente para tener el costo estimado si se decide habilitar Quick Look en el futuro.

---

## 2. Herramientas de conversión GLB → USDZ

| Herramienta | Plataforma | Notas |
|---|---|---|
| **Reality Converter** (Apple) | macOS | GUI; arrastrar el GLB y exportar USDZ. Permite previsualizar materiales. Requiere Mac. |
| **`usdzconvert` / USD tools** (Apple) | macOS (CLI) | Parte de las herramientas USD de Apple; automatizable por lote. |
| **`usd_from_gltf`** (Google) | Linux/CLI | Conversor glTF→USDZ pensado para pipelines automatizados; buena fidelidad de materiales PBR. |
| **Blender (exportador USD)** | multiplataforma | Exporta `.usd`/`.usdz`; la fidelidad de materiales PBR→USD puede requerir ajustes. |
| Servicios/convertidores web | web | Rápidos para pruebas puntuales; **no** recomendados para piezas reales por privacidad/consistencia. |

Para el proyecto, si se aborda, lo más natural es **Reality Converter** (ya se dispone de macOS por el entorno iOS) para pocas piezas, o **`usd_from_gltf`** si se quiere automatizar la conversión de todo el catálogo.

---

## 3. Costo estimado

- **Por pieza:** bajo (minutos) con Reality Converter una vez que el GLB está validado.
- **Por lote:** un script con `usd_from_gltf`/`usdzconvert` convierte todo el catálogo en una sola pasada; costo principal es la puesta a punto inicial del script (~1–2 h).
- **Riesgo:** diferencias de materiales entre GLB y USDZ (metalicidad, transmisión de gemas). Habría que **revisar visualmente** cada USDZ en Quick Look, lo que suma tiempo si el catálogo crece.

---

## 4. Recomendación

**No incorporar USDZ al flujo principal.** El AR del proyecto ya funciona con GLB vía `ar_flutter_plugin_2`/ARKit. Habilitar Quick Look (y por tanto USDZ) queda como **mejora opcional** de baja prioridad; si se decide, usar **Reality Converter** (pocas piezas) o **`usd_from_gltf`** (lote), y mantener el USDZ como archivo derivado del GLB (que sigue siendo la fuente de verdad, ver D1).

---

## 5. Criterio de cierre de la tarea (según TAREAS_PENDIENTES)

> «Existe una nota breve con la conclusión (viabilidad y herramienta recomendada, de aplicar).» — Cubierto por este documento.
