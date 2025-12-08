import 'package:flutter/foundation.dart';
import '../models/class.dart';
import '../services/api_service.dart';

class ClassesProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Class> _classes = [];
  bool _isLoading = false;

  List<Class> get classes => _classes;
  bool get isLoading => _isLoading;

  Future<void> loadClasses() async {
    _isLoading = true;
    notifyListeners();
    try {
      _classes = await _apiService.getClasses();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addClass(String name, String teacherId) async {
    final classObj = await _apiService.createClass(name, teacherId);
    _classes.add(classObj);
    notifyListeners();
  }

  Future<void> deleteClass(String classId) async {
    await _apiService.deleteClass(classId);
    _classes.removeWhere((classObj) => classObj.id == classId);
    notifyListeners();
  }
}