class Student {
  final String id;
  final String name;
  final String? email;
  final String studentId;
  final String? classId;
  final DateTime? createdAt;
  final bool isRestricted;
  final String? restrictionReason;
  final DateTime? restrictedAt;

  Student({
    required this.id,
    required this.name,
    this.email,
    required this.studentId,
    this.classId,
    this.createdAt,
    this.isRestricted = false,
    this.restrictionReason,
    this.restrictedAt,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      email: json['email'],
      studentId: json['studentId'],
      classId: json['classId'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      isRestricted: json['isRestricted'] ?? false,
      restrictionReason: json['restrictionReason'],
      restrictedAt: json['restrictedAt'] != null ? DateTime.parse(json['restrictedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'studentId': studentId,
      'classId': classId,
    };
  }
}