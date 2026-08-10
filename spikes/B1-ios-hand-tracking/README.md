# B1 — Spike: tracking de manos en iOS

**Frente:** B — Spikes de investigación · **Prioridad:** Alta · **Riesgo:** el más alto del proyecto · **Alimenta:** `IosHandDetector`, C2
**Tipo:** Técnica (nota comparativa + scaffolding) · **Estado:** Recomendación definida; POC preparado, pendiente de ejecutar en Mac/iPhone · **Última actualización:** 2026-08-10

> `hand_landmarker` (el detector usado en Android) es **Android-only**: usa un puente JNI a MediaPipe que no existe en iOS. Este spike evalúa las alternativas para iOS y deja el andamiaje listo para implementarlas.

---

## 1. Alternativas evaluadas

| Criterio | **Apple Vision** (`VNDetectHumanHandPoseRequest`) | MediaPipe Tasks (nativo iOS) | TFLite (modelo hand landmarks) |
|---|---|---|---|
| Disponibilidad iOS | Nativa (iOS 14+), sin dependencias | Requiere pods de MediaPipe | Requiere runtime TFLite + modelo |
| Landmarks | 21, **2D** (x, y) + confianza | 21, **3D** (x, y, z relativo) | 21, 3D (según modelo) |
| Precisión | Alta (Neural Engine) | Alta (mismo modelo que Android) | Media–alta |
| Latencia | Baja | Media | Media |
| Esfuerzo de integración | **Bajo** | Medio–alto (pods, binario grande) | Alto (preprocesado YUV→RGB, tensores) |
| Paridad con Android | Distinta topología/convención de coords | **Total** (mismo modelo) | Variable |
| Profundidad (z) | **No** (2D) | Sí (z relativo) | Sí |
| Dependencias extra | Ninguna | MediaPipe iOS | TFLite + assets |

---

## 2. Recomendación

**Apple Vision (`VNDetectHumanHandPoseRequest`)** como opción primaria para iOS.

- Es **nativa, sin dependencias** y de **bajo esfuerzo** de integración; entrega los 21 landmarks (incluida la muñeca, índice 0) con confianza por punto y buen rendimiento en el Neural Engine.
- Réplica funcional de lo que `hand_landmarker` hace en Android para el anclaje de la pulsera.

**Salvedad (documentada):** Vision es **2D** (no da z relativo como MediaPipe). Para el anclaje de la **muñeca** esto es aceptable: x,y ubican el punto y la profundidad del mundo la aporta la sesión AR (hit-test/proyección). Si más adelante se necesita **z por landmark** o **paridad exacta** de topología con Android, la alternativa es **MediaPipe Tasks nativo**; TFLite se descarta por ser la de mayor esfuerzo.

---

## 3. Arquitectura de integración

Dos enfoques posibles para llevar los landmarks de iOS a Flutter:

- **(elegido) MethodChannel por frame:** el frame llega por la cámara de Flutter (`CameraService`), y `IosHandDetector.detect()` envía sus bytes a la capa nativa, que corre Vision y devuelve los landmarks. Encaja con la interfaz `HandDetector` y con **una sola** cámara (la de Flutter). El costo de marshalling por frame se mitiga con el **isolate de detección (B5)** y el throttling.
- **(alternativa) AVCaptureSession nativo + EventChannel:** la capa nativa maneja su propia cámara y transmite landmarks por streaming. Más eficiente, pero implica **dos** pipelines de cámara y más código nativo. Se reserva por si el enfoque por frame no rinde.

### Piezas
- **Dart (ya integrado):** `lib/features/tracking/data/datasources/ios_hand_detector.dart` — cablea el `MethodChannel` `co.edu.javeriana.jewelry_ar/hand_tracking_ios`, envía el frame y mapea la respuesta a `Landmark` (función pura `mapVisionLandmarks`, cubierta por `test/ios_hand_detector_test.dart`).
- **Swift (referencia):** `native/HandTrackingHandler.swift` — implementación con Vision.

---

## 4. Pasos para completar el POC (en el Mac)

1. Copiar `native/HandTrackingHandler.swift` a `ios/Runner/` y añadirlo al target Runner en Xcode.
2. Registrar el handler en `ios/Runner/AppDelegate.swift`:

```swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var handTracking: HandTrackingHandler?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      handTracking = HandTrackingHandler(messenger: controller.binaryMessenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

3. **Formato de cámara por plataforma:** Vision espera BGRA. En iOS conviene configurar `CameraService` con `ImageFormatGroup.bgra8888` (Android mantiene `yuv420` para MediaPipe). Es un ajuste pendiente en `CameraService`.
4. Ejecutar en un **iPhone físico** y validar que la muñeca (landmark 0) se detecta y sigue la mano.

---

## 5. Qué falta validar en dispositivo

- Precisión y latencia reales de Vision frente al MediaPipe de Android (¿comparable para el anclaje?).
- Correcta reconstrucción del `CVPixelBuffer` desde los bytes del frame (formato/stride).
- Comportamiento con una o dos manos y con la mano parcialmente fuera de cuadro.

---

## 6. Criterio de cierre (según TAREAS_PENDIENTES)

> «Existe una nota comparativa con recomendación y, de resultar viable, una prueba de concepto que detecte la muñeca en un dispositivo iOS.»
> **Cubierto:** nota comparativa y recomendación (Apple Vision). **POC preparado** (cableado Dart con prueba + esqueleto Swift de referencia); su **ejecución en un iPhone** queda pendiente por requerir Mac + dispositivo, y corresponde a la tarea C2.
