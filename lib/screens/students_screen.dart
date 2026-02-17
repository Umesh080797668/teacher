import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/class.dart' as class_model;
import '../providers/students_provider.dart';
import '../providers/classes_provider.dart';
import '../providers/auth_provider.dart';
import 'student_details_screen.dart';
import '../widgets/custom_widgets.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _studentIdController = TextEditingController();
  String? _selectedClassId;
  bool _showForm = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStudents();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _studentIdController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    final studentsProvider = Provider.of<StudentsProvider>(context, listen: false);
    final classesProvider = Provider.of<ClassesProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await studentsProvider.loadStudents(teacherId: auth.teacherId);
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
          _phoneController.text.isEmpty ? null : _phoneController.text,
          _studentIdController.text, // Use the auto-generated ID
          _selectedClassId,
        );
        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
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

  String _generateStudentId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    final random = (DateTime.now().microsecondsSinceEpoch % 1000).toString().padLeft(3, '0');
    return 'STU$timestamp$random';
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
          actions: [],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim().toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search students...',
                    prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.outline),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
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
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: 'Total Students',
                                value: '${provider.students.length}',
                                icon: Icons.people,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _StatCard(
                                title: 'Active',
                                value: '${provider.students.length}',
                                icon: Icons.check_circle,
                                color: Colors.green,
                              ),
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
                              // Generate student ID when form is opened
                              _studentIdController.text = _generateStudentId();
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
                          color: Theme.of(context).colorScheme.surface,
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
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.close,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _showForm = false;
                                            _studentIdController
                                                .clear(); // Clear the generated ID when closing
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _nameController,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Name',
                                      prefixIcon: Icon(
                                        Icons.person,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.6),
                                      ),
                                      labelStyle: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                      ),
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
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Email (optional)',
                                      prefixIcon: Icon(
                                        Icons.email,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.6),
                                      ),
                                      labelStyle: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                      ),
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _phoneController,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Mobile Number',
                                      prefixIcon: Icon(
                                        Icons.phone,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.6),
                                      ),
                                      labelStyle: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                      ),
                                    ),
                                    keyboardType: TextInputType.phone,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _studentIdController,
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Student ID (Auto-generated)',
                                      prefixIcon: Icon(
                                        Icons.badge,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.6),
                                      ),
                                      labelStyle: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                      ),
                                      filled: true,
                                      fillColor: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withOpacity(0.3),
                                      helperText: 'This ID is automatically generated',
                                      helperStyle: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.5),
                                      ),
                                    ),
                                    enabled: false, // Make the field disabled
                                  ),
                                  const SizedBox(height: 12),
                                  Consumer<ClassesProvider>(
                                    builder: (context, classesProvider, child) {
                                      return DropdownButtonFormField<String>(
                                        initialValue: _selectedClassId,
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                        dropdownColor: Theme.of(context).colorScheme.surface,
                                        decoration: InputDecoration(
                                          labelText: 'Class (optional)',
                                          prefixIcon: Icon(
                                            Icons.class_,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.6),
                                          ),
                                          labelStyle: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.7),
                                          ),
                                        ),
                                        items: [
                                          DropdownMenuItem<String>(
                                            value: null,
                                            child: Text(
                                              'No class assigned',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                          ...classesProvider.classes.map((classObj) {
                                            return DropdownMenuItem<String>(
                                              value: classObj.id,
                                              child: Text(
                                                classObj.name,
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                ),
                                              ),
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
              SizedBox(
                height:
                    MediaQuery.of(context).size.height * 0.5, // Fixed height for scrollable area
                child: Consumer<StudentsProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading) {
                      return ListSkeleton(
                        itemCount: 6,
                        itemBuilder: (context) => const StudentCardSkeleton(),
                      );
                    }

                    final filteredStudents = provider.students.where((student) {
                      if (_searchQuery.isEmpty) return true;
                      return student.name.toLowerCase().contains(_searchQuery) ||
                          (student.email?.toLowerCase().contains(_searchQuery) ?? false) ||
                          student.studentId.toLowerCase().contains(_searchQuery);
                    }).toList();
                    if (filteredStudents.isEmpty) {
                      return SizedBox(
                        height: 200,
                        child: Center(
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
                                'No students found',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'Add your first student to get started'
                                    : 'Try a different search term',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = filteredStudents[index];
                        return Slidable(
                          endActionPane: ActionPane(
                            motion: const ScrollMotion(),
                            children: [
                              // Restrict/Unrestrict action
                              SlidableAction(
                                onPressed: (context) async {
                                  final isCurrentlyRestricted = student.isRestricted;
                                  final action = isCurrentlyRestricted ? 'unrestrict' : 'restrict';
                                  final actionText =
                                      isCurrentlyRestricted ? 'Unrestrict' : 'Restrict';

                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('$actionText Student',
                                          style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface)),
                                      content: Text(
                                          'Are you sure you want to $action ${student.name}?',
                                          style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface)),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: Text(actionText,
                                              style: TextStyle(
                                                  color: isCurrentlyRestricted
                                                      ? Colors.green
                                                      : Colors.orange)),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true && context.mounted) {
                                    try {
                                      final provider =
                                          Provider.of<StudentsProvider>(context, listen: false);
                                      if (isCurrentlyRestricted) {
                                        await provider.unrestrictStudent(student.id);
                                      } else {
                                        await provider.restrictStudent(student.id);
                                      }
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Student ${isCurrentlyRestricted ? 'unrestricted' : 'restricted'} successfully'),
                                            backgroundColor: isCurrentlyRestricted
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to ${action} student: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                backgroundColor:
                                    student.isRestricted ? Colors.green : Colors.orange,
                                foregroundColor: Colors.white,
                                icon: student.isRestricted ? Icons.lock_open : Icons.lock,
                                label: student.isRestricted ? 'Unrestrict' : 'Restrict',
                                borderRadius: BorderRadius.circular(12),
                              ),
                              // Delete action
                              SlidableAction(
                                onPressed: (slidableContext) async {
                                  // Capture the scaffold messenger before showing dialogs
                                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                                  final navigator = Navigator.of(context);
                                  
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: Text('Delete Student',
                                          style: TextStyle(
                                              color: Theme.of(dialogContext).colorScheme.onSurface)),
                                      content: Text(
                                          'Are you sure you want to delete ${student.name}?',
                                          style: TextStyle(
                                              color: Theme.of(dialogContext).colorScheme.onSurface)),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(dialogContext).pop(false),
                                          child: Text('Cancel',
                                              style: TextStyle(
                                                  color: Theme.of(dialogContext).colorScheme.primary)),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(dialogContext).pop(true),
                                          child: const Text('Delete',
                                              style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    // Show loading dialog
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (dialogContext) => const AlertDialog(
                                        content: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(),
                                            SizedBox(width: 16),
                                            Text('Deleting student...'),
                                          ],
                                        ),
                                      ),
                                    );

                                    try {
                                      await Provider.of<StudentsProvider>(context, listen: false)
                                          .deleteStudent(student.id);

                                      // Close loading dialog
                                      navigator.pop();
                                      
                                      // Show success message
                                      scaffoldMessenger.showSnackBar(
                                        const SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(Icons.check_circle, color: Colors.white),
                                              SizedBox(width: 12),
                                              Text('Student deleted successfully'),
                                            ],
                                          ),
                                          backgroundColor: Colors.green,
                                          duration: Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    } catch (e) {
                                      // Close loading dialog
                                      navigator.pop();
                                      
                                      // Show error message
                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.error, color: Colors.white),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text('Failed to delete: ${e.toString()}'),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: Colors.red,
                                          duration: const Duration(seconds: 3),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
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
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      student.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  if (student.isRestricted) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.lock,
                                            size: 14,
                                            color: Colors.red.shade700,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Restricted',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.badge,
                                          size: 14, color: Theme.of(context).colorScheme.outline),
                                      const SizedBox(width: 4),
                                      Text('ID: ${student.studentId}'),
                                    ],
                                  ),
                                  if (student.email != null && student.email!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.email,
                                            size: 14, color: Theme.of(context).colorScheme.outline),
                                        const SizedBox(width: 4),
                                        Expanded(
                                            child: Text(student.email!,
                                                overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  ],
                                  Consumer<ClassesProvider>(
                                    builder: (context, classesProvider, child) {
                                      final classObj = classesProvider.classes.firstWhere(
                                        (c) => c.id == student.classId,
                                        orElse: () =>
                                            class_model.Class(id: '', name: '', teacherId: ''),
                                      );
                                      if (classObj.id.isNotEmpty) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Row(
                                            children: [
                                              Icon(Icons.class_,
                                                  size: 14,
                                                  color: Theme.of(context).colorScheme.outline),
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
        ));
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
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
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
        ],
      ),
    );
  }
}
