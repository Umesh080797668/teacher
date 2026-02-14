import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/quiz.dart';
import '../models/class.dart';
import '../providers/classes_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class CreateQuizScreen extends StatefulWidget {
  @override
  _CreateQuizScreenState createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _durationController = TextEditingController();
  final _attemptsController = TextEditingController(text: '1');
  final List<QuizQuestion> _questions = [];
  final List<String> _selectedClassIds = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
       final auth = Provider.of<AuthProvider>(context, listen: false);
       Provider.of<ClassesProvider>(context, listen: false).loadClasses(teacherId: auth.teacherId);
    });
  }

  void _addQuestion() {
    showDialog(
      context: context,
      builder: (context) => AddQuestionDialog(
        onSave: (question) {
          setState(() {
            _questions.add(question);
          });
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Add at least one question')));
      return;
    }
    if (_selectedClassIds.isEmpty) {
      // confirm if they want to create for NO classes? or maybe force at least one?
      // For now, let's require at least one class for "by class" logic.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select at least one class')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final quiz = Quiz(
        title: _titleController.text,
        duration: int.parse(_durationController.text),
        maxAttempts: int.parse(_attemptsController.text),
        questions: _questions,
        classIds: _selectedClassIds,
      );
      await ApiService.createQuiz(quiz);
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create quiz: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Quiz')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                        labelText: 'Quiz Title',
                        border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                        Expanded(
                            child: TextFormField(
                                controller: _durationController,
                                decoration: InputDecoration(
                                    labelText: 'Duration (m)',
                                    border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                            child: TextFormField(
                                controller: _attemptsController,
                                decoration: InputDecoration(
                                    labelText: 'Max Attempts',
                                    border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                        ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text('Assign to Classes', style: Theme.of(context).textTheme.titleLarge),
                  Consumer<ClassesProvider>(
                    builder: (context, classesProvider, _) {
                        return Wrap(
                            spacing: 8.0,
                            children: classesProvider.classes.map((cls) {
                                final isSelected = _selectedClassIds.contains(cls.id);
                                return FilterChip(
                                    label: Text(cls.name),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                        setState(() {
                                            if (selected) {
                                                _selectedClassIds.add(cls.id);
                                            } else {
                                                _selectedClassIds.remove(cls.id);
                                            }
                                        });
                                    },
                                );
                            }).toList(),
                        );
                    },
                  ),
                  SizedBox(height: 20),
                  Text('Questions (${_questions.length})', style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(height: 10),
                  ..._questions.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final q = entry.value;
                        return Card(
                        margin: EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text('Q${idx + 1}: ${q.text}'),
                          subtitle: Text('Answer: Option ${q.correctOptionIndex + 1}'),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() => _questions.remove(q));
                            },
                          ),
                        ),
                      );
                  }),
                  ElevatedButton.icon(
                    onPressed: _addQuestion,
                    icon: Icon(Icons.add),
                    label: Text('Add Question'),
                    style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text('Create Quiz'),
                    style: ElevatedButton.styleFrom(
                       minimumSize: Size(double.infinity, 50),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}

class AddQuestionDialog extends StatefulWidget {
  final Function(QuizQuestion) onSave;

  AddQuestionDialog({required this.onSave});

  @override
  _AddQuestionDialogState createState() => _AddQuestionDialogState();
}

class _AddQuestionDialogState extends State<AddQuestionDialog> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  int _correctIndex = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Question'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _questionController, decoration: InputDecoration(labelText: 'Question Text')),
            ..._optionControllers.asMap().entries.map((entry) {
              int idx = entry.key;
              return Row(
                children: [
                  Radio<int>(
                    value: idx,
                    groupValue: _correctIndex,
                    onChanged: (v) => setState(() => _correctIndex = v!),
                  ),
                  Expanded(
                    child: TextField(
                      controller: entry.value,
                      decoration: InputDecoration(labelText: 'Option ${idx + 1}'),
                    ),
                  ),
                ],
              );
            }),
            TextButton(
              onPressed: () {
                setState(() => _optionControllers.add(TextEditingController()));
              },
              child: Text('Add Option'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_questionController.text.isEmpty) return;
            final options = _optionControllers.map((c) => c.text).where((t) => t.isNotEmpty).toList();
            if (options.length < 2) return;
            
            widget.onSave(QuizQuestion(
              text: _questionController.text,
              options: options,
              correctOptionIndex: _correctIndex,
            ));
            Navigator.pop(context);
          },
          child: Text('Add'),
        ),
      ],
    );
  }
}
