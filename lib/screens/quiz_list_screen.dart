import 'package:flutter/material.dart';
import '../models/quiz.dart';
import '../services/api_service.dart';
import 'create_quiz_screen.dart';
import 'quiz_results_screen.dart';

class QuizListScreen extends StatefulWidget {
  static const routeName = '/quizzes';

  @override
  _QuizListScreenState createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  late Future<List<Quiz>> _quizzesFuture;

  @override
  void initState() {
    super.initState();
    _refreshQuizzes();
  }

  void _refreshQuizzes() {
    setState(() {
      _quizzesFuture = ApiService.getQuizzes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quizzes'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _refreshQuizzes),
        ],
      ),
      body: FutureBuilder<List<Quiz>>(
        future: _quizzesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No quizzes found. Create one!', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)));
          }

          final quizzes = snapshot.data!;
          return ListView.builder(
            itemCount: quizzes.length,
            itemBuilder: (context, index) {
              final quiz = quizzes[index];
              return ListTile(
                title: Text(quiz.title),
                subtitle: Text('${quiz.questions.length} Questions • ${quiz.duration} mins'),
                trailing: Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizResultsScreen(quizId: quiz.id!, quizTitle: quiz.title),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateQuizScreen()),
          );
          if (result == true) {
            _refreshQuizzes();
          }
        },
      ),
    );
  }
}
