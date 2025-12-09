import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reports_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsProvider>().loadReports();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Attendance Summary'),
            Tab(text: 'Student Reports'),
            Tab(text: 'Monthly Stats'),
          ],
        ),
      ),
      body: Consumer<ReportsProvider>(
        builder: (context, reportsProvider, child) {
          if (reportsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _AttendanceSummaryTab(reportsProvider: reportsProvider),
              _StudentReportsTab(reportsProvider: reportsProvider),
              _MonthlyStatsTab(reportsProvider: reportsProvider),
            ],
          );
        },
      ),
    );
  }
}

class _AttendanceSummaryTab extends StatelessWidget {
  final ReportsProvider reportsProvider;

  const _AttendanceSummaryTab({required this.reportsProvider});

  @override
  Widget build(BuildContext context) {
    final summary = reportsProvider.attendanceSummary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Attendance Summary',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Total Students',
                  value: summary['totalStudents']?.toString() ?? '0',
                  color: Colors.blue,
                  icon: Icons.people,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryCard(
                  title: 'Present Today',
                  value: summary['presentToday']?.toString() ?? '0',
                  color: Colors.green,
                  icon: Icons.check_circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Absent Today',
                  value: summary['absentToday']?.toString() ?? '0',
                  color: Colors.red,
                  icon: Icons.cancel,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryCard(
                  title: 'Late Today',
                  value: summary['lateToday']?.toString() ?? '0',
                  color: Colors.orange,
                  icon: Icons.schedule,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Monthly Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _MonthlyOverviewChart(reportsProvider: reportsProvider),
        ],
      ),
    );
  }
}

class _StudentReportsTab extends StatelessWidget {
  final ReportsProvider reportsProvider;

  const _StudentReportsTab({required this.reportsProvider});

  @override
  Widget build(BuildContext context) {
    final studentReports = reportsProvider.studentReports;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: studentReports.length,
      itemBuilder: (context, index) {
        final report = studentReports[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report['studentName'] ?? 'Unknown Student',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatChip(
                      label: 'Present: ${report['presentCount'] ?? 0}',
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'Absent: ${report['absentCount'] ?? 0}',
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'Late: ${report['lateCount'] ?? 0}',
                      color: Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Attendance Rate: ${report['attendanceRate']?.toStringAsFixed(1) ?? '0.0'}%',
                  style: TextStyle(
                    color: (report['attendanceRate'] ?? 0) >= 75 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
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
    final monthlyStats = reportsProvider.monthlyStats;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Statistics',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ...monthlyStats.map((stat) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${stat['month']}/${stat['year']}',
                    style: TextStyle(
                      fontSize: 16,
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
                  Text(
                    'Average Rate: ${stat['averageRate']?.toStringAsFixed(1) ?? '0.0'}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
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

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
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

class _MonthlyOverviewChart extends StatelessWidget {
  final ReportsProvider reportsProvider;

  const _MonthlyOverviewChart({required this.reportsProvider});

  @override
  Widget build(BuildContext context) {
    // Simple bar chart representation
    final monthlyStats = reportsProvider.monthlyStats.take(6).toList().reversed.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last 6 Months',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: monthlyStats.map((stat) {
                  final present = stat['presentCount'] ?? 0;
                  final absent = stat['absentCount'] ?? 0;
                  final total = present + absent;
                  final presentHeight = total > 0 ? (present / total) * 150 : 0.0;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 30,
                            height: presentHeight,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${stat['month']}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}