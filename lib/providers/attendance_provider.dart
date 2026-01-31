import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/attendance.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

class AttendanceProvider with ChangeNotifier {
  List<Attendance> _attendance = [];
  bool _isLoading = false;

  List<Attendance> get attendance => _attendance;
  bool get isLoading => _isLoading;

  Future<void> loadAttendance({int? month, int? year, String? teacherId, bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    
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
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Load cached data first for instant display
      if (!silent && teacherId != null) {
        try {
          final cacheKey = 'attendance_${teacherId}_${month ?? 'all'}_${year ?? 'all'}';
          final cachedData = await CacheService.getOfflineCachedData(cacheKey);
          if (cachedData != null) {
            final attendanceJson = json.decode(cachedData) as List;
            _attendance = attendanceJson.map((json) => Attendance.fromJson(json)).toList();
            _isLoading = false;
            notifyListeners();
            debugPrint('✓ Loaded cached attendance instantly');
          }
        } catch (e) {
          debugPrint('Error loading cached attendance: $e');
        }
      }

      // Fetch fresh data with timeout
      try {
        _attendance = await ApiService.getAttendance(month: month, year: year, teacherId: teacherId)
            .timeout(const Duration(seconds: 5));
        
        // Cache for next time
        if (teacherId != null) {
          final cacheKey = 'attendance_${teacherId}_${month ?? 'all'}_${year ?? 'all'}';
          CacheService.cacheOfflineData(cacheKey, 
              json.encode(_attendance.map((a) => a.toJson()).toList()));
        }
        
        debugPrint('✓ Loaded fresh attendance data');
      } catch (e) {
        // If failed and we have cached data, keep it
        if (_attendance.isEmpty && teacherId != null) {
          final cacheKey = 'attendance_${teacherId}_${month ?? 'all'}_${year ?? 'all'}';
          final cachedData = await CacheService.getOfflineCachedData(cacheKey);
          if (cachedData != null) {
            final attendanceJson = json.decode(cachedData) as List;
            _attendance = attendanceJson.map((json) => Attendance.fromJson(json)).toList();
            debugPrint('⚠️ Using cached attendance due to error: $e');
          }
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}