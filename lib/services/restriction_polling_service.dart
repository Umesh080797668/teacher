import 'dart:async';
import 'package:flutter/material.dart';
import '../services/restriction_service.dart';
import '../screens/restriction_screen.dart';

class RestrictionPollingService {
  static final RestrictionPollingService _instance = RestrictionPollingService._internal();
  factory RestrictionPollingService() => _instance;
  RestrictionPollingService._internal();

  final RestrictionService _restrictionService = RestrictionService();
  Timer? _pollTimer;
  BuildContext? _context;
  String? _userId;
  String? _userType; // 'teacher' or 'student'
  bool _isPolling = false;
  bool _isRestrictionScreenShown = false;

  /// Start polling for restriction status
  void startPolling({
    required BuildContext context,
    required String userId,
    required String userType,
  }) {
    _context = context;
    _userId = userId;
    _userType = userType;
    _isPolling = true;

    // Check immediately
    _checkRestrictionStatus();

    // Then check every 5 seconds
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isPolling) {
        _checkRestrictionStatus();
      }
    });

    print('Restriction polling started for $userType: $userId');
  }

  /// Stop polling
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isPolling = false;
    _isRestrictionScreenShown = false;
    print('Restriction polling stopped');
  }

  /// Check restriction status
  Future<void> _checkRestrictionStatus() async {
    if (_context == null || _userId == null || _userType == null) {
      return;
    }

    try {
      Map<String, dynamic> status;

      if (_userType == 'teacher') {
        status = await _restrictionService.checkTeacherRestrictionStatus(_userId!);
      } else {
        status = await _restrictionService.checkStudentRestrictionStatus(_userId!);
      }

      // If restricted and restriction screen not already shown
      if (status['isRestricted'] == true && !_isRestrictionScreenShown) {
        _showRestrictionScreen(status);
      }
    } catch (e) {
      print('Error checking restriction status: $e');
    }
  }

  /// Show restriction screen
  void _showRestrictionScreen(Map<String, dynamic> status) {
    if (_context == null || _userId == null) return;
    
    _isRestrictionScreenShown = true;

    // Stop polling temporarily as the restriction screen will handle it
    _pollTimer?.cancel();

    Navigator.of(_context!).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => RestrictionScreen(
          teacherId: _userId!,
          initialReason: status['restrictionReason'],
        ),
      ),
      (route) => false, // Remove all previous routes
    );

    print('Navigating to restriction screen');
  }

  /// Resume polling after app comes back from background
  void resumePolling() {
    if (_isPolling && _userId != null && _userType != null && _context != null) {
      _checkRestrictionStatus();
    }
  }

  /// Pause polling when app goes to background
  void pausePolling() {
    _pollTimer?.cancel();
  }

  bool get isPolling => _isPolling;
}
