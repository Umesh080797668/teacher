import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Service to handle real-time polling for subscription status updates
class SubscriptionPollingService {
  Timer? _pollingTimer;
  bool _isPolling = false;
  Duration _pollingInterval;
  final String? _userEmail;
  final Function(Map<String, dynamic>)? _onStatusChanged;
  Map<String, dynamic>? _lastStatus;

  SubscriptionPollingService({
    Duration pollingInterval = const Duration(seconds: 3),
    String? userEmail,
    Function(Map<String, dynamic>)? onStatusChanged,
  })  : _pollingInterval = pollingInterval,
        _userEmail = userEmail,
        _onStatusChanged = onStatusChanged;

  bool get isPolling => _isPolling;

  /// Start polling for subscription status changes
  Future<void> startPolling() async {
    if (_isPolling || _userEmail == null) {
      debugPrint('Polling already active or no email provided');
      return;
    }

    _isPolling = true;
    debugPrint('Starting subscription status polling for $_userEmail');

    // Initial check
    await _checkSubscriptionStatus();

    // Set up periodic polling
    _pollingTimer = Timer.periodic(_pollingInterval, (timer) async {
      await _checkSubscriptionStatus();
    });
  }

  /// Stop polling for subscription status changes
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    debugPrint('Subscription polling stopped');
  }

  /// Check subscription status and trigger callback if changed
  Future<void> _checkSubscriptionStatus() async {
    if (_userEmail == null) return;

    try {
      final status = await ApiService.checkTeacherStatus(_userEmail);

      // Check if status changed
      if (_lastStatus == null || _hasStatusChanged(status)) {
        _lastStatus = status;
        debugPrint(
            'Subscription status changed: ${status['subscriptionType']} (Active: ${status['isActive']})');
        _onStatusChanged?.call(status);
      }
    } catch (e) {
      debugPrint('Error checking subscription status: $e');
      // Continue polling on error to handle temporary network issues
    }
  }

  /// Check if subscription status has changed significantly
  bool _hasStatusChanged(Map<String, dynamic> newStatus) {
    if (_lastStatus == null) return true;

    // Check for payment proof rejection
    final oldPaymentProofStatus = _lastStatus!['paymentProofStatus'] as String?;
    final newPaymentProofStatus = newStatus['paymentProofStatus'] as String?;
    
    if (oldPaymentProofStatus != newPaymentProofStatus) {
      if (newPaymentProofStatus == 'rejected') {
        debugPrint('Payment proof was rejected!');
        newStatus['_paymentRejected'] = true;
        return true;
      } else if (newPaymentProofStatus == 'approved') {
        debugPrint('Payment proof was approved!');
        newStatus['_paymentApproved'] = true;
        return true;
      }
    }

    // Check for subscription type change
    if (_lastStatus!['subscriptionType'] != newStatus['subscriptionType']) {
      // Special handling: detect upgrade from free to paid plan
      final oldType = _lastStatus!['subscriptionType'] as String?;
      final newType = newStatus['subscriptionType'] as String?;
      final isActive = newStatus['isActive'] as bool? ?? true;
      final wasActive = _lastStatus!['isActive'] as bool? ?? true;
      
      if (oldType == 'free' && (newType == 'monthly' || newType == 'yearly')) {
        debugPrint('Subscription upgraded from free to $newType - should show subscription screen');
        // Mark this as a special upgrade change
        newStatus['_showSubscriptionScreen'] = true;
        
        // Also check if account became inactive with the subscription change
        if (!isActive && wasActive) {
          debugPrint('Account was inactivated with subscription change');
          newStatus['_accountInactivated'] = true;
        }
      }
      
      return true;
    }

    // Check for activation status change
    if (_lastStatus!['isActive'] != newStatus['isActive']) {
      final isActive = newStatus['isActive'] as bool? ?? true;
      final wasActive = _lastStatus!['isActive'] as bool? ?? true;
      
      // Detect account inactivation specifically
      if (wasActive && !isActive) {
        debugPrint('Account was inactivated');
        newStatus['_accountInactivated'] = true;
      } else if (!wasActive && isActive) {
        debugPrint('Account was activated/reactivated');
        newStatus['_accountActivated'] = true;
      }
      
      return true;
    }

    // Check for subscription expiry status change
    if (_lastStatus!['subscriptionExpired'] !=
        newStatus['subscriptionExpired']) {
      return true;
    }

    // Check for subscription expiring soon status change
    if (_lastStatus!['subscriptionExpiringSoon'] !=
        newStatus['subscriptionExpiringSoon']) {
      return true;
    }

    return false;
  }

  /// Update polling interval dynamically
  void updatePollingInterval(Duration newInterval) {
    if (_isPolling) {
      stopPolling();
      _pollingInterval = newInterval;
      startPolling();
    }
  }

  /// Get current status without polling
  Future<Map<String, dynamic>> getCurrentStatus() async {
    if (_userEmail == null) {
      throw Exception('No email provided for status check');
    }
    return ApiService.checkTeacherStatus(_userEmail);
  }

  /// Cleanup resources
  void dispose() {
    stopPolling();
  }
}
