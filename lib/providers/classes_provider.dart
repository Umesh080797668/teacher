import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/class.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

class ClassesProvider with ChangeNotifier {
  List<Class> _classes = [];
  bool _isLoading = false;

  List<Class> get classes => _classes;
  bool get isLoading => _isLoading;

  Future<void> loadClasses({String? teacherId, bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    
    try {
      if (teacherId == 'guest_teacher_id') {
        _classes = [
          Class(id: 'guest_class_1', name: 'Mathematics 101', teacherId: teacherId!),
          Class(id: 'guest_class_2', name: 'Physics 202', teacherId: teacherId),
        ];
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Load cached data first for instant display
      if (!silent && teacherId != null) {
        try {
          final cachedData = await CacheService.getOfflineCachedData('classes_$teacherId');
          if (cachedData != null) {
            final classesJson = json.decode(cachedData) as List;
            _classes = classesJson.map((json) => Class.fromJson(json)).toList();
            _isLoading = false;
            notifyListeners();
            debugPrint('✓ Loaded cached classes instantly');
          }
        } catch (e) {
          debugPrint('Error loading cached classes: $e');
        }
      }

      // Fetch fresh data with timeout
      try {
        _classes = await ApiService.getClasses(teacherId: teacherId)
            .timeout(const Duration(seconds: 5));
        
        // Cache for next time
        if (teacherId != null) {
          CacheService.cacheOfflineData('classes_$teacherId', 
              json.encode(_classes.map((c) => c.toJson()).toList()));
        }
        
        debugPrint('✓ Loaded fresh classes data');
      } catch (e) {
        // If failed and we have cached data, keep it
        if (_classes.isEmpty && teacherId != null) {
          final cachedData = await CacheService.getOfflineCachedData('classes_$teacherId');
          if (cachedData != null) {
            final classesJson = json.decode(cachedData) as List;
            _classes = classesJson.map((json) => Class.fromJson(json)).toList();
            debugPrint('⚠️ Using cached classes due to error: $e');
          }
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addClass(String name, String teacherId) async {
    if (teacherId == 'guest_teacher_id') {
         final newClass = Class(
          id: 'guest_class_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          teacherId: teacherId,
          createdAt: DateTime.now(),
        );
        _classes.add(newClass);
        notifyListeners();
        return;
    }
    final classObj = await ApiService.createClass(name, teacherId);
    _classes.add(classObj);
    notifyListeners();
  }

  Future<void> deleteClass(String classId) async {
    if (classId.startsWith('guest_class_')) {
      _classes.removeWhere((classObj) => classObj.id == classId);
      notifyListeners();
      return;
    }
    await ApiService.deleteClass(classId);
    _classes.removeWhere((classObj) => classObj.id == classId);
    notifyListeners();
  }

  Future<void> updateClass(String classId, String name) async {
    if (classId.startsWith('guest_class_')) {
      final index = _classes.indexWhere((classObj) => classObj.id == classId);
      if (index != -1) {
        _classes[index] = Class(
          id: classId,
          name: name,
          teacherId: _classes[index].teacherId,
          createdAt: _classes[index].createdAt,
        );
        notifyListeners();
      }
      return;
    }
    final updatedClass = await ApiService.updateClass(classId, name);
    final index = _classes.indexWhere((classObj) => classObj.id == classId);
    if (index != -1) {
      _classes[index] = updatedClass;
      notifyListeners();
    }
  }
}