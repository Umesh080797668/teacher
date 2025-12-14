import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/students_provider.dart';

class AttendanceViewScreen extends StatefulWidget {
  const AttendanceViewScreen({super.key});

  @override
  State<AttendanceViewScreen> createState() => _AttendanceViewScreenState();
}

class _AttendanceViewScreenState extends State<AttendanceViewScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _showChart = true;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final studentsProvider = Provider.of<StudentsProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await Future.wait([
        provider.loadAttendance(month: _selectedMonth, year: _selectedYear, teacherId: auth.teacherId),
        studentsProvider.loadStudents(teacherId: auth.teacherId),
      ]);
    } catch (e) {
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

  Map<String, int> _getAttendanceStats(AttendanceProvider provider) {
    int present = 0;
    int absent = 0;
    int late = 0;

    for (var attendance in provider.attendance) {
      switch (attendance.status) {
        case 'present':
          present++;
          break;
        case 'absent':
          absent++;
          break;
        case 'late':
          late++;
          break;
      }
    }

    return {'present': present, 'absent': absent, 'late': late};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('View Attendance'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
        actions: [
          IconButton(
            icon: Icon(_showChart ? Icons.list : Icons.pie_chart),
            onPressed: () {
              setState(() {
                _showChart = !_showChart;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                Card(
                  elevation: 2,
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.filter_list,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filter by Date',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  // Month Selector
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      value: _selectedMonth,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                      dropdownColor: Theme.of(context).colorScheme.surface,
                                      decoration: InputDecoration(
                                        labelText: 'Month',
                                        labelStyle: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                      items: List.generate(12, (index) {
                                        return DropdownMenuItem(
                                          value: index + 1,
                                          child: Text(
                                            DateFormat.MMMM().format(DateTime(2000, index + 1)),
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                        );
                                      }),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedMonth = value!;
                                          _loadAttendance();
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Year Selector
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      value: _selectedYear,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                      dropdownColor: Theme.of(context).colorScheme.surface,
                                      decoration: InputDecoration(
                                        labelText: 'Year',
                                        labelStyle: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                      items: List.generate(10, (index) {
                                        return DropdownMenuItem(
                                          value: 2020 + index,
                                          child: Text(
                                            '${2020 + index}',
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                        );
                                      }),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedYear = value!;
                                          _loadAttendance();
                                        });
                                      },
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
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Consumer<AttendanceProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.attendance.isEmpty) {
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
                          'No attendance records',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Records for ${DateFormat.MMMM().format(DateTime(2000, _selectedMonth))} $_selectedYear',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final stats = _getAttendanceStats(provider);

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      // Statistics Cards
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: 'Present',
                                value: '${stats['present']}',
                                icon: Icons.check_circle,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                title: 'Absent',
                                value: '${stats['absent']}',
                                icon: Icons.cancel,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                title: 'Late',
                                value: '${stats['late']}',
                                icon: Icons.access_time,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Chart or List
                      if (_showChart && stats.values.any((v) => v > 0))
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Card(
                            elevation: 2,
                            color: Theme.of(context).colorScheme.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Attendance Overview',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    height: 280,
                                    child: PieChart(
                                      PieChartData(
                                        sections: [
                                          if (stats['present']! > 0)
                                            PieChartSectionData(
                                              value: stats['present']!.toDouble(),
                                              title: '${stats['present']}',
                                              color: Colors.green,
                                              radius: 80,
                                              titleStyle: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          if (stats['absent']! > 0)
                                            PieChartSectionData(
                                              value: stats['absent']!.toDouble(),
                                              title: '${stats['absent']}',
                                              color: Colors.red,
                                              radius: 80,
                                              titleStyle: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          if (stats['late']! > 0)
                                            PieChartSectionData(
                                              value: stats['late']!.toDouble(),
                                              title: '${stats['late']}',
                                              color: Colors.orange,
                                              radius: 80,
                                              titleStyle: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                        ],
                                        sectionsSpace: 2,
                                        centerSpaceRadius: 40,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Attendance List
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'Attendance Records (${provider.attendance.length})',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: provider.attendance.length,
                              itemBuilder: (context, index) {
                                final attendance = provider.attendance[index];
                                Color statusColor;
                                IconData statusIcon;

                                switch (attendance.status) {
                                  case 'present':
                                    statusColor = Colors.green;
                                    statusIcon = Icons.check_circle;
                                    break;
                                  case 'absent':
                                    statusColor = Colors.red;
                                    statusIcon = Icons.cancel;
                                    break;
                                  case 'late':
                                    statusColor = Colors.orange;
                                    statusIcon = Icons.access_time;
                                    break;
                                  default:
                                    statusColor = Colors.grey;
                                    statusIcon = Icons.help;
                                }

                                // Get student name from students provider
                                return Consumer<StudentsProvider>(
                                  builder: (context, studentsProvider, child) {
                                    var student;
                                    try {
                                      student = studentsProvider.students.firstWhere(
                                        (s) => s.id == attendance.studentId,
                                      );
                                    } catch (e) {
                                      student = null;
                                    }
                                    final studentName = student?.name ?? 'Unknown Student';
                                    final studentId = student?.studentId ?? 'N/A';

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: statusColor.withOpacity(0.2),
                                          child: Icon(
                                            statusIcon,
                                            color: statusColor,
                                          ),
                                        ),
                                        title: Text(
                                          studentName,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Text(
                                              'ID: $studentId',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                              ),
                                            ),
                                            Text(
                                              DateFormat('EEEE, MMM d, y').format(attendance.date),
                                            ),
                                            Text(
                                              'Session: ${attendance.session.toUpperCase()}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                        trailing: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: statusColor, width: 1),
                                          ),
                                          child: Text(
                                            attendance.status.toUpperCase(),
                                            style: TextStyle(
                                              color: statusColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
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
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}