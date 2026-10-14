# B6 (continuación) — Oclusión de la pieza: alternativas, estado y trabajo futuro

**Frente:** B — Investigación y decisiones técnicas · **Corresponde a:** Sprint 5 del plan (VFP8 §3.3.2)
**Tipo:** Análisis + registro de implementación · **Estado:** Vigente · **Última actualización:** 2026-10-01

> **Documento interno de trabajo.** Continúa y actualiza `B6_NOTA_OCLUSION.md`, que era un análisis
> **previo a implementar** y recomendaba una alternativa que luego se probó y **se descartó con datos**.
> Donde los dos se contradigan, manda este.
>
> El contenido no debe trasladarse literalmente a documentos académicos: allí aplican las convenciones
> de lenguaje del proyecto (no se nombra al cliente, no se emplean "MVP" ni "prototipo", y no se hace
> referencia a anillos ni a dedos).

---

## 1. Qué es la oclusión aquí, y por qué importa

La aplicación dibuja un modelo 3D sobre un punto anatómico detectado (muñeca, lóbulo, cuello). Sin
manejo de oclusión la pieza se pinta **siempre por delante** de la imagen de cámara: la parte del
brazalete que debería pasar **por detrás** del antebrazo se ve igual que la de delante, y el resultado
es un aro flotando sobre el brazo en vez de un aro puesto alrededor del brazo.

Ese es exactamente el síntoma que el usuario reportó como *"parece una imagen 3D superpuesta, no una
joya puesta en el cuerpo"*, y es lo que conecta esta tarea con la formulación del problema del
proyecto, que pide visualizar las piezas **"de manera realista"** (VFP8 §1.1.2).

Conviene separar dos problemas que se confunden:

| | Qué tapa a la joya | Estado |
|---|---|---|
| **Oclusión propia** | La misma extremidad que lleva la pieza (el antebrazo dentro del brazalete) | **Resuelta para pulseras** |
| **Oclusión por terceros** | Algo distinto que pasa por delante: cabello sobre el arete, la otra mano sobre la muñeca, la barbilla sobre el collar | **No abordada** |

`B6_NOTA_OCLUSION.md` estudiaba sobre todo el segundo caso. Lo que resultó decisivo para la percepción
de "calcomanía" fue el primero, que esa nota no contemplaba.

---

## 2. Qué pedían los documentos de planeación

### 2.1. Documentos consultados

| Documento | Dónde | Qué aporta |
|---|---|---|
| **VFP8** — Propuesta para Proyecto de Grado | `docs/VFP8.pdf` | Problema, objetivo general, objetivos específicos, metodología y contenido de los 6 sprints |
| **B6 — Nota de oclusión** | `docs/B6_NOTA_OCLUSION.md` | Análisis previo (2026-08-09) con recomendación preliminar |
| **Tareas pendientes** | `docs/TAREAS_PENDIENTES.md` | B6 marcada ✅ con criterio de cierre "existe una nota técnica" |
| **SDD 2.3 — Arquitectura** | `docs/SDD_2.3_ARQUITECTURA_DEL_SISTEMA.md` | ADR-08, ADR-09, ADR-16, ADR-17 y la tabla de trabajo abierto |
| **Spike B7** | `spikes/B7-motor-render/README.md` | Evidencia medida en dispositivo de lo que funciona y lo que no |

> **Faltante conocido:** `docs/SPMPPlantilla.pdf` es la **plantilla en blanco** del Plan de
> Administración de Proyecto, no el plan diligenciado del equipo. El SPMP real no está en el
> repositorio, así que esta comparación se hace contra VFP8 + los documentos internos. Si el SPMP fija
> fechas o entregables distintos para el Sprint 5, hay que contrastarlo aparte.

### 2.2. Lo que el plan comprometió

De **VFP8 §3.3.2**, actividades del Sprint 5:

> **Sprint 5:** Oclusión y escalado: implementación de **oclusión por segmentación**, calibración de
> escala relativa al tamaño del dedo/oreja y pruebas comparativas joya real vs. virtual.

Y de **VFP8 §3.3.3** (resultados esperados): *"sistema de oclusión y escalado calibrado (Sprint 5)"*.

De la **recomendación preliminar de B6** (§4): priorizar **segmentación de persona** como enfoque base y
transversal a las tres categorías, con la Depth API como mejora opcional para pulseras.

### 2.3. Dos desviaciones del plan que hay que registrar

1. **La técnica comprometida no es la implementada.** El plan dice "oclusión por segmentación"; lo que
   funciona hoy es **oclusión por buffer de profundidad con un proxy geométrico**. La segmentación se
   implementó, se midió y se descartó (§3.4). La desviación está justificada con datos, pero debe
   quedar escrita en la retrospectiva del sprint (VFP8 §3.4), no descubrirse en la sustentación.
2. **La redacción del Sprint 5 está desactualizada.** Habla de calibrar "relativa al tamaño del
   dedo/oreja", y el proyecto ya no trabaja anillos ni dedos (convención registrada en
   `TAREAS_PENDIENTES.md`). La categoría equivalente hoy es la **pulsera**, calibrada contra el ancho
   de palma. Conviene corregir la redacción en el documento académico antes de citarla.

---

## 3. Catálogo completo de alternativas

Todas las opciones que se consideraron, en el orden en que aparecieron. La columna **Estado** distingue
lo que solo se pensó, lo que se probó, lo que se descartó y lo que está en producción.

| # | Alternativa | Estado | Veredicto en una línea |
|---|---|---|---|
| A | Sin oclusión (la pieza siempre encima) | Statu quo hasta 2026-09-18 | Es la causa del efecto "calcomanía" |
| B | Recorte 2D del *sprite* sobre la imagen | **Probado y descartado** | Ataca el síntoma, no la causa |
| C | **Proxy geométrico invisible que escribe profundidad** | **En producción (pulseras)** | **Adoptado** — ADR-16 / ADR-17 |
| D | Segmentación de persona (ML Kit / MediaPipe) | **Probada y descartada** | No distingue el brazo y corre a 2,5 Hz |
| E | Depth API de ARCore / ARKit (LiDAR) | Descartada por análisis | Sin soporte en cámara frontal (2 de 3 categorías) y dependiente de hardware |
| F | Detección de pose para medir el antebrazo | **Probada y descartada** | Alucina el brazo dentro de la mano, con `likelihood` 0,99 |
| G | Reconstrucción métrica de MediaPipe como fuente de tamaño | **Probada y descartada (2 veces)** | De ella solo sirven las direcciones |
| H | Proxy de la mano (dedos) sobre la pieza | **No probada — propuesta** | Los datos ya están; es la siguiente de mejor relación costo/beneficio |
| I | Segmentación multiclase (pelo / piel / cuerpo) | **No probada — propuesta** | Es la única vía realista para aretes y collares, pero exige código nativo |
| J | Profundidad monocular por red neuronal | **No probada — propuesta** | Resolvería todas las categorías; riesgo alto de rendimiento |
| K | Pedir la talla al usuario | Descartada por criterio | Traslada al cliente un problema técnico y no resuelve el eje ni la oclusión |

### 3.1. A — Sin oclusión

El comportamiento de ADR-08: `model_viewer_plus` dibuja el GLB dentro de un WebView y el resultado se
compone como una imagen plana sobre la vista previa. No hay buffer de profundidad compartido con nada,
así que la pieza es incapaz de quedar tapada.

**Por qué no se quedó así:** es precisamente el defecto que motivó todo el trabajo. ADR-08 está marcada
como **superada por ADR-16**. Se conserva en el SDD porque sigue explicando por qué el anclaje corporal
no depende de ARCore, que sí sigue vigente.

### 3.2. B — Recorte 2D del *sprite*

Antes de cambiar de motor se probó recortar la imagen de la joya con una máscara en pantalla, de modo
que la mitad "de atrás" simplemente no se dibujara.

**Por qué se descartó.** Tres razones, en orden de gravedad:

- La silueta de un brazo no es una recta: el borde del recorte se nota como un corte limpio sobre una
  pieza curva.
- No hay una "mitad de atrás" bien definida cuando el brazo está inclinado o la pieza girada; el
  recorte habría necesitado su propio modelo de la geometría, que es el problema que se quería evitar.
- Aun recortando bien, la pieza sigue sin tener perspectiva propia: el dije asimétrico caía del lado
  equivocado, que es un defecto independiente de la oclusión.

Se implementó, se vio en dispositivo y **no se llegó a commitear**: la conclusión fue que el recorte
ataca el síntoma y el motor de render ataca la causa. Quedó registrada dentro de ADR-16.

### 3.3. C — Proxy geométrico invisible (adoptada)

**La que está en producción.** Se dibuja en la escena 3D un sólido que representa la extremidad, con un
material que **escribe profundidad pero no escribe color**:

```dart
three.Mesh(
  three.CylinderGeometry(0.5, 0.5 * _occluderTaper, 1, 48),
  three.MeshBasicMaterial.fromMap({'colorWrite': false}),
)..renderOrder = -1;
```

`renderOrder = -1` lo dibuja **antes** que la joya, así que cuando la pieza se pinta, el buffer de
profundidad ya contiene al brazo y el GPU descarta por sí solo los fragmentos del arco que quedan
detrás. La oclusión sale del propio motor, con silueta curva y correcta en cualquier inclinación, sin
ninguna heurística de "delante/detrás".

Esto **solo es posible gracias a ADR-16**: `model_viewer_plus` no comparte buffer de profundidad con
nada. Cambiar de motor fue el habilitador, no un fin en sí mismo.

**Por qué esta y no las otras:** no depende de hardware especial, no añade ni un modelo de ML por frame
(coste ≈ 0 contra el presupuesto de ADR-12) y funciona igual en cámara frontal y trasera. Su precio es
que **el proxy hay que estimarlo**, y de ahí viene toda la limitación de ADR-17.

### 3.4. D — Segmentación de persona

Era la **recomendación preliminar de B6**. Se implementó en el spike B7 con
`google_mlkit_selfie_segmentation` 0.11.0 (la 0.12+ exige Dart `^3.12`, fuera del SDK que fija el CI) y
falla por dos motivos **independientes**:

- **No distingue el brazo.** La máscara cubre casi toda la escena —escritorio, ratón, suelo— porque el
  modelo está entrenado para *selfies*: una persona de frente sobre un fondo lejano. Un brazo sobre un
  escritorio visto con la cámara trasera no se le parece.
- **Corre a 2,5 Hz**, cuatro veces por debajo del presupuesto de detección de ADR-12.

Cualquiera de los dos bastaba para descartarla. Que fallara la alternativa recomendada por B6 es el
hallazgo más importante de este frente, y es la razón de ser de este documento.

### 3.5. E — Depth API de ARCore / ARKit

Descartada **sin implementar**, por análisis, en dos sitios independientes: B6 §2.2 y ADR-09.

- La mejor calidad depende de **hardware con sensor de profundidad** (LiDAR solo en iPhone Pro / iPad
  Pro); la Depth API de ARCore no está en todos los dispositivos Android.
- **La cámara frontal apenas tiene soporte de profundidad**, y es la que usan aretes y collares: **2 de
  las 3 categorías** del producto.
- Ningún plugin de Flutter la expone hoy. `ar_flutter_plugin_2`, que ya es dependencia, **no publica el
  mapa de profundidad**: haría falta un canal nativo propio y además puentear esa textura al motor 3D.
- El pipeline de anclaje corporal se diseñó deliberadamente **independiente de ARCore** (ADR-09) para
  maximizar dispositivos compatibles; volver a depender de él contradice esa decisión.

### 3.6. F — Detección de pose para medir el antebrazo

No es oclusión por sí misma, pero es **el insumo que le falta**: con muñeca y codo reales el eje del
antebrazo dejaría de extrapolarse y el proxy quedaría bien puesto.

`google_mlkit_pose_detection` ya es dependencia del proyecto (collares). Probado en el spike B7 con un
solo brazo en el encuadre: devuelve 33 puntos a 15 Hz, pero **todos amontonados sobre la mano** —los que
marca como muñeca y codo aterrizan en los dedos—. El modelo encaja un cuerpo entero dentro de la mano.

Lo peligroso es que los reporta con **`likelihood` 0,99**: esa métrica **no sirve como filtro de
validez**, porque es alta sobre puntos completamente inventados. Es un resultado negativo que vale la
pena citar tal cual en el documento académico.

### 3.7. G — Reconstrucción métrica de MediaPipe como fuente de tamaño

El fork propio de `hand_landmarker` (ADR-14) expone los `worldLandmarks` en metros. Se intentó usarlos
**dos veces** para dimensionar el proxy —primero por escala absoluta, luego por proporciones— y las dos
veces empeoró. Medido en dispositivo con **302 muestras en dos poses**: el ancho métrico de la palma
pasa de 7,3 a 4,4 cm al girar la mano, un **65 %** en una distancia 3D que no puede cambiar, mientras
que el ancho medido sobre la imagen varía un **4 %**.

**Regla que queda, y que no hay que volver a romper:** de esa reconstrucción sirven las **direcciones**;
las distancias no, ni absolutas ni en cociente. El tamaño se mide sobre la imagen.

### 3.8. K — Pedir la talla al usuario

Descartada por criterio, no por medición: trasladaría al cliente final un problema técnico del sistema,
y además **no resolvería nada de lo que falla**. El ancho del brazo es solo uno de los tres datos que el
proxy necesita; los otros dos —el eje y el giro— seguirían siendo estimaciones.

---

## 4. Estado actual de la oclusión

**Resumen: implementada y funcionando para pulseras; inexistente para aretes y collares.**

| Categoría | Cámara | Oclusión hoy | Por qué |
|---|---|---|---|
| **Pulseras** | Trasera | ✅ Proxy de antebrazo | MediaPipe Hands da reconstrucción métrica → hay eje 3D con el que orientar el proxy |
| **Aretes** | Frontal | ❌ Ninguna | ML Kit Face no entrega reconstrucción métrica; sin eje 3D no hay cómo orientar un proxy |
| **Collares** | Frontal | ❌ Ninguna | Igual que aretes, con ML Kit Pose |

### 4.1. Cómo funciona, paso a paso

Todo ocurre en `lib/features/ar_experience/presentation/widgets/jewelry_scene.dart`:

1. **La escena cubre toda el área de cámara** y la pieza se sitúa *dentro* del espacio 3D, proyectada
   sobre el punto de anclaje — no es una caja que se mueve por la pantalla (ADR-16).
2. **El proxy es un tronco de cono**, no un cilindro, porque el antebrazo se estrecha hacia la muñeca
   (`_occluderTaper = 0.85`). Su extremo ancho mira al codo.
3. **Se orienta con el eje 3D real** del antebrazo (`AnchorPose.axis3D`), que viene de las direcciones
   métricas de MediaPipe.
4. **Se achata y se gira sobre ese eje** usando la normal de la palma (`palmNormal3D`), porque el
   antebrazo no es redondo: es más ancho de lado a lado que de dorso a palma
   (`_occluderFlatness = 0.75`). Sin ese giro el achatamiento caería en una dirección arbitraria.
5. **Se acota al hueco del aro** (`_occluderHoleMargin = 0.96`): si el proxy fuese más ancho que el
   agujero de la pieza, la atravesaría y se comería cuentas que sí deben verse.
6. **Degrada en silencio.** Sin eje 3D o sin diámetro, el proxy se oculta y la pieza se dibuja entera:
   el comportamiento anterior. Peor, pero no erróneo.

Un hallazgo que no es obvio y conviene no perder: **el diámetro del proxy no se puede deducir del
modelo**. La caja envolvente de un GLB no da el hueco del aro — en una pieza de cuentas la dimensión más
delgada es el grosor de la cuenta, pero en un brazalete es el ancho de la banda. Por eso se estima como
fracción del ancho de palma.

**Actualización (2026-10-13).** Lo que sí se puede deducir del modelo es el **hueco**, siempre que se mida
sobre los vértices y no sobre la caja: `lib/core/math/ring_geometry.dart` toma la mediana del borde interior
por sectores angulares alrededor del eje del aro. La estimación por caja subestimaba el hueco (0,68 del
diámetro en `pulsera_perlas_basica` frente a 0,845 real; 0,847 frente a 0,909 en `cartier`), lo que inflaba
cada pieza en una proporción distinta. El ancho del **brazo** sigue saliendo de la palma (`_limbToPalm`).

Para calibrar esa constante, el overlay de diagnóstico (botón de diana) dibuja ahora el proxy en alambre
rojo: basta comparar sus bordes con los del brazo en una captura.

### 4.2. Resultados medidos

| Qué se midió | Antes | Después |
|---|---|---|
| Desvío del ancla respecto al eje del brazo | 25 px | **~5 px** (bajando `forearmOffset` de 0,45 a 0,20) |
| Oscilación del eje (temblor) | 9,14° | **1,13°** (amortiguando la profundidad al 25 % y cerrando filtros) |
| FPS de render con la cámara corriendo | — | **56,6** sostenidos (presupuesto de detección: 10 FPS) |
| Modelos del catálogo que carga el motor | 5 de 7 | **7 de 7** (con el normalizador de GLB) |
| Hueco del aro, error de la estimación (perlas / cartier) | −20 % / −7 % | **0 %** (medido sobre vértices, igual en dispositivo y fuera de línea) |
| Ancho del proxy frente al brazo real (2026-10-13) | −20 % (200 px vs 252) | **±3 %** (`_limbToPalm` de 0,88 a 1,08) |

El coste en rendimiento de esta oclusión es **nulo en la práctica**: el proxy son 48 segmentos sin
material visible, dibujados por el mismo motor que ya dibuja la pieza.

### 4.3. Lo que no está resuelto

1. **El ajuste del aro no convence al usuario.** Al cierre del trabajo el veredicto fue literalmente
   *"no me convence"*. **No está cerrado como resuelto** ni aquí ni en el SDD. Topa con ADR-17: sin una
   fuente que mida el brazo, el eje y el ancho son estimaciones.
2. **Las constantes antropométricas se calibraron sobre una sola persona.** `_limbToPalm = 1.08` ya se
   midió sobre captura contra el proxy visible (antes era 0,88 a ojo, compensando el error del hueco), pero
   la holgura del aro (`1.12`) sigue siendo juicio visual. **Riesgo directo para el Sprint 6**: unas
   pruebas de usabilidad con varias personas van a exponerlo; el alambre rojo hace esa validación rápida.
3. **Error angular cuando la muñeca se dobla.** El eje se extrapola desde la mano; medido con el
   overlay de diagnóstico, estimaba 95° (casi recto hacia abajo) mientras el antebrazo real bajaba
   hacia la derecha. Con el proxy visible se ve directamente: con la muñeca algo desviada el proxy se
   inclina respecto al brazo y el ancla queda ~25 px a un lado. Es ahora **el error dominante** del ajuste,
   y no se corrige con constantes (ADR-17).
4. **Temblor residual.** Queda un pico ocasional de posición (salto máximo de 0,128 del ancho del
   frame) que parece fallo puntual de detección, no ruido continuo.
5. ~~**`cartier.glb` no se puede medir.**~~ **Resuelto (2026-10-13).** El problema no era la forma
   sino la caja: `BoundingBox` de three_js transforma la caja de cada malla por la matriz de su nodo y con
   nodos rotados la infla (3,50 de diámetro donde los vértices miden 2,53). Medida sobre vértices, la pieza
   es un aro normal y no hace falta reexportarla.
6. **Aretes y collares, sin oclusión.**

---

## 5. Trabajo futuro, con estimación de tiempo

### 5.1. Cómo se construyeron estas estimaciones

No son estimaciones a ojo: se calibran contra un dato real de este mismo proyecto. La migración
completa del motor de render —spike, decisión, normalizador de GLB, sustitución del overlay,
orientación 3D, oclusión y CI— fueron **15 commits repartidos en 2 jornadas de calendario** (18 y 19 de
septiembre de 2026), trabajando con Claude Code.

De esas 2 jornadas, **la escritura de código ocupó una fracción pequeña**. El tiempo se fue en:
instalar y relanzar el APK, mirar en dispositivo, medir, ajustar una constante y repetir. Ese ciclo
**no se acelera** con un asistente: depende de un teléfono, de un brazo humano y de compilar.

De ahí la regla que se usa abajo, y que conviene explicitar en la planeación:

> **El asistente acelera el código, no la medición.** En tareas de RA anclada al cuerpo, la medición en
> dispositivo es la mayor parte del trabajo. Un factor de aceleración global de "×3 porque usamos
> Claude Code" sobreestima el ahorro; el factor real se aplica solo a la columna de código.

**Unidad:** *jornada* = ~6 horas efectivas de una persona. Las columnas separan el trabajo de código del
trabajo de medición/calibración en dispositivo, porque se comportan muy distinto.

### 5.2. Estimaciones

| # | Trabajo | Código | Medición | **Total** | Riesgo | Valor |
|---|---|---|---|---|---|---|
| 1 | **Reexportar `cartier.glb`** y registrar el hueco del aro como metadato del catálogo | 0,5 | 0,5 | **~1 jornada** | Bajo | Alto — elimina una estimación entera |
| 2 | **Validar las constantes antropométricas con varias personas** | 0 | 1 | **~1 jornada** | Bajo | Alto — es lo que pide el Sprint 6 |
| 3 | **Proxy de la mano** (dedos que cruzan la pulsera) — alternativa H | 1 | 1 | **~2 jornadas** | Bajo-medio | Medio-alto |
| 4 | **Proxy de cabeza/mandíbula para aretes** — extiende C a cámara frontal | 0,5–1 | 1–1,5 | **~2 jornadas** | Medio | Alto — cierra una categoría |
| 5 | **Proxy de cuello/torso para collares** | 0,5–1 | 1,5–2 | **~2,5 jornadas** | Medio-alto | Alto — cierra la tercera |
| 6 | **Seguir afinando el ajuste del aro** sin fuente nueva | 0,5 | 2+ | **~2,5 jornadas** | **Alto** | **Incierto** |
| 7 | **Segmentación multiclase** (pelo/piel/cuerpo) — alternativa I | 3–4 | 1–2 | **~1 semana / plataforma** | **Alto** | Medio |
| 8 | **Profundidad monocular** por red neuronal — alternativa J | 2–3 | 2–3 | **~1 semana** | **Alto** | Alto si sale |
| 9 | **Depth API de ARCore** — alternativa E | 5–10 | 2–3 | **~2–3 semanas** | **Muy alto** | Bajo (no cubre cámara frontal) |

### 5.3. Detalle de cada propuesta

**1 · Reexportar `cartier.glb` y meter el hueco en el catálogo.** Hoy el hueco del aro se *adivina* desde
la geometría del GLB, y en una pieza que trae mallas extra la adivinanza falla. Si el hueco viene como
dato del catálogo (`D3_ESTRUCTURA_CATALOGO.md`), desaparece una fuente de error completa. **Es la tarea
de mejor relación costo/beneficio de toda la lista** y además es trabajo del frente D, que puede ir en
paralelo.

**2 · Validar con varias personas.** No requiere escribir código: requiere cuatro o cinco muñecas
distintas, el overlay de diagnóstico y anotar. Es además **exactamente lo que exige el objetivo
específico 4 del proyecto** ("evaluar mediante pruebas de uso"), así que no es trabajo extra sino
trabajo adelantado del Sprint 6.

**3 · Proxy de la mano.** Los 21 landmarks métricos de MediaPipe **ya llegan al pipeline** (ADR-14/15) y
nadie los usa para esto. Con ellos se pueden levantar cápsulas invisibles por dedo, con el mismo truco
de `colorWrite: false`. Resuelve el caso "me pongo la otra mano delante" sin añadir ni un modelo de ML.
El riesgo es que la mano que lleva la pulsera y la que la tapa son manos distintas, y hoy solo se
rastrea una.

**4 · Proxy de cabeza/mandíbula.** La cabeza se aproxima razonablemente con un elipsoide. El problema es
que ML Kit Face **no da reconstrucción métrica**, así que hay que derivar una orientación 3D de los
contornos del rostro (que el detector sí puede entregar, hoy desactivados). Es el mismo patrón que ya
funciona en pulseras, trasladado. Resuelve el caso del arete que cuelga por delante de la mandíbula.

**5 · Proxy de cuello/torso.** Más difícil que la cabeza: el cuello es cóncavo donde se apoya el collar,
y un cilindro recto tapa mal justo en la zona que importa. Probablemente requiera dos primitivas
(cuello + pecho) y más iteraciones de calibración. De ahí la medición más alta.

**6 · Seguir afinando el aro.** **Se incluye con una advertencia explícita.** ADR-17 dice que el techo
no es de calibración sino de información: ninguna fuente disponible mide el antebrazo. Invertir más
jornadas en mover constantes puede no converger nunca. **La decisión previa a ejecutarla es de equipo:**
aceptar el resultado actual como límite de alcance documentado, o buscar fuente nueva (que es #7/#8/#9).

**7 · Segmentación multiclase.** MediaPipe tiene un *Image Segmenter* multiclase que separa pelo, piel y
cuerpo — distinto del binario de *selfie* que ya falló. **No hay plugin de Flutter que lo exponga**, así
que hay que escribir uno nativo por plataforma, meterlo en el isolate de detección y componer la máscara
con el buffer de profundidad del motor. Es la única vía realista para **oclusión por terceros** (el
cabello sobre el arete) y por eso sigue en la lista pese al costo. Advertencia: sigue entrenado para
*selfies* y su coste por frame hay que medirlo contra ADR-12 **antes** de integrarlo, no después.

**8 · Profundidad monocular.** Una red tipo MiDaS-small o Depth Anything V2-small sobre `tflite_flutter`
da un mapa de profundidad por frame **sin sensor y en las dos cámaras**: resolvería las tres categorías
de golpe. Dos riesgos serios: la profundidad que devuelve es **relativa, no métrica** (hay que anclarle
la escala con los landmarks métricos, con el antecedente de §3.7 en contra), y el coste por frame en un
gama media es una incógnita. **Es el candidato más interesante a mediano plazo y el que más merece un
spike corto antes de comprometerse.**

**9 · Depth API de ARCore.** Se lista por completitud. No cubre cámara frontal, o sea 2 de las 3
categorías; exige plugin nativo propio; contradice ADR-09; y la cobertura de dispositivos es parcial.
**No se recomienda**, salvo que el alcance se reduzca a pulseras y se exija profundidad del entorno.

### 5.4. Secuencia recomendada

Si hubiera que ordenar: **1 → 2 → 4 → 3 → 5**, y dejar 7/8/9 fuera del semestre salvo que se abra un
spike corto para el 8. Las cinco primeras suman **~8,5 jornadas** y cierran las tres categorías con la
técnica que ya está validada, sin introducir ninguna dependencia nueva ni tocar el presupuesto de
detección.

---

## 6. ¿Esto cumple con la problemática propuesta?

### 6.1. Contra la formulación del problema

> *"¿Cómo permitir a los usuarios **visualizar de manera realista** piezas de joyería **sin necesidad de
> trasladarlas físicamente** entre ciudades, reduciendo la incertidumbre en la compra y los riesgos
> logísticos asociados a su comercialización?"* — VFP8 §1.1.2

| Parte del problema | ¿Se cumple? |
|---|---|
| Sin traslado físico de las piezas | **Sí.** El catálogo es digital y la prueba corre en el teléfono del usuario. La oclusión no afecta esto |
| Reducir riesgos logísticos | **Sí**, por lo mismo |
| Visualizar **sobre el propio cuerpo** | **Sí**, en las tres categorías |
| Visualizar **"de manera realista"** | **Parcialmente.** Pulseras: sí, con perspectiva y oclusión. Aretes y collares: la pieza se ancla y se escala, pero sigue dibujándose siempre encima |
| Reducir la incertidumbre de compra | **Pendiente de medir.** Es lo que evalúa el Sprint 6; el ajuste no validado del aro es un riesgo directo para esa medición |

**Lectura honesta:** el problema del proyecto está formulado alrededor de la **logística** —no trasladar
piezas entre ciudades—, y eso se resuelve por completo. El calificativo *"de manera realista"* es donde
entra la oclusión, y ahí el cumplimiento es **de una de tres categorías**.

Importa no inflar la conclusión: la oclusión es **condición necesaria** del realismo, no suficiente. Aun
con oclusión perfecta quedan pendientes la coherencia de iluminación (hoy la escena usa una iluminación
de estudio fija, no la luz real del entorno) y la sombra de contacto, que son las otras dos pistas que
delatan un montaje.

### 6.2. Contra los objetivos específicos

| Objetivo (VFP8 §1.2.2) | Aporte de este trabajo |
|---|---|
| 1 · Analizar tecnologías de RA y visión computacional y **seleccionar la tecnología base** | **Cumplido y documentado con evidencia medida.** Se evaluaron 11 alternativas de oclusión, 4 se probaron en dispositivo. Los **resultados negativos** (segmentación, pose, reconstrucción métrica) son material de primera para esta sección |
| 2 · Diseñar la arquitectura y la interfaz | **Cumplido.** La oclusión no es un parche: sale del buffer de profundidad como consecuencia del motor elegido. Registrado en ADR-16 y ADR-17 |
| 3 · Implementar con un conjunto de productos de una o dos joyerías | **Parcial.** Funciona para pulseras; aretes y collares siguen sin oclusión (§5.3, puntos 4 y 5) |
| 4 · Evaluar el impacto mediante **pruebas de uso y métricas de usabilidad** | **En riesgo.** Las constantes están calibradas sobre una sola muñeca; una prueba con varios usuarios lo va a exponer. Es la razón de poner #2 arriba en la secuencia |

### 6.3. Qué decirle al equipo

Tres cosas, en este orden:

1. **El Sprint 5 se cumplió, pero con otra técnica que la comprometida.** La segmentación se probó y
   falló por dos motivos medidos e independientes. La sustitución está justificada y documentada; hay
   que llevarla a la retrospectiva.
2. **La oclusión está cerrada para una de tres categorías.** Las otras dos son ~4,5 jornadas con la
   misma técnica ya validada, sin dependencias nuevas.
3. **Hay una decisión de equipo pendiente y bloqueante:** si el ajuste actual del aro se acepta como
   límite de alcance documentado (ADR-17) o si se abre una vía nueva. Afinar constantes sin fuente
   nueva de información puede no converger, y conviene no gastar jornadas ahí por inercia.

---

## 7. Trazabilidad

| Dónde | Qué contiene |
|---|---|
| `docs/B6_NOTA_OCLUSION.md` | Análisis preliminar (2026-08-09). **Su recomendación quedó invalidada por medición**; ver §3.4 |
| `docs/SDD_2.3_ARQUITECTURA_DEL_SISTEMA.md` | ADR-08 (superada), ADR-09, ADR-16, ADR-17 y la tabla de trabajo abierto (Parte D) |
| `spikes/B7-motor-render/README.md` | Evidencia en dispositivo: motor validado, segmentación descartada, pose descartada |
| `lib/features/ar_experience/presentation/widgets/jewelry_scene.dart` | Implementación del proxy (`_applyOccluder`) y las constantes |
| `lib/features/tracking/domain/entities/anchor_pose.dart` | `axis3D` y `palmNormal3D`, los dos insumos que hacen posible el proxy |
| `lib/features/tracking/domain/strategies/bracelet_strategy.dart` | De dónde salen el eje y el ancho; `forearmOffset` |

---

## 8. Criterio de cierre

Este documento cierra la parte de **análisis** del frente de oclusión: todas las alternativas conocidas
están listadas, probadas o descartadas con su razón. **No cierra la implementación**, que sigue abierta
para aretes y collares, ni el ajuste del aro, que está pendiente de decisión de equipo.
