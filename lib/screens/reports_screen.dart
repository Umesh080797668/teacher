import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'pdf_viewer_screen.dart';
import '../providers/reports_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/classes_provider.dart';
import '../providers/students_provider.dart';
import '../providers/payment_provider.dart';
import '../services/cache_service.dart';
import '../services/data_export_service.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';
import '../models/class.dart';

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

  void _showMonthlyReportDialog(BuildContext context) {
    int selectedMonth = DateTime.now().month;
    int selectedYear = DateTime.now().year;

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
                          child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Download Monthly Report', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: cs.onSurface)),
                            Text('Select month and year for the report', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          ]),
                        ),
                        IconButton(onPressed: () => Navigator.pop(sheetCtx), icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selectedMonth,
                            dropdownColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                            style: TextStyle(color: cs.onSurface),
                            items: List.generate(12, (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text(DateFormat('MMMM').format(DateTime(2022, index + 1)), style: TextStyle(color: cs.onSurface)),
                            )),
                            onChanged: (val) => setSheetState(() => selectedMonth = val!),
                            decoration: InputDecoration(labelText: 'Month', labelStyle: TextStyle(color: cs.onSurfaceVariant)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selectedYear,
                            dropdownColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                            style: TextStyle(color: cs.onSurface),
                            items: List.generate(10, (index) {
                              final year = DateTime.now().year - 5 + index;
                              return DropdownMenuItem(value: year, child: Text(year.toString(), style: TextStyle(color: cs.onSurface)));
                            }),
                            onChanged: (val) => setSheetState(() => selectedYear = val!),
                            decoration: InputDecoration(labelText: 'Year', labelStyle: TextStyle(color: cs.onSurfaceVariant)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _generateReport(selectedMonth, selectedYear);
                      },
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 5))],
                        ),
                        child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.download_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text('Download Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        ])),
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

  Future<void> _generateReport(int month, int year) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final teacherId = auth.teacherId;
      
      final classesProvider = Provider.of<ClassesProvider>(context, listen: false);
      final studentsProvider = Provider.of<StudentsProvider>(context, listen: false);
      final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
      
      await Future.wait([
        classesProvider.loadClasses(teacherId: teacherId),
        studentsProvider.loadStudents(teacherId: teacherId),
        paymentProvider.loadPayments(teacherId: teacherId),
      ]);
      
      // Fetch attendance for the month
      final attendanceRecords = await ApiService.getAttendance(
        teacherId: teacherId,
        month: month,
        year: year,
      );

      final filePath = await DataExportService.generateMonthlyReport(
        month: month,
        year: year,
        classes: classesProvider.classes,
        students: studentsProvider.students,
        payments: paymentProvider.payments,
        attendanceRecords: attendanceRecords,
      );
      
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Report saved to $filePath'), backgroundColor: Colors.green),
        );

        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => PdfViewerScreen(filePath: filePath, title: 'Monthly Report - $month/$year'))
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to generate report: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportsProvider = Provider.of<ReportsProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0E17) : const Color(0xFFF5F5FA),
      body: SafeArea(
        child: Column(
          children: [
            // Gradient Header with TabBar
            Container(
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        colors: [Color(0xFF1E1A2E), Color(0xFF2D2660)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF3730A3), Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
              ),
              child: Column(
                children: [
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
                            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reports',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Analytics & insights',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
                            tooltip: 'Download Monthly Report',
                            onPressed: () => _showMonthlyReportDialog(context),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                            tooltip: 'Refresh',
                            onPressed: _refreshReports,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    dividerColor: Colors.transparent,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: const [
                      Tab(text: 'Attendance'),
                      Tab(text: 'Students'),
                      Tab(text: 'Payments'),
                      Tab(text: 'Earnings'),
                    ],
                  ),
                ],
              ),
            ),
            // Tab content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshReports,
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
            ),
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
              ...provider.dailyByClass.map((classData) {
                return Builder(
                  key: ValueKey('summary-${classData['classId'] ?? classData['className']}'),
                  builder: (context) {
                    final cs = Theme.of(context).colorScheme;
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: isDark ? null : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                      ),
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
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: cs.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${classData['totalStudents'] ?? 0} Students',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: cs.primary,
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
                                  color: const Color(0xFF22C55E),
                                ),
                              ),
                              Expanded(
                                child: _StatItem(
                                  label: 'Absent',
                                  value: classData['absentCount']?.toString() ?? '0',
                                  color: cs.error,
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
                            backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              (classData['attendanceRate'] ?? 0) >= 75
                                  ? const Color(0xFF22C55E)
                                  : Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Attendance Rate: ${(classData['attendanceRate'] ?? 0).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: (classData['attendanceRate'] ?? 0) >= 75
                                  ? const Color(0xFF22C55E)
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
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
                value: _selectedClassId,
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
                  ? const EmptyState(
                      icon: Icons.people_outline,
                      title: 'No students found',
                      message: 'Try selecting a different class',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredReports.length,
                      itemBuilder: (context, index) {
                        final report = filteredReports[index];
                        final cs = Theme.of(context).colorScheme;
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        return Container(
                          key: ValueKey('report-${report['studentId'] ?? index}'),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: isDark ? null : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report['studentName'] ?? 'Unknown Student',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                report['className'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _StatChip(
                                    label: 'Present: ${report['presentCount'] ?? 0}',
                                    color: const Color(0xFF22C55E),
                                  ),
                                  const SizedBox(width: 8),
                                  _StatChip(
                                    label: 'Absent: ${report['absentCount'] ?? 0}',
                                    color: cs.error,
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
                                  color: (report['attendanceRate'] ?? 0) >= 75
                                      ? const Color(0xFF22C55E)
                                      : cs.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
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
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last 6 Months',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
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
                  key: ValueKey('chart-${stat['month']}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: presentHeight,
                          decoration: BoxDecoration(
                            color: cs.primary,
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
                            color: cs.onSurfaceVariant,
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
          
          // Check for explicit month/year fields first (billing period), fallback to transaction date
          int? paymentMonth;
          int? paymentYear;

          if (payment['month'] != null) {
            paymentMonth = payment['month'] is int ? payment['month'] : int.tryParse(payment['month'].toString());
          }
          
          if (payment['year'] != null) {
            paymentYear = payment['year'] is int ? payment['year'] : int.tryParse(payment['year'].toString());
          }

          if (paymentMonth == null || paymentYear == null) {
            final paymentDate = payment['date'] != null ? DateTime.parse(payment['date']) : null;
            if (paymentDate != null) {
              paymentMonth ??= paymentDate.month;
              paymentYear ??= paymentDate.year;
            }
          }

          final matchesMonth = paymentMonth == _selectedMonth && paymentYear == _selectedYear;
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
                  ? const EmptyState(
                      icon: Icons.payment,
                      title: 'No payments found',
                      message: 'Try selecting a different class or month',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: studentPaymentsMap.length,
                      itemBuilder: (context, index) {
                        final studentId = studentPaymentsMap.keys.elementAt(index);
                        final data = studentPaymentsMap[studentId]!;
                        final payments = data['payments'] as List;
                        final cs = Theme.of(context).colorScheme;
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        return Container(
                          key: ValueKey('payment-group-$studentId'),
                          margin: const EdgeInsets.only(bottom: 12),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: isDark ? null : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                          ),
                          child: ExpansionTile(
                            title: Text(
                              data['studentName'] ?? 'Unknown Student',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              data['className'] ?? '',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                'Rs. ${data['totalAmount'].toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFF22C55E),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            children: payments.asMap().entries.map<Widget>((entry) {
                              final payment = entry.value;
                              final index = entry.key;
                              final date = payment['date'] != null 
                                  ? DateTime.parse(payment['date'])
                                  : null;
                              
                              String dateText = date != null
                                  ? DateFormat('dd/MM/yyyy').format(date)
                                  : 'No date';

                              return ListTile(
                                key: ValueKey(payment['_id'] ?? payment['id'] ?? 'payment-$studentId-$index'),
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
                                  dateText,
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
  DateTime? _selectedDate;
  bool _showByDate = false;

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

        return Column(
          children: [
            // View toggle button
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showByDate = false;
                          _selectedDate = null;
                        });
                      },
                      icon: Icon(
                        Icons.calendar_month,
                        color: !_showByDate ? Theme.of(context).colorScheme.primary : null,
                      ),
                      label: Text(
                        'Monthly View',
                        style: TextStyle(
                          color: !_showByDate ? Theme.of(context).colorScheme.primary : null,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: !_showByDate ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : null,
                        side: BorderSide(
                          color: !_showByDate ? Theme.of(context).colorScheme.primary : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showByDate = true;
                        });
                      },
                      icon: Icon(
                        Icons.calendar_today,
                        color: _showByDate ? Theme.of(context).colorScheme.primary : null,
                      ),
                      label: Text(
                        'Daily View',
                        style: TextStyle(
                          color: _showByDate ? Theme.of(context).colorScheme.primary : null,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _showByDate ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : null,
                        side: BorderSide(
                          color: _showByDate ? Theme.of(context).colorScheme.primary : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Filters
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (!_showByDate)
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
                  if (!_showByDate)
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
                  )
                  else
                  // Date picker for daily view
                  GestureDetector(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: Theme.of(context).colorScheme.primary,
                                onPrimary: Colors.white,
                                surface: Theme.of(context).colorScheme.surface,
                                onSurface: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (pickedDate != null) {
                        setState(() {
                          _selectedDate = pickedDate;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedDate == null
                                  ? 'Select Date'
                                  : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                              style: TextStyle(
                                color: _selectedDate == null
                                    ? Theme.of(context).colorScheme.onSurfaceVariant
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // View content based on selection
            Expanded(
              key: ValueKey<String>(_showByDate ? 'daily_$_selectedDate' : 'monthly_${_selectedMonth}_$_selectedYear'),
              child: _showByDate && _selectedDate != null
                  ? _buildDailyPaymentViewContent(context, allEarnings, allClasses, provider)
                  : _buildMonthlyViewContent(context, allEarnings, flattenedEarnings),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthlyViewContent(BuildContext context, List<Map<String, dynamic>> allEarnings, List<Map<String, dynamic>> flattenedEarnings) {
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

    return SingleChildScrollView(
      child: Column(
        children: [
          // Summary card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'Total Earnings',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rs. ${totalEarnings.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalPayments payment${totalPayments != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Earnings list
          if (filteredEarnings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: EmptyState(
                icon: Icons.account_balance_wallet,
                title: 'No earnings',
                message: 'No earnings for ${_getMonthName(_selectedMonth)} $_selectedYear',
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredEarnings.length,
              itemBuilder: (context, index) {
                final earning = filteredEarnings[index];
                
                return Card(
                  key: ValueKey('monthly-earning-${earning['classId']}-${earning['month']}-${earning['year']}'),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
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
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
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
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDailyPaymentViewContent(BuildContext context, List<Map<String, dynamic>> allEarnings, List<Class> allClasses, ReportsProvider provider) {
    // Get the selected date's payment data
    final selectedDateStr = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day).toIso8601String().split('T')[0];
    
    // Filter payments for the selected date
    double totalDailyPayments = 0;
    int paymentCount = 0;
    final dailyPaymentsByClass = <Map<String, dynamic>>[];
    
    // Use the raw payments data from provider
    final allPayments = provider.payments;
    for (final payment in allPayments) {
      final dateVal = payment['date'];
      if (dateVal != null) {
        final paymentDate = DateTime.parse(dateVal.toString());
        final paymentDateStr = paymentDate.toIso8601String().split('T')[0];
        
        if (paymentDateStr == selectedDateStr) {
          final className = payment['className'] ?? 'Unknown Class';
          final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
          
          totalDailyPayments += amount;
          paymentCount++;
          
          final existingClass = dailyPaymentsByClass.firstWhere(
            (item) => item['className'] == className,
            orElse: () => {
              'className': className,
              'amount': 0.0,
              'count': 0,
              'payments': <Map<String, dynamic>>[],
            },
          );
          
          if (!dailyPaymentsByClass.contains(existingClass)) {
            dailyPaymentsByClass.add(existingClass);
          }
          
          existingClass['amount'] = (existingClass['amount'] as num).toDouble() + amount;
          existingClass['count'] = (existingClass['count'] as int) + 1;
          (existingClass['payments'] as List).add(payment);
        }
      }
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Daily summary card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'Payments on ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rs. ${totalDailyPayments.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$paymentCount payment${paymentCount != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Daily payments list
          if (dailyPaymentsByClass.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: EmptyState(
                icon: Icons.receipt,
                title: 'No payments',
                message: 'No payments recorded on this date',
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: dailyPaymentsByClass.length,
              itemBuilder: (context, index) {
                final classPayment = dailyPaymentsByClass[index];
                
                return Card(
                  key: ValueKey('daily-earning-${classPayment['className']}'),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt, color: Colors.blue),
                    ),
                    title: Text(
                      classPayment['className'] ?? 'Unknown Class',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${classPayment['count']} payment${classPayment['count'] != 1 ? 's' : ''}',
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Rs. ${(classPayment['amount'] as num).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          
          const SizedBox(height: 16),
        ],
      ),
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
