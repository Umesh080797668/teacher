import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/student.dart';
import '../models/attendance.dart';
import '../models/class.dart';
import '../models/payment.dart';
import '../models/home_stats.dart';

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
    final requestHeaders = {'Content-Type': 'application/json', ...?headers};

    try {
      late http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http
              .get(Uri.parse(url), headers: requestHeaders)
              .timeout(timeout);
          break;
        case 'POST':
          response = await http
              .post(
                Uri.parse(url),
                headers: requestHeaders,
                body: body != null
                    ? (body is String ? body : json.encode(body))
                    : null,
              )
              .timeout(timeout);
          break;
        case 'PUT':
          response = await http
              .put(
                Uri.parse(url),
                headers: requestHeaders,
                body: body != null
                    ? (body is String ? body : json.encode(body))
                    : null,
              )
              .timeout(timeout);
          break;
        case 'DELETE':
          response = await http
              .delete(Uri.parse(url), headers: requestHeaders)
              .timeout(timeout);
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
          errorMessage =
              errorData['error'] ?? errorData['message'] ?? errorMessage;
          errorCode = errorData['code'];
        } catch (e) {
          // If response body is not JSON, use status code based messages
          errorMessage = _getErrorMessageFromStatusCode(response.statusCode);
        }

        // Throw ApiException without printing to console
        throw ApiException(
          errorMessage,
          statusCode: response.statusCode,
          errorCode: errorCode,
        );
      }

      return response;
    } on TimeoutException {
      if (retryCount < maxRetries) {
        await Future.delayed(retryDelay);
        return _makeRequest(
          method,
          endpoint,
          headers: headers,
          body: body,
          retryCount: retryCount + 1,
        );
      }
      throw ApiException(
        'Request timed out. Please check your internet connection and try again.',
      );
    } on SocketException catch (e) {
      if (retryCount < maxRetries) {
        await Future.delayed(retryDelay);
        return _makeRequest(
          method,
          endpoint,
          headers: headers,
          body: body,
          retryCount: retryCount + 1,
        );
      }
      // Handle SSL/TLS errors specifically
      if (e.message.contains('CERTIFICATE_VERIFY_FAILED') ||
          e.message.contains('Handshake error') ||
          e.message.contains('SSL') ||
          e.message.contains('TLS')) {
        throw ApiException(
          'Secure connection failed. Please check your device date/time settings or update your system.',
        );
      }
      throw ApiException(
        'Network error. Please check your internet connection and try again.',
      );
    } on HandshakeException {
      throw ApiException(
        'Secure connection failed. Please ensure your device has the latest security updates and correct date/time settings.',
      );
    } on http.ClientException {
      if (retryCount < maxRetries) {
        await Future.delayed(retryDelay);
        return _makeRequest(
          method,
          endpoint,
          headers: headers,
          body: body,
          retryCount: retryCount + 1,
        );
      }
      // Don't expose internal error details to avoid console errors
      throw ApiException(
        'Network error. Please check your internet connection and try again.',
      );
    } on FormatException {
      throw ApiException(
        'Invalid response format from server. Please try again.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      // Catch all other exceptions and provide user-friendly message without exposing details
      throw ApiException(
        'Unable to connect to server. Please check your connection and try again.',
      );
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
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await _makeRequest(
      'POST',
      '/api/auth/login',
      body: {'email': email, 'password': password},
    );

    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> sendVerificationCode(String email) async {
    final response = await _makeRequest(
      'POST',
      '/api/auth/send-verification-code',
      body: {'email': email},
    );

    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> verifyCode(
    String email,
    String code,
  ) async {
    final response = await _makeRequest(
      'POST',
      '/api/auth/verify-code',
      body: {'email': email, 'code': code},
    );

    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> forgotPasswordRequest(
    String email,
  ) async {
    final response = await _makeRequest(
      'POST',
      '/api/auth/forgot-password',
      body: {'email': email},
    );

    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> resetPassword(
    String email,
    String resetCode,
    String newPassword,
  ) async {
    final response = await _makeRequest(
      'POST',
      '/api/auth/reset-password',
      body: {
        'email': email,
        'resetCode': resetCode,
        'newPassword': newPassword,
      },
    );

    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> registerTeacher({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await _makeRequest(
      'POST',
      '/api/teachers',
      body: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
      },
    );

    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> updateTeacher(String teacherId, Map<String, dynamic> updateData) async {
    final response = await _makeRequest(
      'PUT',
      '/api/teachers/$teacherId',
      body: updateData,
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to update teacher', statusCode: response.statusCode);
    }

    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> getTeacher(String teacherId) async {
    final response = await _makeRequest('GET', '/api/teachers/$teacherId');

    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch teacher', statusCode: response.statusCode);
    }

    return json.decode(response.body);
  }

  // Students
  static Future<List<Student>> getStudents({String? teacherId}) async {
    final queryParams = <String, String>{};
    if (teacherId != null) queryParams['teacherId'] = teacherId;

    final endpoint = Uri(
      path: '/api/students',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    ).toString();
    final response = await _makeRequest('GET', endpoint);
    List<dynamic> data = json.decode(response.body);
    return data.map((json) => Student.fromJson(json)).toList();
  }

  static Future<Student> createStudent(
    String name,
    String? email,
    String? studentId,
    String? classId,
  ) async {
    final response = await _makeRequest(
      'POST',
      '/api/students',
      body: {
        'name': name,
        'email': email,
        'studentId': studentId,
        'classId': classId,
      },
    );

    return Student.fromJson(json.decode(response.body));
  }

  static Future<void> deleteStudent(String studentId) async {
    await _makeRequest('DELETE', '/api/students/$studentId');
  }

  // Attendance
  static Future<List<Attendance>> getAttendance({
    String? studentId,
    int? month,
    int? year,
    String? teacherId,
  }) async {
    final queryParams = <String, String>{};
    if (studentId != null) queryParams['studentId'] = studentId;
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();
    if (teacherId != null) queryParams['teacherId'] = teacherId;

    final endpoint = Uri(
      path: '/api/attendance',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    ).toString();
    final response = await _makeRequest('GET', endpoint);
    List<dynamic> data = json.decode(response.body);
    return data.map((json) => Attendance.fromJson(json)).toList();
  }

  static Future<Attendance> markAttendance(
    String studentId,
    DateTime date,
    String session,
    String status,
  ) async {
    final response = await _makeRequest(
      'POST',
      '/api/attendance',
      body: {
        'studentId': studentId,
        'date': date.toIso8601String(),
        'session': session,
        'status': status,
      },
    );

    return Attendance.fromJson(json.decode(response.body));
  }

  // Classes
  static Future<List<Class>> getClasses({String? teacherId}) async {
    final endpoint = teacherId != null ? '/api/classes?teacherId=$teacherId' : '/api/classes';
    final response = await _makeRequest('GET', endpoint);
    List<dynamic> data = json.decode(response.body);
    return data.map((json) => Class.fromJson(json)).toList();
  }

  static Future<Class> createClass(String name, String teacherId) async {
    final response = await _makeRequest(
      'POST',
      '/api/classes',
      body: {'name': name, 'teacherId': teacherId},
    );

    return Class.fromJson(json.decode(response.body));
  }

  static Future<void> deleteClass(String classId) async {
    await _makeRequest('DELETE', '/api/classes/$classId');
  }

  static Future<Class> updateClass(String classId, String name) async {
    final response = await _makeRequest(
      'PUT',
      '/api/classes/$classId',
      body: {'name': name},
    );

    return Class.fromJson(json.decode(response.body));
  }

  // Payments
  static Future<List<Payment>> getPayments({
    String? classId,
    String? studentId,
    String? teacherId,
  }) async {
    final queryParams = <String, String>{};
    if (classId != null) queryParams['classId'] = classId;
    if (studentId != null) queryParams['studentId'] = studentId;
    if (teacherId != null) queryParams['teacherId'] = teacherId;

    final endpoint = Uri(
      path: '/api/payments',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    ).toString();
    final response = await _makeRequest('GET', endpoint);
    List<dynamic> data = json.decode(response.body);
    return data.map((json) => Payment.fromJson(json)).toList();
  }

  static Future<Payment> createPayment(
    String studentId,
    String classId,
    double amount,
    String type, {
    int? month,
  }) async {
    final response = await _makeRequest(
      'POST',
      '/api/payments',
      body: {
        'studentId': studentId,
        'classId': classId,
        'amount': amount,
        'type': type,
        if (month != null) 'month': month,
      },
    );

    return Payment.fromJson(json.decode(response.body));
  }

  static Future<void> deletePayment(String paymentId) async {
    await _makeRequest('DELETE', '/api/payments/$paymentId');
  }

  // Get payments as raw map data for reports
  static Future<List<Map<String, dynamic>>> getPaymentsMap({
    String? classId,
    String? studentId,
    String? teacherId,
  }) async {
    final queryParams = <String, String>{};
    if (classId != null) queryParams['classId'] = classId;
    if (studentId != null) queryParams['studentId'] = studentId;
    if (teacherId != null) queryParams['teacherId'] = teacherId;

    final endpoint = Uri(
      path: '/api/payments',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    ).toString();
    final response = await _makeRequest('GET', endpoint);
    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }

  // Reports
  static Future<Map<String, dynamic>> getAttendanceSummary({String? teacherId}) async {
    final queryParams = <String, String>{};
    if (teacherId != null) queryParams['teacherId'] = teacherId;

    final endpoint = Uri(
      path: '/api/reports/attendance-summary',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    ).toString();
    final response = await _makeRequest('GET', endpoint);
    return json.decode(response.body);
  }

  static Future<List<Map<String, dynamic>>> getStudentReports({String? teacherId}) async {
    final queryParams = <String, String>{};
    if (teacherId != null) queryParams['teacherId'] = teacherId;

    final endpoint = Uri(
      path: '/api/reports/student-reports',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    ).toString();
    final response = await _makeRequest('GET', endpoint);
    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }

  static Future<List<Map<String, dynamic>>> getMonthlyStats({String? teacherId}) async {
    final queryParams = <String, String>{};
    if (teacherId != null) queryParams['teacherId'] = teacherId;

    final endpoint = Uri(
      path: '/api/reports/monthly-stats',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    ).toString();
    final response = await _makeRequest('GET', endpoint);
    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }

  static Future<List<Map<String, dynamic>>> getDailyByClass({String? teacherId, String? date}) async {
    final queryParams = <String, String>{};
    if (teacherId != null) queryParams['teacherId'] = teacherId;
    if (date != null) queryParams['date'] = date;

    final endpoint = Uri(
      path: '/api/reports/daily-by-class',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    ).toString();
    final response = await _makeRequest('GET', endpoint);
    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }

  static Future<List<Map<String, dynamic>>> getMonthlyByClass({String? teacherId}) async {
    final queryParams = <String, String>{};
    if (teacherId != null) queryParams['teacherId'] = teacherId;

    final endpoint = Uri(
      path: '/api/reports/monthly-by-class',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    ).toString();
    final response = await _makeRequest('GET', endpoint);
    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }

  static Future<Map<String, dynamic>> getClassStudentDetails({
    required String classId,
    required int month,
    required int year,
  }) async {
    final queryParams = <String, String>{
      'classId': classId,
      'month': month.toString(),
      'year': year.toString(),
    };

    final endpoint = Uri(
      path: '/api/reports/class-student-details',
      queryParameters: queryParams,
    ).toString();
    final response = await _makeRequest('GET', endpoint);
    return json.decode(response.body) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getMonthlyEarningsByClass({
    String? teacherId, 
    int? year, 
    int? month
  }) async {
    final queryParams = <String, String>{};
    if (teacherId != null) queryParams['teacherId'] = teacherId;
    if (year != null) queryParams['year'] = year.toString();
    if (month != null) queryParams['month'] = month.toString();

    final endpoint = Uri(
      path: '/api/reports/monthly-earnings-by-class',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    ).toString();
    final response = await _makeRequest('GET', endpoint);
    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }

  // Home Dashboard
  static Future<HomeStats> getHomeStats({String? teacherId}) async {
    final queryParams = <String, String>{};
    if (teacherId != null) queryParams['teacherId'] = teacherId;

    final endpoint = Uri(
      path: '/api/home/stats',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    ).toString();
    final response = await _makeRequest('GET', endpoint);
    final data = json.decode(response.body);
    return HomeStats.fromJson(data);
  }

  static Future<List<RecentActivity>> getRecentActivities({String? teacherId}) async {
    final queryParams = <String, String>{};
    if (teacherId != null) queryParams['teacherId'] = teacherId;

    final endpoint = Uri(
      path: '/api/home/activities',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    ).toString();
    final response = await _makeRequest('GET', endpoint);
    final data = json.decode(response.body);
    return (data as List).map((item) => RecentActivity.fromJson(item)).toList();
  }
}
