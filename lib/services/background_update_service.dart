import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background task handler - this runs even when app is closed
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('Background update check task started: $task');

      // Perform the update check
      await _performBackgroundUpdateCheck();

      debugPrint('Background update check completed successfully');
      return Future.value(true);
    } catch (e) {
      debugPrint('Error in background update check: $e');
      return Future.value(false);
    }
  });
}

/// Perform the actual update check in the background
Future<void> _performBackgroundUpdateCheck() async {
  try {
    // Initialize notification plugin
    final FlutterLocalNotificationsPlugin notificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await notificationsPlugin.initialize(initializationSettings);

    // Get current app version
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    debugPrint('Background check - Current version: $currentVersion');

    // Fetch update info from GitHub
    final dio = Dio();
    // Add cache-busting headers to prevent stale data
    final response = await dio.get(
      'https://raw.githubusercontent.com/Umesh080797668/teacher/main/update.json',
      options: Options(
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final latestVersion = data['version'] as String;
      final releaseNotes = data['releaseNotes'] as String? ?? '';
      final isForced = data['isForced'] as bool? ?? false;

      debugPrint('Background check - Latest version: $latestVersion');

      // Save last check time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'last_update_check',
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setString('latest_version', latestVersion);

      // Compare versions
      final isNewer = _isNewerVersion(currentVersion, latestVersion);

      if (isNewer) {
        await prefs.setBool('update_available', true);

        // Show notification
        const AndroidNotificationDetails androidDetails =
            AndroidNotificationDetails(
              'update_channel',
              'App Updates',
              channelDescription: 'Notifications for app updates',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
              icon: '@mipmap/ic_launcher',
            );

        const NotificationDetails notificationDetails = NotificationDetails(
          android: androidDetails,
        );

        await notificationsPlugin.show(
          0,
          'Update Available',
          'Version $latestVersion is now available. ${isForced ? 'This update is required.' : 'Tap to update.'}',
          notificationDetails,
        );

        debugPrint('Notification shown for version $latestVersion');
      } else {
        await prefs.setBool('update_available', false);
        debugPrint('No update available');
      }
    }
  } catch (e) {
    debugPrint('Error in background update check: $e');
    rethrow;
  }
}

/// Compare version strings (e.g., "1.0.0" vs "1.0.1")
bool _isNewerVersion(String current, String latest) {
  try {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      final latestPart = i < latestParts.length ? latestParts[i] : 0;

      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }

    return false; // Versions are equal
  } catch (e) {
    debugPrint('Error comparing versions: $e');
    return false;
  }
}

class BackgroundUpdateService {
  static const String _updateCheckTaskName = 'updateCheckTask';

  /// Initialize and schedule background update checks
  static Future<void> initialize() async {
    try {
      // Initialize Workmanager
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );

      // Register periodic task to check for updates every 6 hours
      await Workmanager().registerPeriodicTask(
        _updateCheckTaskName,
        _updateCheckTaskName,
        frequency: const Duration(hours: 6),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 15),
        initialDelay: const Duration(minutes: 5), // First check after 5 minutes
      );

      debugPrint('Background update service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing background update service: $e');
    }
  }

  /// Cancel all background tasks
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
    debugPrint('All background tasks cancelled');
  }

  /// Cancel specific update check task
  static Future<void> cancelUpdateCheck() async {
    await Workmanager().cancelByUniqueName(_updateCheckTaskName);
    debugPrint('Update check task cancelled');
  }
}
