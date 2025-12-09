import 'package:flutter/foundation.dart';
import '../models/class.dart';
import '../services/api_service.dart';

class ClassesProvider with ChangeNotifier {
  List<Class> _classes = [];
  bool _isLoading = false;

  List<Class> get classes => _classes;
  bool get isLoading => _isLoading;

  Future<void> loadClasses() async {
    _isLoading = true;
    notifyListeners();
    try {
      _classes = await ApiService.getClasses();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addClass(String name, String teacherId) async {
    final classObj = await ApiService.createClass(name, teacherId);
    _classes.add(classObj);
    notifyListeners();
  }

  Future<void> deleteClass(String classId) async {
    await ApiService.deleteClass(classId);
    _classes.removeWhere((classObj) => classObj.id == classId);
    notifyListeners();
  }

  Future<void> updateClass(String classId, String name) async {
    final updatedClass = await ApiService.updateClass(classId, name);
    final index = _classes.indexWhere((classObj) => classObj.id == classId);
    if (index != -1) {
      _classes[index] = updatedClass;
      notifyListeners();
    }
  }
}