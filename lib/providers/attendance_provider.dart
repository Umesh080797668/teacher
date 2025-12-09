import 'package:flutter/foundation.dart';
import '../models/attendance.dart';
import '../services/api_service.dart';

class AttendanceProvider with ChangeNotifier {
  List<Attendance> _attendance = [];
  bool _isLoading = false;

  List<Attendance> get attendance => _attendance;
  bool get isLoading => _isLoading;

  Future<void> loadAttendance({int? month, int? year}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _attendance = await ApiService.getAttendance(month: month, year: year);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}