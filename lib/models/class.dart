class Class {
  final String id;
  final String name;
  final String teacherId;

  Class({
    required this.id,
    required this.name,
    required this.teacherId,
  });

  factory Class.fromJson(Map<String, dynamic> json) {
    return Class(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      teacherId: json['teacherId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'teacherId': teacherId,
    };
  }
}