# D1 — Pipeline de digitalización de piezas de joyería

**Frente:** D — Modelos 3D y catálogo · **Prioridad:** Alta · **Desbloquea:** D2, D3
**Estado:** Borrador para revisión del equipo · **Última actualización:** 2026-08-09

> Documento interno de trabajo. Define el flujo reproducible para convertir una pieza física de la joyería participante en un modelo 3D listo para renderizarse y anclarse en la aplicación. Alcance del producto: **aretes, pulseras y collares**.

---

## 1. Objetivo

Establecer un procedimiento repetible y documentado para digitalizar piezas reales, de modo que cualquier integrante pueda producir un modelo con la misma calidad y las mismas convenciones (formato, escala, materiales), y que el resultado se integre sin fricción en el visor 3D (`model_viewer_plus`) y en la colocación en realidad aumentada (`ar_flutter_plugin_2` sobre ARCore/ARKit).

**Formato de salida obligatorio:** GLB (glTF 2.0 binario) con materiales PBR *metallic-roughness*. Es el único formato validado en las tres vías de renderizado del proyecto (visor WebView, ARCore, ARKit).

---

## 2. Decisión de método: fotogrametría vs. modelado manual

La joyería presenta condiciones adversas para la fotogrametría: piezas **pequeñas**, **metálicas y reflectantes**, con **geometría delgada** (cadenas, aros, engastes) y a menudo **transparentes** (gemas). Estas características rompen los supuestos de la reconstrucción por fotografías, que asume superficies opacas, mate y con textura suficiente para el emparejamiento de puntos.

| Criterio | Fotogrametría | Modelado manual en Blender |
|---|---|---|
| Piezas reflectantes/metálicas | Deficiente (requiere spray mateante que altera la pieza) | Controlado |
| Geometría delgada (cadenas, aros) | Muy deficiente | Controlado |
| Gemas transparentes | Inviable | Se modela + material de transmisión |
| Precisión dimensional | Depende de escalado con referencia | Exacta (se modela con medidas reales) |
| Curva de aprendizaje | Media (captura + software) | Media–alta (Blender) |
| Reproducibilidad | Baja para joyería | Alta |
| Costo de herramientas | Escáner/app + PC | Blender (gratuito) |

**Recomendación:** **modelado manual en Blender** como método principal, a partir de fotografías de referencia (frente, perfil, detalle) y **medidas reales tomadas con calibrador (pie de rey)**. La fotogrametría se reserva como método secundario **solo** para piezas grandes y de acabado mate (p. ej. un dije voluminoso), y con la advertencia de que la pieza no puede intervenirse con spray.

---

## 3. Herramientas seleccionadas

| Etapa | Herramienta | Notas |
|---|---|---|
| Captura de referencia | Cámara del teléfono + calibrador (pie de rey) | Fotos frente/perfil/detalle sobre fondo neutro y regla visible. Registrar medidas en mm. |
| Modelado y retopología | **Blender 4.x** (gratuito) | Add-ons útiles: *LoopTools*, *Bool Tool*. Exportador glTF 2.0 incluido de fábrica. |
| Materiales PBR | Blender (Principled BSDF) | Mapeo directo a glTF *metallic-roughness*. |
| Optimización/inspección | **glTF-Transform** (CLI) y **gltf-report** | Cuantiza, comprime (Draco) e inspecciona conteo de triángulos/materiales. |
| Validación visual | Visor `model_viewer_plus` de la app + [gltf-viewer de Khronos](https://github.khronos.org/glTF-Sample-Viewer-Release/) | Comparar contra un visor de referencia antes de meterlo a la app. |
| Fotogrametría (secundaria) | App de escaneo (p. ej. RealityScan / Polycam) | Solo piezas grandes y mate. |

---

## 4. Flujo completo (paso a paso)

### 4.1 Captura de referencia
1. Fotografiar la pieza sobre fondo neutro, iluminación difusa, incluyendo **frente, perfil y detalle de engastes/broches**.
2. Medir con calibrador las **dimensiones reales en milímetros** (largo, ancho, grosor; diámetro en aros/aretes; longitud de cadena en collares). Registrar todo — es insumo directo de la calibración de escala (ver §6) y del catálogo D3.
3. Anotar el **tipo de anclaje** de la pieza:
   - Arete → lóbulo de la oreja.
   - Pulsera → muñeca (landmark 0 / WRIST).
   - Collar → base del cuello / entre hombros (pose, landmarks 11 y 12).

### 4.2 Modelado
1. Modelar con las medidas reales activando unidades métricas en Blender (Scene → Units → Metric, escala 0.001 para trabajar en mm cómodamente, o modelar en metros directamente).
2. Usar simetría (modifier *Mirror*) donde aplique. Modelar cadenas con *Array + Curve* modifiers en lugar de eslabón por eslabón manual.
3. Mantener geometría **manifold** (sin caras internas ni normales invertidas).

### 4.3 Retopología y presupuesto de polígonos
- Objetivo móvil: **≤ 20 000–50 000 triángulos por pieza** (menor es mejor; varias piezas pueden coexistir en escena).
- Si se esculpe alto detalle o se usa fotogrametría, **hornear (bake) un normal map** desde el modelo de alta densidad hacia una malla de baja densidad. El detalle fino (grabados, texturas de metal) va al normal map, no a la geometría.
- Aplicar todas las transformaciones antes de exportar (Object → Apply → All Transforms) para evitar escalas/rotaciones no horneadas.

### 4.4 Materiales PBR (metallic-roughness)
Usar **Principled BSDF**, que mapea directamente al modelo *metallic-roughness* de glTF:

| Material | Base Color | Metallic | Roughness | Notas |
|---|---|---|---|---|
| Oro pulido | tono dorado | **1.0** | 0.05–0.2 | El color del metal va en Base Color, no en un mapa aparte. |
| Plata / oro blanco | gris claro / blanco | **1.0** | 0.05–0.25 | |
| Metal cepillado | según metal | **1.0** | 0.3–0.5 | Roughness map si hay variación. |
| Gema (diamante, etc.) | tinte de la gema | 0.0 | 0.0–0.05 | Requiere extensiones de transmisión (ver ⚠). |

⚠ **Gemas y transparencia (limitación importante):** el realismo de las gemas depende de extensiones glTF (`KHR_materials_transmission`, `KHR_materials_ior`, `KHR_materials_volume`). Estas **sí** se renderizan en `model_viewer_plus`, pero el soporte en `ar_flutter_plugin_2` (ARCore/Sceneform) y en ARKit es **limitado o inexistente**. **Decisión práctica para la primera iteración:** aproximar las gemas con un material opaco/semi-especular (roughness muy baja, color con brillo) para garantizar consistencia entre las tres vías, y dejar la transmisión física como mejora posterior sujeta a spike. Documentar la aproximación usada por pieza.

### 4.5 Exportación a GLB
Exportar con **File → Export → glTF 2.0 (.glb)** y estas opciones:
- **Format:** `glTF Binary (.glb)` (texturas embebidas en un solo archivo).
- **Include:** solo *Selected Objects* (la pieza), sin cámaras ni luces.
- **Transform:** `+Y Up` (convención glTF).
- **Data → Mesh:** aplicar modifiers; exportar normales y UVs.
- **Materials:** `Export` (con imágenes embebidas).
- **Compression (Draco):** opcional. Reduce tamaño, pero **verificar que `ar_flutter_plugin_2` cargue GLB con Draco en dispositivo antes de adoptarlo como estándar** (spike menor). Si hay duda, exportar sin Draco en la primera pieza.

Convención de escala del archivo: **1 unidad glTF = 1 metro**. Una pulsera de 60 mm de diámetro debe medir 0.06 en el GLB. Esto permite anclar con escalas realistas (ver la escala `Vector3(0.15,...)` que el MVP usaba solo como placeholder sobre mesa).

### 4.6 Optimización e inspección (opcional pero recomendado)
```bash
# Inspeccionar conteo de triángulos, materiales y tamaño
npx gltf-transform inspect pieza.glb

# Cuantizar geometría y opcionalmente comprimir (validar en dispositivo)
npx gltf-transform optimize pieza.glb pieza.opt.glb --compress draco
```

### 4.7 Validación en la aplicación
1. Cargar el GLB en la pantalla del visor (`model_viewer_plus`) y verificar: materiales PBR correctos, reflejos, ausencia de caras invertidas, orientación.
2. Colocarlo con `ar_flutter_plugin_2` sobre superficie y confirmar que **la escala real** se ve correcta (usar la medida en mm como verdad de terreno).
3. Registrar cualquier discrepancia de material entre el visor y AR (ver ⚠ de §4.4).

---

## 5. Convenciones obligatorias (checklist de aceptación por pieza)

- [ ] Formato **GLB (glTF 2.0)**, texturas embebidas, un solo archivo.
- [ ] Escala **1 unidad = 1 metro**, coherente con la medida real en mm.
- [ ] Orientación **+Y up**; transformaciones aplicadas.
- [ ] Materiales **metallic-roughness** (metales con Metallic = 1.0).
- [ ] **≤ 50 000 triángulos**; detalle fino en normal map.
- [ ] Renderiza correctamente en el **visor** y se ancla con escala real en **AR**.
- [ ] **Dimensiones reales (mm)** y **tipo de anclaje** registrados en el catálogo (D3).

---

## 6. Escala real y calibración

La medida física en milímetros de cada pieza es el puente entre el modelo y el mundo real. El anclaje coloca la pieza en el punto anatómico detectado (muñeca, lóbulo, cuello), pero su **tamaño aparente** debe corresponder al tamaño físico. Por eso cada pieza del catálogo lleva su dimensión real (D3), y la app derivará el factor de escala a partir de ella en lugar de usar valores fijos como en la validación técnica previa.

---

## 7. Pendientes / spikes derivados

- Confirmar en dispositivo si `ar_flutter_plugin_2` carga GLB con **compresión Draco** (define si Draco entra al estándar).
- Spike de **gemas**: viabilidad de `KHR_materials_transmission` en ARCore/ARKit vs. aproximación opaca.
- Relación con **D4** (evaluación de conversión GLB→USDZ) para el botón Quick Look de iOS.

---

## 8. Criterio de cierre de la tarea (según TAREAS_PENDIENTES)

> «Existe una guía breve y reproducible del pipeline, con las herramientas seleccionadas.» — Cubierto por este documento, pendiente de revisión de al menos otro integrante.
