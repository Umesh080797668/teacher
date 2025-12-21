import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../models/class.dart';

class ReportsProvider with ChangeNotifier {
  bool _isLoading = false;
  bool _isDailyLoading = false;

  Map<String, dynamic> _attendanceSummary = {};
  List<Map<String, dynamic>> _studentReports = [];
  List<Map<String, dynamic>> _monthlyStats = [];
  List<Map<String, dynamic>> _dailyByClass = [];
  List<Map<String, dynamic>> _monthlyByClass = [];
  List<Map<String, dynamic>> _payments = [];
  
  // For daily view
  List<Attendance> _dailyAttendance = [];
  List<Student> _allStudents = [];
  List<Class> _allClasses = [];

  bool get isLoading => _isLoading;
  bool get isDailyLoading => _isDailyLoading;
  Map<String, dynamic> get attendanceSummary => _attendanceSummary;
  List<Map<String, dynamic>> get studentReports => _studentReports;
  List<Map<String, dynamic>> get monthlyStats => _monthlyStats;
  List<Map<String, dynamic>> get dailyByClass => _dailyByClass;
  List<Map<String, dynamic>> get monthlyByClass => _monthlyByClass;
  List<Map<String, dynamic>> get payments => _payments;
  List<Attendance> get dailyAttendance => _dailyAttendance;
  List<Student> get allStudents => _allStudents;
  List<Class> get allClasses => _allClasses;

  Future<void> loadReports({String? teacherId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        _loadAttendanceSummary(teacherId: teacherId),
        _loadStudentReports(teacherId: teacherId),
        _loadMonthlyStats(teacherId: teacherId),
        _loadDailyByClass(teacherId: teacherId),
        _loadMonthlyByClass(teacherId: teacherId),
        _loadPayments(teacherId: teacherId),
        _loadStudentsAndClasses(teacherId: teacherId),
      ]);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAttendanceSummary({String? teacherId}) async {
    try {
      final response = await ApiService.getAttendanceSummary(teacherId: teacherId);
      _attendanceSummary = response;
    } catch (e) {
      debugPrint('Error loading attendance summary: $e');
      _attendanceSummary = {};
    }
  }

  Future<void> _loadStudentReports({String? teacherId}) async {
    try {
      final response = await ApiService.getStudentReports(teacherId: teacherId);
      _studentReports = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading student reports: $e');
      _studentReports = [];
    }
  }

  Future<void> _loadMonthlyStats({String? teacherId}) async {
    try {
      final response = await ApiService.getMonthlyStats(teacherId: teacherId);
      _monthlyStats = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading monthly stats: $e');
      _monthlyStats = [];
    }
  }

  Future<void> _loadDailyByClass({String? teacherId}) async {
    try {
      final response = await ApiService.getDailyByClass(teacherId: teacherId);
      _dailyByClass = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading daily by class: $e');
      _dailyByClass = [];
    }
  }

  Future<void> _loadMonthlyByClass({String? teacherId}) async {
    try {
      final response = await ApiService.getMonthlyByClass(teacherId: teacherId);
      _monthlyByClass = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading monthly by class: $e');
      _monthlyByClass = [];
    }
  }

  Future<void> _loadPayments({String? teacherId}) async {
    try {
      final response = await ApiService.getPaymentsMap(teacherId: teacherId);
      _payments = response;
    } catch (e) {
      debugPrint('Error loading payments: $e');
      _payments = [];
    }
  }

  Future<void> _loadStudentsAndClasses({String? teacherId}) async {
    try {
      final studentsList = await ApiService.getStudents(teacherId: teacherId);
      final classesList = await ApiService.getClasses(teacherId: teacherId);
      _allStudents = studentsList;
      _allClasses = classesList;
    } catch (e) {
      debugPrint('Error loading students and classes: $e');
      _allStudents = [];
      _allClasses = [];
    }
  }

  Future<void> refreshReports({String? teacherId}) async {
    await loadReports(teacherId: teacherId);
  }

  // Load daily attendance data for a specific date
  Future<void> loadDailyAttendance(DateTime date, {String? teacherId}) async {
    _isDailyLoading = true;
    notifyListeners();

    try {
      // Get the year and month from the selected date
      final year = date.year;
      final month = date.month;

      // Fetch attendance, students, and classes
      final attendanceList = await ApiService.getAttendance(
        teacherId: teacherId,
        month: month,
        year: year,
      );
      final studentsList = await ApiService.getStudents(teacherId: teacherId);
      final classesList = await ApiService.getClasses(teacherId: teacherId);

      // Filter attendance for the specific date
      final selectedDateStr = DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0];
      _dailyAttendance = attendanceList.where((attendance) {
        final attendanceDateStr = attendance.date.toIso8601String().split('T')[0];
        return attendanceDateStr == selectedDateStr;
      }).toList();

      _allStudents = studentsList;
      _allClasses = classesList;
    } catch (e) {
      debugPrint('Error loading daily attendance: $e');
      _dailyAttendance = [];
      _allStudents = [];
      _allClasses = [];
    } finally {
      _isDailyLoading = false;
      notifyListeners();
    }
  }

  // Get daily statistics for the selected date
  Map<String, dynamic> getDailyStats() {
    final presentCount = _dailyAttendance.where((a) => a.status == 'present').length;
    final absentCount = _dailyAttendance.where((a) => a.status == 'absent').length;
    final lateCount = _dailyAttendance.where((a) => a.status == 'late').length;
    final totalRecorded = _dailyAttendance.length;
    final attendanceRate = totalRecorded > 0 ? (presentCount / totalRecorded) * 100 : 0.0;

    return {
      'totalStudents': _allStudents.length,
      'presentCount': presentCount,
      'absentCount': absentCount,
      'lateCount': lateCount,
      'attendanceRate': attendanceRate,
    };
  }

  // Get students grouped by class with their attendance status
  Map<String, List<Map<String, dynamic>>> getStudentsByClass() {
    final Map<String, List<Map<String, dynamic>>> result = {};

    for (final cls in _allClasses) {
      final classStudents = _allStudents.where((s) => s.classId == cls.id).toList();
      final studentsList = classStudents.map((student) {
        final attendanceIndex = _dailyAttendance.indexWhere((a) => a.studentId == student.id);
        final hasAttendance = attendanceIndex != -1;
        final attendance = hasAttendance ? _dailyAttendance[attendanceIndex] : null;

        return {
          'id': student.id,
          'name': student.name,
          'studentId': student.studentId,
          'status': attendance?.status ?? 'not-recorded',
          'session': attendance?.session ?? '',
        };
      }).toList();

      result[cls.name] = studentsList;
    }

    return result;
  }

  // Get student count by class
  Map<String, int> getStudentCountByClass() {
    final Map<String, int> result = {};

    for (final cls in _allClasses) {
      final classStudents = _allStudents.where((s) => s.classId == cls.id).toList();
      result[cls.name] = classStudents.length;
    }

    return result;
  }
}