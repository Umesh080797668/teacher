import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:teacher_attendance/services/api_service.dart';

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
  bool get isLoading => _isLoading;
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
    
    _isLoggedIn = false;
    _isGuest = false;
    _userEmail = null;
    _userName = null;
    _teacherId = null;
    _teacherData = null;
    _isActivated = false; // Reset activation status
    notifyListeners();
  }

  Future<void> updateActivationStatus(bool isActivated) async {
    _isActivated = isActivated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_activated', isActivated);
    notifyListeners();
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
      
      if (!isActive) {
        debugPrint('Teacher account is inactive, logging out...');
        await logout();
        
        // You might want to show a dialog here, but since this is in a provider,
        // we'll just log out silently. The UI will update accordingly.
      }
    } catch (e) {
      debugPrint('Error checking teacher status: $e');
      // Don't logout on network errors, just log the error
    }
  }

  @override
  void dispose() {
    _stopStatusChecking();
    super.dispose();
  }
}
