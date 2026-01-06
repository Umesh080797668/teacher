class Teacher {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? teacherId;
  final String status;
  final String? profilePicture;
  final String? subscriptionType;
  final String? subscriptionStatus;
  final DateTime? subscriptionExpiryDate;
  final bool? isFirstLogin;
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
    this.subscriptionType,
    this.subscriptionStatus,
    this.subscriptionExpiryDate,
    this.isFirstLogin,
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
      subscriptionType: json['subscriptionType'] is String ? json['subscriptionType'] : null,
      subscriptionStatus: json['subscriptionStatus'] is String ? json['subscriptionStatus'] : null,
      subscriptionExpiryDate: json['subscriptionExpiryDate'] != null 
        ? DateTime.parse(json['subscriptionExpiryDate'].toString()) 
        : null,
      isFirstLogin: json['isFirstLogin'] is bool ? json['isFirstLogin'] : null,
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
      'subscriptionType': subscriptionType,
      'subscriptionStatus': subscriptionStatus,
      'subscriptionExpiryDate': subscriptionExpiryDate?.toIso8601String(),
      'isFirstLogin': isFirstLogin,
    };
  }

  Teacher copyWith({
    String? name,
    String? email,
    String? phone,
    String? teacherId,
    String? status,
    String? profilePicture,
    String? subscriptionType,
    String? subscriptionStatus,
    DateTime? subscriptionExpiryDate,
    bool? isFirstLogin,
  }) {
    return Teacher(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      teacherId: teacherId ?? this.teacherId,
      status: status ?? this.status,
      profilePicture: profilePicture ?? this.profilePicture,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionExpiryDate: subscriptionExpiryDate ?? this.subscriptionExpiryDate,
      isFirstLogin: isFirstLogin ?? this.isFirstLogin,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}