# D3 — Estructura del catálogo y esquema de metadatos

**Frente:** D — Modelos 3D y catálogo · **Prioridad:** Media · **Insumo directo de:** SRS (requisitos funcionales) y Sprint 4
**Estado:** Borrador para revisión y coordinación con la Product Owner · **Última actualización:** 2026-08-09

> Documento interno de trabajo. Define **qué piezas** entran en el alcance del semestre y **qué metadatos** describe cada pieza, de modo que el catálogo sea consumible tanto por la aplicación como por la documentación académica. Alcance del producto: **aretes, pulseras y collares** (sin anillos).

---

## 1. Alcance de piezas por categoría (propuesta)

La cantidad final requiere **coordinación con la joyería participante a través de la Product Owner**. Se propone un alcance conservador que permita cubrir las tres técnicas de anclaje sin sobrecargar la producción de modelos 3D (tarea D2, de esfuerzo alto):

| Categoría | Técnica de anclaje | Piezas sugeridas (semestre) | Justificación |
|---|---|---|---|
| Aretes | Rostro — lóbulo (detección facial) | 2–3 | Cubre el frente de detección facial (B3, C1). |
| Pulseras | Muñeca — landmark 0 / WRIST | 2–3 | Técnica ya validada en Android; menor riesgo. |
| Collares | Pose — hombros/cuello (landmarks 11, 12) | 1–2 | Mayor riesgo técnico (B2, sin investigación previa); iniciar con pocas. |
| **Total** | — | **~6–8 piezas** | Suficiente para demostrar las tres técnicas sin exceder capacidad de modelado. |

**Recomendación de secuencia:** empezar por **una pulsera o un arete de geometría simple** (coherente con D2), validar el pipeline completo end-to-end, y luego escalar el resto.

---

## 2. Esquema de metadatos por pieza

Cada pieza se describe con los siguientes campos. Los tipos de anclaje están acotados al alcance del proyecto.

| Campo | Tipo | Requerido | Descripción |
|---|---|---|---|
| `id` | string | Sí | Identificador estable, kebab-case (p. ej. `pulsera-eslabon-01`). |
| `nombre` | string | Sí | Nombre comercial/descriptivo de la pieza. |
| `categoria` | enum | Sí | `arete` \| `pulsera` \| `collar`. |
| `tipo_anclaje` | enum | Sí | `lobulo` \| `muneca` \| `cuello`. Deriva de la categoría. |
| `landmark_anclaje` | objeto/int | Sí | Punto de referencia del tracking: pulsera → `0` (WRIST); collar → `[11, 12]` (hombros, Pose); arete → landmark(s) de oreja/lóbulo según B3. |
| `modelo_glb` | string (ruta) | Sí | Ruta al archivo GLB en `assets/models/`. |
| `foto` | string (ruta) | Sí | Foto de referencia de la pieza real. |
| `dimensiones_mm` | objeto | Sí | Medidas reales en milímetros (ver §3). Insumo de calibración de escala. |
| `material` | string | No | Descripción del material (p. ej. "plata 925", "oro 18k con circón"). |
| `descripcion` | string | No | Texto breve para la ficha en la UI. |
| `estado` | enum | Sí | `pendiente` \| `modelado` \| `validado` (avance de producción del modelo). |
| `notas_material` | string | No | Aproximaciones aplicadas (p. ej. gema opaca en vez de transmisión — ver D1 §4.4). |

### 2.1 Subesquema `dimensiones_mm`
| Campo | Aplica a | Descripción |
|---|---|---|
| `alto` | todas | Altura de la pieza en mm. |
| `ancho` | todas | Ancho en mm. |
| `profundidad` | todas | Grosor en mm. |
| `diametro` | aretes, pulseras | Diámetro del aro/pulsera en mm. |
| `longitud` | collares | Longitud total de la cadena en mm. |

---

## 3. Ejemplo de catálogo (JSON)

Formato propuesto para `assets/catalog/catalog.json` en el proyecto:

```json
{
  "version": 1,
  "categorias": ["arete", "pulsera", "collar"],
  "piezas": [
    {
      "id": "pulsera-eslabon-01",
      "nombre": "Pulsera de eslabones clásica",
      "categoria": "pulsera",
      "tipo_anclaje": "muneca",
      "landmark_anclaje": 0,
      "modelo_glb": "assets/models/pulsera-eslabon-01.glb",
      "foto": "assets/catalog/fotos/pulsera-eslabon-01.jpg",
      "dimensiones_mm": { "alto": 8, "ancho": 180, "profundidad": 4, "diametro": 60 },
      "material": "plata 925",
      "descripcion": "Pulsera de eslabones, cierre de mosquetón.",
      "estado": "pendiente",
      "notas_material": ""
    },
    {
      "id": "arete-gota-01",
      "nombre": "Arete gota con circón",
      "categoria": "arete",
      "tipo_anclaje": "lobulo",
      "landmark_anclaje": null,
      "modelo_glb": "assets/models/arete-gota-01.glb",
      "foto": "assets/catalog/fotos/arete-gota-01.jpg",
      "dimensiones_mm": { "alto": 22, "ancho": 8, "profundidad": 6 },
      "material": "plata 925 con circón",
      "descripcion": "Arete colgante en forma de gota.",
      "estado": "pendiente",
      "notas_material": "Circón aproximado con material opaco especular (ver D1)."
    },
    {
      "id": "collar-cadena-01",
      "nombre": "Collar cadena fina con dije",
      "categoria": "collar",
      "tipo_anclaje": "cuello",
      "landmark_anclaje": [11, 12],
      "modelo_glb": "assets/models/collar-cadena-01.glb",
      "foto": "assets/catalog/fotos/collar-cadena-01.jpg",
      "dimensiones_mm": { "alto": 15, "ancho": 12, "profundidad": 3, "longitud": 420 },
      "material": "oro 18k",
      "descripcion": "Collar de cadena fina con dije central.",
      "estado": "pendiente",
      "notas_material": ""
    }
  ]
}
```

`landmark_anclaje` de aretes queda `null` a la espera del resultado de **B3** (definición exacta del/los landmark(s) de lóbulo con ML Kit o Face Mesh).

---

## 4. Estructura de carpetas de assets (propuesta)

```
assets/
├── catalog/
│   ├── catalog.json                # metadatos de todas las piezas
│   └── fotos/                       # fotos de referencia de las piezas reales
│       ├── pulsera-eslabon-01.jpg
│       └── ...
└── models/                         # modelos GLB (glTF 2.0, PBR)
    ├── pulsera-eslabon-01.glb
    └── ...
```

Cada pieza mantiene el **mismo `id`** como nombre base de su GLB y su foto, para trazabilidad directa.

---

## 5. Relación con otras tareas

- **D1** (pipeline): produce los GLB y exige registrar dimensiones reales y tipo de anclaje → alimentan este esquema.
- **D2** (primer modelo real): la primera pieza validada estrena este catálogo (`estado: validado`).
- **B2 / B3**: definen `landmark_anclaje` de collares y aretes respectivamente.
- **SRS (E1)**: los requisitos funcionales deben cubrir las tres categorías; este catálogo es la fuente de verdad del alcance de piezas.
- **Sprint 4**: consume la estructura para la vista de catálogo/selección de pieza.

---

## 6. Criterio de cierre de la tarea (según TAREAS_PENDIENTES)

> «Existe una lista acordada de piezas y un esquema de metadatos por pieza.»
> Pendiente: **acordar la lista final con la joyería participante (vía Product Owner)**. El esquema de metadatos y la estructura de catálogo quedan propuestos en este documento para revisión.
