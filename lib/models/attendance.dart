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
    return Attendance(
      id: json['_id'] ?? json['id'],
      studentId: json['studentId'],
      date: DateTime.parse(json['date']),
      session: json['session'],
      status: json['status'],
      month: json['month'],
      year: json['year'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
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