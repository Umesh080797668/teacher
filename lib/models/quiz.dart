class QuizQuestion {
  String text;
  List<String> options;
  int correctOptionIndex;
  int marks;

  QuizQuestion({
    required this.text,
    required this.options,
    required this.correctOptionIndex,
    this.marks = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'marks': marks,
    };
  }

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      text: json['text'],
      options: List<String>.from(json['options']),
      correctOptionIndex: json['correctOptionIndex'],
      marks: json['marks'] ?? 1,
    );
  }
}

class Quiz {
  String? id;
  String title;
  String? description;
  List<QuizQuestion> questions;
  List<String> classIds;
  int duration; // minutes
  int maxAttempts;
  bool isActive;
  DateTime? createdAt;

  Quiz({
    this.id,
    required this.title,
    this.description,
    required this.questions,
    this.classIds = const [],
    required this.duration,
    this.maxAttempts = 1,
    this.isActive = true,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'questions': questions.map((q) => q.toJson()).toList(),
      'classIds': classIds,
      'duration': duration,
      'maxAttempts': maxAttempts,
      'isActive': isActive,
    };
  }

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['_id'],
      title: json['title'],
      description: json['description'],
      questions: (json['questions'] as List)
          .map((q) => QuizQuestion.fromJson(q))
          .toList(),
      classIds: json['classIds'] != null ? List<String>.from(json['classIds']) : [],
      duration: json['duration'],
      maxAttempts: json['maxAttempts'] ?? 1,
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : null,
    );
  }
}

class QuizResult {
  String id;
  String studentId;
  String quizId;
  int score;
  int totalMarks;
  DateTime submittedAt;
  Map<String, dynamic>? studentDetails; // For populating student info

  QuizResult({
    required this.id,
    required this.studentId,
    required this.quizId,
    required this.score,
    required this.totalMarks,
    required this.submittedAt,
    this.studentDetails,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    return QuizResult(
      id: json['_id'],
      studentId: json['studentId'] is String 
          ? json['studentId'] 
          : (json['studentId']['_id'] ?? ''),
      quizId: json['quizId'] is String 
          ? json['quizId'] 
          : (json['quizId']['_id'] ?? ''),
      score: json['score'],
      totalMarks: json['totalMarks'],
      submittedAt: DateTime.parse(json['submittedAt']),
      studentDetails: json['studentId'] is Map<String, dynamic> 
          ? json['studentId'] 
          : null,
    );
  }
}
