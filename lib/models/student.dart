class Student {
  final String id;
  final String name;
  final String? email;
  final String studentId;
  final String? classId;

  Student({
    required this.id,
    required this.name,
    this.email,
    required this.studentId,
    this.classId,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      email: json['email'],
      studentId: json['studentId'],
      classId: json['classId'],
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