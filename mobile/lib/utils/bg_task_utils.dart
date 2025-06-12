import "dart:io";

import "package:logging/logging.dart";
import "package:permission_handler/permission_handler.dart";
import "package:photos/db/upload_locks_db.dart";
import "package:photos/main.dart";
import "package:photos/service_locator.dart";
import "package:photos/utils/file_uploader.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:workmanager/workmanager.dart" as workmanager;

@pragma('vm:entry-point')
void callbackDispatcher() {
  workmanager.Workmanager().executeTask((taskName, inputData) async {
    try {
      await runBackgroundTask(taskName);
      return true;
    } catch (e) {
      BgTaskUtils.$.info('Task error: $e');
      final prefs = await SharedPreferences.getInstance();
      await BgTaskUtils.releaseResourcesForKill(taskName, prefs);
      return Future.error(e.toString());
    }
  });
}

class BgTaskUtils {
  static final $ = Logger("BgTaskUtils");

  static Future<void> releaseResourcesForKill(
    String taskId,
    SharedPreferences prefs,
  ) async {
    await UploadLocksDB.instance.releaseLocksAcquiredByOwnerBefore(
      ProcessType.background.toString(),
      DateTime.now().microsecondsSinceEpoch,
    );
    await prefs.remove(kLastBGTaskHeartBeatTime);
  }

  static Future configureWorkmanager() async {
    if (Platform.isIOS) {
      final status = await Permission.backgroundRefresh.status;
      if (status != PermissionStatus.granted) {
        $.warning(
          "Background refresh permission is not granted. Please grant it to start the background service.",
        );
        return;
      }
    }
    $.warning("Configuring Work Manager for background tasks");
    const iOSBackgroundAppRefresh = "io.ente.frame.iOSBackgroundAppRefresh";
    const androidPeriodicTask = "io.ente.photos.androidPeriodicTask";
    final backgroundTaskIdentifier =
        Platform.isIOS ? iOSBackgroundAppRefresh : androidPeriodicTask;
    try {
      await workmanager.Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: flagService.internalUser,
      );
      await workmanager.Workmanager().registerPeriodicTask(
        backgroundTaskIdentifier,
        backgroundTaskIdentifier,
        frequency: Platform.isIOS
            ? const Duration(minutes: 60)
            : const Duration(minutes: 15),
        // TODO(prateekmedia): uncomment at last
        // initialDelay: const Duration(minutes: 10),
        constraints: workmanager.Constraints(
          networkType: workmanager.NetworkType.connected,
          requiresCharging: false,
          requiresStorageNotLow: false,
          requiresDeviceIdle: false,
        ),
        existingWorkPolicy: workmanager.ExistingWorkPolicy.append,
        backoffPolicy: workmanager.BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 15),
      );
      $.info("WorkManager configured");
    } catch (e) {
      $.warning("Failed to configure WorkManager: $e");
    }
  }
}
