class Attendance {
  final String id;
  final String studentId;
  final DateTime date;
  final String session;
  final String status;
  final int month;
  final int year;

  Attendance({
    required this.id,
    required this.studentId,
    required this.date,
    required this.session,
    required this.status,
    required this.month,
    required this.year,
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