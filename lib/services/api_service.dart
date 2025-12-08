import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/student.dart';
import '../models/attendance.dart';
import '../models/class.dart';
import '../models/payment.dart';

class ApiService {
  // For production (hosted backend), use the Vercel URL
  static const String baseUrl = 'https://teacher-psi-drab.vercel.app';

  // Students
  Future<List<Student>> getStudents() async {
    final response = await http.get(Uri.parse('$baseUrl/api/students'));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => Student.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load students');
    }
  }

  Future<Student> createStudent(String name, String? email, String studentId, String? classId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/students'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': name,
        'email': email,
        'studentId': studentId,
        'classId': classId,
      }),
    );
    if (response.statusCode == 201) {
      return Student.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create student');
    }
  }

  // Attendance
  Future<List<Attendance>> getAttendance({String? studentId, int? month, int? year}) async {
    final queryParams = <String, String>{};
    if (studentId != null) queryParams['studentId'] = studentId;
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();

    final uri = Uri.parse('$baseUrl/api/attendance').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => Attendance.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load attendance');
    }
  }

  Future<Attendance> markAttendance(String studentId, DateTime date, String session, String status) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/attendance'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'studentId': studentId,
        'date': date.toIso8601String(),
        'session': session,
        'status': status,
      }),
    );
    if (response.statusCode == 201) {
      return Attendance.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to mark attendance');
    }
  }

  // Classes
  Future<List<Class>> getClasses() async {
    final response = await http.get(Uri.parse('$baseUrl/api/classes'));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => Class.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load classes');
    }
  }

  Future<Class> createClass(String name, String teacherId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/classes'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': name,
        'teacherId': teacherId,
      }),
    );
    if (response.statusCode == 201) {
      return Class.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create class');
    }
  }

  Future<void> deleteClass(String classId) async {
    final response = await http.delete(Uri.parse('$baseUrl/api/classes/$classId'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete class');
    }
  }

  // Payments
  Future<List<Payment>> getPayments({String? classId, String? studentId}) async {
    final queryParams = <String, String>{};
    if (classId != null) queryParams['classId'] = classId;
    if (studentId != null) queryParams['studentId'] = studentId;

    final uri = Uri.parse('$baseUrl/api/payments').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => Payment.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load payments');
    }
  }

  Future<Payment> createPayment(String studentId, String classId, double amount, String type) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/payments'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'studentId': studentId,
        'classId': classId,
        'amount': amount,
        'type': type,
      }),
    );
    if (response.statusCode == 201) {
      return Payment.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create payment');
    }
  }

  Future<void> deletePayment(String paymentId) async {
    final response = await http.delete(Uri.parse('$baseUrl/api/payments/$paymentId'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete payment');
    }
  }

  // Reports
  Future<Map<String, dynamic>> getAttendanceSummary() async {
    final response = await http.get(Uri.parse('$baseUrl/api/reports/attendance-summary'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load attendance summary');
    }
  }

  Future<List<Map<String, dynamic>>> getStudentReports() async {
    final response = await http.get(Uri.parse('$baseUrl/api/reports/student-reports'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load student reports');
    }
  }

  Future<List<Map<String, dynamic>>> getMonthlyStats() async {
    final response = await http.get(Uri.parse('$baseUrl/api/reports/monthly-stats'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load monthly stats');
    }
  }
}