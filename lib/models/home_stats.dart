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
      totalStudents: json['totalStudents'] is int ? json['totalStudents'] : 0,
      todayAttendancePercentage: (json['todayAttendancePercentage'] is num ? json['todayAttendancePercentage'] : 0.0)
          .toDouble(),
      totalClasses: json['totalClasses'] is int ? json['totalClasses'] : 0,
      paymentStatusPercentage: (json['paymentStatusPercentage'] is num ? json['paymentStatusPercentage'] : 0.0)
          .toDouble(),
      studentsTrend: json['studentsTrend'] is String ? json['studentsTrend'] : '0%',
      attendanceTrend: json['attendanceTrend'] is String ? json['attendanceTrend'] : '0%',
      classesTrend: json['classesTrend'] is String ? json['classesTrend'] : '0',
      paymentTrend: json['paymentTrend'] is String ? json['paymentTrend'] : '0%',
      studentsPositive: json['studentsPositive'] is bool ? json['studentsPositive'] : true,
      attendancePositive: json['attendancePositive'] is bool ? json['attendancePositive'] : true,
      classesPositive: json['classesPositive'] is bool ? json['classesPositive'] : true,
      paymentPositive: json['paymentPositive'] is bool ? json['paymentPositive'] : true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalStudents': totalStudents,
      'todayAttendancePercentage': todayAttendancePercentage,
      'totalClasses': totalClasses,
      'paymentStatusPercentage': paymentStatusPercentage,
      'studentsTrend': studentsTrend,
      'attendanceTrend': attendanceTrend,
      'classesTrend': classesTrend,
      'paymentTrend': paymentTrend,
      'studentsPositive': studentsPositive,
      'attendancePositive': attendancePositive,
      'classesPositive': classesPositive,
      'paymentPositive': paymentPositive,
    };
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
      id: (json['_id'] ?? json['id']) is String ? (json['_id'] ?? json['id']) : '',
      type: json['type'] is String ? json['type'] : '',
      title: json['title'] is String ? json['title'] : '',
      subtitle: json['subtitle'] is String ? json['subtitle'] : '',
      timestamp: json['timestamp'] is String ? DateTime.parse(json['timestamp']) : DateTime.now(),
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
