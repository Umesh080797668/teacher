import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:teacher_attendance/services/api_service.dart';
import 'package:teacher_attendance/services/notification_service.dart';

class UserAccount {
  final String email;
  final String name;
  final String? teacherId;
  final Map<String, dynamic>? teacherData;
  final DateTime lastLogin;

  UserAccount({
    required this.email,
    required this.name,
    this.teacherId,
    this.teacherData,
    DateTime? lastLogin,
  }) : lastLogin = lastLogin ?? DateTime.now();

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      email: json['email'],
      name: json['name'],
      teacherId: json['teacherId'],
      teacherData: json['teacherData'],
      lastLogin: DateTime.parse(json['lastLogin']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'teacherId': teacherId,
      'teacherData': teacherData,
      'lastLogin': lastLogin.toIso8601String(),
    };
  }

  UserAccount copyWith({
    String? email,
    String? name,
    String? teacherId,
    Map<String, dynamic>? teacherData,
    DateTime? lastLogin,
  }) {
    return UserAccount(
      email: email ?? this.email,
      name: name ?? this.name,
      teacherId: teacherId ?? this.teacherId,
      teacherData: teacherData ?? this.teacherData,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isGuest = false;
  String? _userEmail;
  String? _userName;
  String? _teacherId;
  Map<String, dynamic>? _teacherData;
  bool _isActivated = false; // New field for account activation
  bool _isLoading = true;
  bool _accountInactive = false; // New field for account inactive status
  bool _subscriptionExpired = false; // New field for subscription expiry
  bool _subscriptionExpiringSoon = false; // New field for subscription expiring soon
  DateTime? _lastSubscriptionWarningDate; // Track when warning was last shown
  bool _isWarningScreenShown = false; // Track if warning screen is currently shown
  bool _hasCompletedSubscriptionSetup = false; // Track if user has completed subscription setup
  bool _hasSelectedSubscriptionPlan = false; // Track if user has selected a subscription plan
  String? _selectedSubscriptionPlan; // Track the selected subscription plan
  bool _wasActivationNotified = false; // Track if activation notification was shown
  List<UserAccount> _accountHistory = [];
  Timer? _statusCheckTimer;

  bool get isLoggedIn => _isLoggedIn;
  bool get isGuest => _isGuest;
  bool get isAuthenticated => _isLoggedIn || _isGuest;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  String? get teacherId => _teacherId;
  Map<String, dynamic>? get teacherData => _teacherData;
  bool get isActivated => _isActivated; // Getter for activation status
  bool get accountInactive => _accountInactive; // Getter for account inactive status
  bool get subscriptionExpired => _subscriptionExpired; // Getter for subscription expiry
  bool get subscriptionExpiringSoon => _subscriptionExpiringSoon; // Getter for subscription expiring soon
  bool get shouldShowSubscriptionWarning => _subscriptionExpiringSoon && 
    (_lastSubscriptionWarningDate == null || 
     !_isSameDay(_lastSubscriptionWarningDate!, DateTime.now())) &&
    !_isWarningScreenShown;
  bool get isWarningScreenShown => _isWarningScreenShown;
  bool get isLoading => _isLoading;
  bool get hasCompletedSubscriptionSetup => _hasCompletedSubscriptionSetup;
  bool get hasSelectedSubscriptionPlan => _hasSelectedSubscriptionPlan;
  String? get selectedSubscriptionPlan => _selectedSubscriptionPlan;
  List<UserAccount> get accountHistory => _accountHistory;

  AuthProvider() {
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      _isGuest = prefs.getBool('is_guest') ?? false;
      _userEmail = prefs.getString('user_email');
      _userName = prefs.getString('user_name');
      _teacherId = prefs.getString('teacher_id');
      _isActivated = prefs.getBool('is_activated') ?? false; // Load activation status
      _accountInactive = prefs.getBool('account_inactive') ?? false; // Load account inactive status
      _subscriptionExpired = prefs.getBool('subscription_expired') ?? false; // Load subscription expiry
      _subscriptionExpiringSoon = prefs.getBool('subscription_expiring_soon') ?? false; // Load subscription expiring soon
      final lastWarningDateStr = prefs.getString('last_subscription_warning_date');
      if (lastWarningDateStr != null) {
        _lastSubscriptionWarningDate = DateTime.parse(lastWarningDateStr);
      }
      _hasCompletedSubscriptionSetup = prefs.getBool('has_completed_subscription_setup') ?? false; // Load subscription setup completion
      _hasSelectedSubscriptionPlan = prefs.getBool('has_selected_subscription_plan') ?? false; // Load subscription plan selection
      _selectedSubscriptionPlan = prefs.getString('selected_subscription_plan'); // Load selected subscription plan
      _wasActivationNotified = prefs.getBool('was_activation_notified') ?? false; // Load activation notification status
      final teacherDataJson = prefs.getString('teacher_data');
      if (teacherDataJson != null) {
        _teacherData = Map<String, dynamic>.from(json.decode(teacherDataJson));
      }

      // Load account history
      final accountHistoryJson = prefs.getString('account_history');
      if (accountHistoryJson != null) {
        final List<dynamic> historyList = json.decode(accountHistoryJson);
        _accountHistory = historyList.map((item) => UserAccount.fromJson(item)).toList();
      }

      // Start status checking if user is logged in
      if (_isLoggedIn && _userEmail != null) {
        _startStatusChecking();
      }
    } catch (e) {
      debugPrint('Error loading auth state: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String name, {String? teacherId, Map<String, dynamic>? teacherData, bool? isActivated}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setBool('is_guest', false);
    await prefs.setString('user_email', email);
    await prefs.setString('user_name', name);
    
    // Determine activation status from teacherData or parameter
    bool activationStatus = isActivated ?? false;
    if (teacherData != null && teacherData['status'] != null) {
      activationStatus = teacherData['status'] == 'active';
    }
    
    await prefs.setBool('is_activated', activationStatus);
    
    if (teacherId != null) {
      await prefs.setString('teacher_id', teacherId);
    }
    if (teacherData != null) {
      await prefs.setString('teacher_data', json.encode(teacherData));
    }

    _isLoggedIn = true;
    _isGuest = false;
    _userEmail = email;
    _userName = name;
    _teacherId = teacherId;
    _teacherData = teacherData;
    _isActivated = activationStatus;

    // Add to account history
    final newAccount = UserAccount(
      email: email,
      name: name,
      teacherId: teacherId,
      teacherData: teacherData,
    );

    // Remove existing account with same email if exists
    _accountHistory.removeWhere((account) => account.email == email);
    // Add to beginning of list
    _accountHistory.insert(0, newAccount);
    // Keep only last 5 accounts
    if (_accountHistory.length > 5) {
      _accountHistory = _accountHistory.sublist(0, 5);
    }

    // Save account history
    await prefs.setString('account_history', json.encode(_accountHistory.map((a) => a.toJson()).toList()));

    // Start status checking
    _startStatusChecking();

    notifyListeners();
  }

  Future<void> loginAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.setBool('is_guest', true);
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    
    _isLoggedIn = false;
    _isGuest = true;
    _userEmail = null;
    _userName = 'Guest';
    notifyListeners();
  }

  Future<void> logout() async {
    // Stop status checking
    _stopStatusChecking();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_logged_in');
    await prefs.remove('is_guest');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.remove('teacher_id');
    await prefs.remove('teacher_data');
    await prefs.remove('is_activated'); // Remove activation status
    await prefs.remove('account_inactive'); // Remove account inactive status
    await prefs.remove('subscription_expired'); // Remove subscription expiry
    await prefs.remove('subscription_expiring_soon'); // Remove subscription expiring soon
    await prefs.remove('last_subscription_warning_date'); // Remove last warning date
    await prefs.remove('has_completed_subscription_setup'); // Remove subscription setup completion
    await prefs.remove('has_selected_subscription_plan'); // Remove subscription plan selection
    await prefs.remove('selected_subscription_plan'); // Remove selected subscription plan
    await prefs.remove('was_activation_notified'); // Remove activation notification status
    
    _isLoggedIn = false;
    _isGuest = false;
    _userEmail = null;
    _userName = null;
    _teacherId = null;
    _teacherData = null;
    _isActivated = false; // Reset activation status
    _accountInactive = false; // Reset account inactive status
    _subscriptionExpired = false; // Reset subscription expiry
    _subscriptionExpiringSoon = false; // Reset subscription expiring soon
    _lastSubscriptionWarningDate = null; // Reset last warning date
    _isWarningScreenShown = false; // Reset warning screen shown
    _hasCompletedSubscriptionSetup = false; // Reset subscription setup completion
    _hasSelectedSubscriptionPlan = false; // Reset subscription plan selection
    _selectedSubscriptionPlan = null; // Reset selected subscription plan
    _wasActivationNotified = false; // Reset activation notification status
    notifyListeners();
  }

  Future<void> updateActivationStatus(bool isActivated) async {
    _isActivated = isActivated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_activated', isActivated);
    notifyListeners();
  }

  Future<void> updateAccountInactiveStatus(bool isInactive) async {
    _accountInactive = isInactive;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('account_inactive', isInactive);
    notifyListeners();
  }

  Future<void> updateSubscriptionExpiredStatus(bool isExpired) async {
    _subscriptionExpired = isExpired;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('subscription_expired', isExpired);
    notifyListeners();
  }

  Future<void> markSubscriptionWarningShown() async {
    _lastSubscriptionWarningDate = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_subscription_warning_date', _lastSubscriptionWarningDate!.toIso8601String());
  }

  void setWarningScreenShown(bool shown) {
    _isWarningScreenShown = shown;
    notifyListeners();
  }

  Future<void> markSubscriptionSetupCompleted() async {
    _hasCompletedSubscriptionSetup = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_subscription_setup', true);
    notifyListeners();
  }

  Future<void> setSelectedSubscriptionPlan(String plan) async {
    _hasSelectedSubscriptionPlan = true;
    _selectedSubscriptionPlan = plan;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_selected_subscription_plan', true);
    await prefs.setString('selected_subscription_plan', plan);
    notifyListeners();
  }

  Future<void> clearSelectedSubscriptionPlan() async {
    _hasSelectedSubscriptionPlan = false;
    _selectedSubscriptionPlan = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('has_selected_subscription_plan');
    await prefs.remove('selected_subscription_plan');
    notifyListeners();
  }

  Future<void> markActivationNotified() async {
    _wasActivationNotified = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('was_activation_notified', true);
  }

  Future<void> switchToAccount(UserAccount account) async {
    await login(
      account.email,
      account.name,
      teacherId: account.teacherId,
      teacherData: account.teacherData,
    );
  }

  Future<void> removeAccount(String email) async {
    _accountHistory.removeWhere((account) => account.email == email);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('account_history', json.encode(_accountHistory.map((a) => a.toJson()).toList()));
    notifyListeners();
  }

  void _startStatusChecking() {
    // Stop existing timer if any
    _stopStatusChecking();
    
    // Check status every 5 minutes
    _statusCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      await _checkTeacherStatus();
    });
  }

  void _stopStatusChecking() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;
  }

  Future<void> _checkTeacherStatus() async {
    if (_userEmail == null || !_isLoggedIn) {
      return;
    }

    try {
      final response = await ApiService.checkTeacherStatus(_userEmail!);
      final isActive = response['isActive'] as bool;
      final subscriptionExpired = response['subscriptionExpired'] as bool? ?? false;
      final subscriptionExpiringSoon = response['subscriptionExpiringSoon'] as bool? ?? false;
      final teacherStatus = response['status'] as String? ?? 'inactive';

      // Update activation status based on teacher status
      final isActivated = teacherStatus == 'active';
      if (_isActivated != isActivated) {
        final wasInactive = !_isActivated;
        _isActivated = isActivated;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_activated', _isActivated);
        
        // Show notification if account just got activated and we haven't notified yet
        if (isActivated && wasInactive && !_wasActivationNotified) {
          try {
            final notificationService = NotificationService();
            await notificationService.initialize();
            await notificationService.showNotification(
              title: 'Account Activated!',
              body: 'Your account has been successfully activated. You can now use all features.',
            );
            await markActivationNotified();
          } catch (e) {
            debugPrint('Failed to show activation notification: $e');
          }
        }
      }

      // Update subscription expired status
      if (_subscriptionExpired != subscriptionExpired) {
        _subscriptionExpired = subscriptionExpired;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('subscription_expired', _subscriptionExpired);
      }

      // Update subscription expiring soon status
      if (_subscriptionExpiringSoon != subscriptionExpiringSoon) {
        _subscriptionExpiringSoon = subscriptionExpiringSoon;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('subscription_expiring_soon', _subscriptionExpiringSoon);
      }

      if (!isActive && !_accountInactive) {
        debugPrint('Teacher account became inactive, logging out...');
        _accountInactive = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('account_inactive', true);
        // Force logout for inactive accounts
        await logout();
        notifyListeners();
      } else if (isActive && _accountInactive) {
        debugPrint('Teacher account became active again');
        _accountInactive = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('account_inactive', false);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking teacher status: $e');
      // Check if teacher not found (account deleted)
      if (e is ApiException && e.statusCode == 404) {
        debugPrint('Teacher account not found, logging out...');
        await logout();
        notifyListeners();
      }
      // Don't change status on other network errors
    }
  }

  Future<void> checkStatusNow() async {
    await _checkTeacherStatus();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  @override
  void dispose() {
    _stopStatusChecking();
    super.dispose();
  }
}