import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/quiz.dart';
import '../providers/classes_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../main.dart';

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

  bool get _isFormValid {
    if (_titleController.text.trim().isEmpty) return false;
    if (_durationController.text.trim().isEmpty || int.tryParse(_durationController.text) == null) return false;
    if (_attemptsController.text.trim().isEmpty || int.tryParse(_attemptsController.text) == null) return false;
    if (_selectedClassIds.isEmpty) return false;
    if (_questions.isEmpty) return false;
    return true;
  }

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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FocusScope.of(MyApp.navigatorKey.currentContext!).unfocus();
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
      debugPrint('Creating quiz with data: ${quiz.toJson()}');
      await ApiService.createQuiz(quiz);
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error creating quiz: $e');
      debugPrint('Error type: ${e.runtimeType}');
      if (e is ApiException) {
        debugPrint('ApiException details: message=${e.message}, statusCode=${e.statusCode}, errorCode=${e.errorCode}');
      }
      if (e is FormatException) {
        debugPrint('FormatException details: ${e.message} at ${e.offset}');
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create quiz: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0E17) : const Color(0xFFF5F5FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // Gradient Header
                  Container(
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? const LinearGradient(
                              colors: [Color(0xFF1E1A2E), Color(0xFF2D2660)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF3730A3), Color(0xFF4F46E5), Color(0xFF7C3AED)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Quiz',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Build a new quiz for students',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Form body
                  Expanded(
                    child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Quiz Title
                  _sectionLabel('Quiz Details', cs),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Quiz Title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                      prefixIcon: const Icon(Icons.title_rounded),
                    ),
                    style: TextStyle(color: cs.onSurface),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _durationController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Duration (min)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                            prefixIcon: const Icon(Icons.timer_rounded),
                          ),
                          style: TextStyle(color: cs.onSurface),
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Required' : int.tryParse(v) == null ? 'Must be a number' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _attemptsController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Max Attempts',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                            prefixIcon: const Icon(Icons.repeat_rounded),
                          ),
                          style: TextStyle(color: cs.onSurface),
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Required' : int.tryParse(v) == null ? 'Must be a number' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('Assign to Classes', cs),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: isDark
                          ? Border.all(color: Colors.white.withValues(alpha: 0.07))
                          : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: Consumer<ClassesProvider>(
                      builder: (context, classesProvider, _) {
                        return Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: classesProvider.classes.map((cls) {
                            final isSelected = _selectedClassIds.contains(cls.id);
                            return FilterChip(
                              label: Text(cls.name),
                              selected: isSelected,
                              selectedColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                              checkmarkColor: const Color(0xFF4F46E5),
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
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _sectionLabel('Questions (${_questions.length})', cs),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addQuestion,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._questions.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final q = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: isDark
                            ? Border.all(color: Colors.white.withValues(alpha: 0.07))
                            : Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          q.text,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Correct: Option ${q.correctOptionIndex + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF22C55E).withValues(alpha: 0.9),
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                          onPressed: () => setState(() => _questions.remove(q)),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 28),
                  // Submit button
                  Container(
                    decoration: BoxDecoration(
                      gradient: _isFormValid ? const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ) : null,
                      color: _isFormValid ? null : (isDark ? Colors.white12 : Colors.black12),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _isFormValid ? [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ] : [],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isFormValid ? _submit : null,
                      icon: Icon(Icons.check_rounded, color: _isFormValid ? Colors.white : Colors.grey),
                      label: Text(
                        'Create Quiz',
                        style: GoogleFonts.poppins(
                          color: _isFormValid ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        disabledForegroundColor: Colors.grey,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String text, ColorScheme cs) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: cs.onSurface,
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
      title: Text('Add Question', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      content: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _questionController, decoration: InputDecoration(labelText: 'Question Text'), style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              SizedBox(height: 16),
              ..._optionControllers.asMap().entries.map((entry) {
                int idx = entry.key;
                return Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
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
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() => _optionControllers.add(TextEditingController()));
                },
                child: Text('Add Option'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_questionController.text.isEmpty) return;
            final options = _optionControllers.map((c) => c.text).where((t) => t.isNotEmpty).toList();
            if (options.length < 2) return;
            
            // Find the correct index in the filtered options
            int correctIndex = 0;
            int nonEmptyCount = 0;
            for (int i = 0; i < _optionControllers.length; i++) {
              if (_optionControllers[i].text.isNotEmpty) {
                if (i == _correctIndex) {
                  correctIndex = nonEmptyCount;
                  break;
                }
                nonEmptyCount++;
              }
            }
            
            widget.onSave(QuizQuestion(
              text: _questionController.text,
              options: options,
              correctOptionIndex: correctIndex,
            ));
            FocusScope.of(context).unfocus();
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
