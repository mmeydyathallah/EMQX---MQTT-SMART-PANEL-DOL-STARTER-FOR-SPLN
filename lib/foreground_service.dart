import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Callback top-level yang dipanggil saat service dijalankan.
/// Isinya sengaja kosong: service hanya dipakai agar proses & socket MQTT
/// di main isolate tetap hidup saat layar mati (bukan menjalankan task di isolate ini).
@pragma('vm:entry-point')
void dolForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(DolTaskHandler());
}

class DolTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

class ForegroundService {
  ForegroundService._();

  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'dol_starter_service',
        channelName: 'Koneksi DOL Starter',
        channelDescription: 'Menjaga koneksi MQTT ke EMQX tetap aktif saat layar mati.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _initialized = true;
  }

  /// Minta izin notifikasi (Android 13+) dan pengecualian optimasi baterai (Android 12+).
  static Future<void> requestPermissions() async {
    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (!Platform.isAndroid) return;
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  static Future<bool> start() async {
    try {
      if (await FlutterForegroundTask.isRunningService) return true;
      final result = await FlutterForegroundTask.startService(
        serviceId: 3671,
        serviceTypes: const [ForegroundServiceTypes.dataSync],
        notificationTitle: 'DOL Starter aktif',
        notificationText: 'Koneksi MQTT terjaga saat layar mati',
        callback: dolForegroundCallback,
      );
      return result is ServiceRequestSuccess;
    } catch (_) {
      return false;
    }
  }

  static Future<void> updateText(String text) async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(notificationText: text);
      }
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }
}
