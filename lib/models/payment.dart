class Payment {
  final String id;
  final String studentId;
  final String classId;
  final double amount;
  final String type; // 'full', 'half', 'free'
  final DateTime date;
  final int? month;

  Payment({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.amount,
    required this.type,
    required this.date,
    this.month,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['date']);
    final month = json['month'] ?? date.month; // Derive from date if not provided
    
    return Payment(
      id: json['_id'] ?? json['id'],
      studentId: json['studentId'],
      classId: json['classId'],
      amount: (json['amount'] as num).toDouble(),
      type: json['type'],
      date: date,
      month: month,
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
    };
  }
}