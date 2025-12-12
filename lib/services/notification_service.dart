import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _isInitialized = false;
  bool _notificationsEnabled = true;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Request notification permissions for Android 13+
    if (_notificationsEnabled) {
      await _requestPermissions();
    }

    _isInitialized = true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);

    if (enabled) {
      // Initialize notification permissions if enabled
      await _requestPermissions();
    }
  }

  Future<bool> _requestPermissions() async {
    // Request notification permissions for Android 13+ (API level 33+)
    final result = await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    debugPrint('Notification permissions: $result');
    return result ?? true;
  }

  bool get isEnabled => _notificationsEnabled;

  Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    if (!_notificationsEnabled) {
      debugPrint('Notifications disabled - showing in-app notification instead');
      // In-app notification will be handled by the UI layer
      return;
    }

    // Show actual system notification
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'general_channel',
      'General Notifications',
      channelDescription: 'General app notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );

    debugPrint('System notification shown: $title - $body');
  }

  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    int id = 0,
  }) async {
    if (!_notificationsEnabled) {
      debugPrint('Notifications disabled - will not schedule');
      return;
    }

    // Note: For scheduled notifications, you would typically use timezone package
    // This is a placeholder for the scheduling logic
    debugPrint('Scheduled Notification: $title - $body at $scheduledDate');
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
}
