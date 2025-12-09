import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _isInitialized = false;
  bool _notificationsEnabled = true;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
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
    // In a real app, you would request notification permissions here
    // For now, we'll just return true
    debugPrint('Notification permissions requested');
    return true;
  }

  bool get isEnabled => _notificationsEnabled;

  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    if (!_notificationsEnabled) return;

    // In a real app, you would show an actual notification here
    debugPrint('Notification: $title - $body');
  }

  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_notificationsEnabled) return;

    // In a real app, you would schedule a notification here
    debugPrint('Scheduled Notification: $title - $body at $scheduledDate');
  }
}
