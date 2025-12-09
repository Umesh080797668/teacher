import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/student.dart';
import '../models/attendance.dart';
import '../models/class.dart';
import '../models/payment.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;

  ApiException(this.message, {this.statusCode, this.errorCode});

  @override
  String toString() => message;
}

class ApiService {
  // For production (hosted backend), use the Vercel URL
  static const String baseUrl = 'https://teacher-eight-chi.vercel.app';

  // Timeout duration for all requests
  static const Duration timeout = Duration(seconds: 30);

  // Retry configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // Centralized HTTP request method with error handling
  static Future<http.Response> _makeRequest(
    String method,
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
    int retryCount = 0,
  }) async {
    final url = '$baseUrl$endpoint';
    final requestHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };

    try {
      late http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(Uri.parse(url), headers: requestHeaders).timeout(timeout);
          break;
        case 'POST':
          response = await http.post(
            Uri.parse(url),
            headers: requestHeaders,
            body: body != null ? (body is String ? body : json.encode(body)) : null,
          ).timeout(timeout);
          break;
        case 'PUT':
          response = await http.put(
            Uri.parse(url),
            headers: requestHeaders,
            body: body != null ? (body is String ? body : json.encode(body)) : null,
          ).timeout(timeout);
          break;
        case 'DELETE':
          response = await http.delete(Uri.parse(url), headers: requestHeaders).timeout(timeout);
          break;
        default:
          throw ApiException('Unsupported HTTP method: $method');
      }

      // Handle HTTP error status codes
      if (response.statusCode >= 400) {
        String errorMessage = 'Request failed';
        String? errorCode;

        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
          errorCode = errorData['code'];
        } catch (e) {
          // If response body is not JSON, use status code based messages
          errorMessage = _getErrorMessageFromStatusCode(response.statusCode);
        }

        throw ApiException(errorMessage, statusCode: response.statusCode, errorCode: errorCode);
      }

      return response;

    } on TimeoutException {
      if (retryCount < maxRetries) {
        await Future.delayed(retryDelay);
        return _makeRequest(method, endpoint, headers: headers, body: body, retryCount: retryCount + 1);
      }
      throw ApiException('Request timed out. Please check your internet connection and try again.');

    } on http.ClientException catch (e) {
      if (retryCount < maxRetries) {
        await Future.delayed(retryDelay);
        return _makeRequest(method, endpoint, headers: headers, body: body, retryCount: retryCount + 1);
      }
      throw ApiException('Network error: ${e.message}. Please check your internet connection.');

    } on FormatException {
      throw ApiException('Invalid response format from server. Please try again.');

    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred: ${e.toString()}');
    }
  }

  static String _getErrorMessageFromStatusCode(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Bad request. Please check your input.';
      case 401:
        return 'Authentication failed. Please check your credentials.';
      case 403:
        return 'Access denied. You may not have permission for this action.';
      case 404:
        return 'Service not found. Please try again later.';
      case 408:
        return 'Request timed out. Please try again.';
      case 429:
        return 'Too many requests. Please wait and try again.';
      case 500:
        return 'Server error. Please try again later.';
      case 502:
        return 'Service temporarily unavailable. Please try again later.';
      case 503:
        return 'Service unavailable. Please try again later.';
      default:
        return 'Request failed with status $statusCode. Please try again.';
    }
  }

  // Authentication methods
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _makeRequest('POST', '/api/auth/login', body: {
      'email': email,
      'password': password,
    });

    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> sendVerificationCode(String email) async {
    final response = await _makeRequest('POST', '/api/auth/send-verification-code', body: {
      'email': email,
    });

    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> verifyCode(String email, String code) async {
    final response = await _makeRequest('POST', '/api/auth/verify-code', body: {
      'email': email,
      'code': code,
    });

    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> registerTeacher({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await _makeRequest('POST', '/api/teachers', body: {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
    });

    return json.decode(response.body);
  }

  // Students
  static Future<List<Student>> getStudents() async {
    final response = await _makeRequest('GET', '/api/students');
    List<dynamic> data = json.decode(response.body);
    return data.map((json) => Student.fromJson(json)).toList();
  }

  static Future<Student> createStudent(String name, String? email, String? studentId, String? classId) async {
    final response = await _makeRequest('POST', '/api/students', body: {
      'name': name,
      'email': email,
      'studentId': studentId,
      'classId': classId,
    });

    return Student.fromJson(json.decode(response.body));
  }

  // Attendance
  static Future<List<Attendance>> getAttendance({String? studentId, int? month, int? year}) async {
    final queryParams = <String, String>{};
    if (studentId != null) queryParams['studentId'] = studentId;
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();

    final endpoint = Uri(path: '/api/attendance', queryParameters: queryParams).toString();
    final response = await _makeRequest('GET', endpoint);
    List<dynamic> data = json.decode(response.body);
    return data.map((json) => Attendance.fromJson(json)).toList();
  }

  static Future<Attendance> markAttendance(String studentId, DateTime date, String session, String status) async {
    final response = await _makeRequest('POST', '/api/attendance', body: {
      'studentId': studentId,
      'date': date.toIso8601String(),
      'session': session,
      'status': status,
    });

    return Attendance.fromJson(json.decode(response.body));
  }

  // Classes
  static Future<List<Class>> getClasses() async {
    final response = await _makeRequest('GET', '/api/classes');
    List<dynamic> data = json.decode(response.body);
    return data.map((json) => Class.fromJson(json)).toList();
  }

  static Future<Class> createClass(String name, String teacherId) async {
    final response = await _makeRequest('POST', '/api/classes', body: {
      'name': name,
      'teacherId': teacherId,
    });

    return Class.fromJson(json.decode(response.body));
  }

  static Future<void> deleteClass(String classId) async {
    await _makeRequest('DELETE', '/api/classes/$classId');
  }

  static Future<Class> updateClass(String classId, String name) async {
    final response = await _makeRequest('PUT', '/api/classes/$classId', body: {
      'name': name,
    });

    return Class.fromJson(json.decode(response.body));
  }

  // Payments
  static Future<List<Payment>> getPayments({String? classId, String? studentId}) async {
    final queryParams = <String, String>{};
    if (classId != null) queryParams['classId'] = classId;
    if (studentId != null) queryParams['studentId'] = studentId;

    final endpoint = Uri(path: '/api/payments', queryParameters: queryParams).toString();
    final response = await _makeRequest('GET', endpoint);
    List<dynamic> data = json.decode(response.body);
    return data.map((json) => Payment.fromJson(json)).toList();
  }

  static Future<Payment> createPayment(String studentId, String classId, double amount, String type) async {
    final response = await _makeRequest('POST', '/api/payments', body: {
      'studentId': studentId,
      'classId': classId,
      'amount': amount,
      'type': type,
    });

    return Payment.fromJson(json.decode(response.body));
  }

  static Future<void> deletePayment(String paymentId) async {
    await _makeRequest('DELETE', '/api/payments/$paymentId');
  }

  // Reports
  static Future<Map<String, dynamic>> getAttendanceSummary() async {
    final response = await _makeRequest('GET', '/api/reports/attendance-summary');
    return json.decode(response.body);
  }

  static Future<List<Map<String, dynamic>>> getStudentReports() async {
    final response = await _makeRequest('GET', '/api/reports/student-reports');
    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }

  static Future<List<Map<String, dynamic>>> getMonthlyStats() async {
    final response = await _makeRequest('GET', '/api/reports/monthly-stats');
    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }
}