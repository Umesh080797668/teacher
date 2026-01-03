class Teacher {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? teacherId;
  final String status;
  final String? profilePicture;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Teacher({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.teacherId,
    required this.status,
    this.profilePicture,
    this.createdAt,
    this.updatedAt,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] is String ? json['name'] : '',
      email: json['email'] is String ? json['email'] : '',
      phone: json['phone'] is String ? json['phone'] : null,
      teacherId: json['teacherId'] is String ? json['teacherId'] : null,
      status: json['status'] is String ? json['status'] : 'active',
      profilePicture: json['profilePicture'] is String ? json['profilePicture'] : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'teacherId': teacherId,
      'status': status,
      'profilePicture': profilePicture,
    };
  }

  Teacher copyWith({
    String? name,
    String? email,
    String? phone,
    String? teacherId,
    String? status,
    String? profilePicture,
  }) {
    return Teacher(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      teacherId: teacherId ?? this.teacherId,
      status: status ?? this.status,
      profilePicture: profilePicture ?? this.profilePicture,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}