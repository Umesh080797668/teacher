import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class ReportsProvider with ChangeNotifier {
  bool _isLoading = false;

  Map<String, dynamic> _attendanceSummary = {};
  List<Map<String, dynamic>> _studentReports = [];
  List<Map<String, dynamic>> _monthlyStats = [];

  bool get isLoading => _isLoading;
  Map<String, dynamic> get attendanceSummary => _attendanceSummary;
  List<Map<String, dynamic>> get studentReports => _studentReports;
  List<Map<String, dynamic>> get monthlyStats => _monthlyStats;

  Future<void> loadReports({String? teacherId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        _loadAttendanceSummary(teacherId: teacherId),
        _loadStudentReports(teacherId: teacherId),
        _loadMonthlyStats(teacherId: teacherId),
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

  Future<void> refreshReports({String? teacherId}) async {
    await loadReports(teacherId: teacherId);
  }
}