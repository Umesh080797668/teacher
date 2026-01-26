import 'package:flutter/foundation.dart';
import '../models/payment.dart';
import '../services/api_service.dart';

class PaymentProvider with ChangeNotifier {
  List<Payment> _payments = [];
  bool _isLoading = false;

  List<Payment> get payments => _payments;
  bool get isLoading => _isLoading;

  Future<void> loadPayments({String? classId, String? studentId, String? teacherId}) async {
    _isLoading = true;
    notifyListeners();
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
      } else {
        _payments = await ApiService.getPayments(
            classId: classId, studentId: studentId, teacherId: teacherId);
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