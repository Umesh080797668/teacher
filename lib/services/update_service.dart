import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:install_plugin/install_plugin.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final bool isForced;

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    this.isForced = false,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String,
      downloadUrl: json['downloadUrl'] as String,
      releaseNotes: json['releaseNotes'] as String? ?? '',
      isForced: json['isForced'] as bool? ?? false,
    );
  }
}

class UpdateService {
  // Use raw.githubusercontent.com instead of cdn.jsdelivr.net to avoid CDN caching issues
  static String get _updateCheckUrl =>
      dotenv.env['UPDATE_CHECK_URL'] ??
      'https://raw.githubusercontent.com/Umesh080797668/teacher/main/update.json';
  static const String _lastUpdateCheckKey = 'last_update_check';
  static const String _skippedVersionKey = 'skipped_version';
  static const String _updateAvailableKey = 'update_available';
  static const String _latestVersionKey = 'latest_version';

  final Dio _dio = Dio();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initialize notifications
  Future<void> initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Request notification permissions for Android 13+ (API level 33+)
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Check if there's a new version available
  Future<UpdateInfo?> checkForUpdates({bool showNotification = true}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      debugPrint('Current app version: $currentVersion');
      debugPrint(
          'PackageInfo details: appName=${packageInfo.appName}, packageName=${packageInfo.packageName}, version=${packageInfo.version}, buildNumber=${packageInfo.buildNumber}');

      // Update the URL below with your actual JSON file URL from MEGA or GitHub
      // For MEGA, you'll need to create a public link
      // Add cache-busting headers and timestamp to prevent stale data
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final urlWithTimestamp = '$_updateCheckUrl?t=$timestamp';

      debugPrint('Fetching update info from: $urlWithTimestamp');

      // Don't add custom headers to avoid CORS issues with GitHub raw content
      // Set response type to plain for raw GitHub content
      final response = await _dio.get(
        urlWithTimestamp,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200) {
        // Parse the JSON string response
        final jsonString = response.data as String;
        final data = json.decode(jsonString) as Map<String, dynamic>;
        final latestVersion = data['version'] as String;

        debugPrint('Latest version from server: $latestVersion');
        debugPrint('Full server response: $data');

        // Save last check time
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          _lastUpdateCheckKey,
          DateTime.now().millisecondsSinceEpoch,
        );
        await prefs.setString(_latestVersionKey, latestVersion);

        // Compare versions
        final isNewer = _isNewerVersion(currentVersion, latestVersion);
        debugPrint(
            'Is newer version available: $isNewer (Current: $currentVersion, Latest: $latestVersion)');

        if (isNewer) {
          final updateInfo = UpdateInfo.fromJson(data);
          await prefs.setBool(_updateAvailableKey, true);

          // Show notification for new update only if requested
          if (showNotification) {
            await _showUpdateNotification(updateInfo);
          }

          return updateInfo;
        } else {
          await prefs.setBool(_updateAvailableKey, false);
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
    return null;
  }

  /// Check if update is required (forced after 10 days)
  Future<bool> isUpdateRequired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckTime = prefs.getInt(_lastUpdateCheckKey);
      final updateAvailable = prefs.getBool(_updateAvailableKey) ?? false;

      if (!updateAvailable || lastCheckTime == null) {
        return false;
      }

      final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckTime);
      final daysSinceUpdate = DateTime.now().difference(lastCheck).inDays;

      // Force update after 10 days
      return daysSinceUpdate >= 10;
    } catch (e) {
      debugPrint('Error checking if update is required: $e');
      return false;
    }
  }

  /// Download and install the update
  Future<bool> downloadAndInstallUpdate(
    String downloadUrl, {
    Function(double)? onProgress,
  }) async {
    try {
      // Request install packages permission before downloading
      if (Platform.isAndroid) {
        final status = await Permission.requestInstallPackages.status;
        if (!status.isGranted) {
          final result = await Permission.requestInstallPackages.request();
          if (!result.isGranted) {
            debugPrint('Install packages permission denied');
          }
        }
      }

      debugPrint('Starting download from: $downloadUrl');

      // Get download directory
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        throw Exception('Could not access storage');
      }

      final savePath = '${dir.path}/teacher_attendance_update.apk';
      debugPrint('Save path: $savePath');

      // Delete old APK if exists
      final file = File(savePath);
      if (await file.exists()) {
        debugPrint('Deleting old APK');
        await file.delete();
      }

      // Report initial progress
      if (onProgress != null) {
        onProgress(0.0);
      }

      // Download the APK with better error handling
      await _dio.download(
        downloadUrl,
        savePath,
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status == 200,
          receiveTimeout: const Duration(minutes: 10),
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            debugPrint(
                'Download progress: ${(progress * 100).toStringAsFixed(1)}% ($received / $total bytes)');
            if (onProgress != null) {
              onProgress(progress);
            }
          } else {
            debugPrint('Download progress: $received bytes (total unknown)');
            // For unknown total size, just report that we're downloading
            if (onProgress != null && received > 0) {
              // Use a fake progress that never reaches 100%
              final fakeProgress = 0.5;
              onProgress(fakeProgress);
            }
          }
        },
      );

      debugPrint('Download complete. File size: ${await file.length()} bytes');

      // Ensure progress shows 100% before installation
      if (onProgress != null) {
        onProgress(1.0);
      }

      // Brief delay to show 100% completion
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify file exists and has content
      if (!await file.exists()) {
        throw Exception('Downloaded file does not exist');
      }

      final fileSize = await file.length();
      if (fileSize < 1000000) {
        // Less than 1MB is suspicious for an APK
        debugPrint('Warning: APK file size is only $fileSize bytes');
      }

      // Install the APK
      if (Platform.isAndroid) {
        debugPrint('Starting installation...');
        await InstallPlugin.install(savePath);
        debugPrint('Installation initiated successfully');
        
        // Close the app to allow update to proceed smoothly
        await Future.delayed(const Duration(seconds: 1));
        SystemNavigator.pop();
        
        return true;
      }

      return false;
    } catch (e, stackTrace) {
      debugPrint('Error downloading/installing update: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow; // Rethrow to let caller handle the error
    }
  }

  /// Get cached update info
  Future<Map<String, dynamic>> getCachedUpdateInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();

    return {
      'currentVersion': packageInfo.version,
      'latestVersion': prefs.getString(_latestVersionKey),
      'updateAvailable': prefs.getBool(_updateAvailableKey) ?? false,
      'lastCheckTime': prefs.getInt(_lastUpdateCheckKey),
    };
  }

  /// Mark version as skipped (user chose to skip this version)
  Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skippedVersionKey, version);
  }

  /// Check if version was skipped
  Future<bool> isVersionSkipped(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final skippedVersion = prefs.getString(_skippedVersionKey);
    return skippedVersion == version;
  }

  /// Reset update check (after successful update)
  Future<void> resetUpdateCheck() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_updateAvailableKey);
    await prefs.remove(_skippedVersionKey);
    await prefs.setInt(
      _lastUpdateCheckKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Show notification for available update
  Future<void> _showUpdateNotification(UpdateInfo updateInfo) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'update_channel',
      'App Updates',
      channelDescription: 'Notifications for app updates',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      0,
      'Update Available',
      'Version ${updateInfo.version} is now available. ${updateInfo.isForced ? 'This update is required.' : 'Tap to update.'}',
      notificationDetails,
    );
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

  /// Get days since last update check
  Future<int> getDaysSinceUpdateAvailable() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckTime = prefs.getInt(_lastUpdateCheckKey);

    if (lastCheckTime == null) return 0;

    final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckTime);
    return DateTime.now().difference(lastCheck).inDays;
  }

  /// Check if enough time has passed since last background check (checks every 6 hours)
  Future<bool> shouldCheckForUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckTime = prefs.getInt(_lastUpdateCheckKey);

    if (lastCheckTime == null) return true; // Never checked before

    final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckTime);
    final hoursSinceLastCheck = DateTime.now().difference(lastCheck).inHours;

    // Check every 6 hours
    return hoursSinceLastCheck >= 6;
  }

  /// Perform background update check (called periodically)
  Future<void> performBackgroundUpdateCheck() async {
    try {
      // Only check if enough time has passed
      final shouldCheck = await shouldCheckForUpdates();
      if (!shouldCheck) {
        debugPrint('Skipping update check - too soon since last check');
        return;
      }

      debugPrint('Performing background update check...');

      // Check for updates and show notification if available
      final updateInfo = await checkForUpdates(showNotification: true);

      if (updateInfo != null) {
        debugPrint('Update available: ${updateInfo.version}');
      } else {
        debugPrint('No updates available');
      }
    } catch (e) {
      debugPrint('Error in background update check: $e');
    }
  }

  /// Clear cached update data (useful for testing or troubleshooting)
  Future<void> clearUpdateCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastUpdateCheckKey);
      await prefs.remove(_skippedVersionKey);
      await prefs.remove(_updateAvailableKey);
      await prefs.remove(_latestVersionKey);
      debugPrint('Update cache cleared successfully');
    } catch (e) {
      debugPrint('Error clearing update cache: $e');
    }
  }
}
