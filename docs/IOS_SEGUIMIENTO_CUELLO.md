# Seguimiento del cuello para collares en iOS

En Android los collares se colocan sobre el cuello **medido** con MediaPipe
(`android/.../NeckTracker.kt`): Face Landmarker para la cara y segmentación
multiclase para la forma del cuello. En iOS ese mismo seguimiento está escrito
en `ios/Runner/NeckTrackingHandler.swift`, pero **no se ha probado en un
iPhone**. Mientras tanto, los collares en iOS siguen con los hombros de ML Kit
Pose, que funciona pero es menos preciso.

## Qué ya está hecho

- **Dart:** no hay que tocarlo. `NeckDetectorDataSource` habla con el canal
  `jewelry_ar/neck` igual en las dos plataformas, y la estrategia del collar
  (`NecklaceStrategy._fromNeck`) es común.
- **Swift:** `NeckTrackingHandler.swift`, registrado en `AppDelegate.swift` y en
  el proyecto de Xcode. Es un puerto línea a línea del de Android.
- **Modelos:** `assets/mediapipe/` (assets de Flutter, compartidos con
  Android). En iOS se buscan con `FlutterDartProject.lookupKey(forAsset:)`.
- **Dependencia:** `pod 'MediaPipeTasksVision', '0.10.21'` en el `Podfile`.

## Cómo encenderlo

1. `cd ios && pod install`.
2. En `lib/core/isolate/detection_runner.dart`, poner
   `iosNeckTrackerEnabled = true`.
3. Compilar en un iPhone y abrir un collar en la prueba virtual.

## Qué verificar

Para cada punto, qué se espera y qué tocar si no se cumple.

1. **Compila.** Si falla en `NeckTrackingHandler.swift`, lo más probable es un
   nombre de la API de MediaPipe distinto en la versión del pod
   (`detect(videoFrame:timestampInMilliseconds:)`, `segment(image:)`,
   `categoryMask`, `uint8Data`).
2. **Los modelos se encuentran.** En la consola de Xcode no debe salir
   `NeckTracking: no se encontró ...`. Si sale, revisar que `assets/mediapipe/`
   esté en el `pubspec.yaml` y en el bundle.
3. **La cara se detecta.** En la prueba virtual, con la diana de depuración,
   deben verse puntos en el mentón y las mejillas, **sobre** la cara. Si salen
   espejados (al otro lado de la cara), cambiar `mirror: false` por `null` en
   `NeckDetectorDataSource.detect`. Si salen girados 90°, la cámara no está
   entregando el frame vertical: hay que rotarlo antes de crear el `MPImage`
   (en Android se hace en `toUprightBitmap`).
4. **Las clases de la máscara.** En Android la máscara trae la clase del modelo
   menos uno, con el fondo en 255: cuello = 1, ropa = 3. Si en iOS el collar no
   se ancla en el cuello o salta, revisar esos valores
   (`NeckMeasure.bodySkin` y `NeckMeasure.clothes` en el Swift). La forma más
   rápida es imprimir los valores de la máscara bajo el mentón.
5. **Los puntos del cuello.** Con la diana deben verse, además, dos puntos donde
   el cuello toca la ropa a cada lado y uno en el centro del cuello de la
   camiseta.
6. **Velocidad.** La cara debería ir a más de 10 por segundo y el cuello a
   unos 3. El segmentador en GPU puede tardar en arrancar la primera vez; si
   falla en GPU usa CPU solo.

## Referencia: cómo quedó en Android

Validado en un Samsung Galaxy A15 (2026-11-05). De frente, cerca y lejos, el
collar rodea el cuello y se oculta detrás de él donde debe; girado, se orienta
hacia donde mira el cuerpo. Las constantes de ajuste (holguras, zona muerta del
giro, proxy del cuello) están en `jewelry_scene.dart` y `necklace_strategy.dart`
con la explicación de cada valor, y son comunes a las dos plataformas.
