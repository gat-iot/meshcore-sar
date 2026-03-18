import '../models/device_info.dart';

class ProfileDeviceKeyResolver {
  static String? resolve({
    required DeviceInfo deviceInfo,
    required ConnectionMode connectionMode,
  }) {
    final publicKey = deviceInfo.publicKey;
    if (publicKey != null && publicKey.isNotEmpty) {
      final hex = publicKey
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      if (hex.isNotEmpty) {
        return 'pk:$hex';
      }
    }

    final deviceId = deviceInfo.deviceId?.trim();
    if (deviceId == null || deviceId.isEmpty) {
      return null;
    }

    if (connectionMode == ConnectionMode.usb && deviceId == 'usb') {
      return null;
    }

    return 'id:$deviceId';
  }
}
