# B7 — Spike: motor de render 3D con fondo transparente (`three_js`)

**Frente:** B — Spikes de investigación · **Prioridad:** Alta · **Alimenta:** ADR-16 (migración del render de la prueba virtual)
**Tipo:** Técnica (prueba de concepto ejecutable en dispositivo) · **Estado:** Resuelto — motor validado · **Última actualización:** 2026-09-18

> La prueba virtual se percibe como una calcomanía superpuesta y no como una joya puesta sobre el cuerpo. La causa está en el render: `model_viewer_plus` dibuja el modelo desde **su propia cámara** dentro de un WebView y el resultado se compone como un *sprite* 2D, sin relación de perspectiva con la extremidad real. Este spike verifica si `three_js` puede sustituirlo, y su pregunta decisiva es una sola: **¿puede renderizar con fondo transparente, de modo que la cámara se vea a través?** Si no, el motor no sirve y no vale la pena seguir.

---

## 1. Qué contiene

Aplicación Flutter mínima e independiente del producto:

```
spikes/B7-motor-render/
├── lib/
│   └── main.dart      # fondo de franjas + vista three_js con alpha + carga de los GLB del catálogo
└── android/           # andamiaje de Flutter (requiere build nativo: ver §4)
```

El fondo son **franjas de colores fuertes** dibujadas con `CustomPaint`, a propósito: o se ven a través del render 3D, o no se ven. No admite interpretación.

### Cómo reproducir

Los modelos **no se versionan aquí** (ya están en el repositorio, no se duplican):

```bash
cd spikes/B7-motor-render
mkdir -p assets && cp ../../assets/models/*.glb assets/
flutter pub get
flutter run --profile -d <dispositivo>
```

---

## 2. Resultado

Verificado en dispositivo físico (Galaxy A15, Android 15):

| Pregunta | Resultado |
|---|---|
| ¿Renderiza con fondo transparente sobre widgets de Flutter? | **Sí.** `Settings(alpha: true, clearAlpha: 0.0)` |
| ¿Dibuja en `Texture` o en *platform view*? | **`Texture`** (`FlutterAngleTexture`) — compone como un widget normal |
| ¿Funciona con Flutter 3.41.7, la versión que fija el CI? | **Sí**, sin subir el SDK |
| ¿Carga los GLB del catálogo? | **5 de 7** (ver §3) |
| Calidad de imagen | PBR con *metalness*/*roughness*, reflejos especulares y antialiasing |

Que dibuje en un `Texture` y no en una *platform view* resuelve de paso un problema que arrastraba el WebView: su composición asíncrona hacía que la joya "nadara" respecto de la imagen de cámara.

---

## 3. Trampas encontradas (y cómo se resuelven)

### 3.1. El visor cachea su tamaño en el primer *build*

`ThreeJS` lee `MediaQuery` la primera vez que se construye y **guarda ese tamaño para siempre** (`initSize` retorna temprano si `screenSize != null`). En arranque en frío ese primer build ocurre antes de que lleguen las medidas de la ventana: el tamaño queda en 0×0 y la creación de la textura falla con

```
PlatformException(Invalid dimensions, Width and height must be positive)
```

**Solución aplicada:** no crear el visor en `initState`, sino tras conocer las restricciones reales (`LayoutBuilder` + `addPostFrameCallback`), pasándole `size` explícito. Es además el patrón que necesita el producto, donde el 3D va dentro de una tarjeta y no a pantalla completa.

### 3.2. El cargador glTF rompe con `KHR_materials_specular`

Dos piezas del catálogo fallan con `type 'int' is not a subtype of type 'double?'`:

| Modelo | Carga |
|---|---|
| `collar-cadena-01.glb`, `cartier.glb`, `_placeholder.glb`, `Collar1_Juanes.glb`, `Collar2_Juanes.glb` | ✅ |
| `arete_perla.glb`, `pulsera_perlas_basica.glb` | ❌ |

**Causa:** ambas usan la extensión `KHR_materials_specular` con `specularFactor: 0`. Blender exporta el cero como **entero**, y el cargador lo asigna crudo a un campo tipado `double?`:

```dart
// three_js_advanced_loaders/lib/gltf/gltf_extensions.dart:144
materialParams['specularIntensity'] = extension['specularFactor'] ?? 1.0;
```

No es un problema general de `int`/`double`: `Collar1_Juanes.glb` trae `transmissionFactor: 1` (también entero) y carga sin problema.

**Dos salidas:** parchear el cargador (`(… as num?)?.toDouble()`, una línea) o reexportar esas dos piezas con un valor no entero.

### 3.3. Exige cadena de compilación nativa

`three_js` depende de `flutter_angle`, que compila ANGLE con CMake y NDK. Sin la versión exacta el build falla con:

```
[CXX1300] CMake '3.31.4' was not found in SDK, PATH, or by cmake.dir property
```

Se instala con `sdkmanager --install "cmake;3.31.4"`. **El CI tendrá que hacerlo también**, o el build romperá ahí.

---

## 4. Recomendación

Adoptar `three_js` como motor de render de la prueba virtual. La justificación completa y las alternativas descartadas (`model_viewer_plus`, `flutter_scene`, Depth API de ARCore/ARKit) están en **ADR-16** del SDD, que es la fuente única de las decisiones de arquitectura.

Lo que este spike **no** cubre y queda para la migración: alimentar la cámara virtual con la pose de la muñeca, añadir el *occluder* de la extremidad para la oclusión por profundidad, y medir el rendimiento con la cámara corriendo en simultáneo.
