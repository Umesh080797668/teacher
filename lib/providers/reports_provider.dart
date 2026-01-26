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
  List<Map<String, dynamic>> _monthlyEarningsByClass = [];
  
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
  List<Map<String, dynamic>> get monthlyEarningsByClass => _monthlyEarningsByClass;
  List<Attendance> get dailyAttendance => _dailyAttendance;
  List<Student> get allStudents => _allStudents;
  List<Class> get allClasses => _allClasses;

  Future<void> loadReports({String? teacherId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (teacherId == 'guest_teacher_id') {
         // Mock Reports Data
         _attendanceSummary = {
           'total_present': 45,
           'total_absent': 5,
           'attendance_percentage': 90.0,
         };
         _studentReports = [
           {'name': 'John Doe', 'present': 20, 'absent': 2, 'percentage': 90.9},
           {'name': 'Jane Smith', 'present': 18, 'absent': 4, 'percentage': 81.8},
         ];
          _monthlyStats = [
            {'month': 'January', 'present': 100, 'absent': 10},
            {'month': 'February', 'present': 120, 'absent': 5},
          ];
          _dailyByClass = [
            {'className': 'Mathematics 101', 'present': 25, 'absent': 2},
            {'className': 'Physics 202', 'present': 20, 'absent': 3},
          ];
          _monthlyByClass = [
             {'className': 'Mathematics 101', 'month': 'January', 'percentage': 92.0},
             {'className': 'Physics 202', 'month': 'January', 'percentage': 88.0},
          ];
          _payments = [
            {
              'studentName': 'John Doe',
              'studentId': 'guest_student_1',
              'classId': 'guest_class_1',
              'className': 'Mathematics 101',
              'amount': 500.0,
              'date': DateTime.now().toIso8601String(),
              'month': DateTime.now().month,
              'year': DateTime.now().year,
            },
          ];
           _monthlyEarningsByClass = [
             {'className': 'Mathematics 101', 'amount': 5000.0},
             {'className': 'Physics 202', 'amount': 4500.0},
           ];
           _allClasses = [
              Class(id: 'guest_class_1', name: 'Mathematics 101', teacherId: teacherId!),
              Class(id: 'guest_class_2', name: 'Physics 202', teacherId: teacherId),
           ];
           _allStudents = [
              Student(id: 'guest_student_1', name: 'John Doe', studentId: 'ST001', createdAt: DateTime.now(), classId: 'guest_class_1'),
              Student(id: 'guest_student_2', name: 'Jane Smith', studentId: 'ST002', createdAt: DateTime.now(), classId: 'guest_class_1'),
           ];

           notifyListeners();
           return;
      }

      await Future.wait([
        _loadAttendanceSummary(teacherId: teacherId),
        _loadStudentReports(teacherId: teacherId),
        _loadMonthlyStats(teacherId: teacherId),
        _loadDailyByClass(teacherId: teacherId),
        _loadMonthlyByClass(teacherId: teacherId),
        _loadPayments(teacherId: teacherId),
        _loadStudentsAndClasses(teacherId: teacherId),
        _loadMonthlyEarningsByClass(teacherId: teacherId),
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

  Future<void> _loadMonthlyEarningsByClass({String? teacherId}) async {
    try {
      final response = await ApiService.getMonthlyEarningsByClass(teacherId: teacherId);
      _monthlyEarningsByClass = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading monthly earnings by class: $e');
      _monthlyEarningsByClass = [];
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
      if (teacherId == 'guest_teacher_id') {
        // Mock data for guest
        _dailyAttendance = [
          Attendance(
              id: 'guest_att_1',
              studentId: 'guest_student_1',
              date: date,
              status: 'present',
              session: 'Morning',
              month: date.month,
              year: date.year),
          Attendance(
              id: 'guest_att_2',
              studentId: 'guest_student_2',
              date: date,
              status: 'absent',
              session: 'Morning',
              month: date.month,
              year: date.year),
        ];
        _allStudents = [
          Student(
              id: 'guest_student_1',
              name: 'John Doe',
              studentId: 'ST001',
              createdAt: DateTime.now(),
              classId: 'guest_class_1'),
          Student(
              id: 'guest_student_2',
              name: 'Jane Smith',
              studentId: 'ST002',
              createdAt: DateTime.now(),
              classId: 'guest_class_1'),
          Student(
              id: 'guest_student_3',
              name: 'Alice Johnson',
              studentId: 'ST003',
              createdAt: DateTime.now(),
              classId: 'guest_class_2'),
        ];
        _allClasses = [
          Class(id: 'guest_class_1', name: 'Mathematics 101', teacherId: teacherId!),
          Class(id: 'guest_class_2', name: 'Physics 202', teacherId: teacherId),
        ];

        _isDailyLoading = false;
        notifyListeners();
        return;
      }

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
        // Try to find attendance by student.id first, then by student.studentId (enrollment ID)
        var attendanceIndex = _dailyAttendance.indexWhere((a) => a.studentId == student.id);
        
        // If not found, try with the student's enrollment ID
        if (attendanceIndex == -1) {
          attendanceIndex = _dailyAttendance.indexWhere((a) => a.studentId == student.studentId);
        }
        
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