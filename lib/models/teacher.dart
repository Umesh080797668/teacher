class Teacher {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? teacherId;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Teacher({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.teacherId,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      teacherId: json['teacherId'],
      status: json['status'] ?? 'active',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'teacherId': teacherId,
      'status': status,
    };
  }

  Teacher copyWith({
    String? name,
    String? email,
    String? phone,
    String? teacherId,
    String? status,
  }) {
    return Teacher(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      teacherId: teacherId ?? this.teacherId,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}