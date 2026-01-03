import 'package:flutter/material.dart';
import '../services/admin_changes_polling_service.dart';

/// Provider to manage admin changes polling service
/// Integrates polling with app lifecycle and notifies listeners of changes
class AdminChangesProvider with ChangeNotifier {
  final AdminChangesPollingService _pollingService = AdminChangesPollingService();
  
  // State tracking
  bool _isRestricted = false;
  String? _restrictionReason;
  Map<String, dynamic>? _restrictionDetails;
  
  bool _subscriptionExpiring = false;
  String? _subscriptionStatus;
  DateTime? _subscriptionExpiryDate;
  Map<String, dynamic>? _subscriptionDetails;
  
  String? _userStatus;
  Map<String, dynamic>? _statusDetails;
  
  List<dynamic>? _classesChanged;
  
  bool _isPolling = false;
  String? _lastChangeDetected;

  // Getters
  bool get isRestricted => _isRestricted;
  String? get restrictionReason => _restrictionReason;
  Map<String, dynamic>? get restrictionDetails => _restrictionDetails;
  
  bool get subscriptionExpiring => _subscriptionExpiring;
  String? get subscriptionStatus => _subscriptionStatus;
  DateTime? get subscriptionExpiryDate => _subscriptionExpiryDate;
  Map<String, dynamic>? get subscriptionDetails => _subscriptionDetails;
  
  String? get userStatus => _userStatus;
  Map<String, dynamic>? get statusDetails => _statusDetails;
  
  List<dynamic>? get classesChanged => _classesChanged;
  
  bool get isPolling => _isPolling;
  String? get lastChangeDetected => _lastChangeDetected;

  /// Start polling for admin changes
  void startPolling({
    required BuildContext context,
    required String userId,
    required String userType,
    int pollIntervalSeconds = 5,
    Function()? onUserNotFound,
  }) {
    _isPolling = true;
    
    _pollingService.startPolling(
      context: context,
      userId: userId,
      userType: userType,
      pollIntervalSeconds: pollIntervalSeconds,
      onRestrictionChanged: _handleRestrictionChange,
      onSubscriptionChanged: _handleSubscriptionChange,
      onStatusChanged: _handleStatusChange,
      onClassesChanged: _handleClassesChange,
      onCriticalChangeDetected: _handleCriticalChange,
      onUserNotFound: onUserNotFound,
    );
    
    notifyListeners();
  }

  /// Stop polling
  void stopPolling() {
    _pollingService.stopPolling();
    _isPolling = false;
    notifyListeners();
  }

  /// Handle restriction changes
  void _handleRestrictionChange(Map<String, dynamic> details) {
    _isRestricted = details['isRestricted'] ?? false;
    _restrictionReason = details['restrictionReason'];
    _restrictionDetails = details;
    _lastChangeDetected = 'RESTRICTION_CHANGED';
    
    print('AdminChangesProvider: Restriction changed - $_isRestricted');
    notifyListeners();
  }

  /// Handle subscription changes
  void _handleSubscriptionChange(Map<String, dynamic> details) {
    _subscriptionStatus = details['status'];
    if (details['expiryDate'] != null) {
      _subscriptionExpiryDate = DateTime.tryParse(details['expiryDate'] as String);
    }
    _subscriptionExpiring = details['expiring'] ?? false;
    _subscriptionDetails = details;
    _lastChangeDetected = 'SUBSCRIPTION_CHANGED';
    
    print('AdminChangesProvider: Subscription changed - $_subscriptionStatus');
    notifyListeners();
  }

  /// Handle status changes
  void _handleStatusChange(Map<String, dynamic> details) {
    _userStatus = details['status'];
    _statusDetails = details;
    _lastChangeDetected = 'STATUS_CHANGED';
    
    print('AdminChangesProvider: Status changed - $_userStatus');
    notifyListeners();
  }

  /// Handle classes/assignments changes
  void _handleClassesChange(Map<String, dynamic> details) {
    _classesChanged = details['classes'];
    _lastChangeDetected = 'CLASSES_CHANGED';
    
    print('AdminChangesProvider: Classes changed');
    notifyListeners();
  }

  /// Handle critical changes (like restriction)
  void _handleCriticalChange(String message) {
    _lastChangeDetected = message;
    
    print('AdminChangesProvider: Critical change detected - $message');
    notifyListeners();
  }

  /// Resume polling when app comes to foreground
  void resumePolling() {
    if (_isPolling) {
      _pollingService.resumePolling();
    }
  }

  /// Pause polling when app goes to background
  void pausePolling() {
    if (_isPolling) {
      _pollingService.pausePolling();
    }
  }

  /// Check if user is restricted
  bool hasRestriction() => _isRestricted;

  /// Get restriction message
  String getRestrictionMessage() {
    if (!_isRestricted) return '';
    return _restrictionReason ?? 'Your account has been restricted by the administrator';
  }
}
