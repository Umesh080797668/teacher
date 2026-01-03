class Class {
  final String id;
  final String name;
  final String teacherId;
  final DateTime? createdAt;

  Class({
    required this.id,
    required this.name,
    required this.teacherId,
    this.createdAt,
  });

  factory Class.fromJson(Map<String, dynamic> json) {
    return Class(
      id: (json['_id'] ?? json['id']) is String ? (json['_id'] ?? json['id']) : '',
      name: json['name'] is String ? json['name'] : '',
      teacherId: json['teacherId'] is String ? json['teacherId'] : '',
      createdAt: json['createdAt'] is String ? DateTime.parse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'teacherId': teacherId,
    };
  }
}