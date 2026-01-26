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
  final bool hasFaceData;
  final List<double>? faceEmbedding;

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
    this.hasFaceData = false,
    this.faceEmbedding,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    // Handle classId which could be a string or an object with _id
    String? extractedClassId;
    if (json['classId'] is String) {
      extractedClassId = json['classId'];
    } else if (json['classId'] is Map) {
      extractedClassId = json['classId']['_id'] ?? json['classId']['id'];
    }

    return Student(
      id: (json['_id'] ?? json['id']) is String ? (json['_id'] ?? json['id']) : '',
      name: json['name'] is String ? json['name'] : '',
      email: json['email'] is String ? json['email'] : null,
      studentId: json['studentId'] is String ? json['studentId'] : '',
      classId: extractedClassId,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : null,
      isRestricted: json['isRestricted'] is bool ? json['isRestricted'] : false,
      restrictionReason: json['restrictionReason'] is String ? json['restrictionReason'] : null,
      restrictedAt: json['restrictedAt'] != null ? DateTime.parse(json['restrictedAt'].toString()) : null,
      hasFaceData: json['hasFaceData'] is bool ? json['hasFaceData'] : false,
      faceEmbedding: json['faceEmbedding'] != null 
          ? List<double>.from(json['faceEmbedding'].map((e) => e.toDouble()))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'studentId': studentId,
      'classId': classId,
      'hasFaceData': hasFaceData,
      'faceEmbedding': faceEmbedding,
    };
  }
}