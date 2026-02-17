import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../models/class.dart';
import '../models/payment.dart';
import '../models/home_stats.dart';
import '../models/quiz.dart';
import 'cache_service.dart';

// Helper functions for parsing JSON in separate isolates
List<Student> _parseStudents(String responseBody) {
  final parsed = json.decode(responseBody) as List<dynamic>;
  return parsed.map<Student>((json) => Student.fromJson(json)).toList();
}

List<Attendance> _parseAttendance(String responseBody) {
  final parsed = json.decode(responseBody) as List<dynamic>;
  return parsed.map<Attendance>((json) => Attendance.fromJson(json)).toList();
}

List<RecentActivity> _parseRecentActivities(String responseBody) {
  final parsed = json.decode(responseBody) as List<dynamic>;
  return parsed.map<RecentActivity>((json) => RecentActivity.fromJson(json)).toList();
}

Map<String, dynamic> _parseAttendanceSummary(String responseBody) {
  return json.decode(responseBody) as Map<String, dynamic>;
}

List<Map<String, dynamic>> _parseListMap(String responseBody) {
  final parsed = json.decode(responseBody) as List<dynamic>;
  return parsed.cast<Map<String, dynamic>>();
}

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
  static final Map<String, DateTime> _urlHealthStatus = {};
  static final Map<String, int> _urlFailureCount = {};
  static const int maxFailuresBeforeSkip = 3;
  static const Duration healthCheckInterval = Duration(minutes: 5);

  static String get baseUrl {
    // Advanced load balancing with health checking
    DateTime now = DateTime.now();
    
    // Try to find a healthy URL
    for (int i = 0; i < baseUrls.length; i++) {
      _currentUrlIndex = (_currentUrlIndex + 1) % baseUrls.length;
      String url = baseUrls[_currentUrlIndex];
      
      int failures = _urlFailureCount[url] ?? 0;
      DateTime? lastCheck = _urlHealthStatus[url];
      
      // Skip if too many failures and not enough time has passed
      if (failures >= maxFailuresBeforeSkip && lastCheck != null) {
        if (now.difference(lastCheck) < healthCheckInterval) {
          continue;
        }
      }
      
      return url;
    }
    
    // If all URLs are unhealthy, reset and try first one
    _urlFailureCount.clear();
    _urlHealthStatus.clear();
    _currentUrlIndex = 0;
    return baseUrls[_currentUrlIndex];
  }
  
  static void _recordSuccess(String url) {
    _urlFailureCount[url] = 0;
    _urlHealthStatus[url] = DateTime.now();
  }
  
  static void _recordFailure(String url) {
    _urlFailureCount[url] = (_urlFailureCount[url] ?? 0) + 1;
    _urlHealthStatus[url] = DateTime.now();
  }

  // Get stored authentication token
  static Future<String?> getToken() async {
    try {
      const FlutterSecureStorage storage = FlutterSecureStorage();
      return await storage.read(key: 'auth_token');
    } catch (e) {
      print('Error getting token: $e');
      return null;
    }
  }

  // Timeout duration for all requests
  static const Duration timeout = Duration(seconds: 30);

  // Retry configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  // Connection pooling configuration
  static http.Client? _httpClient;
  static http.Client get httpClient {
    _httpClient ??= http.Client();
    return _httpClient!;
  }
  
  /// Dispose HTTP client when app closes
  static void dispose() {
    _httpClient?.close();
    _httpClient = null;
  }

  // Centralized HTTP request method with error handling
  static Future<http.Response> _makeRequest(
    String method,
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
    int retryCount = 0,
    bool useCache = false,
    bool useCacheFallback = true, // NEW: Allow fallback to cache on error
  }) async {
    final currentBaseUrl = baseUrl;
    final url = '$currentBaseUrl$endpoint';

    // Check cache for GET requests
    if (method.toUpperCase() == 'GET' && useCache) {
      final cachedResponse = await CacheService.getCachedResponse(endpoint);
      if (cachedResponse != null) {
        return http.Response(cachedResponse, 200);
      }
    }

    // Get token and add to headers
    final token = await getToken();
    final requestHeaders = {'Content-Type': 'application/json', ...?headers};
    if (token != null) {
      requestHeaders['Authorization'] = 'Bearer $token';
    }

    try {
      late http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await httpClient
              .get(Uri.parse(url), headers: requestHeaders)
              .timeout(timeout);
          break;
        case 'POST':
          response = await httpClient
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
          response = await httpClient
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
          response = await httpClient
              .delete(Uri.parse(url), headers: requestHeaders)
              .timeout(timeout);
          break;
        default:
          throw ApiException('Unsupported HTTP method: $method');
      }

      // Handle HTTP error status codes
      if (response.statusCode >= 400) {
        _recordFailure(currentBaseUrl);
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
      
      // Record successful request
      _recordSuccess(currentBaseUrl);

      // Cache successful GET responses (both normal and offline cache)
      if (method.toUpperCase() == 'GET' && useCache) {
        await CacheService.cacheResponse(endpoint, response.body);
        // Also save to offline cache for weak connection scenarios
        await CacheService.cacheOfflineData(endpoint, response.body);
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
          useCacheFallback: useCacheFallback,
        );
      }
      
      // SOLUTION FOR PROBLEM 2: Fallback to any cached data if connection times out
      if (method.toUpperCase() == 'GET' && useCacheFallback) {
        final anyCachedData = await CacheService.getAnyCachedData(endpoint);
        if (anyCachedData != null) {
          debugPrint('⚠️ Using cached fallback data for $endpoint due to timeout');
          return http.Response(anyCachedData, 200);
        }
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
          useCacheFallback: useCacheFallback,
        );
      }
      
      // SOLUTION FOR PROBLEM 2: Fallback to cached data on network error
      if (method.toUpperCase() == 'GET' && useCacheFallback) {
        final anyCachedData = await CacheService.getAnyCachedData(endpoint);
        if (anyCachedData != null) {
          debugPrint('⚠️ Using cached fallback data for $endpoint due to network error');
          return http.Response(anyCachedData, 200);
        }
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
          useCacheFallback: useCacheFallback,
        );
      }
      
      // SOLUTION FOR PROBLEM 2: Fallback to cached data on client error
      if (method.toUpperCase() == 'GET' && useCacheFallback) {
        final anyCachedData = await CacheService.getAnyCachedData(endpoint);
        if (anyCachedData != null) {
          debugPrint('⚠️ Using cached fallback data for $endpoint due to client error');
          return http.Response(anyCachedData, 200);
        }
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
  // Submit problem report with optional images
  static Future<Map<String, dynamic>> submitProblemReport({
    required String userEmail,
    required String issueDescription,
    String? appVersion,
    String? device,
    String? deviceName,
    String? teacherId,
    List<File>? images,
  }) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/api/reports/problem');
    
    if (images == null || images.isEmpty) {
      // If no images, use regular POST request
      final response = await _makeRequest(
        'POST',
        '/api/reports/problem',
        body: {
          'userEmail': userEmail,
          'issueDescription': issueDescription,
          'appVersion': appVersion,
          'device': device,
          'deviceName': deviceName,
          'teacherId': teacherId,
          'userType': 'teacher',
        },
      );

      if (response.statusCode != 201) {
        throw ApiException('Failed to submit problem report', statusCode: response.statusCode);
      }

      return json.decode(response.body);
    }

    // If images present, use multipart request
    final request = http.MultipartRequest('POST', uri);
    
    // Add headers
    request.headers['Authorization'] = 'Bearer $token';
    
    // Add fields
    request.fields['userEmail'] = userEmail;
    request.fields['issueDescription'] = issueDescription;
    if (appVersion != null) request.fields['appVersion'] = appVersion;
    if (device != null) request.fields['device'] = device;
    if (deviceName != null) request.fields['deviceName'] = deviceName;
    if (teacherId != null) request.fields['teacherId'] = teacherId;
    request.fields['userType'] = 'teacher';
    
    // Add images
    for (int i = 0; i < images.length; i++) {
      final file = images[i];
      request.files.add(
        await http.MultipartFile.fromPath(
          'images',
          file.path,
          filename: 'image_$i.jpg',
        ),
      );
    }

    try {
      final response = await request.send().timeout(timeout);
      
      if (response.statusCode != 201) {
        throw ApiException(
          'Failed to submit problem report',
          statusCode: response.statusCode,
        );
      }

      final responseBody = await response.stream.bytesToString();
      return json.decode(responseBody);
    } catch (e) {
      rethrow;
    }
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
    // Use the new teacher endpoint that includes restriction data
    final endpoint = teacherId != null ? '/api/teacher/students?teacherId=$teacherId' : '/api/teacher/students';
    final response = await _makeRequest('GET', endpoint);
    
    // Use compute to parse in background isolate
    return compute(_parseStudents, response.body);
  }

  // Get students by class
  static Future<List<Student>> getStudentsByClass(String classId) async {
    final response = await _makeRequest('GET', '/api/students?classId=$classId');
    
    // Use compute to parse in background isolate
    return compute(_parseStudents, response.body);
  }

  static Future<Student> createStudent(
    String name,
    String? email,
    String? phoneNumber,
    String? studentId,
    String? classId,
  ) async {
    final response = await _makeRequest(
      'POST',
      '/api/students',
      body: {
        'name': name,
        'email': email,
        'phoneNumber': phoneNumber,
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
    String? phoneNumber,
    String? classId,
  ) async {
    final Map<String, dynamic> body = {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'classId': classId,
    };

    final response = await _makeRequest(
      'PUT',
      '/api/students/$studentId',
      body: body,
    );

    return Student.fromJson(json.decode(response.body));
  }

  static Future<Student> updateFaceData(String studentId, List<double> embedding) async {
    final response = await _makeRequest(
      'PUT',
      '/api/students/$studentId',
      body: {
        'hasFaceData': true,
        'faceEmbedding': embedding
      },
    );

    return Student.fromJson(json.decode(response.body));
  }

  static Future<void> deleteStudent(String studentId) async {
    debugPrint('ApiService: Attempting to delete student with ID: "$studentId"');
    try {
      final response = await _makeRequest('DELETE', '/api/students/${studentId.trim()}');
      debugPrint('ApiService: Delete response status: ${response.statusCode}');
      debugPrint('ApiService: Delete response body: ${response.body}');
    } catch (e) {
      debugPrint('ApiService: Error deleting student: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> sendSMS(List<String> recipients, String message) async {
    final response = await _makeRequest(
      'POST',
      '/api/sms/send',
      body: {
        'to': recipients,
        'body': message,
      },
    );
    return json.decode(response.body);
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
    
    // Use compute to parse in background isolate
    return compute(_parseAttendance, response.body);
  }

  static Future<Attendance?> markAttendance(
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

    final responseData = json.decode(response.body);
    
    // If status is empty, we're deleting and response format is different
    if (status.isEmpty) {
      // Return null to indicate deletion
      return null;
    }
    
    return Attendance.fromJson(responseData);
  }

  // Get batch attendance for multiple students on a specific date (faster than individual requests)
  static Future<Map<String, String>> getBatchAttendance(
    List<String> studentIds,
    DateTime date,
  ) async {
    if (studentIds.isEmpty) {
      return {};
    }
    
    final response = await _makeRequest(
      'POST',
      '/api/attendance/batch',
      body: {
        'studentIds': studentIds,
        'date': date.toIso8601String(),
      },
    );

    final Map<String, dynamic> data = json.decode(response.body);
    return data.cast<String, String>();
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

    // If a studentId is provided, use the dedicated student payments endpoint
    if (studentId != null) {
      final endpoint = Uri(
        path: '/api/student/payments',
        queryParameters: {'studentId': studentId},
      ).toString();

      final response = await _makeRequest('GET', endpoint);
      // This endpoint returns an object: { success: true, payments: [...] }
      final Map<String, dynamic> body = json.decode(response.body);
      if (body['success'] == true && body['payments'] is List) {
        return (body['payments'] as List).map((json) => Payment.fromJson(json)).toList();
      }
      return [];
    }

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
    int? year,
    DateTime? recordingDate,
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
        if (year != null) 'year': year,
        if (recordingDate != null) 'recordingDate': recordingDate.toIso8601String(),
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
    
    // Background parse
    return compute(_parseAttendanceSummary, response.body);
  }

  static Future<List<Map<String, dynamic>>> getStudentReports({String? teacherId}) async {
    final queryParams = <String, String>{};
    if (teacherId != null) queryParams['teacherId'] = teacherId;

    final endpoint = Uri(
      path: '/api/reports/student-reports',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    ).toString();
    final response = await _makeRequest('GET', endpoint, useCache: true);
    
    // Background parse
    return compute(_parseListMap, response.body);
  }

  static Future<List<Map<String, dynamic>>> getMonthlyStats({String? teacherId}) async {
    final queryParams = <String, String>{};
    if (teacherId != null) queryParams['teacherId'] = teacherId;

    final endpoint = Uri(
      path: '/api/reports/monthly-stats',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    ).toString();
    final response = await _makeRequest('GET', endpoint, useCache: true);
    
    // Background parse
    return compute(_parseListMap, response.body);
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
    
    // Background parse
    return compute(_parseListMap, response.body);
  }

  static Future<List<Map<String, dynamic>>> getMonthlyByClass({String? teacherId}) async {
    final queryParams = <String, String>{};
    if (teacherId != null) queryParams['teacherId'] = teacherId;

    final endpoint = Uri(
      path: '/api/reports/monthly-by-class',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    ).toString();
    final response = await _makeRequest('GET', endpoint, useCache: true);
    
    // Background parse
    return compute(_parseListMap, response.body);
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
    final token = await getToken();
    final queryParams = <String, String>{};
    if (teacherId != null) queryParams['teacherId'] = teacherId;

    final endpoint = Uri(
      path: '/api/home/stats',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    ).toString();
    final headers = token != null ? {'Authorization': 'Bearer $token'} : <String, String>{};
    final response = await _makeRequest('GET', endpoint, headers: headers);
    final data = json.decode(response.body);
    return HomeStats.fromJson(data);
  }

  static Future<List<RecentActivity>> getRecentActivities({String? teacherId}) async {
    final token = await getToken();
    final queryParams = <String, String>{};
    if (teacherId != null) queryParams['teacherId'] = teacherId;

    final endpoint = Uri(
      path: '/api/home/activities',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    ).toString();
    final headers = token != null ? {'Authorization': 'Bearer $token'} : <String, String>{};
    final response = await _makeRequest('GET', endpoint, headers: headers);
    
    // Use compute to parse in background isolate
    return compute(_parseRecentActivities, response.body);
  }

  static Future<void> markSubscriptionWarningShown(String teacherEmail) async {
    await _makeRequest(
      'POST',
      '/api/teacher/subscription-warning-shown',
      body: {
        'teacherEmail': teacherEmail,
      },
    );
  }
  // Quiz Methods
  static Future<List<Quiz>> getQuizzes() async {
    final token = await getToken();
    final headers = token != null ? {'Authorization': 'Bearer $token'} : <String, String>{};
    final response = await _makeRequest('GET', '/api/quizzes', headers: headers);
    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => Quiz.fromJson(json)).toList();
  }

  static Future<Quiz> createQuiz(Quiz quiz) async {
    final token = await getToken();
    final headers = token != null ? {'Authorization': 'Bearer $token'} : <String, String>{};
    final response = await _makeRequest('POST', '/api/quizzes', 
      headers: headers, 
      body: quiz.toJson()
    );
    return Quiz.fromJson(json.decode(response.body));
  }

  static Future<List<QuizResult>> getQuizResults(String quizId) async {
    final token = await getToken();
    final headers = token != null ? {'Authorization': 'Bearer $token'} : <String, String>{};
    final response = await _makeRequest('GET', '/api/quizzes/$quizId/results', headers: headers);
    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => QuizResult.fromJson(json)).toList();
  }

  // ==========================================
  // NEW FEATURES: Resources, Notices, Insights
  // ==========================================

  // Upload Resource
  static Future<void> uploadResource(String classId, String title, String description, File file, String teacherId) async {
    final token = await getToken();
    var uri = Uri.parse('$baseUrl/api/resources/upload');
    var request = http.MultipartRequest('POST', uri);
    
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['classId'] = classId;
    request.fields['teacherId'] = teacherId;
    
    var stream = http.ByteStream(file.openRead());
    var length = await file.length();
    var multipartFile = http.MultipartFile('file', stream, length, filename: file.path.split('/').last);
    
    request.files.add(multipartFile);
    
    var response = await request.send();
    if (response.statusCode != 201) {
      throw Exception('Failed to upload resource');
    }
  }

  // Get Resources
  static Future<List<Map<String, dynamic>>> getResources(String classId) async {
    final token = await getToken();
    final response = await _makeRequest('GET', '/api/resources/$classId', headers: token != null ? {'Authorization': 'Bearer $token'} : {});
    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }

  // Create Notice
  static Future<void> createNotice(String classId, String title, String content, String teacherId, {String priority = 'normal'}) async {
    final token = await getToken();
    await _makeRequest(
      'POST', 
      '/api/notices', 
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      body: {
        'title': title,
        'content': content,
        'classId': classId,
        'teacherId': teacherId,
        'priority': priority
      }
    );
  }

  // Get Notices
  static Future<List<Map<String, dynamic>>> getNotices(String classId) async {
    final token = await getToken();
    final response = await _makeRequest('GET', '/api/notices/$classId', headers: token != null ? {'Authorization': 'Bearer $token'} : {});
    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }

  // Get Low Attendance Insights
  static Future<List<Map<String, dynamic>>> getLowAttendance(String classId) async {
    final token = await getToken();
    final response = await _makeRequest('GET', '/api/insights/low-attendance/$classId', headers: token != null ? {'Authorization': 'Bearer $token'} : {});
    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }
}
