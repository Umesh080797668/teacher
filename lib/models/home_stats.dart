class HomeStats {
  final int totalStudents;
  final double todayAttendancePercentage;
  final int totalClasses;
  final double paymentStatusPercentage;
  final String studentsTrend;
  final String attendanceTrend;
  final String classesTrend;
  final String paymentTrend;
  final bool studentsPositive;
  final bool attendancePositive;
  final bool classesPositive;
  final bool paymentPositive;

  HomeStats({
    required this.totalStudents,
    required this.todayAttendancePercentage,
    required this.totalClasses,
    required this.paymentStatusPercentage,
    this.studentsTrend = '0%',
    this.attendanceTrend = '0%',
    this.classesTrend = '0',
    this.paymentTrend = '0%',
    this.studentsPositive = true,
    this.attendancePositive = true,
    this.classesPositive = true,
    this.paymentPositive = true,
  });

  factory HomeStats.fromJson(Map<String, dynamic> json) {
    return HomeStats(
      totalStudents: json['totalStudents'] ?? 0,
      todayAttendancePercentage: (json['todayAttendancePercentage'] ?? 0.0)
          .toDouble(),
      totalClasses: json['totalClasses'] ?? 0,
      paymentStatusPercentage: (json['paymentStatusPercentage'] ?? 0.0)
          .toDouble(),
      studentsTrend: json['studentsTrend'] ?? '0%',
      attendanceTrend: json['attendanceTrend'] ?? '0%',
      classesTrend: json['classesTrend'] ?? '0',
      paymentTrend: json['paymentTrend'] ?? '0%',
      studentsPositive: json['studentsPositive'] ?? true,
      attendancePositive: json['attendancePositive'] ?? true,
      classesPositive: json['classesPositive'] ?? true,
      paymentPositive: json['paymentPositive'] ?? true,
    );
  }
}

class RecentActivity {
  final String id;
  final String type; // 'attendance', 'student', 'class', 'payment', 'report'
  final String title;
  final String subtitle;
  final DateTime timestamp;

  RecentActivity({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
  });

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    return RecentActivity(
      id: json['_id'] ?? json['id'],
      type: json['type'],
      title: json['title'],
      subtitle: json['subtitle'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
