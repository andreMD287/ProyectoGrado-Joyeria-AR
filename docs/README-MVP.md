# Jewelry AR — MVP de Validación Técnica
 
MVP (Producto Mínimo Viable) desarrollado en Flutter cuyo propósito **no** es construir la aplicación final, sino **validar la viabilidad técnica** de las tecnologías clave antes de comprometer recursos en el proyecto real de prueba virtual de joyería con Realidad Aumentada.
 
En concreto, este MVP se construyó para responder tres preguntas de fondo:
 
1. **¿Se puede acceder de forma confiable a la cámara desde Flutter en Android e iOS**, con el flujo de permisos en runtime funcionando en ambas plataformas?
2. **¿Se puede superponer un objeto 3D (GLB con PBR) sobre el mundo real** usando ARCore/ARKit desde un plugin unificado de Flutter?
3. **¿Se puede obtener en tiempo real la posición 3D de puntos anatómicos** (la muñeca) para anclar joyas?
Todo el trabajo aquí sirve como **antecedente técnico** del proyecto real: las configuraciones de cámara, los ajustes de Flutter por plataforma, las decisiones de formato de modelo y el manejo de permisos que aquí se probaron son la base sobre la que se construirá la aplicación definitiva.
 
---
 
## 1. Propósito del repositorio
 
Este repositorio es un **laboratorio de pruebas**. Cada pantalla aísla una tecnología y responde una pregunta de factibilidad concreta. El código prioriza la **claridad de validación** (HUDs, indicadores de estado, paneles de coordenadas) sobre la optimización o la arquitectura de producción.
 
El foco principal del MVP fue doble:
 
- **Cámara y permisos multiplataforma:** comprobar que el pipeline de cámara y el flujo de permisos en runtime funcionan tanto en **Android** como en **iOS**, que son notoriamente distintos en su manejo de permisos y de compilación.
- **Superposición de objeto 3D como AR:** comprobar que un modelo 3D con materiales PBR se renderiza correctamente y puede colocarse/anclarse sobre superficies y puntos del mundo real.
---
 
## 2. Stack tecnológico
 
| Paquete | Versión | Rol en el MVP |
|---|---|---|
| `ar_flutter_plugin_2` | ^0.0.3 | AR sobre superficie (ARCore en Android, ARKit en iOS) mediante PlatformViews. API unificada en Dart. |
| `model_viewer_plus` | ^1.10.0 | Visor 3D de modelos GLB con PBR, embebido en un WebView (`<model-viewer>`). |
| `hand_landmarker` | ^2.2.0 | MediaPipe Hand Landmarker vía puente JNI. 21 landmarks con coordenadas x, y, z. **Android únicamente.** |
| `google_mlkit_face_detection` | ^0.13.2 | Detección facial (base para aretes). Integración pendiente. |
| `camera` | ^0.11.1 | Acceso al hardware de cámara y stream de frames en tiempo real. |
| `permission_handler` | ^11.4.0 | Solicitud de permisos en runtime. La versión 11.x es la exigida por `ar_flutter_plugin_2`. |
| `vector_math` | ^2.1.0 | `Vector3`/`Vector4` para posicionar, escalar y rotar el `ARNode`. |
 
Entorno: Flutter con Dart SDK `^3.11.5`, Material 3.
 
---
 
## 3. Estructura del proyecto
 
```
jewelry_ar_mvp/
├── assets/
│   └── models/
│       └── test_jewelry.glb          # Modelo PBR de referencia (Damaged Helmet, Khronos)
├── lib/
│   ├── main.dart                     # App raíz + navegación por rutas nombradas
│   └── screens/
│       ├── home_screen.dart          # Menú principal con 3 botones de prueba
│       ├── model_viewer_screen.dart  # Visor 3D PBR (model_viewer_plus) + acceso a AR
│       ├── ar_placement_screen.dart  # Colocación del GLB en superficie (ar_flutter_plugin_2)
│       ├── ar_hand_screen.dart       # Tracking de muñeca (hand_landmarker / MediaPipe)
│       └── ar_face_screen.dart       # Stub de aretes (integración pendiente)
├── android/
│   └── app/
│       ├── build.gradle.kts          # minSdk 24 (requerido por ARCore)
│       └── src/main/
│           ├── AndroidManifest.xml   # CAMERA + INTERNET + ARCore
│           └── kotlin/.../MainActivity.kt   # FlutterFragmentActivity
├── ios/
│   ├── Podfile                       # platform 16.0 + PERMISSION_CAMERA=1
│   └── Runner/Info.plist             # NSCameraUsageDescription + capacidad arkit
├── docs/
│   └── ios_camera_permission_fix.md  # Procedimiento del fix de cámara en iOS
└── test/
    └── widget_test.dart              # Verifica que HomeScreen muestre los 3 botones
```
 
---
 
## 4. Configuración de la cámara ⭐
 
Esta fue una de las dos validaciones centrales del MVP: **confirmar que la cámara y sus permisos funcionan igual de bien en Android que en iOS**, dado que ambas plataformas manejan los permisos de forma muy diferente.
 
### 4.1 Android
 
El `AndroidManifest.xml` declara:
 
```xml
<!-- Permiso de cámara: requerido por AR y ML Kit -->
<uses-permission android:name="android.permission.CAMERA"/>
 
<!-- Internet: requerido para descargar/servir assets 3D -->
<uses-permission android:name="android.permission.INTERNET"/>
 
<!-- ARCore: la app usa AR y depende de la cámara AR -->
<uses-feature android:name="android.hardware.camera.ar" android:required="true"/>
<uses-permission android:name="com.google.ar.core"/>
 
<!-- ARCore requerido: la app no funciona sin soporte AR -->
<meta-data android:name="com.google.ar.core" android:value="required" />
```
 
En Android el permiso de cámara se concede en runtime; basta con declararlo en el manifest y solicitarlo con `permission_handler`. No requiere pasos de compilación adicionales.
 
### 4.2 iOS — el punto crítico
 
En iOS la configuración es **más delicada** y fue el principal aprendizaje del MVP. Se requieren **dos** cosas:
 
**(a) Descripción de uso en `Info.plist`:**
 
```xml
<key>NSCameraUsageDescription</key>
<string>Esta app necesita acceso a la cámara para la prueba virtual de joyería con realidad aumentada.</string>
```
 
**(b) La macro `PERMISSION_CAMERA=1` en el `Podfile`** — esto es lo crítico:
 
`permission_handler` en iOS **deshabilita todos los permisos a nivel de compilación por defecto**. Si no se activa la cámara con una macro de preprocesador, el código del permiso de cámara ni siquiera se compila dentro de la app. El síntoma es engañoso: `Permission.camera.request()` no muestra el diálogo del sistema, iOS nunca registra que la app pidió la cámara, y la app ni siquiera aparece en *Ajustes → Privacidad → Cámara*.
 
El bloque `post_install` del `ios/Podfile` resuelve esto:
 
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        ## dart: PermissionGroup.camera
        'PERMISSION_CAMERA=1',
      ]
    end
  end
end
```
 
**Procedimiento para aplicar el fix en iOS** (el orden importa):
 
1. Agregar el bloque `post_install` con `PERMISSION_CAMERA=1` al `ios/Podfile`.
2. Ejecutar `pod install` desde la carpeta `ios/`.
3. **Desinstalar la app del iPhone** — obligatorio para limpiar el estado de permisos que quedó corrupto en intentos previos.
4. Recompilar e instalar desde Xcode o con `flutter run`.
5. Al pulsar el botón de permiso debe aparecer el diálogo del sistema iOS.
6. Verificar que la app ya figura en *Ajustes → Privacidad y seguridad → Cámara*.
> El detalle completo está en [`docs/ios_camera_permission_fix.md`](docs/ios_camera_permission_fix.md).
 
### 4.3 Flujo de permiso en código
 
El manejo del permiso en runtime (en `ar_placement_screen.dart`) contempla el caso de denegación permanente, típico de iOS:
 
```dart
var status = await Permission.camera.request();
 
if (status.isGranted) {
  // continuar e iniciar la sesión AR
} else if (status.isPermanentlyDenied) {
  await openAppSettings();   // iOS bloqueó el permiso → abrir Ajustes
  await _checkPermission();  // re-verificar al volver de Ajustes
}
```
 
### 4.4 Configuración del `CameraController`
 
En la pantalla de tracking de manos, el stream de cámara se configura para equilibrar rendimiento y precisión:
 
```dart
_cameraController = CameraController(
  camera,                                 // cámara trasera (el usuario apunta a su mano)
  ResolutionPreset.medium,                // ~640×480: equilibrio rendimiento/precisión
  enableAudio: false,
  imageFormatGroup: ImageFormatGroup.yuv420, // formato nativo de Android
);
await _cameraController!.initialize();
await _cameraController!.startImageStream(_onCameraFrame);
```
 
---
 
## 5. Objeto 3D superpuesto como AR ⭐
 
La segunda validación central: **renderizar un modelo 3D con PBR y superponerlo sobre el mundo real**. Esto se probó en tres capas complementarias.
 
### 5.1 Formato del modelo — GLB (glTF 2.0)
 
Se eligió **GLB (binary glTF 2.0)** por ser el único formato que funciona en las tres vías del MVP:
 
- **ARCore** (Android) vía `ar_flutter_plugin_2`
- **ARKit / Quick Look** (iOS)
- **`model_viewer_plus`** (WebView)
USDZ es exclusivo de Apple y OBJ no tiene soporte PBR nativo, por eso se descartaron. Todo GLB/glTF 2.0 usa materiales **PBR metallic-roughness** por especificación (metalicidad, roughness, occlusion maps, normal maps).
 
El modelo actual (`assets/models/test_jewelry.glb`) es el **Damaged Helmet** de Khronos, el modelo de referencia estándar de la industria para validar que un renderer PBR funciona correctamente. Es un placeholder: en el proyecto real se reemplazará por modelos de joyas.
 
### 5.2 Renderizado en el visor 3D
 
`ModelViewerScreen` usa `model_viewer_plus`, que embebe el web component `<model-viewer>` de Google dentro de un WebView. El rendering 3D ocurre en el WebView, no en el canvas de Flutter:
 
```dart
ModelViewer(
  src: 'assets/models/test_jewelry.glb',
  alt: 'Modelo PBR de referencia',
  ar: true,                                    // habilita el botón AR nativo del SO
  arModes: const ['scene-viewer', 'webxr', 'quick-look'],
  autoRotate: true,
  cameraControls: true,                        // rotación orbital + zoom táctil
  shadowIntensity: 1,
  environmentImage: 'neutral',                 // entorno neutral para mostrar reflejos PBR
  exposure: 1.0,
);
```
 
El HUD superpuesto mide los FPS del **hilo de UI de Flutter** (mediante un `Ticker` sincronizado con VSync), no del render del WebView — esto se indica explícitamente para no inducir a confusión al validar rendimiento.
 
### 5.3 Superposición sobre superficie real (ARCore/ARKit)
 
`ARPlacementScreen` usa `ar_flutter_plugin_2` para colocar el GLB sobre una superficie plana detectada. El flujo de estados es:
 
```
scanning ──(3s)──► ready ──(tap en plano)──► placed
                                               └──(reset)──► ready
    └──(error)──► error / unsupported
```
 
La superposición del objeto se hace por hit-test → ancla → nodo:
 
```dart
// 1. Se detecta el impacto del tap sobre un plano
final anchor = ARPlaneAnchor(transformation: planeHit.worldTransform);
await _arAnchorManager!.addAnchor(anchor);
 
// 2. Se crea el nodo GLB anclado al plano
final node = ARNode(
  type: NodeType.localGLTF2,                 // GLB local; el plugin lo copia a un dir temporal
  uri: 'assets/models/test_jewelry.glb',
  scale: Vector3(0.15, 0.15, 0.15),          // reducido para tamaño realista sobre la mesa
  position: Vector3(0.0, 0.0, 0.0),
  rotation: Vector4(1.0, 0.0, 0.0, 0.0),
);
await _arObjectManager!.addNode(node, planeAnchor: anchor);
```
 
Durante la inicialización de la sesión se muestran planos y feature points para depuración visual (`showPlanes: true`, `showFeaturePoints: true`), y se configuró detección de planos horizontales y verticales.
 
### 5.4 Anclaje sobre la anatomía (muñeca)
 
`ARHandScreen` valida el anclaje del objeto sobre un punto del cuerpo. Usa MediaPipe (vía `hand_landmarker`) para obtener los 21 landmarks de la mano y anclar la pulsera al **landmark 0 (WRIST — la muñeca)**:
 
```dart
final plugin = HandLandmarkerPlugin.create(
  numHands: 1,
  minHandDetectionConfidence: 0.6,
  delegate: HandLandmarkerDelegate.gpu,      // backend GPU de MediaPipe
);
 
final List<Hand> hands = plugin.detect(cameraImage, sensorOrientation);
final Landmark wrist = hands[0].landmarks[0]; // punto de anclaje de la pulsera
// wrist.x, wrist.y, wrist.z  → coordenadas normalizadas [0-1]
```
 
Las coordenadas x, y son la posición en la imagen (0-1) y z es la profundidad relativa a la muñeca (negativo = más cerca de la cámara). Un `CustomPainter` dibuja el esqueleto de la mano y destaca la muñeca como punto de anclaje.
 
---
 
## 6. Las cuatro pantallas
 
| Pantalla | Tecnología que integra | Pregunta que valida | Estado |
|---|---|---|---|
| **Modelo 3D + AR** | `model_viewer_plus` + `ar_flutter_plugin_2` | ¿Se renderiza PBR? ¿Se coloca el GLB en una superficie real? | ✅ Implementada |
| **AR Manos (Pulseras)** | `hand_landmarker` (MediaPipe/JNI) | ¿Se obtiene la posición 3D de la muñeca en tiempo real? | ✅ Implementada (Android) |
| **AR Rostro (Aretes)** | `google_mlkit_face_detection` | ¿Se detectan landmarks de orejas para anclar aretes? | 🔲 Stub — pendiente |
| **Colocación AR** | `ar_flutter_plugin_2` | ¿ARCore/ARKit ancla el modelo sobre el plano detectado? | ✅ Implementada |
 
---
 
## 7. Configuración de plataforma
 
### Android
 
- **`minSdk 24`** — requerido por ARCore.
- **`MainActivity : FlutterFragmentActivity`** — `ar_flutter_plugin_2` usa PlatformViews que exigen que la Activity host extienda `FragmentActivity`. La `FlutterActivity` por defecto no lo hace y provoca errores al crear el `ARView`.
- ARCore declarado como `required` en el manifest.
### iOS
 
- **`platform :ios, '16.0'`** y `IPHONEOS_DEPLOYMENT_TARGET = '16.0'`.
- **`use_modular_headers!`** en el target `Runner`.
- **`PERMISSION_CAMERA=1`** en `post_install` (ver sección 4.2).
- Capacidad **`arkit`** declarada en `UIRequiredDeviceCapabilities` del `Info.plist`.
- ARKit requiere **dispositivo físico** — no funciona en el simulador.
---
 
## 8. Requisitos y ejecución
 
```bash
# Instalar dependencias
flutter pub get
 
# Ejecutar en dispositivo físico (AR no funciona en emulador/simulador)
flutter run --debug
```
 
- **Android:** `minSdk 24`. ARCore se instala/actualiza automáticamente desde la Play Store si falta.
- **iOS:** Xcode, dispositivo físico con soporte ARKit, deployment target 16.0. Tras editar el Podfile, correr `pod install` desde `ios/`.
---
 
## 9. Estado del proyecto y limitaciones conocidas
 
| Feature | Estado |
|---|---|
| Navegación base (3 pantallas) | ✅ Implementado |
| Acceso a cámara + permisos (Android e iOS) | ✅ Validado en ambas plataformas |
| Visor 3D con PBR (`model_viewer_plus`) | ✅ Implementado |
| Superposición del GLB en superficie (`ar_flutter_plugin_2`) | ✅ Implementado |
| Tracking de muñeca (`hand_landmarker`) | ✅ Implementado — Android |
| Tracking de manos — iOS | 🔲 Pendiente (`hand_landmarker` es Android-only) |
| Detección facial para aretes | 🔲 Pendiente (`google_mlkit_face_detection`) |
| Modelo GLB de joya real (hoy usa el casco de referencia) | 🔲 Pendiente |
 
### Limitaciones y notas técnicas para el proyecto real
 
- **Rendimiento de MediaPipe:** `detect()` es síncrono y bloquea el isolate principal de Dart ~15-40 ms por frame; la implementación actual limita la detección a ≤10 FPS. Para producción, la solución es un isolate dedicado con su propia instancia del plugin, pasando los bytes del frame por `SendPort`.
- **iOS y `hand_landmarker`:** el plugin usa un puente JNI que solo existe en Android. Para iOS habría que evaluar alternativas (TFLite o ARKit Hand Anchors nativos).
- **Botón AR nativo en `model-viewer` (iOS):** el modo Quick Look de iOS requiere un archivo **`.usdz`**; con solo GLB y sin `iosSrc`, ese botón nativo no funcionará en iPhone. La colocación vía `ar_flutter_plugin_2`/ARKit es independiente y sí funciona.
- **Comentario obsoleto en `pubspec.yaml`:** un comentario menciona "Landmark 5 = Index MCP", pero el código real ancla al landmark 0 (WRIST). Es un resto de una versión anterior; conviene depurarlo.
---
 
## 10. Valor como antecedente del proyecto real
 
Este MVP deja resueltos y documentados varios de los riesgos técnicos más altos del proyecto definitivo:
 
- El **flujo de cámara y permisos multiplataforma** quedó validado en Android e iOS, incluyendo el fix crítico de `PERMISSION_CAMERA=1` que de otro modo habría costado tiempo de depuración en producción.
- El **formato de modelo (GLB con PBR)** quedó confirmado como el estándar viable para las tres vías de renderizado/AR.
- El **pipeline de superposición 3D** (visor → hit-test → ancla → nodo) quedó demostrado sobre superficie real, y el **anclaje anatómico** sobre la muñeca quedó demostrado con coordenadas 3D en tiempo real.
- Las **configuraciones específicas de Flutter por plataforma** (`FlutterFragmentActivity`, `minSdk 24`, deployment target iOS 16.0, Podfile, manifests) están documentadas y listas para heredarse.
En resumen: este repositorio es la prueba de concepto que confirma que el proyecto real es técnicamente viable, y provee la base de configuración sobre la que construirlo.