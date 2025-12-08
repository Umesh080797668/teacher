import 'package:flutter/foundation.dart';
import '../models/student.dart';
import '../services/api_service.dart';

class StudentsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Student> _students = [];
  bool _isLoading = false;

  List<Student> get students => _students;
  bool get isLoading => _isLoading;

  Future<void> loadStudents() async {
    _isLoading = true;
    notifyListeners();
    try {
      _students = await _apiService.getStudents();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addStudent(String name, String? email, String? studentId, String? classId) async {
    final student = await _apiService.createStudent(name, email, studentId, classId);
    _students.add(student);
    notifyListeners();
  }
}