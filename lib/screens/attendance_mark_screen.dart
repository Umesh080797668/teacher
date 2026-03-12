import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/student.dart';
import '../models/attendance.dart';
import '../services/api_service.dart';
import '../providers/classes_provider.dart';
import '../providers/students_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_widgets.dart';
import 'face_attendance_scanner_screen.dart';
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
  final Map<String, String> _preExistingAttendance = {}; // Track pre-existing attendance
  bool _isSaving = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    debugPrint('DEBUG: Loading initial data');
    // Load classes first
    await Provider.of<ClassesProvider>(context, listen: false).loadClasses(teacherId: auth.teacherId);
    
    if (!mounted) return;

    // Load students
    await _loadStudentsForClass(null); // Load all students initially
    
    if (!mounted) return;

    // Get the current students list
    final studentsProvider = Provider.of<StudentsProvider>(context, listen: false);
    
    // Load attendance records for the selected date
    await _loadAttendanceForDate(_selectedDate, auth.teacherId, studentsProvider.students);
    
    // No need to filter attendance since we loaded it specifically for current students
    
    // Start polling for real-time updates
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel(); // Cancel any existing timer
    
    // Poll every 10 seconds for real-time attendance updates
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      // Don't poll while saving, while user is searching, or if there are unsaved changes
      if (mounted && !_isSaving && _searchText.isEmpty && !_hasNewlyMarkedAttendance()) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final studentsProvider = Provider.of<StudentsProvider>(context, listen: false);
        
        try {
          // Store current state for comparison
          final previousAttendance = Map<String, String>.from(_attendanceStatus);
          
          // Reload attendance data
          await _loadAttendanceForDate(_selectedDate, auth.teacherId, studentsProvider.students);
          
          // Check if attendance data changed (from external sources, not local changes)
          bool hasChanges = false;
          for (final studentId in _attendanceStatus.keys) {
            if (previousAttendance[studentId] != _attendanceStatus[studentId]) {
              hasChanges = true;
              break;
            }
          }
          
          // Also check for deletions
          for (final studentId in previousAttendance.keys) {
            if (!_attendanceStatus.containsKey(studentId)) {
              hasChanges = true;
              break;
            }
          }
          
          if (hasChanges) {
            debugPrint('Real-time polling: Attendance data updated');
            setState(() {}); // Trigger UI update
          }
        } catch (e) {
          debugPrint('Polling error: $e');
        }
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _loadStudentsForClass(String? classId) async {
    final studentsProvider = Provider.of<StudentsProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      if (classId != null) {
        // Load students for the specific class
        final classStudents = await ApiService.getStudentsByClass(classId);
        studentsProvider.setStudents(classStudents);
      } else {
        // Load all students for the teacher
        await studentsProvider.loadStudents(teacherId: auth.teacherId);
      }
    } catch (e) {
      debugPrint('Error loading students for class: $e');
      // Fallback to loading all students
      await studentsProvider.loadStudents(teacherId: auth.teacherId);
    }
  }

  Future<void> _loadAttendanceForDate(DateTime date, String? teacherId, List<Student> students) async {
    try {
      debugPrint('DEBUG: Loading attendance for ${students.length} students on ${date.toString().split(' ')[0]}');
      
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isGuest) {
          // Mock data for guest
           setState(() {
            _attendanceStatus.clear();
            _preExistingAttendance.clear();
             for (var student in students) {
               // Randomly assign status for demo
               if (student.id.hashCode % 2 == 0) {
                 _attendanceStatus[student.id] = 'present';
                 _preExistingAttendance[student.id] = 'present';
               }
             }
          });
          return;
      }

      if (students.isEmpty) {
        debugPrint('DEBUG: No students to load attendance for');
        setState(() {
          _attendanceStatus.clear();
          _preExistingAttendance.clear();
        });
        return;
      }
      
      // Use batch endpoint for faster loading instead of loading each student individually
      final studentIds = students.map((s) => s.id).toList();
      
      try {
        final attendanceMap = await ApiService.getBatchAttendance(studentIds, date);
        
        debugPrint('DEBUG: Batch attendance loaded, found ${attendanceMap.length} records');
        
        setState(() {
          _attendanceStatus.clear();
          _preExistingAttendance.clear();
          
          // Populate from batch result
          attendanceMap.forEach((studentId, status) {
            _attendanceStatus[studentId] = status;
            _preExistingAttendance[studentId] = status;
          });
        });
        
        debugPrint('DEBUG: Loaded attendance for ${students.length} students, found ${_attendanceStatus.length} existing records');
      } catch (batchError) {
        // Fallback to individual requests if batch endpoint fails
        debugPrint('DEBUG: Batch endpoint failed, falling back to individual requests: $batchError');
        
        final Map<String, Attendance?> studentAttendance = {};
        
        for (final student in students) {
          try {
            final attendanceList = await ApiService.getAttendance(
              studentId: student.id,
              month: date.month,
              year: date.year,
            );
            
            // Find attendance for the specific date
            final attendanceForDate = attendanceList.where((record) => 
              record.date.year == date.year && 
              record.date.month == date.month && 
              record.date.day == date.day
            ).toList();
            
            if (attendanceForDate.isNotEmpty) {
              studentAttendance[student.id] = attendanceForDate.first;
            } else {
              studentAttendance[student.id] = null;
            }
          } catch (e) {
            studentAttendance[student.id] = null;
          }
        }
        
        setState(() {
          _attendanceStatus.clear();
          _preExistingAttendance.clear();
          for (final student in students) {
            final attendance = studentAttendance[student.id];
            if (attendance != null) {
              _attendanceStatus[student.id] = attendance.status;
              _preExistingAttendance[student.id] = attendance.status;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading attendance for date: $e');
    }
  }

  bool _hasNewlyMarkedAttendance() {
    // Check for newly marked or changed attendance
    for (var entry in _attendanceStatus.entries) {
      final preExisting = _preExistingAttendance[entry.key];
      if (preExisting == null || preExisting != entry.value) {
        return true;
      }
    }
    
    // Check for unmarked (deleted) attendance
    for (var studentId in _preExistingAttendance.keys) {
      if (!_attendanceStatus.containsKey(studentId)) {
        return true; // Student had attendance but now doesn't (unmarked)
      }
    }
    
    return false;
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

    // Auto-mark unmarked students as Absent
    // Only applies if a specific class is selected to avoid mass-marking all students as absent accidentally
    final studentsProvider = Provider.of<StudentsProvider>(context, listen: false);
    bool autoMarked = false;
    
    if (_selectedClassId != null && studentsProvider.students.isNotEmpty) {
      for (var student in studentsProvider.students) {
        // If student is not in _attendanceStatus (no local selection)
        // AND not in _preExistingAttendance (not previously saved)
        if (!_attendanceStatus.containsKey(student.id) && !_preExistingAttendance.containsKey(student.id)) {
          _attendanceStatus[student.id] = 'absent';
          autoMarked = true;
        }
      }
      
      if (autoMarked && mounted) {
        setState(() {}); // Update UI to reflect auto-marked absent
      }
    }

    // Check if there are any changes to save (new marks or deletions)
    if (!_hasNewlyMarkedAttendance()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No attendance changes to save'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    // Stop polling during save to avoid conflicts
    _stopPolling();

    try {
      if (auth.isGuest) {
        await Future.delayed(const Duration(seconds: 1)); // Simulate network saving
        int markedCount = 0;
        int deletedCount = 0;
         // Process newly marked or changed attendance
        final entries = _attendanceStatus.entries.toList();
        for (var entry in entries) {
           final preExisting = _preExistingAttendance[entry.key];
           if (preExisting == null || preExisting != entry.value) {
             markedCount++;
           }
        }
         // Process deleted (unmarked) attendance
        for (var studentId in _preExistingAttendance.keys) {
          if (!_attendanceStatus.containsKey(studentId)) {
             deletedCount++;
          }
        }

        if (mounted) {
           String message = '';
           if (markedCount > 0 && deletedCount > 0) {
             message = 'Marked: $markedCount, Unmarked: $deletedCount (Simulation)';
           } else if (markedCount > 0) {
             message = 'Attendance marked for $markedCount student${markedCount > 1 ? "s" : ""} (Simulation)';
           } else if (deletedCount > 0) {
             message = 'Attendance unmarked for $deletedCount student${deletedCount > 1 ? "s" : ""} (Simulation)';
           }
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(message)),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
           // Reload attendance data to reflect the newly marked attendance (update preExisting)
          setState(() {
            _attendanceStatus.forEach((key, value) {
              _preExistingAttendance[key] = value;
            });
             // Handle deletions from preExisting
              _preExistingAttendance.removeWhere((key, value) => !_attendanceStatus.containsKey(key));
          });
        }
        return;
      }

      int markedCount = 0;
      int deletedCount = 0;
      
      // Process newly marked or changed attendance
      final entries = _attendanceStatus.entries.toList();
      final providerAuth = Provider.of<AuthProvider>(context, listen: false);
      
      for (var entry in entries) {
        final preExisting = _preExistingAttendance[entry.key];
        if (preExisting == null || preExisting != entry.value) {
          if (providerAuth.isGuest) {
            // Mock mark attendance
            await Future.delayed(const Duration(milliseconds: 100)); // Simulate delay
          } else {
            await ApiService.markAttendance(
              entry.key,
              _selectedDate,
              'daily',
              entry.value,
            );
          }
          markedCount++;
        }
      }
      
      // Process deleted (unmarked) attendance
      for (var studentId in _preExistingAttendance.keys) {
        if (!_attendanceStatus.containsKey(studentId)) {
          if (providerAuth.isGuest) {
            // Mock delete attendance
            await Future.delayed(const Duration(milliseconds: 100)); // Simulate delay
          } else {
            // Send empty status to delete the record
            await ApiService.markAttendance(
              studentId,
              _selectedDate,
              'daily',
              '', // Empty status triggers deletion in backend
            );
          }
          deletedCount++;
        }
      }


      if (mounted) {
        String message = '';
        if (markedCount > 0 && deletedCount > 0) {
          message = 'Marked: $markedCount, Unmarked: $deletedCount';
        } else if (markedCount > 0) {
          message = 'Attendance marked for $markedCount student${markedCount > 1 ? "s" : ""}';
        } else if (deletedCount > 0) {
          message = 'Attendance unmarked for $deletedCount student${deletedCount > 1 ? "s" : ""}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        // Reload attendance data to reflect the newly marked attendance
        final reloadAuth = Provider.of<AuthProvider>(context, listen: false);
        final studentsProvider = Provider.of<StudentsProvider>(context, listen: false);
        await _loadAttendanceForDate(_selectedDate, reloadAuth.teacherId, studentsProvider.students);
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
        // Restart polling after save operation completes
        _startPolling();
      }
    }
  }

  void _openFaceScanner() {
    final studentsProvider = Provider.of<StudentsProvider>(context, listen: false);
    final students = studentsProvider.students;

    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students available to scan')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FaceAttendanceScannerScreen(
          students: students,
          onStudentIdentified: (student) {
            setState(() {
              _attendanceStatus[student.id] = 'present';
            });
            // Optional: show a small toast or just vibrate
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Marked Present: ${student.name}'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0E17) : const Color(0xFFF5F5FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Gradient Header ───────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 20),
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        colors: [Color(0xFF1E1A2E), Color(0xFF2D2660)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [
                          Color(0xFF3730A3),
                          Color(0xFF4F46E5),
                          Color(0xFF7C3AED)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
              ),
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
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mark Attendance',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          DateFormat('EEEE, MMMM d, y')
                              .format(_selectedDate),
                          style: TextStyle(
                              color:
                                  Colors.white.withValues(alpha: 0.75),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _openFaceScanner,
                    tooltip: 'Scan Face',
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.face_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          // Date and Session Selector
          Builder(builder: (context) {
            final cs = Theme.of(context).colorScheme;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.5),
                ),
              ),
            ),
            child: Column(
              children: [
                // Date Picker
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.surfaceContainer
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        debugPrint('DEBUG: Date changed to ${picked.toString().split(' ')[0]}');
                        setState(() {
                          _selectedDate = picked;
                        });
                        // Reload students for current class filter
                        await _loadStudentsForClass(_selectedClassId);
                        // Load attendance for the new date with current students
                        final studentsProvider = Provider.of<StudentsProvider>(context, listen: false);
                        await _loadAttendanceForDate(picked, auth.teacherId, studentsProvider.students);
                        
                        // Restart polling for the new date
                        _startPolling();
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
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.surfaceContainer
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
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
                          onChanged: (value) async {
                            debugPrint('DEBUG: Class changed from $_selectedClassId to $value');
                            setState(() {
                              _selectedClassId = value;
                            });
                            // Reload students for the selected class
                            await _loadStudentsForClass(value);
                            
                            // Load attendance for current students and date
                            final auth = Provider.of<AuthProvider>(context, listen: false);
                            final studentsProvider = Provider.of<StudentsProvider>(context, listen: false);
                            await _loadAttendanceForDate(_selectedDate, auth.teacherId, studentsProvider.students);
                            
                            // Restart polling for the new class
                            _startPolling();
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
          }),
          
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.surfaceContainerHigh
                    : Theme.of(context).colorScheme.surfaceContainerLow,
              ),
            ),
          ),
          
          // Summary
          if (_attendanceStatus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Builder(builder: (context) {
                final cs = Theme.of(context).colorScheme;
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: isDark ? null : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(
                        'Present',
                        _attendanceStatus.values.where((s) => s == 'present').length,
                        const Color(0xFF22C55E),
                      ),
                      _buildSummaryItem(
                        'Absent',
                        _attendanceStatus.values.where((s) => s == 'absent').length,
                        cs.error,
                      ),
                      _buildSummaryItem(
                        'Late',
                        _attendanceStatus.values.where((s) => s == 'late').length,
                        Colors.orange,
                      ),
                    ],
                  ),
                );
              }),
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

                // Filter students by search text and class (class filtering is done by loading appropriate students)
                final filteredStudents = _searchText.isEmpty
                    ? studentsProvider.students
                    : studentsProvider.students.where((student) => 
                        student.name.toLowerCase().contains(_searchText) ||
                        student.studentId.toLowerCase().contains(_searchText)
                      ).toList();

                if (filteredStudents.isEmpty) {
                  return EmptyState(
                    icon: _searchText.isNotEmpty ? Icons.search_off_rounded : Icons.people_outline,
                    title: _searchText.isNotEmpty
                        ? 'No Students Found'
                        : (_selectedClassId == null ? 'No Students' : 'Class is Empty'),
                    message: _searchText.isNotEmpty
                        ? 'No students match "$_searchText"'
                        : (_selectedClassId == null
                            ? 'Add students first to mark attendance'
                            : 'Select a different class or add students'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredStudents.length,
                  itemBuilder: (context, index) {
                    final student = filteredStudents[index];
                    return AttendanceStudentCard(
                      key: ValueKey(student.id), // Add key for proper widget tracking
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
      ),
      floatingActionButton: _hasNewlyMarkedAttendance()
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
                  : () {
                      int changeCount = 0;
                      // Count new/changed marks
                      for (var entry in _attendanceStatus.entries) {
                        if (_preExistingAttendance[entry.key] != entry.value) {
                          changeCount++;
                        }
                      }
                      // Count deletions
                      for (var studentId in _preExistingAttendance.keys) {
                        if (!_attendanceStatus.containsKey(studentId)) {
                          changeCount++;
                        }
                      }
                      return 'Save Changes ($changeCount)';
                    }()),
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
    // Always update _status when widget updates with different currentStatus
    if (widget.currentStatus != oldWidget.currentStatus) {
      setState(() {
        _status = widget.currentStatus;
      });
    }
  }

  // Returns the accent color for the current status
  Color _statusColor() {
    switch (_status) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'late':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Strip color on the left edge
    final stripColor = _statusColor();
    // Subtle tinted background when a status is selected
    final cardBg = _status != null
        ? stripColor.withValues(alpha: isDark ? 0.12 : 0.07)
        : (isDark ? const Color(0xFF1E1B2E) : Colors.white);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _status != null
              ? stripColor.withValues(alpha: 0.5)
              : (isDark ? Colors.white12 : cs.outlineVariant.withValues(alpha: 0.4)),
          width: _status != null ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Colored status strip on the left ──
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 5,
                color: stripColor,
              ),
              // ── Card body ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Avatar + Name/ID + Status badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Avatar
                          CircleAvatar(
                            backgroundColor: cs.primaryContainer,
                            radius: 22,
                            child: Text(
                              widget.student.name.isNotEmpty
                                  ? widget.student.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Name + ID
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.student.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'ID: ${widget.student.studentId}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withValues(alpha: 0.55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Status badge (top-right)
                          if (_status != null)
                            AnimatedScale(
                              scale: _status != null ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: stripColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: stripColor, width: 1.2),
                                ),
                                child: Text(
                                  _status!.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: stripColor,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Bottom row: Full-width P / A / L buttons
                      Row(
                        children: [
                          _StatusChip(
                            label: 'Present',
                            icon: Icons.check_circle_outline,
                            color: Colors.green,
                            isSelected: _status == 'present',
                            onTap: () {
                              setState(() {
                                _status = _status == 'present' ? null : 'present';
                              });
                              widget.onStatusChanged(_status ?? '');
                            },
                          ),
                          const SizedBox(width: 6),
                          _StatusChip(
                            label: 'Absent',
                            icon: Icons.cancel_outlined,
                            color: Colors.red,
                            isSelected: _status == 'absent',
                            onTap: () {
                              setState(() {
                                _status = _status == 'absent' ? null : 'absent';
                              });
                              widget.onStatusChanged(_status ?? '');
                            },
                          ),
                          const SizedBox(width: 6),
                          _StatusChip(
                            label: 'Late',
                            icon: Icons.schedule_outlined,
                            color: Colors.orange,
                            isSelected: _status == 'late',
                            onTap: () {
                              setState(() {
                                _status = _status == 'late' ? null : 'late';
                              });
                              widget.onStatusChanged(_status ?? '');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.4),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : color,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : color,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}