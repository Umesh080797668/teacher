class Payment {
  final String id;
  final String studentId;
  final String classId;
  final double amount;
  final String type; // 'full', 'half', 'free'
  final DateTime date;

  Payment({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.amount,
    required this.type,
    required this.date,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['_id'] ?? json['id'],
      studentId: json['studentId'],
      classId: json['classId'],
      amount: (json['amount'] as num).toDouble(),
      type: json['type'],
      date: DateTime.parse(json['date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'classId': classId,
      'amount': amount,
      'type': type,
      'date': date.toIso8601String(),
    };
  }
}