import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Comprehensive real-time polling service for the teacher app
/// Polls server for updates at regular intervals to keep data synchronized
class RealTimePollingService {
  static final RealTimePollingService _instance = RealTimePollingService._internal();
  factory RealTimePollingService() => _instance;
  RealTimePollingService._internal();

  // Polling timers
  Timer? _attendanceTimer;
  Timer? _studentsTimer;
  Timer? _classesTimer;
  Timer? _notificationsTimer;
  Timer? _paymentsTimer;
  
  // Connection quality tracking
  int _consecutiveFailures = 0;
  bool _isSlowConnection = false;
  DateTime? _lastSuccessfulRequest;
  
  // Polling intervals (configurable and adaptive)
  Duration attendanceInterval = const Duration(seconds: 10);
  Duration studentsInterval = const Duration(seconds: 15);
  Duration classesInterval = const Duration(seconds: 20);
  Duration notificationsInterval = const Duration(seconds: 5);
  Duration paymentsInterval = const Duration(seconds: 30);
  
  // Base intervals for adaptive polling
  static const Duration _baseAttendanceInterval = Duration(seconds: 10);
  static const Duration _baseStudentsInterval = Duration(seconds: 15);
  static const Duration _baseClassesInterval = Duration(seconds: 20);
  static const Duration _baseNotificationsInterval = Duration(seconds: 5);
  static const Duration _basePaymentsInterval = Duration(seconds: 30);
  
  // Slow connection multiplier
  static const int _slowConnectionMultiplier = 3;
  
  // Last update timestamps
  DateTime? _lastAttendanceUpdate;
  DateTime? _lastStudentsUpdate;
  DateTime? _lastClassesUpdate;
  DateTime? _lastNotificationsUpdate;
  DateTime? _lastPaymentsUpdate;
  
  // Callbacks for data updates
  Function(List<dynamic>)? onAttendanceUpdate;
  Function(List<dynamic>)? onStudentsUpdate;
  Function(List<dynamic>)? onClassesUpdate;
  Function(List<dynamic>)? onNotificationsUpdate;
  Function(Map<String, dynamic>)? onPaymentsUpdate;
  
  // Active polling flags
  bool _isPollingAttendance = false;
  bool _isPollingStudents = false;
  bool _isPollingClasses = false;
  bool _isPollingNotifications = false;
  bool _isPollingPayments = false;
  
  /// Start polling for attendance updates
  void startAttendancePolling({
    String? classId,
    DateTime? date,
    Function(List<dynamic>)? onUpdate,
  }) {
    if (_isPollingAttendance) {
      debugPrint('⚠️ Attendance polling already active');
      return;
    }
    
    _isPollingAttendance = true;
    onAttendanceUpdate = onUpdate;
    
    debugPrint('✓ Starting attendance polling (every ${attendanceInterval.inSeconds}s)');
    
    _attendanceTimer = Timer.periodic(attendanceInterval, (timer) async {
      try {
        final attendance = await ApiService.getAttendance(
          teacherId: null,
        );
        
        _recordRequestSuccess(); // Track successful request
        
        if (onAttendanceUpdate != null) {
          onAttendanceUpdate!(attendance);
          _lastAttendanceUpdate = DateTime.now();
        }
      } catch (e) {
        _recordRequestFailure(); // Track failed request
        debugPrint('❌ Attendance polling error: $e');
      }
    });
    
    // Immediately fetch first update
    _fetchAttendanceUpdate(classId, date);
  }
  
  /// Start polling for students updates
  void startStudentsPolling({
    String? teacherId,
    Function(List<dynamic>)? onUpdate,
  }) {
    if (_isPollingStudents) {
      debugPrint('⚠️ Students polling already active');
      return;
    }
    
    _isPollingStudents = true;
    onStudentsUpdate = onUpdate;
    
    debugPrint('✓ Starting students polling (every ${studentsInterval.inSeconds}s)');
    
    _studentsTimer = Timer.periodic(studentsInterval, (timer) async {
      try {
        final students = await ApiService.getStudents(teacherId: teacherId);
        
        _recordRequestSuccess(); // Track successful request
        
        if (onStudentsUpdate != null) {
          onStudentsUpdate!(students);
          _lastStudentsUpdate = DateTime.now();
        }
      } catch (e) {
        _recordRequestFailure(); // Track failed request
        debugPrint('❌ Students polling error: $e');
      }
    });
    
    // Immediately fetch first update
    _fetchStudentsUpdate(teacherId);
  }
  
  /// Start polling for classes updates
  void startClassesPolling({
    String? teacherId,
    Function(List<dynamic>)? onUpdate,
  }) {
    if (_isPollingClasses) {
      debugPrint('⚠️ Classes polling already active');
      return;
    }
    
    _isPollingClasses = true;
    onClassesUpdate = onUpdate;
    
    debugPrint('✓ Starting classes polling (every ${classesInterval.inSeconds}s)');
    
    _classesTimer = Timer.periodic(classesInterval, (timer) async {
      try {
        final classes = await ApiService.getClasses(teacherId: teacherId);
        
        _recordRequestSuccess(); // Track successful request
        
        if (onClassesUpdate != null) {
          onClassesUpdate!(classes);
          _lastClassesUpdate = DateTime.now();
        }
      } catch (e) {
        _recordRequestFailure(); // Track failed request
        debugPrint('❌ Classes polling error: $e');
      }
    });
    
    // Immediately fetch first update
    _fetchClassesUpdate(teacherId);
  }
  
  /// Start polling for notifications
  void startNotificationsPolling({
    Function(List<dynamic>)? onUpdate,
  }) {
    if (_isPollingNotifications) {
      debugPrint('⚠️ Notifications polling already active');
      return;
    }
    
    _isPollingNotifications = true;
    onNotificationsUpdate = onUpdate;
    
    debugPrint('✓ Starting notifications polling (every ${notificationsInterval.inSeconds}s)');
    
    _notificationsTimer = Timer.periodic(notificationsInterval, (timer) async {
      try {
        // For now, return empty list until notification endpoint is available
        if (onNotificationsUpdate != null) {
          onNotificationsUpdate!([]);
          _lastNotificationsUpdate = DateTime.now();
        }
      } catch (e) {
        debugPrint('❌ Notifications polling error: $e');
      }
    });
    
    // Immediately fetch first update
    _fetchNotificationsUpdate();
  }
  
  /// Start polling for payments/subscription updates
  void startPaymentsPolling({
    Function(Map<String, dynamic>)? onUpdate,
  }) {
    if (_isPollingPayments) {
      debugPrint('⚠️ Payments polling already active');
      return;
    }
    
    _isPollingPayments = true;
    onPaymentsUpdate = onUpdate;
    
    debugPrint('✓ Starting payments polling (every ${paymentsInterval.inSeconds}s)');
    
    _paymentsTimer = Timer.periodic(paymentsInterval, (timer) async {
      try {
        // For now, return empty map until subscription endpoint is available
        if (onPaymentsUpdate != null) {
          onPaymentsUpdate!({});
          _lastPaymentsUpdate = DateTime.now();
        }
      } catch (e) {
        debugPrint('❌ Payments polling error: $e');
      }
    });
    
    // Immediately fetch first update
    _fetchPaymentsUpdate();
  }
  
  // Helper methods for immediate updates
  Future<void> _fetchAttendanceUpdate(String? classId, DateTime? date) async {
    try {
      final attendance = await ApiService.getAttendance(
        teacherId: null,
      );
      
      if (onAttendanceUpdate != null) {
        onAttendanceUpdate!(attendance);
        _lastAttendanceUpdate = DateTime.now();
      }
    } catch (e) {
      debugPrint('❌ Initial attendance fetch error: $e');
    }
  }
  
  Future<void> _fetchStudentsUpdate(String? teacherId) async {
    try {
      final students = await ApiService.getStudents(teacherId: teacherId);
      
      if (onStudentsUpdate != null) {
        onStudentsUpdate!(students);
        _lastStudentsUpdate = DateTime.now();
      }
    } catch (e) {
      debugPrint('❌ Initial students fetch error: $e');
    }
  }
  
  Future<void> _fetchClassesUpdate(String? teacherId) async {
    try {
      final classes = await ApiService.getClasses(teacherId: teacherId);
      
      if (onClassesUpdate != null) {
        onClassesUpdate!(classes);
        _lastClassesUpdate = DateTime.now();
      }
    } catch (e) {
      debugPrint('❌ Initial classes fetch error: $e');
    }
  }
  
  Future<void> _fetchNotificationsUpdate() async {
    try {
      // For now, return empty list until notification endpoint is available
      if (onNotificationsUpdate != null) {
        onNotificationsUpdate!([]);
        _lastNotificationsUpdate = DateTime.now();
      }
    } catch (e) {
      debugPrint('❌ Initial notifications fetch error: $e');
    }
  }
  
  Future<void> _fetchPaymentsUpdate() async {
    try {
      // For now, return empty map until subscription endpoint is available
      if (onPaymentsUpdate != null) {
        onPaymentsUpdate!({});
        _lastPaymentsUpdate = DateTime.now();
      }
    } catch (e) {
      debugPrint('❌ Initial payments fetch error: $e');
    }
  }
  
  /// Stop attendance polling
  void stopAttendancePolling() {
    _attendanceTimer?.cancel();
    _attendanceTimer = null;
    _isPollingAttendance = false;
    onAttendanceUpdate = null;
    debugPrint('✓ Stopped attendance polling');
  }
  
  /// Stop students polling
  void stopStudentsPolling() {
    _studentsTimer?.cancel();
    _studentsTimer = null;
    _isPollingStudents = false;
    onStudentsUpdate = null;
    debugPrint('✓ Stopped students polling');
  }
  
  /// Stop classes polling
  void stopClassesPolling() {
    _classesTimer?.cancel();
    _classesTimer = null;
    _isPollingClasses = false;
    onClassesUpdate = null;
    debugPrint('✓ Stopped classes polling');
  }
  
  /// Stop notifications polling
  void stopNotificationsPolling() {
    _notificationsTimer?.cancel();
    _notificationsTimer = null;
    _isPollingNotifications = false;
    onNotificationsUpdate = null;
    debugPrint('✓ Stopped notifications polling');
  }
  
  /// Stop payments polling
  void stopPaymentsPolling() {
    _paymentsTimer?.cancel();
    _paymentsTimer = null;
    _isPollingPayments = false;
    onPaymentsUpdate = null;
    debugPrint('✓ Stopped payments polling');
  }
  
  /// Stop all polling activities
  void stopAllPolling() {
    stopAttendancePolling();
    stopStudentsPolling();
    stopClassesPolling();
    stopNotificationsPolling();
    stopPaymentsPolling();
    debugPrint('✓ Stopped all polling services');
  }
  
  /// Adjust polling intervals dynamically
  void setPollingInterval({
    Duration? attendance,
    Duration? students,
    Duration? classes,
    Duration? notifications,
    Duration? payments,
  }) {
    if (attendance != null) {
      attendanceInterval = attendance;
      if (_isPollingAttendance) {
        stopAttendancePolling();
        startAttendancePolling();
      }
    }
    if (students != null) {
      studentsInterval = students;
      if (_isPollingStudents) {
        stopStudentsPolling();
        startStudentsPolling();
      }
    }
    if (classes != null) {
      classesInterval = classes;
      if (_isPollingClasses) {
        stopClassesPolling();
        startClassesPolling();
      }
    }
    if (notifications != null) {
      notificationsInterval = notifications;
      if (_isPollingNotifications) {
        stopNotificationsPolling();
        startNotificationsPolling();
      }
    }
    if (payments != null) {
      paymentsInterval = payments;
      if (_isPollingPayments) {
        stopPaymentsPolling();
        startPaymentsPolling();
      }
    }
    
    debugPrint('✓ Updated polling intervals');
  }
  
  /// Get status of all polling services
  Map<String, dynamic> getPollingStatus() {
    return {
      'attendance': {
        'active': _isPollingAttendance,
        'interval': attendanceInterval.inSeconds,
        'lastUpdate': _lastAttendanceUpdate?.toIso8601String(),
      },
      'students': {
        'active': _isPollingStudents,
        'interval': studentsInterval.inSeconds,
        'lastUpdate': _lastStudentsUpdate?.toIso8601String(),
      },
      'classes': {
        'active': _isPollingClasses,
        'interval': classesInterval.inSeconds,
        'lastUpdate': _lastClassesUpdate?.toIso8601String(),
      },
      'notifications': {
        'active': _isPollingNotifications,
        'interval': notificationsInterval.inSeconds,
        'lastUpdate': _lastNotificationsUpdate?.toIso8601String(),
      },
      'payments': {
        'active': _isPollingPayments,
        'interval': paymentsInterval.inSeconds,
        'lastUpdate': _lastPaymentsUpdate?.toIso8601String(),
      },
    };
  }
  
  /// Manually trigger a poll cycle for specific service
  Future<void> triggerPoll(String serviceName) async {
    switch (serviceName.toLowerCase()) {
      case 'attendance':
        await _fetchAttendanceUpdate(null, null);
        break;
      case 'students':
        await _fetchStudentsUpdate(null);
        break;
      case 'classes':
        await _fetchClassesUpdate(null);
        break;
      case 'notifications':
        await _fetchNotificationsUpdate();
        break;
      case 'payments':
        await _fetchPaymentsUpdate();
        break;
      default:
        debugPrint('⚠️ Unknown service: $serviceName');
    }
  }
  
  /// SOLUTION FOR PROBLEM 2: Record request success (for connection quality tracking)
  void _recordRequestSuccess() {
    _consecutiveFailures = 0;
    _lastSuccessfulRequest = DateTime.now();
    
    // If connection was slow, restore normal intervals
    if (_isSlowConnection) {
      _isSlowConnection = false;
      _restoreNormalIntervals();
      debugPrint('✓ Connection restored - using normal polling intervals');
    }
  }
  
  /// SOLUTION FOR PROBLEM 2: Record request failure (for connection quality tracking)
  void _recordRequestFailure() {
    _consecutiveFailures++;
    
    // If 3+ consecutive failures, switch to slow connection mode
    if (_consecutiveFailures >= 3 && !_isSlowConnection) {
      _isSlowConnection = true;
      _adaptToSlowConnection();
      debugPrint('⚠️ Slow connection detected - reducing polling frequency');
    }
  }
  
  /// Adapt polling intervals for slow connection
  void _adaptToSlowConnection() {
    // Increase all intervals by multiplier
    attendanceInterval = _baseAttendanceInterval * _slowConnectionMultiplier;
    studentsInterval = _baseStudentsInterval * _slowConnectionMultiplier;
    classesInterval = _baseClassesInterval * _slowConnectionMultiplier;
    notificationsInterval = _baseNotificationsInterval * _slowConnectionMultiplier;
    paymentsInterval = _basePaymentsInterval * _slowConnectionMultiplier;
    
    // Restart active polling with new intervals
    if (_isPollingAttendance) {
      stopAttendancePolling();
      startAttendancePolling();
    }
    if (_isPollingStudents) {
      stopStudentsPolling();
      startStudentsPolling();
    }
    if (_isPollingClasses) {
      stopClassesPolling();
      startClassesPolling();
    }
    if (_isPollingNotifications) {
      stopNotificationsPolling();
      startNotificationsPolling();
    }
    if (_isPollingPayments) {
      stopPaymentsPolling();
      startPaymentsPolling();
    }
  }
  
  /// Restore normal polling intervals
  void _restoreNormalIntervals() {
    attendanceInterval = _baseAttendanceInterval;
    studentsInterval = _baseStudentsInterval;
    classesInterval = _baseClassesInterval;
    notificationsInterval = _baseNotificationsInterval;
    paymentsInterval = _basePaymentsInterval;
    
    // Restart active polling with restored intervals
    if (_isPollingAttendance) {
      stopAttendancePolling();
      startAttendancePolling();
    }
    if (_isPollingStudents) {
      stopStudentsPolling();
      startStudentsPolling();
    }
    if (_isPollingClasses) {
      stopClassesPolling();
      startClassesPolling();
    }
    if (_isPollingNotifications) {
      stopNotificationsPolling();
      startNotificationsPolling();
    }
    if (_isPollingPayments) {
      stopPaymentsPolling();
      startPaymentsPolling();
    }
  }
  
  /// Check if connection is currently slow
  bool get isSlowConnection => _isSlowConnection;
  
  /// Get connection quality info
  Map<String, dynamic> getConnectionQuality() {
    return {
      'isSlowConnection': _isSlowConnection,
      'consecutiveFailures': _consecutiveFailures,
      'lastSuccessfulRequest': _lastSuccessfulRequest?.toIso8601String(),
      'currentIntervalMultiplier': _isSlowConnection ? _slowConnectionMultiplier : 1,
    };
  }
}
