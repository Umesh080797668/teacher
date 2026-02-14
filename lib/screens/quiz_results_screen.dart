import 'package:flutter/material.dart';
import '../models/quiz.dart';
import '../services/api_service.dart';

class QuizResultsScreen extends StatelessWidget {
  final String quizId;
  final String quizTitle;

  QuizResultsScreen({required this.quizId, required this.quizTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Results: $quizTitle')),
      body: FutureBuilder<List<QuizResult>>(
        future: ApiService.getQuizResults(quizId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No submissions yet.'));
          }

          final results = snapshot.data!;
          return ListView.separated(
            itemCount: results.length,
            separatorBuilder: (c, i) => Divider(),
            itemBuilder: (context, index) {
              final result = results[index];
              final studentName = result.studentDetails != null 
                  ? result.studentDetails!['name'] 
                  : 'Student ${result.studentId}';
              final studentReg = result.studentDetails != null && result.studentDetails!['regNo'] != null
                  ? ' (${result.studentDetails!['regNo']})' 
                  : '';

              return ListTile(
                leading: CircleAvatar(child: Text('${result.score}')),
                title: Text('$studentName$studentReg'),
                subtitle: Text('Submitted: ${result.submittedAt.toString().substring(0, 16)}'),
                trailing: Text('${result.score}/${result.totalMarks}', 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              );
            },
          );
        },
      ),
    );
  }
}
