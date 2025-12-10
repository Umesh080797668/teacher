import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:install_plugin/install_plugin.dart';

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
    // Allow overriding the download URL via environment variable
    final envDownload = dotenv.env['UPDATE_DOWNLOAD_URL'];

    return UpdateInfo(
      version: json['version'] as String,
      downloadUrl: envDownload ?? (json['downloadUrl'] as String),
      releaseNotes: json['releaseNotes'] as String? ?? '',
      isForced: json['isForced'] as bool? ?? false,
    );
  }
}

class UpdateService {
  static String get _updateCheckUrl => dotenv.env['UPDATE_CHECK_URL'] ?? 'https://raw.githubusercontent.com/Umesh080797668/teacherssssss/main/updates.json';
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
  }

  /// Check if there's a new version available
  Future<UpdateInfo?> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Update the URL below with your actual JSON file URL from MEGA or GitHub
      // For MEGA, you'll need to create a public link
      final response = await _dio.get(_updateCheckUrl);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final latestVersion = data['version'] as String;

        // Save last check time
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          _lastUpdateCheckKey,
          DateTime.now().millisecondsSinceEpoch,
        );
        await prefs.setString(_latestVersionKey, latestVersion);

        // Compare versions
        if (_isNewerVersion(currentVersion, latestVersion)) {
          final updateInfo = UpdateInfo.fromJson(data);
          await prefs.setBool(_updateAvailableKey, true);
          
          // Show notification for new update
          await _showUpdateNotification(updateInfo);
          
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
      // Get download directory
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        throw Exception('Could not access storage');
      }

      final savePath = '${dir.path}/teacher_attendance_update.apk';

      // Delete old APK if exists
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Download the APK
      await _dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            final progress = received / total;
            onProgress(progress);
          }
        },
      );

      // Install the APK
      if (Platform.isAndroid) {
        await InstallPlugin.install(savePath);
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error downloading/installing update: $e');
      return false;
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

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

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
}
