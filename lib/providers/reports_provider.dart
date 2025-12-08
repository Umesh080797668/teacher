import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class ReportsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  Map<String, dynamic> _attendanceSummary = {};
  List<Map<String, dynamic>> _studentReports = [];
  List<Map<String, dynamic>> _monthlyStats = [];

  bool get isLoading => _isLoading;
  Map<String, dynamic> get attendanceSummary => _attendanceSummary;
  List<Map<String, dynamic>> get studentReports => _studentReports;
  List<Map<String, dynamic>> get monthlyStats => _monthlyStats;

  Future<void> loadReports() async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        _loadAttendanceSummary(),
        _loadStudentReports(),
        _loadMonthlyStats(),
      ]);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAttendanceSummary() async {
    try {
      final response = await _apiService.getAttendanceSummary();
      _attendanceSummary = response;
    } catch (e) {
      debugPrint('Error loading attendance summary: $e');
      _attendanceSummary = {};
    }
  }

  Future<void> _loadStudentReports() async {
    try {
      final response = await _apiService.getStudentReports();
      _studentReports = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading student reports: $e');
      _studentReports = [];
    }
  }

  Future<void> _loadMonthlyStats() async {
    try {
      final response = await _apiService.getMonthlyStats();
      _monthlyStats = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading monthly stats: $e');
      _monthlyStats = [];
    }
  }

  Future<void> refreshReports() async {
    await loadReports();
  }
}