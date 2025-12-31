import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/student.dart';
import '../services/api_service.dart';
import '../providers/classes_provider.dart';
import '../providers/students_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_widgets.dart';
import 'login_screen.dart';

class AttendanceMarkScreen extends StatefulWidget {
  const AttendanceMarkScreen({super.key});

  @override
  State<AttendanceMarkScreen> createState() => _AttendanceMarkScreenState();
}

class _AttendanceMarkScreenState extends State<AttendanceMarkScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedClassId;
  final Map<String, String> _attendanceStatus = {};
  bool _isSaving = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<StudentsProvider>(context, listen: false).loadStudents(teacherId: auth.teacherId);
      Provider.of<ClassesProvider>(context, listen: false).loadClasses(teacherId: auth.teacherId);
    });
  }

  Future<void> _markAllAttendance() async {
    if (_isSaving) return;

    // Check user authentication status before proceeding
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated && auth.isLoggedIn) {
      try {
        await auth.checkStatusNow();
        // If account was invalidated, auth.isAuthenticated will be false now
        if (!auth.isAuthenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Your account has been deactivated. Please login again.'),
                backgroundColor: Colors.red,
              ),
            );
            // Navigate to login screen
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('Error checking user status: $e');
        // Continue with operation if status check fails
      }
    }

    if (_attendanceStatus.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please mark attendance for at least one student'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final entries = _attendanceStatus.entries.toList();
      for (var entry in entries) {
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
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
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
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                          value: _selectedClassId,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          decoration: InputDecoration(
                            labelText: 'Select Class',
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
          
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchText = value.toLowerCase();
                });
              },
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Search students by name...',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchText = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
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
                  return ListSkeleton(
                    itemCount: 8,
                    itemBuilder: (context) => const StudentCardSkeleton(),
                  );
                }

                // Filter students by selected class and search text
                final classFilteredStudents = _selectedClassId == null
                    ? studentsProvider.students
                    : studentsProvider.students.where((student) => student.classId == _selectedClassId).toList();
                
                final filteredStudents = _searchText.isEmpty
                    ? classFilteredStudents
                    : classFilteredStudents.where((student) => 
                        student.name.toLowerCase().contains(_searchText) ||
                        (student.studentId?.toLowerCase().contains(_searchText) ?? false)
                      ).toList();

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
                          _searchText.isNotEmpty 
                              ? 'No students found matching "${_searchText}"'
                              : (_selectedClassId == null ? 'No students found' : 'No students in selected class'),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchText.isNotEmpty
                              ? 'Try a different search term'
                              : (_selectedClassId == null
                                  ? 'Add students first to mark attendance'
                                  : 'Select a different class or add students to this class'),
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
                          if (status.isEmpty) {
                            _attendanceStatus.remove(student.id);
                          } else {
                            _attendanceStatus[student.id] = status;
                          }
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
              onPressed: _isSaving ? null : _markAllAttendance,
              icon: _isSaving
                  ? Container(
                      width: 24,
                      height: 24,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving
                  ? 'Saving...'
                  : 'Save (${_attendanceStatus.length})'),
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
  String? _status;

  @override
  void initState() {
    super.initState();
    _status = widget.currentStatus;
  }

  @override
  void didUpdateWidget(AttendanceStudentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentStatus != _status) {
      _status = widget.currentStatus;
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
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                      if (_status == 'present') {
                        _status = null;
                      } else {
                        _status = 'present';
                      }
                    });
                    widget.onStatusChanged(_status ?? '');
                  },
                ),
                _StatusChip(
                  label: 'A',
                  icon: Icons.cancel,
                  color: Colors.red,
                  isSelected: _status == 'absent',
                  onTap: () {
                    setState(() {
                      if (_status == 'absent') {
                        _status = null;
                      } else {
                        _status = 'absent';
                      }
                    });
                    widget.onStatusChanged(_status ?? '');
                  },
                ),
                _StatusChip(
                  label: 'L',
                  icon: Icons.access_time,
                  color: Colors.orange,
                  isSelected: _status == 'late',
                  onTap: () {
                    setState(() {
                      if (_status == 'late') {
                        _status = null;
                      } else {
                        _status = 'late';
                      }
                    });
                    widget.onStatusChanged(_status ?? '');
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
          color: isSelected ? color : color.withOpacity(0.1),
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