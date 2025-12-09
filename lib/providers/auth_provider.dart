import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isGuest = false;
  String? _userEmail;
  String? _userName;
  String? _teacherId;
  Map<String, dynamic>? _teacherData;
  bool _isLoading = true;

  bool get isLoggedIn => _isLoggedIn;
  bool get isGuest => _isGuest;
  bool get isAuthenticated => _isLoggedIn || _isGuest;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  String? get teacherId => _teacherId;
  Map<String, dynamic>? get teacherData => _teacherData;
  bool get isLoading => _isLoading;

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
      final teacherDataJson = prefs.getString('teacher_data');
      if (teacherDataJson != null) {
        _teacherData = Map<String, dynamic>.from(json.decode(teacherDataJson));
      }
    } catch (e) {
      debugPrint('Error loading auth state: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String name, {String? teacherId, Map<String, dynamic>? teacherData}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setBool('is_guest', false);
    await prefs.setString('user_email', email);
    await prefs.setString('user_name', name);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_logged_in');
    await prefs.remove('is_guest');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.remove('teacher_id');
    await prefs.remove('teacher_data');
    
    _isLoggedIn = false;
    _isGuest = false;
    _userEmail = null;
    _userName = null;
    _teacherId = null;
    _teacherData = null;
    notifyListeners();
  }
}
