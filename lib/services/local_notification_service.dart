import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();
  static const MethodChannel _channel = MethodChannel(
    'chicktemp/notifications',
  );

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('initialize');
      _initialized = true;
    } on PlatformException {
      // Desktop and unsupported Android builds should keep the app running.
    } on MissingPluginException {
      // The native notification bridge exists only on Android.
    }
  }

  Future<void> showAlert({
    required String id,
    required String title,
    required String body,
  }) async {
    await initialize();
    if (!_initialized || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('showAlert', {
        'id': id,
        'title': title,
        'body': body,
      });
    } on PlatformException {
      // Notification failure should not block alert refresh.
    } on MissingPluginException {
      // Non-Android targets intentionally have no native popup bridge.
    }
  }
}
