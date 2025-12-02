import 'package:permission_handler/permission_handler.dart';

class PermissionResult {
  const PermissionResult({required this.granted, required this.deniedForever});

  final bool granted;
  final bool deniedForever;

  bool get requiresSettings => deniedForever && !granted;
}

class AppPermissions {
  static Future<PermissionResult> requestMic() =>
      _request(Permission.microphone);

  static Future<PermissionResult> requestLocation() =>
      _request(Permission.locationWhenInUse);

  static Future<PermissionResult> _request(Permission permission) async {
    final status = await permission.request();
    return PermissionResult(
      granted: status.isGranted || status.isLimited,
      deniedForever: status.isPermanentlyDenied,
    );
  }

  static Future<bool> openSettings() => openAppSettings();
}
