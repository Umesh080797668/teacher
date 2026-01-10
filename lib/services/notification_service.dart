import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Enhanced Notification Channels
final AndroidNotificationChannel criticalChannel = AndroidNotificationChannel(
  'critical_channel',
  'Critical Notifications',
  description: 'Important alerts requiring immediate attention',
  importance: Importance.max,
  sound: RawResourceAndroidNotificationSound('critical_alert'),
  enableVibration: true,
  vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
  ledColor: Colors.red,
  enableLights: true,
);

final AndroidNotificationChannel successChannel = AndroidNotificationChannel(
  'success_channel',
  'Success Notifications',
  description: 'Positive updates and confirmations',
  importance: Importance.high,
  sound: RawResourceAndroidNotificationSound('success_chime'),
  enableVibration: true,
  vibrationPattern: Int64List.fromList([0, 200, 100, 200]),
  ledColor: Colors.green,
  enableLights: true,
);

final AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
  'general_channel',
  'General Notifications',
  description: 'General app notifications and updates',
  importance: Importance.defaultImportance,
  sound: RawResourceAndroidNotificationSound('notification_default'),
  enableVibration: true,
  vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
  ledColor: Colors.blue,
  enableLights: true,
);

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
  debugPrint('Message data: ${message.data}');
  debugPrint('Message notification: ${message.notification?.title}');
  
  // Display local notification for background message
  final notification = message.notification;
  if (notification != null) {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    // Use smart notification details for background messages
    final data = message.data;
    final type = data['type'] as String? ?? 'general';
    final androidDetails = _getNotificationDetailsForType(type);
    
    final notificationDetails = NotificationDetails(android: androidDetails);
    
    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title ?? 'Notification',
      notification.body ?? '',
      notificationDetails,
      payload: json.encode(message.data),
    );
  }
}

/// Get notification details for background handler
AndroidNotificationDetails _getNotificationDetailsForType(String type) {
  switch (type) {
    case 'subscription_approved':
    case 'subscription_activated':
    case 'free_subscription_granted':
      return AndroidNotificationDetails(
        successChannel.id,
        successChannel.name,
        channelDescription: successChannel.description,
        importance: successChannel.importance,
        color: Colors.green,
        colorized: true,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: const BigTextStyleInformation(''),
      );

    case 'restriction':
    case 'teacher_restricted':
    case 'student_restricted':
      return AndroidNotificationDetails(
        criticalChannel.id,
        criticalChannel.name,
        channelDescription: criticalChannel.description,
        importance: criticalChannel.importance,
        color: Colors.red,
        colorized: true,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: const BigTextStyleInformation(''),
        actions: [
          const AndroidNotificationAction('view_details', 'View Details'),
          const AndroidNotificationAction('dismiss', 'Dismiss'),
        ],
      );

    default:
      return AndroidNotificationDetails(
        generalChannel.id,
        generalChannel.name,
        channelDescription: generalChannel.description,
        importance: generalChannel.importance,
        color: Colors.blue,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: const BigTextStyleInformation(''),
      );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _notificationsEnabled = true;
  String? _fcmToken;
  
  // Navigation key to handle navigation from notifications
  static GlobalKey<NavigatorState>? navigatorKey;

  String? get fcmToken => _fcmToken;
  
  /// Set the navigator key for navigation from notifications
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
  }

  /// Initialize Firebase Cloud Messaging and Local Notifications
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load notification preferences
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

      // Initialize local notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse: _onBackgroundAction,
      );

      // Create notification channels
      await _createNotificationChannels();

      // Request notification permissions
      if (_notificationsEnabled) {
        await _requestPermissions();
      }

      // Set up Firebase Cloud Messaging
      await _setupFirebaseMessaging();

      _isInitialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(criticalChannel);
      await androidPlugin.createNotificationChannel(successChannel);
      await androidPlugin.createNotificationChannel(generalChannel);
      debugPrint('Notification channels created successfully');
    }
  }

  /// Handle background notification actions
  @pragma('vm:entry-point')
  static void _onBackgroundAction(NotificationResponse response) async {
    debugPrint('Background action received: ${response.actionId}');
    
    switch (response.actionId) {
      case 'view_details':
        // Handle view details action
        debugPrint('View details action triggered');
        break;
      case 'dismiss':
        // Handle dismiss action
        debugPrint('Dismiss action triggered');
        break;
      default:
        debugPrint('Unknown action: ${response.actionId}');
    }
  }

  /// Get notification details based on type
  AndroidNotificationDetails getNotificationDetailsForType(String type) {
    switch (type) {
      case 'subscription_approved':
      case 'subscription_activated':
      case 'free_subscription_granted':
        return getSuccessNotificationDetails();

      case 'restriction':
      case 'teacher_restricted':
      case 'student_restricted':
        return getCriticalNotificationDetails();

      case 'payment_proof':
      case 'problem_report':
      case 'feature_request':
      case 'class_created':
      case 'attendance_marked':
        return getGeneralNotificationDetails();

      default:
        return getGeneralNotificationDetails();
    }
  }

  /// Critical notifications (red theme)
  AndroidNotificationDetails getCriticalNotificationDetails() {
    return AndroidNotificationDetails(
      criticalChannel.id,
      criticalChannel.name,
      channelDescription: criticalChannel.description,
      importance: criticalChannel.importance,
      color: Colors.red,
      colorized: true,
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: const BigTextStyleInformation(''),
      actions: [
        const AndroidNotificationAction('view_details', 'View Details'),
        const AndroidNotificationAction('dismiss', 'Dismiss'),
      ],
    );
  }

  /// Success notifications (green theme)
  AndroidNotificationDetails getSuccessNotificationDetails() {
    return AndroidNotificationDetails(
      successChannel.id,
      successChannel.name,
      channelDescription: successChannel.description,
      importance: successChannel.importance,
      color: Colors.green,
      colorized: true,
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: const BigTextStyleInformation(''),
    );
  }

  /// General notifications (blue theme)
  AndroidNotificationDetails getGeneralNotificationDetails() {
    return AndroidNotificationDetails(
      generalChannel.id,
      generalChannel.name,
      channelDescription: generalChannel.description,
      importance: generalChannel.importance,
      color: Colors.blue,
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: const BigTextStyleInformation(''),
    );
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      // Request FCM permissions
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('FCM Permission status: ${settings.authorizationStatus}');

      // Request Android 13+ notification permissions
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }
  }

  /// Set up Firebase Cloud Messaging
  Future<void> _setupFirebaseMessaging() async {
    try {
      // Register background message handler FIRST - must be called before other Firebase setup
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Get FCM token
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('FCM Token: $_fcmToken');
      
      // Send token to server
      if (_fcmToken != null) {
        await _sendTokenToServer(_fcmToken!);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('FCM Token refreshed: $newToken');
        // Send updated token to server if needed
        _sendTokenToServer(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Handle initial message if app was launched from notification
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
      
      debugPrint('Firebase Cloud Messaging setup complete');
    } catch (e) {
      debugPrint('Error setting up Firebase Messaging: $e');
    }
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Foreground message received: ${message.messageId}');
    debugPrint('Message data: ${message.data}');
    
    final notification = message.notification;
    final data = message.data;

    // Handle restriction messages immediately (critical)
    if (data['type'] == 'restriction') {
      debugPrint('Restriction notification received: ${data['action']}');
      // This will be handled by AdminChangesProvider polling
      // But we trigger immediate check for faster response
      if (data['action'] == 'restricted' && data['isRestricted'] == 'true') {
        // Force immediate logout and show restriction screen
        // This will be caught by the next polling cycle or auth check
        debugPrint('Teacher restricted - forcing status check');
      }
    }

    // Show notification with smart channel selection
    if (_notificationsEnabled && notification != null) {
      final type = data['type'] as String? ?? 'general';
      final androidDetails = getNotificationDetailsForType(type);

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        notification.title ?? 'Notification',
        notification.body ?? '',
        NotificationDetails(android: androidDetails),
        payload: json.encode(data),
      );
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.messageId}');
    debugPrint('Data: ${message.data}');
    
    // Navigate to appropriate screen based on notification data
    _navigateBasedOnData(message.data);
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
    
    // Parse payload and navigate
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final data = json.decode(response.payload!);
        _navigateBasedOnData(data);
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }
  
  /// Navigate to screen based on notification data
  void _navigateBasedOnData(Map<String, dynamic> data) {
    if (navigatorKey?.currentContext == null) {
      debugPrint('Navigator context not available');
      return;
    }
    
    final type = data['type']?.toString() ?? '';
    final screenRoute = data['screen']?.toString() ?? '';
    
    // Handle specific notification types
    switch (type) {
      case 'subscription':
      case 'payment':
        navigatorKey!.currentState?.pushNamed('/subscription');
        break;
      case 'restriction':
        // Restriction and forced update screens require parameters
        // These will be handled by their respective screens/services
        // Just navigate to home and they will show automatically
        navigatorKey!.currentState?.pushNamed('/home');
        break;
      case 'update':
        // Forced update screen requires parameters
        // Navigate to home and it will be handled by update service
        navigatorKey!.currentState?.pushNamed('/home');
        break;
      case 'admin_change':
      case 'account_change':
        navigatorKey!.currentState?.pushNamed('/home');
        break;
      case 'attendance':
        navigatorKey!.currentState?.pushNamed('/attendance-view');
        break;
      case 'student':
      case 'students':
        navigatorKey!.currentState?.pushNamed('/students');
        break;
      case 'class':
      case 'classes':
        navigatorKey!.currentState?.pushNamed('/classes');
        break;
      case 'report':
      case 'reports':
        navigatorKey!.currentState?.pushNamed('/reports');
        break;
      case 'profile':
      case 'settings':
        navigatorKey!.currentState?.pushNamed('/settings');
        break;
      default:
        // Use screen route if provided, otherwise go to home
        if (screenRoute.isNotEmpty) {
          navigatorKey!.currentState?.pushNamed(screenRoute);
        } else {
          navigatorKey!.currentState?.pushNamed('/home');
        }
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
    String type = 'general',
  }) async {
    final androidDetails = getNotificationDetailsForType(type);
    final notificationDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    debugPrint('Notification shown - ID: $id, Title: $title, Body: $body, Type: $type');
  }

  /// Show custom notification (for backward compatibility)
  Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
    Map<String, dynamic>? data,
  }) async {
    if (!_notificationsEnabled) {
      debugPrint('Notifications disabled');
      return;
    }

    await _showLocalNotification(
      title: title,
      body: body,
      payload: data != null ? json.encode(data) : null,
      id: id,
    );
  }
  
  /// Public method to register FCM token with provided auth token
  Future<void> registerFCMToken(String authToken) async {
    try {
      if (_fcmToken == null) {
        debugPrint('No FCM token available');
        return;
      }
      
      await _sendTokenToServer(_fcmToken!, authToken);
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  /// Send FCM token to server
  Future<void> _sendTokenToServer(String token, [String? authToken]) async {
    try {
      final finalAuthToken = authToken ?? await _getAuthToken();
      if (finalAuthToken == null) {
        debugPrint('No auth token available, skipping FCM token registration');
        return;
      }
      
      final response = await http.post(
        Uri.parse('${_getBaseUrl()}/api/teachers/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $finalAuthToken',
        },
        body: json.encode({
          'fcm_token': token,
          'device_type': 'android',
        }),
      );
      
      if (response.statusCode == 200) {
        debugPrint('FCM token successfully registered with server');
      } else {
        debugPrint('Failed to register FCM token. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error sending FCM token to server: $e');
    }
  }
  
  /// Get authentication token from secure storage
  Future<String?> _getAuthToken() async {
    try {
      const storage = FlutterSecureStorage();
      return await storage.read(key: 'auth_token');
    } catch (e) {
      debugPrint('Error reading auth token: $e');
      return null;
    }
  }
  
  /// Get base URL for API calls
  String _getBaseUrl() {
    return 'https://teacher-eight-chi.vercel.app';
  }

  /// Set notifications enabled/disabled
  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);

    if (enabled) {
      await _requestPermissions();
    }
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }

  /// Show smart notification with enhanced features
  Future<void> showSmartNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    String? imageUrl,
    List<String>? inboxLines,
  }) async {
    if (!_notificationsEnabled) return;

    final type = data['type'] as String? ?? 'general';
    AndroidNotificationDetails androidDetails = getNotificationDetailsForType(type);

    // Add image if provided
    if (imageUrl != null && imageUrl.isNotEmpty) {
      androidDetails = AndroidNotificationDetails(
        androidDetails.channelId,
        androidDetails.channelName,
        channelDescription: androidDetails.channelDescription,
        importance: androidDetails.importance,
        priority: androidDetails.priority,
        color: androidDetails.color,
        colorized: androidDetails.colorized,
        largeIcon: androidDetails.largeIcon,
        styleInformation: BigPictureStyleInformation(
          FilePathAndroidBitmap(imageUrl),
          contentTitle: title,
          summaryText: body,
        ),
      );
    }

    // Add inbox style if multiple lines provided
    if (inboxLines != null && inboxLines.isNotEmpty) {
      androidDetails = AndroidNotificationDetails(
        androidDetails.channelId,
        androidDetails.channelName,
        channelDescription: androidDetails.channelDescription,
        importance: androidDetails.importance,
        priority: androidDetails.priority,
        color: androidDetails.color,
        colorized: androidDetails.colorized,
        largeIcon: androidDetails.largeIcon,
        styleInformation: InboxStyleInformation(
          inboxLines,
          contentTitle: title,
          summaryText: '${inboxLines.length} new items',
        ),
      );
    }

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: json.encode(data),
    );
  }

  /// Schedule notification (for future use)
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

    debugPrint('Scheduled Notification: $title - $body at $scheduledDate');
    // TODO: Implement with timezone package if needed
  }

  bool get isEnabled => _notificationsEnabled;
}
