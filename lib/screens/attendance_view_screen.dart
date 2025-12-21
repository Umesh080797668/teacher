import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/reports_provider.dart';
import '../widgets/class_student_details_modal.dart';

class AttendanceViewScreen extends StatefulWidget {
  const AttendanceViewScreen({super.key});

  @override
  State<AttendanceViewScreen> createState() => _AttendanceViewScreenState();
}

class _AttendanceViewScreenState extends State<AttendanceViewScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      context.read<ReportsProvider>().loadReports(teacherId: auth.teacherId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportsProvider = Provider.of<ReportsProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('View Attendance'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Daily View'),
            Tab(text: 'Monthly Stats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DailyViewTab(reportsProvider: reportsProvider),
          _MonthlyStatsTab(reportsProvider: reportsProvider),
        ],
      ),
    );
  }
}

class _DailyViewTab extends StatefulWidget {
  final ReportsProvider reportsProvider;

  const _DailyViewTab({required this.reportsProvider});

  @override
  State<_DailyViewTab> createState() => _DailyViewTabState();
}

class _DailyViewTabState extends State<_DailyViewTab> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDailyData();
    });
  }

  Future<void> _loadDailyData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await widget.reportsProvider.loadDailyAttendance(
      _selectedDate,
      teacherId: auth.teacherId,
    );
  }

  Future<void> _changeDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
      _loadDailyData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportsProvider>(
      builder: (context, provider, child) {
        final firstDayOfYear = DateTime(_selectedDate.year, 1, 1);
        final dayOfYear = _selectedDate.difference(firstDayOfYear).inDays + 1;

        if (provider.isDailyLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final dailyStats = provider.getDailyStats();
        final studentsByClass = provider.getStudentsByClass();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: InkWell(
                  onTap: _changeDate,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Day of Year',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Day $dayOfYear',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedDate.toString().split(' ')[0],
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                'Daily Attendance View',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Shows attendance for ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Present',
                      value: dailyStats['presentCount'].toString(),
                      color: Colors.green,
                      icon: Icons.check_circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Absent',
                      value: dailyStats['absentCount'].toString(),
                      color: Colors.red,
                      icon: Icons.cancel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Late',
                      value: dailyStats['lateCount'].toString(),
                      color: Colors.orange,
                      icon: Icons.schedule,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Rate',
                      value: '${dailyStats['attendanceRate'].toStringAsFixed(0)}%',
                      color: Colors.blue,
                      icon: Icons.analytics,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (studentsByClass.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No data available for this date',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...studentsByClass.entries.map((entry) {
                  final className = entry.key;
                  final students = entry.value;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ExpansionTile(
                      title: Text(
                        className,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        '${students.length} Students',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: students.map((student) {
                              final status = student['status'] as String;
                              Color statusColor;
                              IconData statusIcon;
                              String statusText;

                              switch (status) {
                                case 'present':
                                  statusColor = Colors.green;
                                  statusIcon = Icons.check_circle;
                                  statusText = 'Present';
                                  break;
                                case 'absent':
                                  statusColor = Colors.red;
                                  statusIcon = Icons.cancel;
                                  statusText = 'Absent';
                                  break;
                                case 'late':
                                  statusColor = Colors.orange;
                                  statusIcon = Icons.schedule;
                                  statusText = 'Late';
                                  break;
                                default:
                                  statusColor = Colors.grey;
                                  statusIcon = Icons.help_outline;
                                  statusText = 'Not Recorded';
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: statusColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(statusIcon, color: statusColor, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            student['name'],
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                          if (student['studentId'] != null && student['studentId'].toString().isNotEmpty)
                                            Text(
                                              'ID: ${student['studentId']}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          statusText,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: statusColor,
                                          ),
                                        ),
                                        if (student['session'] != null && student['session'].toString().isNotEmpty)
                                          Text(
                                            student['session'],
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
            ],
          ),
        );
      },
    );
  }
}

class _MonthlyStatsTab extends StatelessWidget {
  final ReportsProvider reportsProvider;

  const _MonthlyStatsTab({required this.reportsProvider});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final monthlyByClass = provider.monthlyByClass;

        if (monthlyByClass.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 80,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No monthly statistics available',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monthly Statistics by Class',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              ...monthlyByClass.map((classData) {
                final className = classData['className'] ?? 'Unknown Class';
                final classId = classData['classId'] ?? '';
                final totalStudents = classData['totalStudents'] ?? 0;
                final monthlyStats = classData['monthlyStats'] as List? ?? [];

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: monthlyStats.isNotEmpty
                        ? () {
                            final recentStat = monthlyStats.first;
                            final month = recentStat['month'] ?? DateTime.now().month;
                            final year = recentStat['year'] ?? DateTime.now().year;
                            
                            showDialog(
                              context: context,
                              builder: (context) => ClassStudentDetailsModal(
                                classId: classId,
                                className: className,
                                month: month,
                                year: year,
                              ),
                            );
                          }
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  className,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$totalStudents Students',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                  if (monthlyStats.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (monthlyStats.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'No attendance records yet',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...monthlyStats.map((stat) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${stat['month']}/${stat['year']}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _StatItem(
                                            label: 'Present',
                                            value: stat['presentCount']?.toString() ?? '0',
                                            color: Colors.green,
                                          ),
                                        ),
                                        Expanded(
                                          child: _StatItem(
                                            label: 'Absent',
                                            value: stat['absentCount']?.toString() ?? '0',
                                            color: Colors.red,
                                          ),
                                        ),
                                        Expanded(
                                          child: _StatItem(
                                            label: 'Late',
                                            value: stat['lateCount']?.toString() ?? '0',
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: LinearProgressIndicator(
                                            value: (stat['averageRate'] ?? 0) / 100,
                                            backgroundColor: Colors.grey[300],
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              (stat['averageRate'] ?? 0) >= 75 ? Colors.green : Colors.orange,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${(stat['averageRate'] ?? 0).toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: (stat['averageRate'] ?? 0) >= 75 ? Colors.green : Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
