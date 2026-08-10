# Registro de tareas pendientes — Visualización virtual de joyería con Realidad Aumentada

**Equipo:** Grupo 7 (2026) · **Última actualización:** 2026-08-10
 
> **Documento interno de trabajo.** El contenido de este archivo no debe trasladarse literalmente a documentos académicos. En esos documentos aplican las convenciones de lenguaje del proyecto: no se nombra al cliente, no se emplean los términos "MVP" ni "prototipo", y no se hace referencia a anillos ni a dedos.

> **Nota de seguimiento (2026-08-10):** se añadió a cada tarea un bloque **Estado** indicando si está hecha (qué se hizo y para qué sirve) o si sigue pendiente. Todo el trabajo realizado está commiteado en el repositorio oficial de la tesis.
 
---
 
## 1. Propósito y uso de este documento
 
Este documento consolida las tareas pendientes que pueden ejecutarse antes del inicio formal de los sprints, con el fin de reducir riesgo técnico y dejar el entorno de desarrollo preparado. No constituye una asignación obligatoria de trabajo: cada integrante selecciona las tareas según su disponibilidad y área de interés.
 
**Procedimiento de asignación:**
- Al tomar una tarea, el integrante debe registrar su nombre en el campo **Asignado a** y notificar al equipo.
- El avance debe reflejarse mediante actualización de este documento (commit o pull request al repositorio).
- No se establecen fechas límite individuales en este periodo. La referencia temporal aplicable es el inicio del semestre 2026-2 (27 de julio) y el inicio de los sprints (aproximadamente el 17 de agosto).
**Clasificación de prioridad:**
- **Alta** — bloquea el inicio de los Sprints 1–3 o bloquea el trabajo de otros integrantes.
- **Media** — adelanta trabajo correspondiente a los sprints o reduce riesgo técnico relevante.
- **Baja** — deuda técnica o mejora no crítica para el alcance actual.
**Estimación de esfuerzo:** S (1–3 horas) · M (4–8 horas) · L (10–20 horas). Corresponde a horas de trabajo efectivo estimadas, no a una cadencia diaria o semanal.
 
**Tipo de tarea:** *Técnica* (requiere entorno de desarrollo) o *General* (documentación, definición, coordinación).
 
**Alcance del producto:** aretes, pulseras y collares. Los anillos están explícitamente fuera de alcance; no se contempla tracking de dedos en ninguna parte del proyecto. Plataformas objetivo: Android 9.0 (API 28) en adelante e iOS 16.0 en adelante.
 
---
 
## 2. Estado actual del desarrollo
 
Conforme a lo documentado en el repositorio, se encuentra resuelto y validado:
 
- Acceso a cámara y gestión de permisos en Android e iOS, incluyendo la corrección de `PERMISSION_CAMERA=1`.
- Visor 3D con materiales PBR (`model_viewer_plus`) y colocación en realidad aumentada sobre superficie detectada (`ar_flutter_plugin_2`).
- Tracking de muñeca mediante MediaPipe (`hand_landmarker`, landmark 0 — WRIST), validado únicamente en Android.
- Entorno de desarrollo iOS operativo (Mac Mini); ejecución confirmada en dispositivo físico en modo debug.
- Repositorio configurado en GitHub, con Podfile unificado (iOS 16.0, `use_modular_headers!`).
**Pendiente de mayor relevancia:** tracking de manos en iOS, detección facial para aretes (actualmente un stub sin implementar), collares (sin desarrollo ni investigación iniciada), modelos GLB de piezas reales, y varias secciones del SRS y del SPMP.

### 2.1 Trabajo realizado en esta sesión (2026-08-10)

Además del avance por tarea (ver §3), se construyeron cimientos que antes no existían:

- **Arquitectura de la aplicación** (`docs/ARQUITECTURA.md`): Clean Architecture *feature-first* + Riverpod, con el subsistema de tracking/AR, el patrón *Strategy* de anclaje por categoría y los diagramas. **Sirve para** tener una base profesional, testeable y extensible sobre la que construir los sprints.
- **Scaffolding del proyecto Flutter** en el repositorio oficial (antes vacío): estructura `app/core/features`, catálogo funcional que carga `catalog.json`, tema, navegación (`go_router`) e inyección de dependencias. **Sirve para** empezar a desarrollar sobre código real ya organizado.
- **Pipeline de tracking conectado** (cámara → detector → estrategia → estabilizador → estado): las tres estrategias de anclaje implementadas y con pruebas unitarias; `AndroidHandDetector` cableado al plugin real. **Sirve para** tener el flujo funcionando de punta a punta (validación en dispositivo pendiente).
- **Código de referencia del MVP** clonado localmente en `mvp-reference/` (ignorado por git) para consulta.

> El detalle técnico de cada spike vive en `spikes/` y en los documentos `docs/`.
 
---
 
## 3. Detalle de tareas
 
### Frente A — Entorno de desarrollo
 
Estas tareas condicionan la ejecución del resto del trabajo: sin entornos de desarrollo estables, no es posible avanzar en implementación ni en pruebas.
 
#### A1 — Resolución del error `Flutter.h not found` (MacBook Air, Valentina Carreño)
**Prioridad:** Alta · **Esfuerzo:** M (3–6 h) · **Tipo:** Técnica · **Dependencias:** ninguna
 
Diagnosticar y corregir el fallo de compilación de iOS en el equipo indicado. Procedimiento sugerido: `flutter clean` y eliminación de `ios/Pods` y `Podfile.lock`; `flutter pub get`; `pod install` desde `ios/` verificando que CocoaPods esté actualizado; confirmación de deployment target 16.0 y de `use_modular_headers!` en el Podfile; limpieza de DerivedData en Xcode; apertura del proyecto mediante `Runner.xcworkspace` y no mediante el `.xcodeproj`. En equipos con procesador Apple Silicon, revisar conflictos de arquitectura entre Rosetta y arm64 en los pods.
 
**Criterio de cierre:** la aplicación compila y se ejecuta en modo debug sobre un iPhone físico desde este equipo.
**Asignado a:** _(pendiente — se recomienda ejecución conjunta con Valentina Carreño)_

> **Estado (2026-08-10): ⏳ Pendiente.** Requiere el equipo físico (MacBook Air) para diagnosticar; no abordable de forma remota.
 
#### A2 — Unificación del requisito de versión de API en Android
**Prioridad:** Alta · **Esfuerzo:** S (1–3 h) · **Tipo:** Técnica · **Dependencias:** ninguna
 
Existe una discrepancia entre el `minSdk 24` declarado en el repositorio (mínimo exigido por ARCore) y el requisito de Android 9.0 (API 28) establecido para el proyecto; se ha reportado además una incompatibilidad de nivel de API durante pruebas de un integrante. Se debe definir el `minSdk` definitivo, actualizarlo en `build.gradle`, y documentar en el README los requisitos reales de dispositivo (versión mínima de Android y presencia en la lista oficial de dispositivos con soporte ARCore).
 
**Criterio de cierre:** el `minSdk` queda unificado en el repositorio y el README refleja los requisitos de dispositivo verificados.
**Asignado a:** _(pendiente)_

> **Estado (2026-08-10): ✅ Hecho.** En el repositorio oficial se fijó `minSdk = 28` (Android 9.0) en `android/app/build.gradle.kts`, valor que además satisface el mínimo de ARCore (24); los requisitos de dispositivo quedaron documentados en el `README.md` y en `docs/A3_INVENTARIO_DISPOSITIVOS.md`. **Sirve para** eliminar la discrepancia reportada y fijar de forma coherente el requisito real de dispositivo.
 
#### A3 — Inventario de dispositivos del equipo
**Prioridad:** Alta · **Esfuerzo:** S (~1 h) · **Tipo:** General · **Dependencias:** ninguna
 
Registrar los dispositivos móviles disponibles entre los cuatro integrantes: modelo, versión de sistema operativo y compatibilidad con ARCore o ARKit. Confirmar que se dispone de al menos un dispositivo iOS y uno Android aptos para desarrollo y pruebas continuas.
 
**Criterio de cierre:** existe una tabla de dispositivos disponibles, incorporada a este documento o al README.
**Asignado a:** _(pendiente)_

> **Estado (2026-08-10): 🟡 Parcial.** Se creó la plantilla `docs/A3_INVENTARIO_DISPOSITIVOS.md` con los requisitos verificables, los enlaces a las listas oficiales de ARCore/ARKit y la tabla lista para llenar. **Falta** que cada integrante complete su fila con sus datos reales. **Sirve para** conocer la capacidad de hardware del equipo antes de los sprints.
 
#### A4 — Verificación cruzada de entornos
**Prioridad:** Alta · **Esfuerzo:** S–M (2–4 h por persona) · **Tipo:** Técnica · **Dependencias:** A1, A2
 
Cada integrante debe clonar el repositorio desde cero, compilar el proyecto y ejecutar la aplicación en al menos una plataforma. El resultado debe registrarse (quién puede ejecutar en iOS, en Android, o en ambos), con el fin de establecer la capacidad real del equipo antes del inicio de los sprints.
 
**Criterio de cierre:** los cuatro integrantes confirman compilación y ejecución exitosa en al menos una plataforma.
**Asignado a:** _(los cuatro integrantes, individualmente)_

> **Estado (2026-08-10): ⏳ Pendiente.** Requiere que cada integrante clone y compile en su propio equipo/dispositivo. Nota: ahora hay código real que compilar (el scaffolding), no solo el MVP.
 
---
 
### Frente B — Investigación y decisiones técnicas (spikes)
 
Cada spike debe producir una nota escrita breve con hallazgos, recomendación y, cuando aplique, una prueba de concepto mínima. Estas notas alimentarán directamente el SRS, el SPMP y las decisiones de Sprint Planning.
 
#### B1 — Spike: tracking de manos en iOS
**Prioridad:** Alta · **Esfuerzo:** L (8–15 h) · **Tipo:** Técnica · **Dependencias:** entorno iOS funcional
 
El plugin `hand_landmarker` utiliza un puente JNI disponible únicamente en Android, lo que constituye el riesgo técnico más alto del proyecto en su estado actual. Deben evaluarse alternativas para iOS: (a) MediaPipe Tasks Vision nativo mediante platform channel; (b) modelo TFLite de hand landmarks; (c) framework Vision de Apple (`VNDetectHumanHandPoseRequest`). La evaluación debe comparar precisión, latencia y esfuerzo de integración con Flutter.
 
**Criterio de cierre:** existe una nota comparativa con recomendación y, de resultar viable, una prueba de concepto que detecte la muñeca en un dispositivo iOS.
**Asignado a:** _(pendiente)_

> **Estado (2026-08-10): 🟡 Análisis y andamiaje hechos; POC en dispositivo pendiente.** Se escribió la nota comparativa (`spikes/B1-ios-hand-tracking/`) con recomendación de **Apple Vision** (`VNDetectHumanHandPoseRequest`), se cableó el lado Dart (`IosHandDetector` sobre platform channel, con función de mapeo probada) y se dejó el esqueleto Swift de referencia. **Falta** ejecutar el POC en un iPhone físico (corresponde a C2). **Sirve para** tener resuelto el riesgo más alto del proyecto en cuanto al enfoque, con el código listo para implementar.
 
#### B2 — Spike: MediaPipe Pose para collares
**Prioridad:** Alta · **Esfuerzo:** L (8–15 h) · **Tipo:** Técnica · **Dependencias:** entorno funcional en cualquier plataforma
 
Los collares no están cubiertos por MediaPipe Hands ni por Face Mesh; requieren detección de hombros y cuello mediante Pose (landmarks 11 y 12, correspondientes a los hombros). Se deben evaluar alternativas disponibles en Flutter —por ejemplo `google_mlkit_pose_detection`, ya presente en el stack, frente a MediaPipe Pose nativo— y desarrollar una prueba de concepto de detección de hombros con cámara frontal, orientada a estimar el punto de anclaje del collar.
 
**Criterio de cierre:** existe una prueba de concepto de detección de hombros y una nota de viabilidad con la opción recomendada.
**Asignado a:** _(pendiente)_

> **Estado (2026-08-10): ✅ Hecho (validación en dispositivo pendiente).** Se desarrolló el spike (`spikes/B2-pose-collares/`) con la estimación del anclaje del collar a partir de los hombros (POC ejecutable con pruebas), la nota de viabilidad con recomendación de **`google_mlkit_pose_detection`**, y la integración en la app (`PoseDetectorDataSource` + `NecklaceStrategy` con pruebas unitarias). **Sirve para** habilitar los collares, que antes no tenían ni investigación iniciada. Queda pendiente validar la detección en cámara frontal en dispositivo.
 
#### B3 — Spike: detección de lóbulos para aretes
**Prioridad:** Alta · **Esfuerzo:** M–L (6–10 h) · **Tipo:** Técnica · **Dependencias:** entorno funcional
 
`google_mlkit_face_detection` provee landmarks y contornos básicos del rostro. Debe determinarse si esta precisión es suficiente para ubicar los lóbulos con la exactitud que exige el anclaje de un arete, o si se requiere una integración nativa de Face Mesh (468 puntos). Las pruebas deben realizarse con cámara frontal, distintos ángulos de cabeza y con el cabello suelto y recogido.
 
**Criterio de cierre:** existe una decisión documentada (suficiencia de ML Kit o necesidad de Face Mesh) respaldada por evidencia de las pruebas realizadas.
**Asignado a:** _(pendiente)_

> **Estado (2026-08-10): ✅ Decisión hecha (evidencia en dispositivo pendiente).** Se documentó (`spikes/B3-lobulos-aretes/`) que ML Kit no expone un landmark de lóbulo (se estima desplazando la oreja), con la decisión de **empezar con `google_mlkit_face_detection`** y escalar a Face Mesh solo si la precisión no basta; se implementó el POC de estimación (con pruebas), el `FaceDetectorDataSource` y la `EarringStrategy`. Se dejó el **protocolo de prueba en dispositivo** (ángulos de cabeza, cabello suelto/recogido). **Sirve para** desbloquear los aretes con una vía cross-platform y de bajo esfuerzo.
 
#### B4 — Spike: estabilización del tracking
**Prioridad:** Media · **Esfuerzo:** M (4–8 h) · **Tipo:** Técnica · **Dependencias:** ninguna
 
Los landmarks obtenidos presentan variación (jitter) entre fotogramas. Debe evaluarse la aplicación de un filtro de Kalman frente a un One Euro Filter sobre las coordenadas del landmark de anclaje, utilizando la implementación actual de tracking de muñeca en Android como banco de pruebas. Los parámetros seleccionados deben quedar documentados.
 
**Criterio de cierre:** existe una comparación práctica entre ambos filtros y una recomendación con parámetros iniciales definidos.
**Asignado a:** _(pendiente)_

> **Estado (2026-08-10): ✅ Hecho.** Se implementaron ambos filtros y un banco de comparación ejecutable (`spikes/B4-estabilizacion/`), con recomendación de **One Euro Filter** (menos lag en movimiento, jitter en reposo comparable) y parámetros iniciales `minCutoff=1.0, beta=0.02, dCutoff=1.0`. El filtro ya está integrado en el pipeline de la app. **Sirve para** que el anclaje deje de temblar; falta afinar parámetros en dispositivo (C3).
 
#### B5 — Spike: rendimiento de la detección (isolate dedicado)
**Prioridad:** Media · **Esfuerzo:** M–L (6–12 h) · **Tipo:** Técnica · **Dependencias:** ninguna
 
La función `detect()` es actualmente síncrona y bloquea el isolate principal (entre 15 y 40 ms por fotograma), limitando la detección a un máximo aproximado de 10 FPS. Se debe prototipar la solución documentada en el README: un isolate dedicado con su propia instancia del plugin, transfiriendo los bytes del fotograma mediante `SendPort`. Deben medirse los FPS antes y después de la intervención.
 
**Criterio de cierre:** existe una prueba de concepto con métricas de FPS que confirme o descarte la mejora de rendimiento.
**Asignado a:** _(pendiente)_

> **Estado (2026-08-10): ✅ Hecho (prototipo).** Se prototipó el isolate dedicado con un banco de medición (`spikes/B5-isolate/`): la detección síncrona congela la UI (0 FPS) mientras el isolate la mantiene fluida (~60 FPS) preservando el throughput de detección (~24 FPS). **Sirve para** confirmar que mover la detección a un isolate libera la UI; falta portarlo con el detector real en dispositivo (C2/C3).
 
#### B6 — Investigación: oclusión por segmentación
**Prioridad:** Baja · **Esfuerzo:** M (4–8 h) · **Tipo:** Técnica/General · **Dependencias:** ninguna
 
Corresponde al alcance del Sprint 5, pero representa un riesgo técnico considerable y se recomienda contar con un panorama previo. Debe investigarse las alternativas disponibles (MediaPipe Selfie Segmentation, APIs de profundidad de ARKit/ARCore) y documentarse una nota comparativa. Esta tarea corresponde únicamente a análisis; no incluye implementación.
 
**Criterio de cierre:** existe una nota técnica con las alternativas evaluadas y una recomendación preliminar.
**Asignado a:** _(pendiente)_

> **Estado (2026-08-10): ✅ Hecho.** Se redactó la nota de análisis (`docs/B6_NOTA_OCLUSION.md`) comparando segmentación de persona (ML Kit/MediaPipe) vs. APIs de profundidad (ARCore/ARKit), con recomendación preliminar de priorizar segmentación. **Sirve para** llegar al Sprint 5 con el panorama de oclusión ya explorado.
 
---
 
### Frente C — Desarrollo
 
#### C1 — Pantalla de realidad aumentada facial (aretes)
**Prioridad:** Alta · **Esfuerzo:** L (10–20 h) · **Tipo:** Técnica · **Dependencias:** B3
 
Implementar la pantalla actualmente pendiente (stub): captura mediante cámara frontal, detección del rostro, anclaje de un modelo de arete en la zona del lóbulo y seguimiento del movimiento de la cabeza. Debe emplearse un modelo GLB simple como base inicial.
 
**Criterio de cierre:** el modelo de prueba se ancla correctamente al lóbulo y sigue el movimiento del rostro en un dispositivo físico.
**Asignado a:** _(pendiente)_

> **Estado (2026-08-10): ⏳ Pendiente.** Las bases están listas (`EarringStrategy`, `FaceDetectorDataSource` y el pipeline conectado), pero falta la pantalla con captura frontal, render del GLB anclado al lóbulo y seguimiento, y su validación en dispositivo.
 
#### C2 — Tracking de muñeca en iOS
**Prioridad:** Alta · **Esfuerzo:** L (10–20 h) · **Tipo:** Técnica · **Dependencias:** B1
 
Implementar en iOS la alternativa seleccionada en el spike B1, replicando la funcionalidad ya disponible en Android: obtención de la posición tridimensional de la muñeca en tiempo real como punto de anclaje de la pulsera.
 
**Criterio de cierre:** la detección de muñeca se ejecuta en un iPhone físico con precisión comparable a la obtenida en Android.
**Asignado a:** _(pendiente)_

> **Estado (2026-08-10): ⏳ Pendiente.** El andamiaje de B1 está listo (Dart + esqueleto Swift), pero falta agregar el Swift al target en Xcode, registrarlo y validar la detección en un iPhone.
 
#### C3 — Integración del filtro de estabilización (Android)
**Prioridad:** Media · **Esfuerzo:** M (4–6 h) · **Tipo:** Técnica · **Dependencias:** B4
 
Aplicar el filtro seleccionado en B4 al tracking de muñeca existente y verificar que el anclaje deje de presentar variación (jitter) sin introducir latencia perceptible.
 
**Criterio de cierre:** el anclaje se mantiene estable durante el movimiento normal de la mano.
**Asignado a:** _(pendiente)_

> **Estado (2026-08-10): 🟡 Integrado en código; validación en dispositivo pendiente.** El One Euro Filter (B4) ya se aplica en el `TrackingRepositoryImpl` a la posición de anclaje. **Falta** verificar en un Android físico que el jitter desaparece sin latencia perceptible y afinar los parámetros.
 
#### C4 — Depuración técnica del repositorio
**Prioridad:** Baja · **Esfuerzo:** S (~1 h) · **Tipo:** Técnica · **Dependencias:** ninguna
 
Eliminar el comentario obsoleto en `pubspec.yaml` ("Landmark 5 = Index MCP"; el código actual ancla al landmark 0, WRIST) y revisar el repositorio en busca de referencias residuales a anillos o dedos en código, comentarios o documentación, con el fin de mantener coherencia con el alcance definido.
 
**Criterio de cierre:** no queda ninguna referencia a anillos ni a dedos en el repositorio.
**Asignado a:** _(pendiente)_

> **Estado (2026-08-10): 🟡 El repositorio oficial nace limpio; queda el del MVP.** El código nuevo de la tesis no contiene referencias a anillos ni a dedos. El comentario obsoleto vive en el repositorio del MVP (`JewelryAR-MVP`), que es referencia y no se sube aquí; si se decide conservarlo, allí sigue pendiente esa limpieza.
 
#### C5 — Ejecución del Prompt 4 (Claude Code): integración final y `VIABILIDAD_TECNICA.md`
**Prioridad:** Media · **Esfuerzo:** M (4–8 h) · **Tipo:** Técnica · **Dependencias:** A4
 
Ejecutar el prompt pendiente de integración final y de generación del documento de viabilidad técnica, contando con un entorno de dispositivo confirmado y estable. El documento resultante debe ser revisado antes de incorporarse al repositorio.
 
**Criterio de cierre:** `VIABILIDAD_TECNICA.md` queda incorporado al repositorio y ha sido revisado por al menos otro integrante del equipo.
**Asignado a:** _(pendiente)_

> **Estado (2026-08-10): ⏳ Pendiente.** Depende de A4 (entorno de dispositivo confirmado).
 
---
 
### Frente D — Modelos 3D y catálogo
 
#### D1 — Definición del pipeline de digitalización de piezas
**Prioridad:** Alta · **Esfuerzo:** M (4–8 h) · **Tipo:** General/Técnica · **Dependencias:** ninguna
 
Definir el método de digitalización de las piezas reales de la joyería participante: fotogrametría mediante aplicaciones de escaneo, o modelado manual en Blender a partir de fotografías y medidas. Debe documentarse el flujo completo: captura, modelado y retopología, definición de materiales PBR (metalicidad, rugosidad), exportación en formato GLB (glTF 2.0) y validación en el visor de la aplicación.
 
**Criterio de cierre:** existe una guía breve y reproducible del pipeline, con las herramientas seleccionadas.
**Asignado a:** _(pendiente)_

> **Estado (2026-08-10): ✅ Hecho.** Se redactó la guía reproducible (`docs/D1_PIPELINE_DIGITALIZACION.md`): recomendación de modelado manual en Blender frente a fotogrametría, materiales PBR, exportación a GLB, checklist de aceptación y calibración de escala, con una advertencia sobre gemas transparentes. **Sirve para** que cualquier integrante produzca modelos con la misma calidad y convenciones; desbloquea D2.
 
#### D2 — Primer modelo GLB de una pieza real
**Prioridad:** Alta · **Esfuerzo:** L (10–20 h, según experiencia previa en modelado 3D) · **Tipo:** Técnica · **Dependencias:** D1
 
Producir el primer modelo GLB de una pieza real del catálogo (se sugiere iniciar con un arete o una pulsera de geometría simple), con materiales PBR, y validarlo en el visor de la aplicación en reemplazo del modelo de prueba actual. Debe registrarse la dimensión real de la pieza en milímetros, como insumo para la calibración de escala.
 
**Criterio de cierre:** la pieza real se renderiza correctamente en la aplicación con materiales PBR, y su escala real queda documentada.
**Asignado a:** _(pendiente)_

> **Estado (2026-08-10): ⏳ Pendiente.** Requiere trabajo de modelado 3D de una pieza real (siguiendo la guía D1).
 
#### D3 — Definición de la estructura del catálogo
**Prioridad:** Media · **Esfuerzo:** S–M (2–4 h) · **Tipo:** General · **Dependencias:** ninguna
 
Acordar el conjunto de piezas a incluir en el alcance del semestre —cantidad por categoría (aretes, pulseras, collares)— y los metadatos necesarios para cada una (nombre, fotografía, archivo GLB, dimensiones reales, tipo de anclaje). Esta definición constituye un insumo directo para el SRS y para el Sprint 4.
 
**Criterio de cierre:** existe una lista acordada de piezas y un esquema de metadatos por pieza.
**Asignado a:** _(pendiente — requiere coordinación con la joyería participante a través de la Product Owner)_

> **Estado (2026-08-10): ✅ Esquema hecho (lista final pendiente de coordinar).** Se definió el esquema de metadatos y la estructura del catálogo (`docs/D3_ESTRUCTURA_CATALOGO.md`), y se implementó en la app un `catalog.json` de ejemplo que ya se carga y se lista. **Falta** acordar la lista definitiva de piezas con la joyería participante (vía Product Owner). **Sirve para** tener la fuente de verdad del alcance de piezas, consumible por la app y el SRS.
 
#### D4 — Evaluación de conversión GLB a USDZ (opcional)
**Prioridad:** Baja · **Esfuerzo:** S (~2 h) · **Tipo:** Técnica · **Dependencias:** D2
 
El botón de realidad aumentada nativo de `model-viewer` en iOS (Quick Look) requiere archivos en formato `.usdz`. No es un requisito del flujo principal, dado que la colocación mediante `ar_flutter_plugin_2` y ARKit funciona correctamente con archivos GLB; no obstante, conviene documentar el costo de conversión en caso de considerarse en el futuro. Esta tarea corresponde únicamente a evaluación, sin implementación.
 
**Criterio de cierre:** existe una nota breve con la conclusión (viabilidad y herramienta recomendada, de aplicar).
**Asignado a:** _(pendiente)_

> **Estado (2026-08-10): ✅ Hecho.** Se redactó la nota (`docs/D4_NOTA_GLB_USDZ.md`) con la conclusión de **no incorporar USDZ al flujo principal** (el AR ya funciona con GLB vía `ar_flutter_plugin_2`) y las herramientas de conversión por si se decide a futuro. **Sirve para** cerrar la duda sobre el botón Quick Look de iOS sin gastar esfuerzo de implementación.
 
---
 
### Frente E — Documentación académica
 
> En todas las tareas de este frente debe emplearse la terminología del proyecto: "la joyería participante" o "una joyería del sector" (nunca el nombre del cliente); "la aplicación" o "el producto" (nunca "MVP" ni "prototipo"); y ninguna referencia a anillos ni a dedos.

> **Nota (2026-08-10):** el Frente E (documentación académica) no se abordó en esta sesión por decisión del equipo; todas sus tareas siguen pendientes.
 
#### E1 — Redacción de las secciones pendientes del SRS
**Prioridad:** Alta · **Esfuerzo:** M–L por sección (4–10 h cada una) · **Tipo:** General · **Dependencias:** B2 y B3 aportan contexto, pero no son bloqueantes
 
La Sección 2 ya se encuentra asignada a André Landinez. Las secciones restantes (requisitos funcionales, requisitos no funcionales, interfaces, restricciones, entre otras según la plantilla de línea base) deben distribuirse entre el equipo. Debe verificarse que los requisitos funcionales cubran explícitamente las tres categorías de producto, incluyendo el requisito de collares con detección de pose, que constituye un requisito técnico independiente del correspondiente a aretes y pulseras.
 
**Criterio de cierre:** todas las secciones cuentan con un borrador completo, revisado por al menos otro integrante del equipo.
**Asignado a:** _(pendiente — asignación por sección)_

> **Estado (2026-08-10): ⏳ Pendiente.**
 
#### E2 — Avance del SPMP (ISO/IEC/IEEE 16326-2009)
**Prioridad:** Alta · **Esfuerzo:** L (10–15 h en total, distribuible) · **Tipo:** General · **Dependencias:** ninguna
 
Completar las secciones pendientes conforme a la plantilla institucional: descomposición de actividades (WBS, con el detalle de una sola iteración por tratarse de un ciclo ágil), calendarización (carta Gantt del semestre con fechas de sprints y entregas), gestión de riesgos y planes de soporte. Esta tarea es divisible en subsecciones para su distribución entre varios integrantes.
 
**Criterio de cierre:** el documento cumple con la plantilla completa y queda listo para revisión del director del proyecto.
**Asignado a:** _(pendiente — asignación por sección)_

> **Estado (2026-08-10): ⏳ Pendiente.**
 
#### E3 — Actualización del plan de sprints en la documentación
**Prioridad:** Alta · **Esfuerzo:** S–M (2–4 h) · **Tipo:** General · **Dependencias:** ninguna
 
El plan de sprints presente en los documentos de metodología conserva referencias al alcance anterior (anclaje en dedo índice, menciones de anillos en el backlog). Debe actualizarse para reflejar el alcance vigente: Sprint 2 correspondiente a pulseras ancladas en la muñeca (landmark 0), e incorporación de collares mediante detección de pose, ya sea ampliando el Sprint 3 o redistribuyendo las actividades entre sprints. Se mantiene la estructura de 6 sprints.
 
**Criterio de cierre:** la planificación de sprints documentada es coherente con el alcance vigente (sin anillos, con collares incluidos) en la totalidad de los documentos del proyecto.
**Asignado a:** _(pendiente)_

> **Estado (2026-08-10): ⏳ Pendiente.**
 
#### E4 — Finalización de la presentación de requisitos (Canva)
**Prioridad:** Media · **Esfuerzo:** S–M (2–4 h) · **Tipo:** General · **Dependencias:** avance de E1
 
Completar la presentación de requisitos, verificando su coherencia con el SRS: mismas categorías de producto, mismos requisitos y misma terminología del proyecto.
 
**Criterio de cierre:** la presentación queda completa y alineada con el SRS.
**Asignado a:** _(pendiente)_

> **Estado (2026-08-10): ⏳ Pendiente.**
 
#### E5 — Auditoría de citas bibliográficas (formato IEEE)
**Prioridad:** Media · **Esfuerzo:** S–M (2–4 h) · **Tipo:** General · **Dependencias:** ninguna
 
Revisar, en la totalidad de los documentos, que la numeración de citas sea secuencial y que cada referencia en el texto corresponda a la entrada correcta en la bibliografía. Se han identificado errores de correspondencia en versiones anteriores; la revisión debe realizarse cita por cita.
 
**Criterio de cierre:** todas las citas de todos los documentos entregables quedan verificadas.
**Asignado a:** _(pendiente)_

> **Estado (2026-08-10): ⏳ Pendiente.**
 
---
 
## 4. Mapa de dependencias
 
```
A1, A2 ──► A4 ──► C5
B1 ─────► C2
B3 ─────► C1
B4 ─────► C3
D1 ─────► D2 ──► D4 (opcional)
E1 ─────► E4
```
 
- **Tareas con mayor efecto habilitador:** A1 y A2 (condicionan el desarrollo posterior) y los spikes B1–B3 (definen el enfoque de implementación de las tres categorías de producto).
- **Tareas sin dependencias, ejecutables de inmediato:** A3, B4, B5, B6, C4, D1, D3, E1, E2, E3, E5.
- **Riesgo técnico de mayor magnitud identificado a la fecha:** B1 (sin solución definida para tracking de manos en iOS) y B2 (sin desarrollo ni investigación iniciada para collares).
## 5. Criterio de distribución del trabajo
 
No se establecen asignaciones fijas. Cada integrante selecciona tareas según su disponibilidad y perfil, apoyándose en la clasificación **Tipo** (Técnica / General). Se sugieren los siguientes criterios, sin carácter obligatorio:
 
- Con entorno de desarrollo operativo, se recomienda priorizar los spikes del Frente B, dado que son las tareas que reducen mayor incertidumbre antes del inicio de los sprints.
- Con entorno de desarrollo no operativo, se recomienda iniciar por el Frente A, y avanzar en paralelo tareas de tipo General (Frente E, D3, A3).
- Las tareas de esfuerzo L pueden ejecutarse en pareja o dividirse en dos etapas; la separación entre spike (Frente B) e implementación (Frente C) responde precisamente a este propósito.

---

## 6. Resumen de estado (2026-08-10)

| Tarea | Estado |
|---|---|
| A1 — Fix `Flutter.h` (MacBook Air) | ⏳ Pendiente |
| A2 — Unificación `minSdk` | ✅ Hecho |
| A3 — Inventario de dispositivos | 🟡 Plantilla lista (falta llenar) |
| A4 — Verificación cruzada de entornos | ⏳ Pendiente |
| B1 — Tracking de manos en iOS | 🟡 Análisis + andamiaje (POC en iPhone pendiente) |
| B2 — Pose para collares | ✅ Hecho (validación en dispositivo pendiente) |
| B3 — Lóbulos para aretes | ✅ Decisión hecha (evidencia en dispositivo pendiente) |
| B4 — Estabilización del tracking | ✅ Hecho |
| B5 — Isolate de detección | ✅ Hecho (prototipo) |
| B6 — Oclusión por segmentación | ✅ Hecho |
| C1 — Pantalla de aretes | ⏳ Pendiente |
| C2 — Tracking de muñeca en iOS | ⏳ Pendiente |
| C3 — Filtro de estabilización (Android) | 🟡 Integrado en código (validación pendiente) |
| C4 — Depuración del repositorio | 🟡 Repo oficial limpio (queda el del MVP) |
| C5 — Prompt 4 / `VIABILIDAD_TECNICA.md` | ⏳ Pendiente |
| D1 — Pipeline de digitalización | ✅ Hecho |
| D2 — Primer modelo GLB real | ⏳ Pendiente |
| D3 — Estructura del catálogo | ✅ Esquema hecho (lista final por coordinar) |
| D4 — Evaluación GLB→USDZ | ✅ Hecho |
| E1–E5 — Documentación académica | ⏳ Pendiente (fuera de alcance de la sesión) |
