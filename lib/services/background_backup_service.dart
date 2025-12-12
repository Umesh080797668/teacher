import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backup_service.dart';

/// Background task handler for automatic backups
@pragma('vm:entry-point')
void backupCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('Background backup task started: $task');

      // Check if auto backup is enabled
      final prefs = await SharedPreferences.getInstance();
      final autoBackupEnabled = prefs.getBool('auto_backup') ?? true;

      if (!autoBackupEnabled) {
        debugPrint('Auto backup is disabled, skipping');
        return Future.value(true);
      }

      // Perform the backup
      final backupService = BackupService();
      await backupService.initialize();
      final backupPath = await backupService.performBackup();

      if (backupPath != null) {
        debugPrint('Background backup completed successfully: $backupPath');
      } else {
        debugPrint('Background backup failed');
      }

      return Future.value(true);
    } catch (e) {
      debugPrint('Error in background backup: $e');
      // Return true to prevent error notifications
      return Future.value(true);
    }
  });
}

class BackgroundBackupService {
  static const String _backupTaskName = 'autoBackupTask';

  /// Initialize and schedule automatic backups every 24 hours
  static Future<void> initialize() async {
    try {
      // Skip initialization on web platform
      if (kIsWeb) {
        debugPrint('Background backup service skipped on web platform');
        return;
      }

      // Check if auto backup is enabled
      final prefs = await SharedPreferences.getInstance();
      final autoBackupEnabled = prefs.getBool('auto_backup') ?? true;

      if (!autoBackupEnabled) {
        debugPrint('Auto backup is disabled, cancelling background tasks');
        await cancelBackupTask();
        return;
      }

      // Initialize Workmanager for backup tasks
      await Workmanager().initialize(
        backupCallbackDispatcher,
        isInDebugMode: kDebugMode,
      );

      // Register periodic task to backup every 24 hours
      await Workmanager().registerPeriodicTask(
        _backupTaskName,
        _backupTaskName,
        frequency: const Duration(hours: 24),
        constraints: Constraints(
          networkType: NetworkType.not_required, // Backup doesn't need internet
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: true, // Only backup if storage is not low
        ),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(hours: 1),
        initialDelay: const Duration(hours: 1), // First backup after 1 hour
      );

      debugPrint('Background backup service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing background backup service: $e');
    }
  }

  /// Cancel backup task
  static Future<void> cancelBackupTask() async {
    if (kIsWeb) {
      debugPrint('Background tasks not supported on web');
      return;
    }
    await Workmanager().cancelByUniqueName(_backupTaskName);
    debugPrint('Background backup task cancelled');
  }

  /// Re-enable backup task
  static Future<void> enableBackupTask() async {
    if (kIsWeb) {
      debugPrint('Background tasks not supported on web');
      return;
    }
    await initialize();
  }
}
