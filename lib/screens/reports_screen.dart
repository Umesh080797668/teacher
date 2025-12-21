import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reports_provider.dart';
import '../providers/auth_provider.dart';


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
        title: const Text('Reports'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Attendance Summary'),
            Tab(text: 'Student Reports'),
            Tab(text: 'Payments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AttendanceSummaryTab(reportsProvider: reportsProvider),
          _StudentReportsTab(reportsProvider: reportsProvider),
          _PaymentsTab(reportsProvider: reportsProvider),
        ],
      ),
    );
  }
}

class _AttendanceSummaryTab extends StatelessWidget {
  final ReportsProvider reportsProvider;

  const _AttendanceSummaryTab({required this.reportsProvider});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final summary = provider.attendanceSummary;

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
                'Daily Attendance by Class',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              ...provider.dailyByClass.map((classData) => Card(
            margin: const EdgeInsets.only(bottom: 12),
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
                          classData['className'] ?? 'Unknown Class',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${classData['totalStudents'] ?? 0} Students',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatItem(
                          label: 'Present',
                          value: classData['presentCount']?.toString() ?? '0',
                          color: Colors.green,
                        ),
                      ),
                      Expanded(
                        child: _StatItem(
                          label: 'Absent',
                          value: classData['absentCount']?.toString() ?? '0',
                          color: Colors.red,
                        ),
                      ),
                      Expanded(
                        child: _StatItem(
                          label: 'Late',
                          value: classData['lateCount']?.toString() ?? '0',
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (classData['attendanceRate'] ?? 0) / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      (classData['attendanceRate'] ?? 0) >= 75 ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Attendance Rate: ${(classData['attendanceRate'] ?? 0).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: (classData['attendanceRate'] ?? 0) >= 75 ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          )),
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
          _MonthlyOverviewChart(reportsProvider: provider),
        ],
      ),
        );
      },
    );
  }
}

class _StudentReportsTab extends StatefulWidget {
  final ReportsProvider reportsProvider;

  const _StudentReportsTab({required this.reportsProvider});

  @override
  State<_StudentReportsTab> createState() => _StudentReportsTabState();
}

class _StudentReportsTabState extends State<_StudentReportsTab> {
  String? _selectedClassId;

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final allStudentReports = provider.studentReports;
        
        // Get unique classes from student reports
        final classesMap = <String, String>{};
        for (var report in allStudentReports) {
          final classId = report['classId'] as String?;
          final className = report['className'] as String?;
          if (classId != null && className != null) {
            classesMap[classId] = className;
          }
        }

        // Filter students by selected class
        final filteredReports = _selectedClassId == null
            ? allStudentReports
            : allStudentReports.where((report) => report['classId'] == _selectedClassId).toList();

        return Column(
          children: [
            // Class filter dropdown
            Container(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                value: _selectedClassId,
                decoration: InputDecoration(
                  labelText: 'Filter by Class',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.class_),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Classes'),
                  ),
                  ...classesMap.entries.map((entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedClassId = value;
                  });
                },
              ),
            ),
            
            // Student reports list
            Expanded(
              child: filteredReports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No students found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredReports.length,
                      itemBuilder: (context, index) {
                        final report = filteredReports[index];
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
                                const SizedBox(height: 4),
                                Text(
                                  report['className'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                    ),
            ),
          ],
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

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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

// Payments Tab
class _PaymentsTab extends StatefulWidget {
  final ReportsProvider reportsProvider;

  const _PaymentsTab({required this.reportsProvider});

  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
  String? _selectedClassId;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Get payment data from provider
        final allPayments = provider.payments;
        
        // Get unique classes
        final classesMap = <String, String>{};
        for (var payment in allPayments) {
          final classId = payment['classId'] as String?;
          final className = payment['className'] as String?;
          if (classId != null && className != null) {
            classesMap[classId] = className;
          }
        }

        // Filter payments by class and month
        final filteredPayments = allPayments.where((payment) {
          final matchesClass = _selectedClassId == null || payment['classId'] == _selectedClassId;
          final paymentDate = payment['date'] != null ? DateTime.parse(payment['date']) : null;
          final matchesMonth = paymentDate != null && 
                               paymentDate.month == _selectedMonth && 
                               paymentDate.year == _selectedYear;
          return matchesClass && matchesMonth;
        }).toList();

        // Group payments by student
        final studentPaymentsMap = <String, Map<String, dynamic>>{};
        for (var payment in filteredPayments) {
          final studentId = payment['studentId'] as String;
          if (!studentPaymentsMap.containsKey(studentId)) {
            studentPaymentsMap[studentId] = {
              'studentName': payment['studentName'],
              'className': payment['className'],
              'payments': [],
              'totalAmount': 0.0,
            };
          }
          studentPaymentsMap[studentId]!['payments'].add(payment);
          studentPaymentsMap[studentId]!['totalAmount'] += (payment['amount'] as num).toDouble();
        }

        return Column(
          children: [
            // Filters
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Class filter
                  DropdownButtonFormField<String>(
                    value: _selectedClassId,
                    decoration: InputDecoration(
                      labelText: 'Filter by Class',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.class_),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All Classes'),
                      ),
                      ...classesMap.entries.map((entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedClassId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Month and Year filter
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _selectedMonth,
                          decoration: InputDecoration(
                            labelText: 'Month',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.calendar_month),
                          ),
                          items: List.generate(12, (index) => index + 1)
                              .map((month) => DropdownMenuItem<int>(
                                    value: month,
                                    child: Text(_getMonthName(month)),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedMonth = value;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _selectedYear,
                          decoration: InputDecoration(
                            labelText: 'Year',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.calendar_today),
                          ),
                          items: List.generate(5, (index) => DateTime.now().year - index)
                              .map((year) => DropdownMenuItem<int>(
                                    value: year,
                                    child: Text(year.toString()),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedYear = value;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Payments list
            Expanded(
              child: studentPaymentsMap.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.payment,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No payments found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: studentPaymentsMap.length,
                      itemBuilder: (context, index) {
                        final studentId = studentPaymentsMap.keys.elementAt(index);
                        final data = studentPaymentsMap[studentId]!;
                        final payments = data['payments'] as List;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ExpansionTile(
                            title: Text(
                              data['studentName'] ?? 'Unknown Student',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(data['className'] ?? ''),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Text(
                                'Rs. ${data['totalAmount'].toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            children: payments.map<Widget>((payment) {
                              final date = payment['date'] != null 
                                  ? DateTime.parse(payment['date'])
                                  : null;
                              return ListTile(
                                leading: Icon(
                                  Icons.check_circle,
                                  color: _getPaymentTypeColor(payment['type']),
                                ),
                                title: Text(
                                  payment['type'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  date != null
                                      ? '${date.day}/${date.month}/${date.year}'
                                      : 'No date',
                                ),
                                trailing: Text(
                                  'Rs. ${(payment['amount'] as num).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _getPaymentTypeColor(payment['type']),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  Color _getPaymentTypeColor(String? type) {
    switch (type?.toLowerCase()) {
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
}
