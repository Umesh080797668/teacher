import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/class.dart' as class_model;
import '../providers/students_provider.dart';
import '../providers/classes_provider.dart';
import '../providers/auth_provider.dart';
import 'student_details_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _studentIdController = TextEditingController();
  String? _selectedClassId;
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    final studentsProvider = Provider.of<StudentsProvider>(context, listen: false);
    final classesProvider = Provider.of<ClassesProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await studentsProvider.loadStudents();
      await classesProvider.loadClasses(teacherId: auth.teacherId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addStudent() async {
    if (_formKey.currentState!.validate()) {
      final provider = Provider.of<StudentsProvider>(context, listen: false);
      try {
        await provider.addStudent(
          _nameController.text,
          _emailController.text.isEmpty ? null : _emailController.text,
          _studentIdController.text.isEmpty ? null : _studentIdController.text, // Allow empty for auto-generation
          _selectedClassId,
        );
        _nameController.clear();
        _emailController.clear();
        _studentIdController.clear();
        setState(() {
          _selectedClassId = null;
          _showForm = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Student added successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add student: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Students'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      body: Column(
        children: [
          // Header with stats
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Consumer<StudentsProvider>(
              builder: (context, provider, child) {
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatCard(
                          title: 'Total Students',
                          value: '${provider.students.length}',
                          icon: Icons.people,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        _StatCard(
                          title: 'Active',
                          value: '${provider.students.length}',
                          icon: Icons.check_circle,
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Add Student Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: !_showForm
                  ? ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showForm = true;
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add New Student'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Add New Student',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      setState(() {
                                        _showForm = false;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Name',
                                  prefixIcon: Icon(Icons.person),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email (optional)',
                                  prefixIcon: Icon(Icons.email),
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _studentIdController,
                                decoration: const InputDecoration(
                                  labelText: 'Student ID (optional - auto-generated)',
                                  prefixIcon: Icon(Icons.badge),
                                  helperText: 'Leave empty to auto-generate',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Consumer<ClassesProvider>(
                                builder: (context, classesProvider, child) {
                                  return DropdownButtonFormField<String>(
                                    initialValue: _selectedClassId,
                                    decoration: const InputDecoration(
                                      labelText: 'Class (optional)',
                                      prefixIcon: Icon(Icons.class_),
                                    ),
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text('No class assigned'),
                                      ),
                                      ...classesProvider.classes.map((classObj) {
                                        return DropdownMenuItem<String>(
                                          value: classObj.id,
                                          child: Text(classObj.name),
                                        );
                                      }),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedClassId = value;
                                      });
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _addStudent,
                                icon: const Icon(Icons.save),
                                label: const Text('Save Student'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 50),
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          
          // Students List
          Expanded(
            child: Consumer<StudentsProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (provider.students.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No students yet',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first student to get started',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: provider.students.length,
                  itemBuilder: (context, index) {
                    final student = provider.students[index];
                    return Slidable(
                      endActionPane: ActionPane(
                        motion: const ScrollMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (context) {
                              // Delete functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Delete feature coming soon!')),
                              );
                            },
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            icon: Icons.delete,
                            label: 'Delete',
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ],
                      ),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            radius: 28,
                            child: Text(
                              student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          title: Text(
                            student.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.badge, size: 14, color: Theme.of(context).colorScheme.outline),
                                  const SizedBox(width: 4),
                                  Text('ID: ${student.studentId}'),
                                ],
                              ),
                              if (student.email != null && student.email!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.email, size: 14, color: Theme.of(context).colorScheme.outline),
                                    const SizedBox(width: 4),
                                    Expanded(child: Text(student.email!, overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              ],
                              Consumer<ClassesProvider>(
                                builder: (context, classesProvider, child) {
                                  final classObj = classesProvider.classes.firstWhere(
                                    (c) => c.id == student.classId,
                                    orElse: () => class_model.Class(id: '', name: '', teacherId: ''),
                                  );
                                  if (classObj.id.isNotEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Row(
                                        children: [
                                          Icon(Icons.class_, size: 14, color: Theme.of(context).colorScheme.outline),
                                          const SizedBox(width: 4),
                                          Text('Class: ${classObj.name}'),
                                        ],
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          onTap: () {
                            // Navigate to student details
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StudentDetailsScreen(student: student),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}