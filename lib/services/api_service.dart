import 'dart:convert';
import 'dart:async';
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

  // Students
  static Future<List<Student>> getStudents() async {
    final response = await _makeRequest('GET', '/api/students');
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

  // Attendance
  static Future<List<Attendance>> getAttendance({
    String? studentId,
    int? month,
    int? year,
  }) async {
    final queryParams = <String, String>{};
    if (studentId != null) queryParams['studentId'] = studentId;
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();

    final endpoint = Uri(
      path: '/api/attendance',
      queryParameters: queryParams,
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
  }) async {
    final queryParams = <String, String>{};
    if (classId != null) queryParams['classId'] = classId;
    if (studentId != null) queryParams['studentId'] = studentId;

    final endpoint = Uri(
      path: '/api/payments',
      queryParameters: queryParams,
    ).toString();
    final response = await _makeRequest('GET', endpoint);
    List<dynamic> data = json.decode(response.body);
    return data.map((json) => Payment.fromJson(json)).toList();
  }

  static Future<Payment> createPayment(
    String studentId,
    String classId,
    double amount,
    String type,
  ) async {
    final response = await _makeRequest(
      'POST',
      '/api/payments',
      body: {
        'studentId': studentId,
        'classId': classId,
        'amount': amount,
        'type': type,
      },
    );

    return Payment.fromJson(json.decode(response.body));
  }

  static Future<void> deletePayment(String paymentId) async {
    await _makeRequest('DELETE', '/api/payments/$paymentId');
  }

  // Reports
  static Future<Map<String, dynamic>> getAttendanceSummary() async {
    final response = await _makeRequest(
      'GET',
      '/api/reports/attendance-summary',
    );
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

  // Home Dashboard
  static Future<HomeStats> getHomeStats() async {
    try {
      // Fetch all required data in parallel
      final results = await Future.wait([
        ApiService.getStudents(),
        ApiService.getAttendance(),
        ApiService.getClasses(),
        ApiService.getPayments(),
      ]);

      final students = results[0] as List<Student>;
      final allAttendance = results[1] as List<Attendance>;
      final classes = results[2] as List<Class>;
      final payments = results[3] as List<Payment>;

      final today = DateTime.now();

      // Calculate today's attendance
      final todayAttendance = allAttendance
          .where(
            (a) =>
                a.date.year == today.year &&
                a.date.month == today.month &&
                a.date.day == today.day,
          )
          .toList();

      final presentCount = todayAttendance
          .where((a) => a.status.toLowerCase() == 'present')
          .length;
      final todayAttendancePercentage = todayAttendance.isEmpty
          ? 0.0
          : (presentCount / todayAttendance.length * 100);

      // Calculate yesterday's attendance for trend
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayAttendance = allAttendance
          .where(
            (a) =>
                a.date.year == yesterday.year &&
                a.date.month == yesterday.month &&
                a.date.day == yesterday.day,
          )
          .toList();

      final yesterdayPresentCount = yesterdayAttendance
          .where((a) => a.status.toLowerCase() == 'present')
          .length;
      final yesterdayAttendancePercentage = yesterdayAttendance.isEmpty
          ? 0.0
          : (yesterdayPresentCount / yesterdayAttendance.length * 100);

      final attendanceDiff =
          todayAttendancePercentage - yesterdayAttendancePercentage;
      final attendanceTrend =
          '${attendanceDiff >= 0 ? '+' : ''}${attendanceDiff.toStringAsFixed(1)}%';
      final attendancePositive = attendanceDiff >= 0;

      // Calculate payment status (students who have paid this month)
      final currentMonth = today.month;
      final currentYear = today.year;
      final monthPayments = payments
          .where(
            (p) => p.date.month == currentMonth && p.date.year == currentYear,
          )
          .toList();

      final uniquePayingStudents = monthPayments
          .map((p) => p.studentId)
          .toSet()
          .length;
      final paymentStatusPercentage = students.isEmpty
          ? 0.0
          : (uniquePayingStudents / students.length * 100);

      // Calculate last month's payment for trend
      final lastMonth = currentMonth == 1 ? 12 : currentMonth - 1;
      final lastMonthYear = currentMonth == 1 ? currentYear - 1 : currentYear;
      final lastMonthPayments = payments
          .where(
            (p) => p.date.month == lastMonth && p.date.year == lastMonthYear,
          )
          .toList();

      final lastMonthPayingStudents = lastMonthPayments
          .map((p) => p.studentId)
          .toSet()
          .length;
      final lastMonthPaymentPercentage = students.isEmpty
          ? 0.0
          : (lastMonthPayingStudents / students.length * 100);

      final paymentDiff = paymentStatusPercentage - lastMonthPaymentPercentage;
      final paymentTrend =
          '${paymentDiff >= 0 ? '+' : ''}${paymentDiff.toStringAsFixed(1)}%';
      final paymentPositive = paymentDiff >= 0;

      // Calculate student trend (total count - simple indicator)
      final studentsTrend = students.length > 10
          ? '+${(students.length * 0.05).round()}'
          : students.length > 5
          ? '+${(students.length * 0.1).round()}'
          : '+${students.length}';
      final studentsPositive = true;

      // Calculate classes trend (simple indicator based on total)
      final classesTrend = classes.length > 5
          ? '+1'
          : classes.length > 0
          ? '+${classes.length}'
          : '0';
      final classesPositive = classes.isNotEmpty;

      return HomeStats(
        totalStudents: students.length,
        todayAttendancePercentage: todayAttendancePercentage,
        totalClasses: classes.length,
        paymentStatusPercentage: paymentStatusPercentage,
        studentsTrend: studentsTrend,
        attendanceTrend: attendanceTrend,
        classesTrend: classesTrend,
        paymentTrend: paymentTrend,
        studentsPositive: studentsPositive,
        attendancePositive: attendancePositive,
        classesPositive: classesPositive,
        paymentPositive: paymentPositive,
      );
    } catch (e) {
      // Return default stats if error occurs
      return HomeStats(
        totalStudents: 0,
        todayAttendancePercentage: 0.0,
        totalClasses: 0,
        paymentStatusPercentage: 0.0,
        studentsTrend: '0',
        attendanceTrend: '0%',
        classesTrend: '0',
        paymentTrend: '0%',
        studentsPositive: true,
        attendancePositive: true,
        classesPositive: true,
        paymentPositive: true,
      );
    }
  }

  static Future<List<RecentActivity>> getRecentActivities() async {
    try {
      // Fetch recent data
      final results = await Future.wait([
        ApiService.getAttendance(),
        ApiService.getStudents(),
        ApiService.getPayments(),
        ApiService.getClasses(),
      ]);

      final allAttendance = results[0] as List<Attendance>;
      final students = results[1] as List<Student>;
      final payments = results[2] as List<Payment>;
      final classes = results[3] as List<Class>;

      final activities = <RecentActivity>[];

      // Get recent attendance records (last 3 unique dates)
      final attendanceByDate = <String, List<Attendance>>{};
      for (var attendance in allAttendance) {
        final dateKey =
            '${attendance.date.year}-${attendance.date.month}-${attendance.date.day}';
        attendanceByDate.putIfAbsent(dateKey, () => []).add(attendance);
      }

      final sortedDates = attendanceByDate.keys.toList()
        ..sort((a, b) => b.compareTo(a));

      for (var i = 0; i < sortedDates.length && i < 2; i++) {
        final dateKey = sortedDates[i];
        final dateAttendance = attendanceByDate[dateKey]!;
        final date = dateAttendance.first.date;
        final createdAt = dateAttendance.first.createdAt ?? date;

        activities.add(
          RecentActivity(
            id: 'attendance_$dateKey',
            type: 'attendance',
            title: 'Attendance Marked',
            subtitle:
                'Attendance recorded for ${dateAttendance.length} students',
            timestamp: createdAt,
          ),
        );
      }

      // Get recently added students (last 2)
      if (students.isNotEmpty) {
        final recentStudents = students.where((s) => s.createdAt != null)
            .toList()
          ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
        
        for (var i = 0; i < recentStudents.length && i < 2; i++) {
          final student = recentStudents[i];
          activities.add(
            RecentActivity(
              id: 'student_${student.id}',
              type: 'student',
              title: 'New Student Added',
              subtitle: '${student.name} has been registered',
              timestamp: student.createdAt ?? DateTime.now(),
            ),
          );
        }
      }

      // Get recent payments (last 1)
      if (payments.isNotEmpty) {
        final recentPayment = payments.last;
        activities.add(
          RecentActivity(
            id: 'payment_${recentPayment.id}',
            type: 'payment',
            title: 'Payment Received',
            subtitle:
                'Payment of Rs.${recentPayment.amount.toStringAsFixed(2)} received',
            timestamp: recentPayment.date,
          ),
        );
      }

      // Get recently added classes (last 2)
      if (classes.isNotEmpty) {
        final recentClasses = classes.where((c) => c.createdAt != null)
            .toList()
          ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
        
        for (var i = 0; i < recentClasses.length && i < 2; i++) {
          final classItem = recentClasses[i];
          activities.add(
            RecentActivity(
              id: 'class_${classItem.id}',
              type: 'class',
              title: 'New Class Added',
              subtitle: '${classItem.name} has been created',
              timestamp: classItem.createdAt ?? DateTime.now(),
            ),
          );
        }
      }

      // Sort by timestamp descending and return top 3
      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return activities.take(3).toList();
    } catch (e) {
      return [];
    }
  }
}
