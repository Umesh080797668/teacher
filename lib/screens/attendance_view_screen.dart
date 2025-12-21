import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/reports_provider.dart';

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

class _MonthlyStatsTab extends StatefulWidget {
  final ReportsProvider reportsProvider;

  const _MonthlyStatsTab({required this.reportsProvider});

  @override
  State<_MonthlyStatsTab> createState() => _MonthlyStatsTabState();
}

class _MonthlyStatsTabState extends State<_MonthlyStatsTab> {
  DateTime _selectedMonth = DateTime.now();
  bool _showAllMonths = true;

  Future<void> _changeMonth() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedMonth = pickedDate;
        _showAllMonths = false;
      });
    }
  }

  void _toggleShowAllMonths() {
    setState(() {
      _showAllMonths = !_showAllMonths;
    });
  }

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
                  'No monthly attendance records available',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          );
        }

        // Filter data based on selected month if not showing all months
        final filteredMonthlyByClass = _showAllMonths
            ? monthlyByClass
            : monthlyByClass.map((classData) {
                final monthlyStats = classData['monthlyStats'] as List? ?? [];
                final filteredStats = monthlyStats.where((monthStat) {
                  final year = monthStat['year'] ?? 0;
                  final month = monthStat['month'] ?? 0;
                  return year == _selectedMonth.year && month == _selectedMonth.month;
                }).toList();

                return {
                  ...classData,
                  'monthlyStats': filteredStats,
                };
              }).where((classData) {
                final monthlyStats = classData['monthlyStats'] as List? ?? [];
                return monthlyStats.isNotEmpty;
              }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month selector header
              Card(
                elevation: 4,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: InkWell(
                  onTap: _changeMonth,
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
                                  'Selected Month',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _showAllMonths
                                      ? 'All Months'
                                      : '${_getMonthName(_selectedMonth.month)} ${_selectedMonth.year}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: _toggleShowAllMonths,
                                  icon: Icon(
                                    _showAllMonths ? Icons.calendar_view_month : Icons.calendar_view_week,
                                    size: 18,
                                  ),
                                  label: Text(_showAllMonths ? 'Filter' : 'Show All'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                if (!_showAllMonths)
                                  IconButton(
                                    onPressed: _changeMonth,
                                    icon: Icon(
                                      Icons.calendar_today,
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _showAllMonths
                              ? 'Showing attendance for all months'
                              : 'Tap to change month • Showing data for ${_getMonthName(_selectedMonth.month)} ${_selectedMonth.year}',
                          style: TextStyle(
                            fontSize: 12,
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
                'Monthly Attendance Statistics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _showAllMonths
                    ? 'Showing attendance statistics for all months'
                    : 'Showing attendance statistics for ${_getMonthName(_selectedMonth.month)} ${_selectedMonth.year}',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),

              if (filteredMonthlyByClass.isEmpty)
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
                            _showAllMonths
                                ? 'No attendance records available'
                                : 'No attendance records for ${_getMonthName(_selectedMonth.month)} ${_selectedMonth.year}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...filteredMonthlyByClass.map((classData) {
                  final className = classData['className'] ?? 'Unknown Class';
                  final totalStudents = classData['totalStudents'] ?? 0;
                  final monthlyStats = classData['monthlyStats'] as List? ?? [];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ExpansionTile(
                      title: Row(
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '$totalStudents Students',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        _showAllMonths
                            ? '${monthlyStats.length} months with records'
                            : '${monthlyStats.isNotEmpty ? monthlyStats[0]['totalDays'] ?? 0 : 0} days conducted',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      children: [
                        if (monthlyStats.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
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
                          ...monthlyStats.map((monthStat) {
                            final year = monthStat['year'] ?? 0;
                            final month = monthStat['month'] ?? 0;
                            final conductedDays = monthStat['conductedDays'] as List? ?? [];
                            final totalDays = monthStat['totalDays'] ?? conductedDays.length;

                            return Container(
                              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _showAllMonths ? '${_getMonthName(month)} $year' : 'Attendance Details',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$totalDays Days Conducted',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ...conductedDays.map((dayStat) {
                                    final dateStr = dayStat['date']?.toString() ?? '';
                                    final present = dayStat['presentCount'] ?? 0;
                                    final absent = dayStat['absentCount'] ?? 0;
                                    final late = dayStat['lateCount'] ?? 0;
                                    final total = dayStat['totalRecorded'] ?? 0;

                                    // Parse and format date
                                    DateTime? date;
                                    try {
                                      date = DateTime.parse(dateStr);
                                    } catch (e) {
                                      date = null;
                                    }

                                    final formattedDate = date != null
                                        ? '${_getMonthName(date.month)} ${date.day}, ${date.year}'
                                        : dateStr;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surface,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.calendar_today,
                                                    size: 14,
                                                    color: Theme.of(context).colorScheme.primary,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    formattedDate,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                      color: Theme.of(context).colorScheme.onSurface,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.secondaryContainer,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  'Total: $total',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _StatItem(
                                                  label: 'Present',
                                                  value: present.toString(),
                                                  color: Colors.green,
                                                ),
                                              ),
                                              Expanded(
                                                child: _StatItem(
                                                  label: 'Absent',
                                                  value: absent.toString(),
                                                  color: Colors.red,
                                                ),
                                              ),
                                              Expanded(
                                                child: _StatItem(
                                                  label: 'Late',
                                                  value: late.toString(),
                                                  color: Colors.orange,
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
                            );
                          }).toList(),
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

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return month >= 1 && month <= 12 ? months[month - 1] : 'Unknown';
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
