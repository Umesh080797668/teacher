import 'package:flutter/foundation.dart';
import '../models/attendance.dart';
import '../services/api_service.dart';

class AttendanceProvider with ChangeNotifier {
  List<Attendance> _attendance = [];
  bool _isLoading = false;

  List<Attendance> get attendance => _attendance;
  bool get isLoading => _isLoading;

  Future<void> loadAttendance({int? month, int? year, String? teacherId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (teacherId == 'guest_teacher_id') {
        _attendance = [
          Attendance(
              id: 'guest_att_1',
              studentId: 'guest_student_1',
              date: DateTime.now(),
              status: 'present',
              session: 'Morning',
              month: DateTime.now().month,
              year: DateTime.now().year),
          Attendance(
              id: 'guest_att_2',
              studentId: 'guest_student_2',
              date: DateTime.now().subtract(const Duration(days: 1)),
              status: 'absent',
              session: 'Morning',
              month: DateTime.now().month,
              year: DateTime.now().year),
        ];
      } else {
        _attendance = await ApiService.getAttendance(month: month, year: year, teacherId: teacherId);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}