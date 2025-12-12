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
      // Return true to prevent WorkManager from showing error notifications
      // Errors will be logged but won't notify the user
      return Future.value(true);
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

    // Fetch update info from GitHub with timeout
    final dio = Dio();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final updateUrl = 'https://raw.githubusercontent.com/Umesh080797668/teacher/main/update.json?t=$timestamp';
    
    debugPrint('Background check - Fetching from: $updateUrl');
    
    final response = await dio.get(
      updateUrl,
      options: Options(
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final latestVersion = data['version'] as String;
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

        // Show notification only if updates are available
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
    // Silently fail - don't show error notifications to user
    // Just log the error for debugging
    debugPrint('Background update check failed (will retry later): $e');
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
      // Skip initialization on web platform as workmanager is not supported
      if (kIsWeb) {
        debugPrint('Background update service skipped on web platform');
        return;
      }

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
    if (kIsWeb) {
      debugPrint('Background tasks not supported on web');
      return;
    }
    await Workmanager().cancelAll();
    debugPrint('All background tasks cancelled');
  }

  /// Cancel specific update check task
  static Future<void> cancelUpdateCheck() async {
    if (kIsWeb) {
      debugPrint('Background tasks not supported on web');
      return;
    }
    await Workmanager().cancelByUniqueName(_updateCheckTaskName);
    debugPrint('Update check task cancelled');
  }
}
