import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../models/payment.dart';
import '../services/api_service.dart';

class StudentDetailsScreen extends StatefulWidget {
  final Student student;

  const StudentDetailsScreen({super.key, required this.student});

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> with SingleTickerProviderStateMixin {
  List<Attendance> _studentAttendance = [];
  List<Payment> _studentPayments = [];
  bool _isLoadingAttendance = true;
  bool _isLoadingPayments = true;
  Map<String, int> _attendanceStats = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
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
      final attendance = await ApiService.getAttendance(studentId: widget.student.id);

      // Sort attendance by date descending (most recent first)
      attendance.sort((a, b) => b.date.compareTo(a.date));

      // Calculate statistics
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
    } catch (e) {
      setState(() {
        _isLoadingAttendance = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load attendance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadStudentPayments() async {
    setState(() {
      _isLoadingPayments = true;
    });

    try {
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
    
    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).colorScheme.background : Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Student Details'),
        elevation: 0,
        backgroundColor: isDark ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: isDark ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onPrimaryContainer,
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
                    const Center(child: CircularProgressIndicator())
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
                    const Center(child: CircularProgressIndicator())
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
                    const Center(child: CircularProgressIndicator())
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
                          color: isDark ? Theme.of(context).colorScheme.surfaceVariant : Theme.of(context).colorScheme.surface,
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