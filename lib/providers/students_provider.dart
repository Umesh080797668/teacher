import 'package:flutter/foundation.dart';
import '../models/student.dart';
import '../services/api_service.dart';

class StudentsProvider with ChangeNotifier {
  List<Student> _students = [];
  bool _isLoading = false;

  List<Student> get students => _students;
  bool get isLoading => _isLoading;

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

  Future<void> deleteStudent(String studentId) async {
    await ApiService.deleteStudent(studentId);
    _students.removeWhere((s) => s.id == studentId);
    notifyListeners();
  }
}