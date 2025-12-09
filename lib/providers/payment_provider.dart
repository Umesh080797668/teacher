import 'package:flutter/foundation.dart';
import '../models/payment.dart';
import '../services/api_service.dart';

class PaymentProvider with ChangeNotifier {
  List<Payment> _payments = [];
  bool _isLoading = false;

  List<Payment> get payments => _payments;
  bool get isLoading => _isLoading;

  Future<void> loadPayments({String? classId, String? studentId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _payments = await ApiService.getPayments(classId: classId, studentId: studentId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addPayment(String studentId, String classId, double amount, String type) async {
    final payment = await ApiService.createPayment(studentId, classId, amount, type);
    _payments.add(payment);
    notifyListeners();
  }

  Future<void> deletePayment(String paymentId) async {
    await ApiService.deletePayment(paymentId);
    _payments.removeWhere((payment) => payment.id == paymentId);
    notifyListeners();
  }
}