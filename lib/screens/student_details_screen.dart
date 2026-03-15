import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teacher_attendance/screens/screen_tutorial.dart';
import 'package:teacher_attendance/screens/tutorial_keys.dart';
import 'package:teacher_attendance/screens/tutorial_screen.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // Added for contact actions
import '../models/student.dart';
import '../models/attendance.dart';
import '../models/payment.dart';
import '../services/api_service.dart';
import '../providers/students_provider.dart';
import '../providers/classes_provider.dart';
import '../widgets/custom_widgets.dart';
import 'face_registration_screen.dart';

class StudentDetailsScreen extends StatefulWidget {
  final Student student;

  const StudentDetailsScreen({super.key, required this.student});

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> with SingleTickerProviderStateMixin {
  late Student _currentStudent; // Local state to hold the potentially updated student
  List<Attendance> _studentAttendance = [];
  List<Payment> _studentPayments = [];
  bool _isLoadingAttendance = true;
  bool _isLoadingPayments = true;
  Map<String, int> _attendanceStats = {};
  late TabController _tabController;

  // Tutorial Steps
  final List<STStep> _tutSteps = [
    STStep(
      targetKey: tutorialKeySdProfile,
      title: 'Student Profile',
      body: 'View the student\'s details, parent contact, and validation status here.',
      icon: Icons.person_rounded,
      accent: const Color(0xFF4F46E5),
    ),
    STStep(
      targetKey: tutorialKeySdActions,
      title: 'Quick Actions',
      body: 'Edit student details, reset linked devices, or delete the student from this menu.',
      icon: Icons.more_vert_rounded,
      accent: const Color(0xFF4F46E5),
    ),
    STStep(
      targetKey: tutorialKeySdTabs,
      title: 'Student Records',
      body: 'Switch between the student\'s Attendance history, Payments, and Quiz grades.',
      icon: Icons.tab_rounded,
      accent: const Color(0xFF4F46E5),
    ),
  ];

  Future<void> _maybeShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    if (TutorialScreen.isRunning) return;
    final allSkipped = prefs.getBool('all_tutorials_skipped') ?? false;
    if (allSkipped) return;
    
    final hasSeen = prefs.getBool('tutorial_sd_v1') ?? false;
    if (!hasSeen) {
      if (!mounted) return;
      await prefs.setBool('tutorial_sd_v1', true);
      showSTTutorial(context: context, steps: _tutSteps, prefKey: 'tutorial_sd_v1');
    }
  }


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { _maybeShowTutorial(); });
    _currentStudent = widget.student; // Initialize with widget data
    _tabController = TabController(length: 2, vsync: this);
    _loadStudentAttendance();
    _loadStudentPayments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentAttendance() async {
    setState(() {
      _isLoadingAttendance = true;
    });

    try {
      if (widget.student.id.startsWith('guest_student_')) {
          await Future.delayed(const Duration(milliseconds: 500)); // Simulate delay
          List<Attendance> attendance = [
            Attendance(
              id: 'guest_att_1',
              studentId: widget.student.id,
              date: DateTime.now().subtract(const Duration(days: 1)),
              session: 'Morning',
              status: 'Present',
              month: DateTime.now().month,
              year: DateTime.now().year,
            ),
             Attendance(
              id: 'guest_att_2',
              studentId: widget.student.id,
              date: DateTime.now().subtract(const Duration(days: 2)),
              session: 'Morning',
              status: 'Present',
              month: DateTime.now().month,
              year: DateTime.now().year,
            ),
             Attendance(
              id: 'guest_att_3',
              studentId: widget.student.id,
              date: DateTime.now().subtract(const Duration(days: 5)),
              session: 'Morning',
              status: 'Absent',
              month: DateTime.now().month,
              year: DateTime.now().year,
            ),
          ];
          
          attendance.sort((a, b) => b.date.compareTo(a.date));

          final stats = <String, int>{};
          for (final record in attendance) {
            final status = record.status.toLowerCase().trim();
            stats[status] = (stats[status] ?? 0) + 1;
          }

          setState(() {
            _studentAttendance = attendance;
            _attendanceStats = stats;
            _isLoadingAttendance = false;
          });
          return;
      }

      final attendance = await ApiService.getAttendance(studentId: widget.student.id);

      // Sort attendance by date descending (most recent first)
      attendance.sort((a, b) => b.date.compareTo(a.date));

      // Calculate statistics
      final stats = <String, int>{};
      for (final record in attendance) {
        final status = record.status.toLowerCase().trim();
        stats[status] = (stats[status] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          _studentAttendance = attendance;
          _attendanceStats = stats;
          _isLoadingAttendance = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAttendance = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load attendance: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _assignToClass(Student student) async {
    final classesProvider = Provider.of<ClassesProvider>(context, listen: false);
    
    // Ensure classes are loaded
    if (classesProvider.classes.isEmpty) {
        // Maybe fetch?
    }

    String? selectedClassId;
    
    // Filter available classes (exclude current class and already assigned classes)
    final existingClassIds = [
      if (student.classId != null) student.classId!,
      if (student.classIds != null) ...student.classIds!
    ];
    
    final availableClasses = classesProvider.classes.where(
      (c) => !existingClassIds.contains(c.id)
    ).toList();
    
    if (availableClasses.isEmpty) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No other classes available to assign.')),
        );
      }
       return; 
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        final cs = Theme.of(sheetCtx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, -4))],
                ),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2)))),
                    Row(
                      children: [
                        Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Assign to Another Class', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: cs.onSurface)),
                            Text('Select a class for this student', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          ]),
                        ),
                        IconButton(onPressed: () => Navigator.pop(sheetCtx), icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: selectedClassId,
                      hint: Text('Select Class', style: TextStyle(color: cs.onSurfaceVariant)),
                      dropdownColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                      style: TextStyle(color: cs.onSurface),
                      isExpanded: true,
                      items: availableClasses.map((c) {
                        return DropdownMenuItem(value: c.id, child: Text(c.name, style: TextStyle(color: cs.onSurface)));
                      }).toList(),
                      onChanged: (value) => setSheetState(() => selectedClassId = value),
                      decoration: InputDecoration(
                        labelText: 'Class',
                        labelStyle: TextStyle(color: cs.onSurfaceVariant),
                        prefixIcon: const Icon(Icons.class_rounded),
                      ),
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: selectedClassId == null
                          ? null
                          : () async {
                              final classIdToAdd = selectedClassId;
                              Navigator.pop(sheetCtx);
                              try {
                                final provider = Provider.of<StudentsProvider>(context, listen: false);
                                await provider.addStudent(student.name, student.email, student.phoneNumber, student.studentId, classIdToAdd);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully assigned to new class')));
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to assign class: $e'), backgroundColor: Theme.of(context).colorScheme.error));
                                }
                              }
                            },
                      child: AnimatedOpacity(
                        opacity: selectedClassId == null ? 0.5 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: selectedClassId == null ? [] : [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 5))],
                          ),
                          child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.check_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Text('Assign to Class', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                          ])),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadStudentPayments() async {
    setState(() {
      _isLoadingPayments = true;
    });

    try {
      if (widget.student.id.startsWith('guest_student_')) {
          await Future.delayed(const Duration(milliseconds: 500)); // Simulate delay
          List<Payment> payments = [
            Payment(
              id: 'guest_pay_1',
              studentId: widget.student.id,
              classId: widget.student.classId ?? 'guest_class_1',
              amount: 50.0,
              type: 'full',
              date: DateTime.now().subtract(const Duration(days: 5)),
              month: DateTime.now().month,
              year: DateTime.now().year,
            )
          ];

           // Sort payments by date descending (most recent first)
          payments.sort((a, b) => b.date.compareTo(a.date));
          
           setState(() {
            _studentPayments = payments;
            _isLoadingPayments = false;
          });
          return;
      }

      final payments = await ApiService.getPayments(studentId: widget.student.id);

      // Sort payments by date descending (most recent first)
      payments.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _studentPayments = payments;
        _isLoadingPayments = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPayments = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load payments: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Get latest student data from provider to reflect changes like face registration
    final studentsProvider = Provider.of<StudentsProvider>(context);
    final currentStudent = studentsProvider.students.cast<Student?>().firstWhere(
      (s) => s?.id == widget.student.id,
      orElse: () => widget.student,
    ) ?? widget.student;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0E17) : const Color(0xFFF5F5FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Gradient Hero Header ─────────────────────────────────────
            Container(
              key: tutorialKeySdProfile,
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        colors: [Color(0xFF1E1A2E), Color(0xFF2D2660)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)
                    : const LinearGradient(
                        colors: [
                          Color(0xFF3730A3),
                          Color(0xFF4F46E5),
                          Color(0xFF7C3AED)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
              ),
              child: Column(
                children: [
                  // Action bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
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
                        const Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                                alpha:
                                    currentStudent.hasFaceData ? 0.08 : 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.face_rounded,
                                color: Colors.white, size: 20),
                            onPressed: currentStudent.hasFaceData
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            FaceRegistrationScreen(
                                                student: currentStudent))),
                            tooltip: currentStudent.hasFaceData
                                ? 'Face Already Registered'
                                : 'Register Face',
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.class_rounded,
                                color: Colors.white, size: 20),
                            onPressed: () => _assignToClass(currentStudent),
                            tooltip: 'Assign to Another Class',
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.edit_rounded,
                                color: Colors.white, size: 20),
                            onPressed: _showEditStudentDialog,
                            tooltip: 'Edit Student',
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Large avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6))
                      ],
                    ),
                    child: Center(
                      child: Text(
                        currentStudent.name.isNotEmpty
                            ? currentStudent.name[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currentStudent.name,
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      'ID: ${currentStudent.studentId}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ),
                  ),
                  if (currentStudent.email != null &&
                      currentStudent.email!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.email_rounded,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.75)),
                        const SizedBox(width: 4),
                        Text(currentStudent.email!,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12)),
                      ],
                    ),
                  ],
                  if (currentStudent.phoneNumber != null &&
                      currentStudent.phoneNumber!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final uri = Uri.parse(
                                'tel:${currentStudent.phoneNumber}');
                            if (await canLaunchUrl(uri)) launchUrl(uri);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.4))),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone_rounded,
                                    size: 14, color: Colors.white),
                                SizedBox(width: 6),
                                Text('Call',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () async {
                            String phone = currentStudent.phoneNumber!
                                .replaceAll(RegExp(r'\D'), '');
                            final uri =
                                Uri.parse('https://wa.me/$phone');
                            if (await canLaunchUrl(uri)) {
                              launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                                color: const Color(0xFF25D366)
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: const Color(0xFF25D366)
                                        .withValues(alpha: 0.6))),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.message_rounded,
                                    size: 14, color: Colors.white),
                                SizedBox(width: 6),
                                Text('WhatsApp',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Attendance'),
                      Tab(text: 'Payments'),
                    ],
                  ),
                ],
              ),
            ),
            // ── Tab Content ───────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAttendanceTab(isDark),
                  _buildPaymentsTab(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceTab(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadStudentAttendance,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Attendance Statistics
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attendance Statistics',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingAttendance)
                    const AttendanceStatsSkeleton()
                  else
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _AttendanceStatCard(
                                title: 'Present',
                                value: '${_attendanceStats['present'] ?? 0}',
                                icon: Icons.check_circle,
                                color: const Color(0xFF22C55E),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _AttendanceStatCard(
                                title: 'Absent',
                                value: '${_attendanceStats['absent'] ?? 0}',
                                icon: Icons.cancel,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _AttendanceStatCard(
                                title: 'Late',
                                value: '${_attendanceStats['late'] ?? 0}',
                                icon: Icons.schedule,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _AttendanceStatCard(
                                title: 'Total',
                                value: '${_studentAttendance.length}',
                                icon: Icons.calendar_today,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                  // Recent Attendance
                  const SizedBox(height: 32),
                  Text(
                    'Recent Attendance',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingAttendance)
                    ListSkeleton(
                      itemCount: 5,
                      itemBuilder: (context) => const AttendanceCardSkeleton(),
                    )
                  else if (_studentAttendance.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: EmptyState(
                          icon: Icons.calendar_today_outlined,
                          title: 'No attendance records',
                          message: 'No records found yet',
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _studentAttendance.length > 10 ? 10 : _studentAttendance.length,
                          itemBuilder: (context, index) {
                            final record = _studentAttendance[index];
                            final cs = Theme.of(context).colorScheme;
                            final dark = Theme.of(context).brightness == Brightness.dark;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: dark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                                border: dark ? null : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getStatusColor(record.status).withValues(alpha: 0.12),
                                  child: Icon(
                                    _getStatusIcon(record.status),
                                    color: _getStatusColor(record.status),
                                  ),
                                ),
                                title: Text(
                                  '${record.date.day}/${record.date.month}/${record.date.year}',
                                  style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface),
                                ),
                                subtitle: Text(
                                  '${record.session} • ${record.status.toUpperCase()}',
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                ),
                                trailing: Text(
                                  '${record.date.hour}:${record.date.minute.toString().padLeft(2, '0')}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        if (_studentAttendance.length > 10)
                          Center(
                            child: TextButton(
                              onPressed: () {
                                // Could navigate to full attendance history
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Full attendance history coming soon!')),
                                );
                              },
                              child: const Text('View All Records'),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentsTab(bool isDark) {
    // Group payments by month
    final paymentsByMonth = <String, List<Payment>>{};
    for (var payment in _studentPayments) {
      final monthKey = '${payment.date.month}/${payment.date.year}';
      paymentsByMonth.putIfAbsent(monthKey, () => []).add(payment);
    }

    return RefreshIndicator(
      onRefresh: _loadStudentPayments,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment History
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment History',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingPayments)
                    ListSkeleton(
                      itemCount: 3,
                      itemBuilder: (context) => const PaymentCardSkeleton(),
                    )
                  else if (_studentPayments.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: EmptyState(
                          icon: Icons.payment_outlined,
                          title: 'No payment records',
                          message: 'No payment history found',
                        ),
                      ),
                    )
                  else
                    Column(
                      children: paymentsByMonth.entries.map((entry) {
                        final monthKey = entry.key;
                        final payments = entry.value;

                        return Builder(builder: (ctx) {
                          final cs = Theme.of(ctx).colorScheme;
                          final dark = Theme.of(ctx).brightness == Brightness.dark;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: dark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: dark ? null : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                            ),
                            child: ExpansionTile(
                              title: Text(
                                _getMonthName(monthKey),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                '${payments.length} payment${payments.length > 1 ? 's' : ''}',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                                ),
                                child: const Text(
                                  'Paid',
                                  style: TextStyle(
                                    color: Color(0xFF22C55E),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              children: payments.map((payment) {
                                return Container(
                                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: dark ? cs.surfaceContainer : cs.surface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: _getPaymentTypeColor(payment.type).withValues(alpha: 0.12),
                                        child: Icon(
                                          Icons.check_circle_rounded,
                                          size: 18,
                                          color: _getPaymentTypeColor(payment.type),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              payment.type.toUpperCase(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: cs.onSurface,
                                              ),
                                            ),
                                            Text(
                                              '${payment.date.day}/${payment.date.month}/${payment.date.year}',
                                              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        'Rs. ${payment.amount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _getPaymentTypeColor(payment.type),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        });
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(String monthKey) {
    final parts = monthKey.split('/');
    final month = int.parse(parts[0]);
    final year = parts[1];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[month - 1]} $year';
  }

  Color _getPaymentTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'full':
      case 'paid':
        return const Color(0xFF22C55E);
      case 'half':
        return Colors.orange;
      case 'free':
        return Theme.of(context).colorScheme.primary;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return const Color(0xFF22C55E);
      case 'absent':
        return Theme.of(context).colorScheme.error;
      case 'late':
        return Colors.orange;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Icons.check_circle;
      case 'absent':
        return Icons.cancel;
      case 'late':
        return Icons.schedule;
      default:
        return Icons.help;
    }
  }

  void _showEditStudentDialog() {
    final nameController = TextEditingController(text: _currentStudent.name);
    final emailController = TextEditingController(text: _currentStudent.email ?? '');
    final phoneController = TextEditingController(text: _currentStudent.phoneNumber ?? '');
    String? selectedClassId = _currentStudent.classId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        final cs = Theme.of(sheetCtx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, -4))],
                ),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2)))),
                      Row(
                        children: [
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Edit Student', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: cs.onSurface)),
                              Text('Update student information', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                            ]),
                          ),
                          IconButton(onPressed: () => Navigator.pop(sheetCtx), icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: nameController,
                        style: TextStyle(color: cs.onSurface),
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          labelStyle: TextStyle(color: cs.onSurfaceVariant),
                          prefixIcon: const Icon(Icons.person_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: emailController,
                        style: TextStyle(color: cs.onSurface),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email (optional)',
                          labelStyle: TextStyle(color: cs.onSurfaceVariant),
                          prefixIcon: const Icon(Icons.email_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: phoneController,
                        style: TextStyle(color: cs.onSurface),
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Mobile Number',
                          labelStyle: TextStyle(color: cs.onSurfaceVariant),
                          prefixIcon: const Icon(Icons.phone_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Consumer<ClassesProvider>(
                        builder: (context, classesProvider, child) {
                          return DropdownButtonFormField<String?>(
                            value: selectedClassId,
                            dropdownColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                            style: TextStyle(color: cs.onSurface),
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Class (optional)',
                              labelStyle: TextStyle(color: cs.onSurfaceVariant),
                              prefixIcon: const Icon(Icons.class_rounded),
                            ),
                            items: [
                              DropdownMenuItem<String?>(value: null, child: Text('No Class', style: TextStyle(color: cs.onSurface))),
                              ...classesProvider.classes.map((cls) => DropdownMenuItem<String?>(
                                value: cls.id,
                                child: Text(cls.name, style: TextStyle(color: cs.onSurface)),
                              )),
                            ],
                            onChanged: (value) => setSheetState(() => selectedClassId = value),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () async {
                          if (nameController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a name')));
                            return;
                          }
                          try {
                            await Provider.of<StudentsProvider>(context, listen: false).updateStudent(
                              _currentStudent.id,
                              nameController.text,
                              emailController.text.isEmpty ? null : emailController.text,
                              phoneController.text.isEmpty ? null : phoneController.text,
                              selectedClassId,
                            );
                            _currentStudent = Student(
                              id: _currentStudent.id,
                              name: nameController.text,
                              email: emailController.text.isEmpty ? null : emailController.text,
                              phoneNumber: phoneController.text.isEmpty ? null : phoneController.text,
                              studentId: _currentStudent.studentId,
                              classId: selectedClassId,
                              createdAt: _currentStudent.createdAt,
                              isRestricted: _currentStudent.isRestricted,
                              restrictionReason: _currentStudent.restrictionReason,
                              restrictedAt: _currentStudent.restrictedAt,
                              hasFaceData: _currentStudent.hasFaceData,
                              faceEmbedding: _currentStudent.faceEmbedding,
                            );
                            this.setState(() {});
                            if (mounted) {
                              Navigator.of(sheetCtx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student updated successfully')));
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update student: $e')));
                            }
                          }
                        },
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 5))],
                          ),
                          child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.save_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                          ])),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AttendanceStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _AttendanceStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? null : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}