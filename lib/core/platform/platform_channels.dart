/// Nombres de los canales nativos (platform channels) usados por la app.
class PlatformChannels {
  PlatformChannels._();

  /// Canal para el tracking de manos en iOS. La implementación nativa (Vision
  /// o MediaPipe Tasks) se define en el spike B1 y se consume desde
  /// `IosHandDetector`.
  static const String iosHandTracking =
      'co.edu.javeriana.jewelry_ar/hand_tracking_ios';
}
