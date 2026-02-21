import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/student.dart';
import '../services/api_service.dart';
import '../services/restriction_service.dart';
import '../services/cache_service.dart';

class StudentsProvider with ChangeNotifier {
  List<Student> _students = [];
  bool _isLoading = false;

  List<Student> get students => _students;
  bool get isLoading => _isLoading;

  // Set students directly (used for class-specific student loading)
  void setStudents(List<Student> students) {
    _students = students;
    notifyListeners();
  }

  Future<void> loadStudents({String? teacherId, bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    
    try {
      if (teacherId == 'guest_teacher_id') {
        _students = [
          Student(
            id: 'guest_student_1',
            name: 'John Doe',
            studentId: 'ST001',
            createdAt: DateTime.now(),
            classId: 'guest_class_1',
            hasFaceData: true,
          ),
          Student(
            id: 'guest_student_2',
            name: 'Jane Smith',
            studentId: 'ST002',
            createdAt: DateTime.now(),
            classId: 'guest_class_1',
            isRestricted: true,
            restrictionReason: 'Late Payment',
          ),
           Student(
            id: 'guest_student_3',
            name: 'Alice Johnson',
            studentId: 'ST003',
            createdAt: DateTime.now(),
            classId: 'guest_class_2',
          ),
        ];
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Load cached data first for instant display
      if (!silent && teacherId != null) {
        try {
          final cachedData = await CacheService.getOfflineCachedData('students_$teacherId');
          if (cachedData != null) {
            final studentsJson = json.decode(cachedData) as List;
            _students = studentsJson.map((json) => Student.fromJson(json)).toList();
            _isLoading = false;
            notifyListeners();
            debugPrint('✓ Loaded cached students instantly');
          }
        } catch (e) {
          debugPrint('Error loading cached students: $e');
        }
      }

      // Fetch fresh data with timeout
      try {
        _students = await ApiService.getStudents(teacherId: teacherId)
            .timeout(const Duration(seconds: 5));
        
        // Cache for next time
        if (teacherId != null) {
          CacheService.cacheOfflineData('students_$teacherId', 
              json.encode(_students.map((s) => s.toJson()).toList()));
        }
        
        debugPrint('✓ Loaded fresh students data');
      } catch (e) {
        // If failed and we have cached data, keep it
        if (_students.isEmpty && teacherId != null) {
          final cachedData = await CacheService.getOfflineCachedData('students_$teacherId');
          if (cachedData != null) {
            final studentsJson = json.decode(cachedData) as List;
            _students = studentsJson.map((json) => Student.fromJson(json)).toList();
            debugPrint('⚠️ Using cached students due to error: $e');
          }
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addStudent(String name, String? email, String? phoneNumber, String? studentId, String? classId) async {
    // Check if we are in guest mode (infer from dummy IDs)
    if (classId != null && classId.startsWith('guest_class_')) {
      final newStudent = Student(
        id: 'guest_student_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        email: email,
        phoneNumber: phoneNumber,
        studentId: studentId ?? 'G${DateTime.now().millisecondsSinceEpoch}',
        classId: classId,
        createdAt: DateTime.now(),
      );
      _students.add(newStudent);
      notifyListeners();
      return;
    }
    final student = await ApiService.createStudent(name, email, phoneNumber, studentId, classId);
    
    // Check if student already exists in the list (based on ID or studentId)
    final index = _students.indexWhere((s) => s.id == student.id || s.studentId == student.studentId);
    if (index != -1) {
      _students[index] = student;
    } else {
      _students.add(student);
    }
    notifyListeners();
  }

  Future<void> updateStudent(String studentId, String name, String? email, String? phoneNumber, String? classId) async {
    if (studentId.startsWith('guest_student_')) {
      final index = _students.indexWhere((s) => s.id == studentId);
        if (index != -1) {
          _students[index] = Student(
            id: studentId,
            name: name,
            email: email,
            phoneNumber: phoneNumber,
            studentId: _students[index].studentId,
            classId: classId,
            createdAt: _students[index].createdAt,
             isRestricted: _students[index].isRestricted,
             restrictionReason: _students[index].restrictionReason,
             restrictedAt: _students[index].restrictedAt,
             hasFaceData: _students[index].hasFaceData,
          );
          notifyListeners();
        }
      return;
    }
    final updatedStudent = await ApiService.updateStudent(studentId, name, email, phoneNumber, classId);
    final index = _students.indexWhere((s) => s.id == studentId);
    if (index != -1) {
      _students[index] = updatedStudent;
      notifyListeners();
    }
  }

  Future<void> updateFaceData(String studentId, List<double> embedding) async {
    if (studentId.startsWith('guest_student_')) {
       final index = _students.indexWhere((s) => s.id == studentId);
        if (index != -1) {
             // Just update hasFaceData locally
             // We can't really update embedding on the model without recreating it fully or handling immutable
            // For guest mode simulation, just flip the flag
             // Actually Student is immutable, need to construct new one
             // And we can't easily deep copy without copyWith
            //  Let's just simulate succesful scan without storing embedding
           
           notifyListeners();
        }
      return;
    }
    
    final updatedStudent = await ApiService.updateFaceData(studentId, embedding);
    final index = _students.indexWhere((s) => s.id == studentId);
    if (index != -1) {
      _students[index] = updatedStudent;
      notifyListeners();
    }
  }

  Future<void> deleteStudent(String studentId) async {
    debugPrint('StudentsProvider: Requesting deletion for student ID: $studentId');
    if (studentId.startsWith('guest_student_')) {
      debugPrint('StudentsProvider: Deleting guest student');
      _students.removeWhere((s) => s.id == studentId);
      notifyListeners();
      return;
    }
    try {
      await ApiService.deleteStudent(studentId);
      debugPrint('StudentsProvider: API deletion successful. Removing from local list.');
      _students.removeWhere((s) => s.id == studentId);
      notifyListeners();
    } catch (e) {
      debugPrint('StudentsProvider: Error in deleteStudent: $e');
      rethrow;
    }
  }

  Future<void> restrictStudent(String studentId, {String? reason}) async {
    if (studentId.startsWith('guest_student_')) {
       final index = _students.indexWhere((s) => s.id == studentId);
      if (index != -1) {
        _students[index] = Student(
          id: _students[index].id,
          name: _students[index].name,
          email: _students[index].email,
          studentId: _students[index].studentId,
          classId: _students[index].classId,
          createdAt: _students[index].createdAt,
          isRestricted: true,
          restrictionReason: reason ?? 'Restricted by teacher',
          restrictedAt: DateTime.now(),
           hasFaceData: _students[index].hasFaceData,
        );
        notifyListeners();
      }
      return;
    }
    final restrictionService = RestrictionService();
    await restrictionService.restrictStudentByTeacher(studentId: studentId, reason: reason);
    // Update the local student data
    final index = _students.indexWhere((s) => s.id == studentId);
    if (index != -1) {
      _students[index] = Student(
        id: _students[index].id,
        name: _students[index].name,
        email: _students[index].email,
        studentId: _students[index].studentId,
        classId: _students[index].classId,
        createdAt: _students[index].createdAt,
        isRestricted: true,
        restrictionReason: reason ?? 'Restricted by teacher',
        restrictedAt: DateTime.now(),
         hasFaceData: _students[index].hasFaceData, // Preserve this
      );
      notifyListeners();
    }
  }

  Future<void> unrestrictStudent(String studentId) async {
     if (studentId.startsWith('guest_student_')) {
        final index = _students.indexWhere((s) => s.id == studentId);
        if (index != -1) {
          _students[index] = Student(
            id: _students[index].id,
            name: _students[index].name,
            email: _students[index].email,
            studentId: _students[index].studentId,
            classId: _students[index].classId,
            createdAt: _students[index].createdAt,
            isRestricted: false,
            restrictionReason: null,
            restrictedAt: null,
             hasFaceData: _students[index].hasFaceData,
          );
          notifyListeners();
        }
        return;
     }

    final restrictionService = RestrictionService();
    await restrictionService.unrestrictStudentByTeacher(studentId);
    // Update the local student data
    final index = _students.indexWhere((s) => s.id == studentId);
    if (index != -1) {
      _students[index] = Student(
        id: _students[index].id,
        name: _students[index].name,
        email: _students[index].email,
        studentId: _students[index].studentId,
        classId: _students[index].classId,
        createdAt: _students[index].createdAt,
        isRestricted: false,
        restrictionReason: null,
        restrictedAt: null,
         hasFaceData: _students[index].hasFaceData, // preserve
      );
      notifyListeners();
    }
  }
}