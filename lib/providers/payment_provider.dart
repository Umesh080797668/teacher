import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/payment.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

class PaymentProvider with ChangeNotifier {
  List<Payment> _payments = [];
  bool _isLoading = false;

  List<Payment> get payments => _payments;
  bool get isLoading => _isLoading;

  Future<void> loadPayments({String? classId, String? studentId, String? teacherId, bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    
    try {
      if (teacherId == 'guest_teacher_id') {
        _payments = [
          Payment(
              id: 'guest_payment_1',
              studentId: 'guest_student_1',
              classId: 'guest_class_1',
              amount: 500.0,
              month: DateTime.now().month,
              year: DateTime.now().year,
              type: 'monthly',
              date: DateTime.now()),
           Payment(
              id: 'guest_payment_2',
              studentId: 'guest_student_2',
              classId: 'guest_class_1',
              amount: 1500.0,
              month: DateTime.now().month,
              year: DateTime.now().year,
              type: 'admission',
              date: DateTime.now().subtract(const Duration(days: 5))),
        ];
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Load cached data first for instant display
      if (!silent && teacherId != null) {
        try {
          final cacheKey = 'payments_${teacherId}_${classId ?? 'all'}_${studentId ?? 'all'}';
          final cachedData = await CacheService.getOfflineCachedData(cacheKey);
          if (cachedData != null) {
            final paymentsJson = json.decode(cachedData) as List;
            _payments = paymentsJson.map((json) => Payment.fromJson(json)).toList();
            _isLoading = false;
            notifyListeners();
            debugPrint('✓ Loaded cached payments instantly');
          }
        } catch (e) {
          debugPrint('Error loading cached payments: $e');
        }
      }

      // Fetch fresh data with timeout
      try {
        _payments = await ApiService.getPayments(
            classId: classId, studentId: studentId, teacherId: teacherId)
            .timeout(const Duration(seconds: 5));
        
        debugPrint('PaymentProvider: Loaded ${_payments.length} payments');

        
        // Cache for next time
        if (teacherId != null) {
          final cacheKey = 'payments_${teacherId}_${classId ?? 'all'}_${studentId ?? 'all'}';
          CacheService.cacheOfflineData(cacheKey, 
              json.encode(_payments.map((p) => p.toJson()).toList()));
        }
        
        debugPrint('✓ Loaded fresh payments data');
      } catch (e) {
        // If failed and we have cached data, keep it
        if (_payments.isEmpty && teacherId != null) {
          final cacheKey = 'payments_${teacherId}_${classId ?? 'all'}_${studentId ?? 'all'}';
          final cachedData = await CacheService.getOfflineCachedData(cacheKey);
          if (cachedData != null) {
            final paymentsJson = json.decode(cachedData) as List;
            _payments = paymentsJson.map((json) => Payment.fromJson(json)).toList();
            debugPrint('⚠️ Using cached payments due to error: $e');
          }
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addPayment(String studentId, String classId, double amount, String type, {int? month, int? year, DateTime? recordingDate}) async {
    if (studentId.startsWith('guest_student_')) {
      final newPayment = Payment(
        id: 'guest_payment_${DateTime.now().millisecondsSinceEpoch}',
        studentId: studentId,
        classId: classId,
        amount: amount,
        type: type,
        month: month ?? DateTime.now().month,
        year: year ?? DateTime.now().year,
        date: recordingDate ?? DateTime.now(),
      );
      _payments.add(newPayment);
      notifyListeners();
      return;
    }
    final payment = await ApiService.createPayment(studentId, classId, amount, type, month: month, year: year, recordingDate: recordingDate);
    _payments.add(payment);
    notifyListeners();
  }

  Future<void> deletePayment(String paymentId) async {
    if (paymentId.startsWith('guest_payment_')) {
      _payments.removeWhere((payment) => payment.id == paymentId);
      notifyListeners();
      return;
    }
    await ApiService.deletePayment(paymentId);
    _payments.removeWhere((payment) => payment.id == paymentId);
    notifyListeners();
  }
}