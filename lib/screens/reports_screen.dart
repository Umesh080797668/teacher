import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/reports_provider.dart';
import '../providers/auth_provider.dart';
import '../services/cache_service.dart';
import '../widgets/custom_widgets.dart';

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
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      context.read<ReportsProvider>().loadReports(teacherId: auth.teacherId);
    });
  }

  Future<void> _refreshReports() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await CacheService.clearCache(); // Clear cache on refresh
    await context.read<ReportsProvider>().loadReports(teacherId: auth.teacherId);
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
          tabs: const [
            Tab(text: 'Attendance Summary'),
            Tab(text: 'Student Reports'),
            Tab(text: 'Payments'),
            Tab(text: 'Earnings'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshReports,
        backgroundColor: Theme.of(context).colorScheme.surface,
        color: Theme.of(context).colorScheme.primary,
        child: TabBarView(
          controller: _tabController,
          children: [
            _AttendanceSummaryTab(reportsProvider: reportsProvider),
            _StudentReportsTab(reportsProvider: reportsProvider),
            _PaymentsTab(reportsProvider: reportsProvider),
            _MonthlyEarningsTab(reportsProvider: reportsProvider),
          ],
        ),
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
          return _buildShimmerLoading(context);
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
          return ListSkeleton(
            itemCount: 8,
            itemBuilder: (context) => const StudentCardSkeleton(),
          );
        }

        final allStudentReports = provider.studentReports;
        final allClasses = provider.allClasses;
        
        // Filter students by selected class
        final filteredReports = _selectedClassId == null
            ? allStudentReports
            : allStudentReports.where((report) {
                // Handle both string IDs and ObjectId comparisons
                final reportClassId = report['classId']?.toString();
                return reportClassId == _selectedClassId;
              }).toList();

        return Column(
          children: [
            // Class filter dropdown
            Container(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedClassId,
                decoration: InputDecoration(
                  labelText: 'Filter by Class',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.class_),
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Classes', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  ),
                  ...allClasses.map((cls) => DropdownMenuItem<String>(
                    value: cls.id,
                    child: Text(cls.name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
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
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.only(
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
          return ListSkeleton(
            itemCount: 6,
            itemBuilder: (context) => const DashboardCardSkeleton(),
          );
        }

        // Get payment data from provider
        final allPayments = provider.payments;
        final allClasses = provider.allClasses;
        
        // Filter payments by class and month
        final filteredPayments = allPayments.where((payment) {
          // Handle both string IDs and ObjectId comparisons for class filtering
          final paymentClassId = payment['classId']?.toString();
          final matchesClass = _selectedClassId == null || paymentClassId == _selectedClassId;
          
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
                    initialValue: _selectedClassId,
                    decoration: InputDecoration(
                      labelText: 'Filter by Class',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.class_),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text('All Classes', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                      ),
                      ...allClasses.map((cls) => DropdownMenuItem<String>(
                        value: cls.id,
                        child: Text(cls.name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
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
                          initialValue: _selectedMonth,
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
                                    child: Text(_getMonthName(month), style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
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
                          initialValue: _selectedYear,
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
                                    child: Text(year.toString(), style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
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

// Monthly Earnings by Class Tab
class _MonthlyEarningsTab extends StatefulWidget {
  final ReportsProvider reportsProvider;

  const _MonthlyEarningsTab({required this.reportsProvider});

  @override
  State<_MonthlyEarningsTab> createState() => _MonthlyEarningsTabState();
}

class _MonthlyEarningsTabState extends State<_MonthlyEarningsTab> {
  String? _selectedClassId;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return ListSkeleton(
            itemCount: 5,
            itemBuilder: (context) => const DashboardCardSkeleton(),
          );
        }

        final allEarnings = provider.monthlyEarningsByClass;
        final allClasses = provider.allClasses;
        
        // Flatten the earnings data to have one entry per class per month
        final flattenedEarnings = <Map<String, dynamic>>[];
        for (final earning in allEarnings) {
          final classId = earning['classId'];
          final className = earning['className'];
          final breakdown = earning['monthlyBreakdown'] as List? ?? [];
          for (final monthData in breakdown) {
            flattenedEarnings.add({
              'classId': classId,
              'className': className,
              'month': monthData['month'],
              'year': monthData['year'],
              'amount': monthData['amount'],
              'paymentCount': monthData['paymentCount'],
            });
          }
        }
        
        // Filter flattened earnings by selected class, month, and year
        final filteredEarnings = flattenedEarnings.where((earning) {
          final earningClassId = earning['classId']?.toString();
          final earningMonth = earning['month'] as int?;
          final earningYear = earning['year'] as int?;
          
          final classMatch = _selectedClassId == null || earningClassId == _selectedClassId;
          final monthMatch = earningMonth == _selectedMonth;
          final yearMatch = earningYear == _selectedYear;
          
          return classMatch && monthMatch && yearMatch;
        }).toList();

        // Calculate total earnings
        double totalEarnings = 0;
        int totalPayments = 0;
        for (var earning in filteredEarnings) {
          totalEarnings += (earning['amount'] as num?)?.toDouble() ?? 0.0;
          totalPayments += (earning['paymentCount'] as int?) ?? 0;
        }

        return Column(
          children: [
            // Filters
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Month filter
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedMonth,
                          decoration: InputDecoration(
                            labelText: 'Month',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.calendar_month),
                          ),
                          items: List.generate(12, (index) {
                            final month = index + 1;
                            return DropdownMenuItem<int>(
                              value: month,
                              child: Text(_getMonthName(month), style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                            );
                          }),
                          onChanged: (value) {
                            setState(() {
                              _selectedMonth = value!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Year filter
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedYear,
                          decoration: InputDecoration(
                            labelText: 'Year',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.calendar_today),
                          ),
                          items: List.generate(5, (index) {
                            final year = DateTime.now().year - 2 + index;
                            return DropdownMenuItem<int>(
                              value: year,
                              child: Text(year.toString(), style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                            );
                          }),
                          onChanged: (value) {
                            setState(() {
                              _selectedYear = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Class filter
                  DropdownButtonFormField<String>(
                    initialValue: _selectedClassId,
                    decoration: InputDecoration(
                      labelText: 'Filter by Class',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.class_),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text('All Classes', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                      ),
                      ...allClasses.map((cls) => DropdownMenuItem<String>(
                        value: cls.id,
                        child: Text(cls.name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedClassId = value;
                      });
                    },
                  ),
                ],
              ),
            ),

            // Summary card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Earnings',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rs. ${totalEarnings.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalPayments payment${totalPayments != 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Earnings list
            Expanded(
              child: filteredEarnings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No earnings for ${_getMonthName(_selectedMonth)} $_selectedYear',
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
                      itemCount: filteredEarnings.length,
                      itemBuilder: (context, index) {
                        final earning = filteredEarnings[index];
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.school, color: Colors.green),
                            ),
                            title: Text(
                              earning['className'] ?? 'Unknown Class',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${_getMonthName(earning['month'])} ${earning['year']} - ${earning['paymentCount']} payment${earning['paymentCount'] != 1 ? 's' : ''}',
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Text(
                                'Rs. ${(earning['amount'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}

Widget _buildShimmerLoading(BuildContext context) {
  return Shimmer.fromColors(
    baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    highlightColor: Theme.of(context).colorScheme.surface,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 20,
            width: 200,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            margin: const EdgeInsets.only(bottom: 16),
          ),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  margin: const EdgeInsets.only(right: 8),
                ),
              ),
              Expanded(
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  margin: const EdgeInsets.only(left: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  margin: const EdgeInsets.only(right: 8),
                ),
              ),
              Expanded(
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  margin: const EdgeInsets.only(left: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 18,
            width: 150,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            margin: const EdgeInsets.only(bottom: 16),
          ),
          ...List.generate(3, (index) => Container(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.only(bottom: 12),
          )),
        ],
      ),
    ),
  );
}
