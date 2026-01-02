import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../models/class.dart';
import '../models/payment.dart';
import '../models/home_stats.dart';
import 'cache_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;

  ApiException(this.message, {this.statusCode, this.errorCode});

  @override
  String toString() => message;
}

class ApiService {
  // For production (hosted backend), use multiple URLs for load balancing
  static const List<String> baseUrls = [
    'https://teacher-eight-chi.vercel.app',
    // Add more URLs if available for load balancing
  ];
  static int _currentUrlIndex = 0;

  static String get baseUrl {
    // Round-robin load balancing
    _currentUrlIndex = (_currentUrlIndex + 1) % baseUrls.length;
    return baseUrls[_currentUrlIndex];
  }

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
    bool useCache = false,
  }) async {
    final url = '$baseUrl$endpoint';

    // Check cache for GET requests
    if (method.toUpperCase() == 'GET' && useCache) {
      final cachedResponse = await CacheService.getCachedResponse(endpoint);
      if (cachedResponse != null) {
        return http.Response(cachedResponse, 200);
      }
    }

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

      // Cache successful GET responses
      if (method.toUpperCase() == 'GET' && useCache) {
        await CacheService.cacheResponse(endpoint, response.body);
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
          useCache: useCache,
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
          useCache: useCache,
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
          useCache: useCache,
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

  static Future<Map<String, dynamic>> checkTeacherStatus(String email) async {
    final response = await _makeRequest(
      'GET',
      '/api/auth/status?email=$email',
    );

    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> activateSubscription(String email, String subscriptionType) async {
    final response = await _makeRequest(
      'POST',
      '/api/auth/activate-subscription',
      body: {
        'email': email,
        'subscriptionType': subscriptionType,
      },
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

  static Future<Map<String, dynamic>> submitPaymentProof(
    String userEmail,
    String subscriptionType,
    String? paymentProofPath,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/auth/submit-payment-proof'),
    );

    request.fields['userEmail'] = userEmail;
    request.fields['subscriptionType'] = subscriptionType;

    if (paymentProofPath != null && File(paymentProofPath).existsSync()) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'paymentProof',
          paymentProofPath,
        ),
      );
    }

    // Add authorization header if available
    final prefs = await SharedPreferences.getInstance();
    final FlutterSecureStorage storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final streamedResponse = await request.send().timeout(timeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      throw ApiException(
        'Failed to submit payment proof: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
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

  static Future<Map<String, dynamic>> getTeacherStatus(String teacherId) async {
    final response = await _makeRequest('GET', '/api/teachers/$teacherId/status');

    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch teacher status', statusCode: response.statusCode);
    }

    return json.decode(response.body);
  }

  // Admin endpoint to activate teacher
  static Future<Map<String, dynamic>> activateTeacher(String teacherId) async {
    final response = await _makeRequest(
      'PUT',
      '/api/teachers/$teacherId/activate',
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to activate teacher', statusCode: response.statusCode);
    }

    return json.decode(response.body);
  }

  // Submit problem report
  static Future<Map<String, dynamic>> submitProblemReport({
    required String userEmail,
    required String issueDescription,
    String? appVersion,
    String? device,
    String? teacherId,
  }) async {
    final response = await _makeRequest(
      'POST',
      '/api/reports/problem',
      body: {
        'userEmail': userEmail,
        'issueDescription': issueDescription,
        'appVersion': appVersion,
        'device': device,
        'teacherId': teacherId,
        'userType': 'teacher',
      },
    );

    if (response.statusCode != 201) {
      throw ApiException('Failed to submit problem report', statusCode: response.statusCode);
    }

    return json.decode(response.body);
  }

  // Submit feature request
  static Future<Map<String, dynamic>> submitFeatureRequest({
    required String userEmail,
    required String featureDescription,
    required double bidPrice,
    String? appVersion,
    String? device,
    String? teacherId,
  }) async {
    final response = await _makeRequest(
      'POST',
      '/api/reports/feature-request',
      body: {
        'userEmail': userEmail,
        'featureDescription': featureDescription,
        'bidPrice': bidPrice,
        'appVersion': appVersion,
        'device': device,
        'teacherId': teacherId,
        'userType': 'teacher',
      },
    );

    if (response.statusCode != 201) {
      throw ApiException('Failed to submit feature request', statusCode: response.statusCode);
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

  static Future<Student> updateStudent(
    String studentId,
    String name,
    String? email,
    String? classId,
  ) async {
    final response = await _makeRequest(
      'PUT',
      '/api/students/$studentId',
      body: {
        'name': name,
        'email': email,
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
    final response = await _makeRequest('GET', endpoint, useCache: true);
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
    final response = await _makeRequest('GET', endpoint, useCache: true);
    return json.decode(response.body);
  }

  static Future<List<Map<String, dynamic>>> getStudentReports({String? teacherId}) async {
    final queryParams = <String, String>{};
    if (teacherId != null) queryParams['teacherId'] = teacherId;

    final endpoint = Uri(
      path: '/api/reports/student-reports',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    ).toString();
    final response = await _makeRequest('GET', endpoint, useCache: true);
    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }

  static Future<List<Map<String, dynamic>>> getMonthlyStats({String? teacherId}) async {
    final queryParams = <String, String>{};
    if (teacherId != null) queryParams['teacherId'] = teacherId;

    final endpoint = Uri(
      path: '/api/reports/monthly-stats',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    ).toString();
    final response = await _makeRequest('GET', endpoint, useCache: true);
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
    final response = await _makeRequest('GET', endpoint, useCache: true);
    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }

  static Future<List<Map<String, dynamic>>> getMonthlyByClass({String? teacherId}) async {
    final queryParams = <String, String>{};
    if (teacherId != null) queryParams['teacherId'] = teacherId;

    final endpoint = Uri(
      path: '/api/reports/monthly-by-class',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    ).toString();
    final response = await _makeRequest('GET', endpoint, useCache: true);
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
    final response = await _makeRequest('GET', endpoint, useCache: true);
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
