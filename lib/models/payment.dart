class Payment {
  final String id;
  final String studentId;
  final String classId;
  final double amount;
  final String type; // 'full', 'half', 'free'
  final DateTime date;
  final int? month;
  final int? year;

  Payment({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.amount,
    required this.type,
    required this.date,
    this.month,
    this.year,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    final date = json['date'] is String ? DateTime.parse(json['date']) : DateTime.now();
    final month = json['month'] is int ? json['month'] : date.month; // Derive from date if not provided
    final year = json['year'] is int ? json['year'] : date.year; // Derive from date if not provided
    
    // Handle classId which could be a string or an object with _id
    String extractedClassId = '';
    if (json['classId'] is String) {
      extractedClassId = json['classId'];
    } else if (json['classId'] is Map) {
      extractedClassId = json['classId']['_id'] ?? json['classId']['id'] ?? '';
    }
    
    // Handle studentId which could be a string or an object with _id
    String extractedStudentId = '';
    if (json['studentId'] is String) {
      extractedStudentId = json['studentId'];
    } else if (json['studentId'] is Map) {
      extractedStudentId = json['studentId']['_id'] ?? json['studentId']['id'] ?? '';
    }
    
    return Payment(
      id: (json['_id'] ?? json['id']) is String ? (json['_id'] ?? json['id']) : '',
      studentId: extractedStudentId,
      classId: extractedClassId,
      amount: json['amount'] is num ? (json['amount'] as num).toDouble() : 0.0,
      type: json['type'] is String ? json['type'] : '',
      date: date,
      month: month,
      year: year,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'classId': classId,
      'amount': amount,
      'type': type,
      'date': date.toIso8601String(),
      'month': month,
      'year': year,
    };
  }
}