import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

/// Unified polling service for all admin changes (restrictions, subscriptions, status changes, etc.)
/// Works in real-time to sync changes from admin app to student/teacher apps
class AdminChangesPollingService {
  static final AdminChangesPollingService _instance = AdminChangesPollingService._internal();
  factory AdminChangesPollingService() => _instance;
  AdminChangesPollingService._internal();

  final String baseUrl = ApiService.baseUrl;
  Timer? _pollTimer;
  BuildContext? _context;
  String? _userId;
  String? _userType; // 'student' or 'teacher'
  bool _isPolling = false;
  
  // Callbacks for different types of changes
  Function(Map<String, dynamic>)? _onRestrictionChanged;
  Function(Map<String, dynamic>)? _onSubscriptionChanged;
  Function(Map<String, dynamic>)? _onStatusChanged;
  Function(Map<String, dynamic>)? _onClassesChanged;
  Function(String)? _onCriticalChangeDetected;

  // Last known state for comparison
  Map<String, dynamic> _lastKnownState = {};
  
  // Poll interval in seconds
  int _pollIntervalSeconds = 5;

  /// Start polling for admin changes
  void startPolling({
    required BuildContext context,
    required String userId,
    required String userType,
    int pollIntervalSeconds = 5,
    Function(Map<String, dynamic>)? onRestrictionChanged,
    Function(Map<String, dynamic>)? onSubscriptionChanged,
    Function(Map<String, dynamic>)? onStatusChanged,
    Function(Map<String, dynamic>)? onClassesChanged,
    Function(String)? onCriticalChangeDetected,
  }) {
    _context = context;
    _userId = userId;
    _userType = userType;
    _pollIntervalSeconds = pollIntervalSeconds;
    _isPolling = true;
    
    // Register callbacks
    _onRestrictionChanged = onRestrictionChanged;
    _onSubscriptionChanged = onSubscriptionChanged;
    _onStatusChanged = onStatusChanged;
    _onClassesChanged = onClassesChanged;
    _onCriticalChangeDetected = onCriticalChangeDetected;

    // Check immediately
    _checkAdminChanges();

    // Then check at specified interval
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: _pollIntervalSeconds), (timer) {
      if (_isPolling) {
        _checkAdminChanges();
      }
    });

    print('AdminChangesPollingService: Started polling for $userType: $userId with interval ${_pollIntervalSeconds}s');
  }

  /// Stop polling
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isPolling = false;
    _lastKnownState.clear();
    print('AdminChangesPollingService: Polling stopped');
  }

  /// Check for admin changes
  Future<void> _checkAdminChanges() async {
    if (_userId == null || _userType == null) {
      return;
    }

    try {
      final token = await ApiService.getToken();
      if (token == null) return;

      final currentState = await _fetchCurrentState(token);
      _processStateChanges(currentState);
      _lastKnownState = currentState;
    } catch (e) {
      print('AdminChangesPollingService: Error checking admin changes: $e');
    }
  }

  /// Fetch current state from backend
  Future<Map<String, dynamic>> _fetchCurrentState(String token) async {
    if (_userType == 'student') {
      return await _fetchStudentState(token);
    } else {
      return await _fetchTeacherState(token);
    }
  }

  /// Fetch student state
  Future<Map<String, dynamic>> _fetchStudentState(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/students/$_userId/admin-changes'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 404) {
      // Fallback: fetch individual status checks
      return await _fetchStudentStateFallback(token);
    } else {
      throw Exception('Failed to fetch student state: ${response.statusCode}');
    }
  }

  /// Fetch teacher state
  Future<Map<String, dynamic>> _fetchTeacherState(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/teachers/$_userId/admin-changes'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 404) {
      // Fallback: fetch individual status checks
      return await _fetchTeacherStateFallback(token);
    } else {
      throw Exception('Failed to fetch teacher state: ${response.statusCode}');
    }
  }

  /// Fallback method to fetch student state using individual API calls
  Future<Map<String, dynamic>> _fetchStudentStateFallback(String token) async {
    try {
      final state = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'restrictions': await _checkStudentRestriction(token),
        'subscription': await _checkStudentSubscription(token),
      };
      return state;
    } catch (e) {
      print('AdminChangesPollingService: Error in fallback fetch: $e');
      return {
        'timestamp': DateTime.now().toIso8601String(),
        'error': true,
      };
    }
  }

  /// Fallback method to fetch teacher state using individual API calls
  Future<Map<String, dynamic>> _fetchTeacherStateFallback(String token) async {
    try {
      final state = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'restrictions': await _checkTeacherRestriction(token),
        'subscription': await _checkTeacherSubscription(token),
        'status': await _checkTeacherStatus(token),
      };
      return state;
    } catch (e) {
      print('AdminChangesPollingService: Error in fallback fetch: $e');
      return {
        'timestamp': DateTime.now().toIso8601String(),
        'error': true,
      };
    }
  }

  /// Check student restriction status
  Future<Map<String, dynamic>> _checkStudentRestriction(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/students/$_userId/restriction-status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'isRestricted': false};
    } catch (e) {
      print('AdminChangesPollingService: Error checking student restriction: $e');
      return {};
    }
  }

  /// Check teacher restriction status
  Future<Map<String, dynamic>> _checkTeacherRestriction(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/teachers/$_userId/restriction-status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'isRestricted': false};
    } catch (e) {
      print('AdminChangesPollingService: Error checking teacher restriction: $e');
      return {};
    }
  }

  /// Check student subscription status
  Future<Map<String, dynamic>> _checkStudentSubscription(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/students/$_userId/subscription-status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'status': 'active'};
    } catch (e) {
      print('AdminChangesPollingService: Error checking student subscription: $e');
      return {};
    }
  }

  /// Check teacher subscription status
  Future<Map<String, dynamic>> _checkTeacherSubscription(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/teachers/$_userId/subscription-status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'status': 'active'};
    } catch (e) {
      print('AdminChangesPollingService: Error checking teacher subscription: $e');
      return {};
    }
  }

  /// Check teacher status
  Future<Map<String, dynamic>> _checkTeacherStatus(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/teachers/$_userId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'status': 'active'};
    } catch (e) {
      print('AdminChangesPollingService: Error checking teacher status: $e');
      return {};
    }
  }

  /// Process state changes and trigger callbacks
  void _processStateChanges(Map<String, dynamic> currentState) {
    // If this is the first check, just store the state
    if (_lastKnownState.isEmpty) {
      return;
    }

    // Check for restriction changes
    if (currentState.containsKey('restrictions') &&
        _lastKnownState.containsKey('restrictions')) {
      final lastRestriction = _lastKnownState['restrictions'] as Map;
      final currentRestriction = currentState['restrictions'] as Map;

      if (lastRestriction['isRestricted'] != currentRestriction['isRestricted']) {
        _onRestrictionChanged?.call(currentRestriction as Map<String, dynamic>);
        
        // Trigger critical change if restricted
        if (currentRestriction['isRestricted'] == true) {
          _onCriticalChangeDetected?.call(
            'RESTRICTED: ${currentRestriction['restrictionReason'] ?? 'No reason provided'}',
          );
        }
      }
    }

    // Check for subscription changes
    if (currentState.containsKey('subscription') &&
        _lastKnownState.containsKey('subscription')) {
      final lastSub = _lastKnownState['subscription'] as Map;
      final currentSub = currentState['subscription'] as Map;

      if (lastSub['status'] != currentSub['status'] ||
          lastSub['expiryDate'] != currentSub['expiryDate']) {
        _onSubscriptionChanged?.call(currentSub as Map<String, dynamic>);
      }
    }

    // Check for status changes
    if (currentState.containsKey('status') &&
        _lastKnownState.containsKey('status')) {
      final lastStatus = _lastKnownState['status'] as Map;
      final currentStatus = currentState['status'] as Map;

      if (lastStatus['status'] != currentStatus['status']) {
        _onStatusChanged?.call(currentStatus as Map<String, dynamic>);
      }
    }

    // Check for classes/assignments changes
    if (currentState.containsKey('classes') &&
        _lastKnownState.containsKey('classes')) {
      final lastClasses = _lastKnownState['classes'];
      final currentClasses = currentState['classes'];

      if (lastClasses.toString() != currentClasses.toString()) {
        _onClassesChanged?.call(currentClasses as Map<String, dynamic>);
      }
    }
  }

  /// Resume polling after app comes back from background
  void resumePolling() {
    if (_isPolling && _userId != null && _userType != null) {
      _checkAdminChanges();
    }
  }

  /// Pause polling when app goes to background
  void pausePolling() {
    _pollTimer?.cancel();
  }

  /// Get current polling status
  bool get isPolling => _isPolling;

  /// Get user type
  String? get userType => _userType;

  /// Get user ID
  String? get userId => _userId;
}
