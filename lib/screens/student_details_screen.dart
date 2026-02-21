import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // Added for contact actions
import '../models/student.dart';
import '../models/attendance.dart';
import '../models/payment.dart';
import '../models/class.dart' as class_model;
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

  @override
  void initState() {
    super.initState();
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
            backgroundColor: Colors.red,
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

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final colors = Theme.of(context).colorScheme;
            return AlertDialog(
              backgroundColor: Theme.of(context).dialogBackgroundColor,
              title: Text(
                'Assign to Another Class',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select a class to add this student to:', style: TextStyle(color: colors.onSurface)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedClassId,
                    hint: Text('Select Class', style: TextStyle(color: colors.onSurfaceVariant)),
                    dropdownColor: Theme.of(context).cardColor,
                    style: TextStyle(color: colors.onSurface),
                    isExpanded: true,
                    items: availableClasses.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, style: TextStyle(color: colors.onSurface)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedClassId = value;
                      });
                    },
                    decoration: InputDecoration(
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: colors.onSurfaceVariant)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                  ),
                  onPressed: selectedClassId == null
                      ? null
                      : () async {
                          final classIdToAdd = selectedClassId; // Capture value
                          Navigator.pop(context); // Close dialog
                          
                          try {
                              final provider = Provider.of<StudentsProvider>(context, listen: false);
                              // Using addStudent which now handles existing students correctly
                              await provider.addStudent(
                                  student.name, 
                                  student.email, 
                                  student.phoneNumber, 
                                  student.studentId, 
                                  classIdToAdd
                              );
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Successfully assigned to new class'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                          } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to assign class: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                          }
                        },
                  child: const Text('Assign'),
                ),
              ],
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
            backgroundColor: Colors.red,
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
      backgroundColor: isDark ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Student Details'),
        elevation: 0,
        backgroundColor: isDark ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: isDark ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onPrimaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.face),
            onPressed: currentStudent.hasFaceData 
              ? null // Disable if already registered
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FaceRegistrationScreen(student: currentStudent),
                  ),
                ),
            tooltip: currentStudent.hasFaceData ? 'Face Already Registered' : 'Register Face',
          ),
          IconButton(
            icon: const Icon(Icons.class_),
            onPressed: () => _assignToClass(currentStudent),
            tooltip: 'Assign to Another Class',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditStudentDialog,
            tooltip: 'Edit Student',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onPrimaryContainer,
          unselectedLabelColor: isDark ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6) : Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.6),
          indicatorColor: isDark ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onPrimaryContainer,
          tabs: const [
            Tab(text: 'Attendance', icon: Icon(Icons.calendar_today)),
            Tab(text: 'Payments', icon: Icon(Icons.payment)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAttendanceTab(isDark),
          _buildPaymentsTab(isDark),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadStudentAttendance,
      backgroundColor: Theme.of(context).colorScheme.surface,
      color: Theme.of(context).colorScheme.primary,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Info Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    radius: 40,
                    child: Text(
                      widget.student.name.isNotEmpty ? widget.student.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.student.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ID: ${widget.student.studentId}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (widget.student.email != null && widget.student.email!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.email,
                          size: 16,
                          color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.student.email!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Added Contact Buttons
                  if (widget.student.phoneNumber != null && widget.student.phoneNumber!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              ElevatedButton.icon(
                                  icon: const Icon(Icons.phone, size: 18),
                                  label: const Text('Call'),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.blue,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                  ),
                                  onPressed: () async {
                                      final uri = Uri.parse('tel:${widget.student.phoneNumber}');
                                      if (await canLaunchUrl(uri)) launchUrl(uri);
                                  }
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                  icon: const Icon(Icons.message, size: 18),
                                  label: const Text('WhatsApp'),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF25D366), // WhatsApp green
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                  ),
                                  onPressed: () async {
                                      String phone = widget.student.phoneNumber!.replaceAll(RegExp(r'\D'), '');
                                      final uri = Uri.parse('https://wa.me/$phone');
                                      if (await canLaunchUrl(uri)) {
                                          launchUrl(uri, mode: LaunchMode.externalApplication);
                                      }
                                  }
                              ),
                          ],
                      ),
                  ]
                ],
              ),
            ),

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
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _AttendanceStatCard(
                                title: 'Absent',
                                value: '${_attendanceStats['absent'] ?? 0}',
                                icon: Icons.cancel,
                                color: Colors.red,
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
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 48,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No attendance records yet',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
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
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getStatusColor(record.status).withOpacity(0.1),
                                  child: Icon(
                                    _getStatusIcon(record.status),
                                    color: _getStatusColor(record.status),
                                  ),
                                ),
                                title: Text(
                                  '${record.date.day}/${record.date.month}/${record.date.year}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text('${record.session} - ${record.status.toUpperCase()}'),
                                trailing: Text(
                                  '${record.date.hour}:${record.date.minute.toString().padLeft(2, '0')}',
                                  style: Theme.of(context).textTheme.bodySmall,
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      color: Theme.of(context).colorScheme.primary,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Info Header (same as attendance tab)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    backgroundColor: isDark ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.primary,
                    radius: 40,
                    child: Text(
                      widget.student.name.isNotEmpty ? widget.student.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Theme.of(context).colorScheme.onPrimaryContainer : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.student.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isDark ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ID: ${widget.student.studentId}',
                      style: TextStyle(
                        color: isDark ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

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
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.payment_outlined,
                              size: 48,
                              color: isDark ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5) : Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No payment records yet',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: isDark ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7) : Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: paymentsByMonth.entries.map((entry) {
                        final monthKey = entry.key;
                        final payments = entry.value;
                        final totalAmount = payments.fold<double>(0, (sum, payment) => sum + payment.amount);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          color: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Theme.of(context).colorScheme.surface,
                          child: ExpansionTile(
                            title: Text(
                              _getMonthName(monthKey),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              '${payments.length} payment${payments.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: isDark ? Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7) : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Text(
                                'Rs. ${totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            children: payments.map((payment) {
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getPaymentTypeColor(payment.type).withOpacity(0.1),
                                  child: Icon(
                                    Icons.check_circle,
                                    color: _getPaymentTypeColor(payment.type),
                                  ),
                                ),
                                title: Text(
                                  payment.type.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  '${payment.date.day}/${payment.date.month}/${payment.date.year}',
                                  style: TextStyle(
                                    color: isDark ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6) : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                                trailing: Text(
                                  'Rs. ${payment.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _getPaymentTypeColor(payment.type),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
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
        return Colors.green;
      case 'half':
        return Colors.orange;
      case 'free':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
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

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            title: Text(
              'Edit Student',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black54,
                    ),
                    prefixIcon: Icon(
                      Icons.person,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black54,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Email (optional)',
                    labelStyle: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black54,
                    ),
                    prefixIcon: Icon(
                      Icons.email,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black54,
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    labelStyle: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black54,
                    ),
                    prefixIcon: Icon(
                      Icons.phone,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black54,
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                Consumer<ClassesProvider>(
                  builder: (context, classesProvider, child) {
                    return Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      child: DropdownButtonFormField<String?>(
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                        dropdownColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.white,
                        initialValue: selectedClassId,
                        decoration: InputDecoration(
                          labelText: 'Class (optional)',
                          labelStyle: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : Colors.black54,
                          ),
                          prefixIcon: Icon(
                            Icons.class_,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : Colors.black54,
                          ),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'No Class',
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                          ),
                          ...classesProvider.classes.map((class_model.Class cls) {
                            return DropdownMenuItem<String?>(
                              value: cls.id,
                              child: Text(
                                cls.name,
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedClassId = value;
                          });
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a name')),
                  );
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

                  // Update local state to reflect changes immediately
                  // Note: Since we are inside a StatefulBuilder, 'setState' here refers to the dialog's state.
                  // We need to update the parent widget's state as well.
                  // By updating _currentStudent (which is in the parent state), we just need to trigger a rebuild of the parent.
                  
                  // Update the variable in the parent state class
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
                    faceEmbedding: _currentStudent.faceEmbedding
                  );

                  // Trigger rebuild of the parent Screen
                  // We can't easily call the parent's setState from here directly without context tricks or passing a callback.
                  // However, since we are popping the dialog immediately, we can just rely on the fact that
                  // when the dialog closes, we want the screen to show new data.
                  // A simple way is to use a callback or just ensure that when we pop, we trigger a rebuild.
                  // But actually, since _currentStudent is updated, using a simple trick:
                  
                  // This calls the SETSTATE OF THE PARENT WIDGET because we are capturing the parent's setState 
                  // method if we were in the scope, but we are shadowed by the StatefulBuilder's setState.
                  // To fix this, we should rely on the fact that we can call the method of the state class.
                  // Since we are in the method _showEditStudentDialog which is a method of _StudentDetailsScreenState,
                  // we can use 'this.setState'.
                  
                  this.setState(() {});

                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Student updated successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update student: $e')),
                    );
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
        },
      ),
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
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}