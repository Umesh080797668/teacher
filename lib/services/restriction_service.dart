import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class RestrictionService {
  final String baseUrl = ApiService.baseUrl;

  /// Check if teacher is restricted
  Future<Map<String, dynamic>> checkTeacherRestrictionStatus(String teacherId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/teacher/restriction-status/$teacherId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to check restriction status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error checking teacher restriction status: $e');
      rethrow;
    }
  }

  /// Check if student is restricted
  Future<Map<String, dynamic>> checkStudentRestrictionStatus(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/student/restriction-status/$studentId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to check restriction status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error checking student restriction status: $e');
      rethrow;
    }
  }

  /// Super Admin: Get all teachers
  Future<List<dynamic>> getAllTeachers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/super-admin/teachers'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch teachers: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching teachers: $e');
      rethrow;
    }
  }

  /// Super Admin: Get all students
  Future<List<dynamic>> getAllStudents() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/super-admin/students'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch students: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching students: $e');
      rethrow;
    }
  }

  /// Super Admin: Restrict teacher
  Future<Map<String, dynamic>> restrictTeacher({
    required String teacherId,
    required String adminId,
    String? reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/super-admin/restrict-teacher'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'teacherId': teacherId,
          'adminId': adminId,
          'reason': reason ?? 'No reason provided',
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to restrict teacher: ${response.statusCode}');
      }
    } catch (e) {
      print('Error restricting teacher: $e');
      rethrow;
    }
  }

  /// Super Admin: Unrestrict teacher
  Future<Map<String, dynamic>> unrestrictTeacher(String teacherId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/super-admin/unrestrict-teacher'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'teacherId': teacherId,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to unrestrict teacher: ${response.statusCode}');
      }
    } catch (e) {
      print('Error unrestricting teacher: $e');
      rethrow;
    }
  }

  /// Super Admin: Restrict student
  Future<Map<String, dynamic>> restrictStudent({
    required String studentId,
    required String adminId,
    String? reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/super-admin/restrict-student'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'studentId': studentId,
          'adminId': adminId,
          'reason': reason ?? 'No reason provided',
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to restrict student: ${response.statusCode}');
      }
    } catch (e) {
      print('Error restricting student: $e');
      rethrow;
    }
  }

  /// Super Admin: Unrestrict student
  Future<Map<String, dynamic>> unrestrictStudent(String studentId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/super-admin/unrestrict-student'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'studentId': studentId,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to unrestrict student: ${response.statusCode}');
      }
    } catch (e) {
      print('Error unrestricting student: $e');
      rethrow;
    }
  }

  /// Teacher: Get students in their classes
  Future<List<dynamic>> getTeacherStudents() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/teacher/students'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await ApiService.getToken()}',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch students: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching teacher students: $e');
      rethrow;
    }
  }

  /// Teacher: Restrict a student
  Future<Map<String, dynamic>> restrictStudentByTeacher({
    required String studentId,
    String? reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/teacher/restrict-student'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await ApiService.getToken()}',
        },
        body: json.encode({
          'studentId': studentId,
          'reason': reason ?? 'Restricted by teacher',
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to restrict student: ${response.statusCode}');
      }
    } catch (e) {
      print('Error restricting student: $e');
      rethrow;
    }
  }

  /// Teacher: Unrestrict a student
  Future<Map<String, dynamic>> unrestrictStudentByTeacher(String studentId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/teacher/unrestrict-student'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await ApiService.getToken()}',
        },
        body: json.encode({
          'studentId': studentId,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to unrestrict student: ${response.statusCode}');
      }
    } catch (e) {
      print('Error unrestricting student: $e');
      rethrow;
    }
  }
}
