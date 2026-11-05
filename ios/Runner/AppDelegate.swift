import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var handTracking: HandTrackingHandler?
  private var neckTracking: NeckTrackingHandler?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    handTracking = HandTrackingHandler(
      messenger: engineBridge.applicationRegistrar.messenger())
    // Collares: sin probar en iPhone; Dart no lo usa hasta encender
    // `iosNeckTrackerEnabled` (ver docs/IOS_SEGUIMIENTO_CUELLO.md).
    neckTracking = NeckTrackingHandler(
      messenger: engineBridge.applicationRegistrar.messenger())
  }
}
