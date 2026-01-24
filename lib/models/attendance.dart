class Attendance {
  final String id;
  final String studentId;
  final DateTime date;
  final String session;
  final String status;
  final int month;
  final int year;
  final DateTime? createdAt;

  Attendance({
    required this.id,
    required this.studentId,
    required this.date,
    required this.session,
    required this.status,
    required this.month,
    required this.year,
    this.createdAt,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    // Handle student id extraction if student field is populated object
    String extractedStudentId = '';
    var studentData = json['studentId'] ?? json['student_id'] ?? json['student'];
    
    if (studentData is String) {
      extractedStudentId = studentData;
    } else if (studentData is Map) {
      extractedStudentId = studentData['_id'] ?? studentData['id'] ?? '';
    }

    return Attendance(
      id: (json['_id'] ?? json['id']) is String ? (json['_id'] ?? json['id']) : '',
      studentId: extractedStudentId,
      date: json['date'] is String ? DateTime.parse(json['date']) : DateTime.now(),
      session: json['session'] is String ? json['session'] : '',
      status: json['status'] is String ? json['status'] : 'unknown',
      month: json['month'] is int ? json['month'] : 0,
      year: json['year'] is int ? json['year'] : 0,
      createdAt: json['createdAt'] is String ? DateTime.parse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'date': date.toIso8601String(),
      'session': session,
      'status': status,
      'month': month,
      'year': year,
    };
  }
}