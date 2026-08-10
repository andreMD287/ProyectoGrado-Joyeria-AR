import 'package:permission_handler/permission_handler.dart';

/// Centraliza el flujo de permiso de cámara, incluido el caso de denegación
/// permanente típico de iOS. Recuerda: en iOS el permiso además exige la macro
/// `PERMISSION_CAMERA=1` en el Podfile (ver configuración de plataforma).
class PermissionService {
  const PermissionService();

  /// Solicita el permiso de cámara. Devuelve `true` si quedó concedido.
  /// Si el usuario lo denegó permanentemente, abre los Ajustes del sistema.
  Future<bool> ensureCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }

  Future<bool> get isCameraGranted async => Permission.camera.isGranted;
}
