import 'package:flutter/foundation.dart';
import '../models/student.dart';
import '../services/api_service.dart';
import '../services/restriction_service.dart';

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

  Future<void> loadStudents({String? teacherId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _students = await ApiService.getStudents(teacherId: teacherId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addStudent(String name, String? email, String? studentId, String? classId) async {
    final student = await ApiService.createStudent(name, email, studentId, classId);
    _students.add(student);
    notifyListeners();
  }

  Future<void> updateStudent(String studentId, String name, String? email, String? classId) async {
    final updatedStudent = await ApiService.updateStudent(studentId, name, email, classId);
    final index = _students.indexWhere((s) => s.id == studentId);
    if (index != -1) {
      _students[index] = updatedStudent;
      notifyListeners();
    }
  }

  Future<void> updateFaceData(String studentId, List<double> embedding) async {
    final updatedStudent = await ApiService.updateFaceData(studentId, embedding);
    final index = _students.indexWhere((s) => s.id == studentId);
    if (index != -1) {
      _students[index] = updatedStudent;
      notifyListeners();
    }
  }

  Future<void> deleteStudent(String studentId) async {
    await ApiService.deleteStudent(studentId);
    _students.removeWhere((s) => s.id == studentId);
    notifyListeners();
  }

  Future<void> restrictStudent(String studentId, {String? reason}) async {
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
      );
      notifyListeners();
    }
  }

  Future<void> unrestrictStudent(String studentId) async {
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
      );
      notifyListeners();
    }
  }
}