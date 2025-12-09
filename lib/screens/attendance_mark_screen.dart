import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/student.dart';
import '../services/api_service.dart';
import '../providers/classes_provider.dart';
import '../providers/students_provider.dart';
import '../providers/auth_provider.dart';

class AttendanceMarkScreen extends StatefulWidget {
  const AttendanceMarkScreen({super.key});

  @override
  State<AttendanceMarkScreen> createState() => _AttendanceMarkScreenState();
}

class _AttendanceMarkScreenState extends State<AttendanceMarkScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedClassId;
  final Map<String, String> _attendanceStatus = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<StudentsProvider>(context, listen: false).loadStudents();
      Provider.of<ClassesProvider>(context, listen: false).loadClasses(teacherId: auth.teacherId);
    });
  }

  Future<void> _markAllAttendance() async {
    if (_attendanceStatus.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please mark attendance for at least one student'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      for (var entry in _attendanceStatus.entries) {
        await ApiService.markAttendance(
          entry.key,
          _selectedDate,
          'daily', // Changed from session to 'daily'
          entry.value,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Attendance marked for ${_attendanceStatus.length} students'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        setState(() {
          _attendanceStatus.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark attendance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
      body: Column(
        children: [
          // Date and Session Selector
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                // Date Picker
                Card(
                  elevation: 2,
                  color: Theme.of(context).colorScheme.surface,
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDate = picked;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Class Selector
                Card(
                  elevation: 2,
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Consumer<ClassesProvider>(
                      builder: (context, classesProvider, child) {
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedClassId,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          decoration: InputDecoration(
                            labelText: 'Select Class',
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            prefixIcon: Icon(
                              Icons.class_,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            border: InputBorder.none,
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                'All Classes',
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
                              _attendanceStatus.clear(); // Clear attendance when class changes
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Summary
          if (_attendanceStatus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(
                        'Present',
                        _attendanceStatus.values.where((s) => s == 'present').length,
                        Colors.green,
                      ),
                      _buildSummaryItem(
                        'Absent',
                        _attendanceStatus.values.where((s) => s == 'absent').length,
                        Colors.red,
                      ),
                      _buildSummaryItem(
                        'Late',
                        _attendanceStatus.values.where((s) => s == 'late').length,
                        Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Students List
          Expanded(
            child: Consumer2<StudentsProvider, ClassesProvider>(
              builder: (context, studentsProvider, classesProvider, child) {
                if (studentsProvider.isLoading || classesProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filter students by selected class
                final filteredStudents = _selectedClassId == null
                    ? studentsProvider.students
                    : studentsProvider.students.where((student) => student.classId == _selectedClassId).toList();

                if (filteredStudents.isEmpty) {
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
                          _selectedClassId == null ? 'No students found' : 'No students in selected class',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedClassId == null
                              ? 'Add students first to mark attendance'
                              : 'Select a different class or add students to this class',
                          textAlign: TextAlign.center,
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
                  itemCount: filteredStudents.length,
                  itemBuilder: (context, index) {
                    final student = filteredStudents[index];
                    return AttendanceStudentCard(
                      student: student,
                      date: _selectedDate,
                      session: 'daily', // Changed from _selectedSession to 'daily'
                      onStatusChanged: (status) {
                        setState(() {
                          _attendanceStatus[student.id] = status;
                        });
                      },
                      currentStatus: _attendanceStatus[student.id],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _attendanceStatus.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _markAllAttendance,
              icon: const Icon(Icons.save),
              label: Text('Save (${_attendanceStatus.length})'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            )
          : null,
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class AttendanceStudentCard extends StatefulWidget {
  final Student student;
  final DateTime date;
  final String session;
  final Function(String) onStatusChanged;
  final String? currentStatus;

  const AttendanceStudentCard({
    super.key,
    required this.student,
    required this.date,
    required this.session,
    required this.onStatusChanged,
    this.currentStatus,
  });

  @override
  State<AttendanceStudentCard> createState() => _AttendanceStudentCardState();
}

class _AttendanceStudentCardState extends State<AttendanceStudentCard> {
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.currentStatus ?? 'present';
  }

  @override
  void didUpdateWidget(AttendanceStudentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentStatus != null && widget.currentStatus != _status) {
      _status = widget.currentStatus!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              radius: 28,
              child: Text(
                widget.student.name.isNotEmpty ? widget.student.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.student.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${widget.student.studentId}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                _StatusChip(
                  label: 'P',
                  icon: Icons.check_circle,
                  color: Colors.green,
                  isSelected: _status == 'present',
                  onTap: () {
                    setState(() {
                      _status = 'present';
                    });
                    widget.onStatusChanged('present');
                  },
                ),
                _StatusChip(
                  label: 'A',
                  icon: Icons.cancel,
                  color: Colors.red,
                  isSelected: _status == 'absent',
                  onTap: () {
                    setState(() {
                      _status = 'absent';
                    });
                    widget.onStatusChanged('absent');
                  },
                ),
                _StatusChip(
                  label: 'L',
                  icon: Icons.access_time,
                  color: Colors.orange,
                  isSelected: _status == 'late',
                  onTap: () {
                    setState(() {
                      _status = 'late';
                    });
                    widget.onStatusChanged('late');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.white : color,
        ),
      ),
    );
  }
}