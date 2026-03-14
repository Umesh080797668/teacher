import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/payment_provider.dart';
import '../providers/students_provider.dart';
import '../providers/classes_provider.dart';
import '../providers/auth_provider.dart';
import '../models/student.dart';
import '../models/payment.dart';
import '../models/class.dart' as class_model;

class PaymentCollectionScreen extends StatefulWidget {
  const PaymentCollectionScreen({super.key});

  @override
  State<PaymentCollectionScreen> createState() =>
      _PaymentCollectionScreenState();
}

class _PaymentCollectionScreenState extends State<PaymentCollectionScreen> {
  String? _selectedClassId;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  // ─── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── helpers ───────────────────────────────────────────────────────────────

  Future<void> _loadData({bool silent = false}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final paymentProvider =
        Provider.of<PaymentProvider>(context, listen: false);
    final studentsProvider =
        Provider.of<StudentsProvider>(context, listen: false);
    final classesProvider =
        Provider.of<ClassesProvider>(context, listen: false);

    // If providers already have cached data, auto-select class and refresh in background
    final hasCache = studentsProvider.students.isNotEmpty &&
        classesProvider.classes.isNotEmpty;

    if (hasCache) {
      if (mounted && _selectedClassId == null && classesProvider.classes.isNotEmpty) {
        setState(() => _selectedClassId = classesProvider.classes.first.id);
      }
      // Refresh data silently in background (no spinner)
      paymentProvider.loadPayments(teacherId: auth.teacherId, silent: true)
          .catchError((_) {});
      studentsProvider.loadStudents(teacherId: auth.teacherId, silent: true)
          .catchError((_) {});
      classesProvider.loadClasses(teacherId: auth.teacherId, silent: true)
          .catchError((_) {});
      return;
    }

    try {
      await Future.wait([
        paymentProvider.loadPayments(teacherId: auth.teacherId),
        studentsProvider.loadStudents(teacherId: auth.teacherId),
        classesProvider.loadClasses(teacherId: auth.teacherId),
      ]);

      // Auto-select the first class
      if (mounted &&
          _selectedClassId == null &&
          classesProvider.classes.isNotEmpty) {
        setState(() {
          _selectedClassId = classesProvider.classes.first.id;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String _monthName(int m) {
    const names = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[m];
  }

  String _shortMonth(int m) {
    const names = [
      '',
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[m];
  }

  /// Returns the Payment for [student] in the currently selected month/year,
  /// or null if not paid.
  Payment? _paymentFor(Student student, List<Payment> payments) {
    return payments
        .where((p) =>
            p.studentId == student.id &&
            p.month == _selectedMonth &&
            p.year == _selectedYear &&
            (_selectedClassId == null || p.classId == _selectedClassId))
        .fold<Payment?>(null, (prev, p) => prev ?? p);
  }

  /// Students that belong to the selected class (or all classes when null).
  List<Student> _filteredStudents(
      List<Student> all, List<Payment> payments) {
    List<Student> result = _selectedClassId == null
        ? all
        : all.where((s) {
            final sel = _selectedClassId!.toString();
            if (s.classId?.toString() == sel) return true;
            if (s.classIds != null &&
                s.classIds!.any((id) => id.toString() == sel)) return true;
            return false;
          }).toList();

    if (_searchText.isNotEmpty) {
      result = result
          .where((s) =>
              s.name.toLowerCase().contains(_searchText) ||
              s.studentId.toLowerCase().contains(_searchText))
          .toList();
    }

    // Sort: unpaid first, then paid
    result.sort((a, b) {
      final aPaid = _paymentFor(a, payments) != null;
      final bPaid = _paymentFor(b, payments) != null;
      if (aPaid == bPaid) return a.name.compareTo(b.name);
      return aPaid ? 1 : -1;
    });

    return result;
  }

  // ─── mark-as-paid bottom sheet ─────────────────────────────────────────────

  void _showMarkAsPaidSheet(Student student) {
    final paymentProvider =
        Provider.of<PaymentProvider>(context, listen: false);

    // Use the currently selected class, or pick first class the student belongs
    // to when "All Classes" is active.
    String? classId = _selectedClassId;
    if (classId == null) {
      if (student.classId != null) {
        classId = student.classId;
      } else if (student.classIds != null && student.classIds!.isNotEmpty) {
        classId = student.classIds!.first;
      }
    }
    if (classId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No class assigned to this student.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final TextEditingController amountCtrl = TextEditingController();
    String paymentType = 'full';
    int month = _selectedMonth;
    int year = _selectedYear;
    bool isLoading = false;

    // Pre-fill amount based on type
    amountCtrl.text = '5000.00';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final cs = Theme.of(context).colorScheme;
            // Re-read on every builder call so it shows once classes load
            final sheetClasses = Provider.of<ClassesProvider>(context, listen: false);
            final className = sheetClasses.classes
                .firstWhere(
                  (c) => c.id == classId,
                  orElse: () => class_model.Class(
                      id: '', name: sheetClasses.isLoading ? 'Loading…' : 'Unknown', teacherId: ''),
                )
                .name;
            void updateAmount(String type) {
              switch (type) {
                case 'full':
                  amountCtrl.text = '5000.00';
                  break;
                case 'half':
                  amountCtrl.text = '2500.00';
                  break;
                case 'free':
                  amountCtrl.text = '0.00';
                  break;
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E1B2E)
                      : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 4),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title row
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                child: Icon(
                                  Icons.person,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isDark ? Colors.white : const Color(0xFF1E1B2E),
                                      ),
                                    ),
                                    Text(
                                      '$className · ID: ${student.studentId}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 12),

                          // Month & Year row
                          Text(
                            'Payment For',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: month,
                                  style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white
                                        : const Color(0xFF1E1B2E),
                                  ),
                                  dropdownColor: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF1E1B2E)
                                      : Colors.white,
                                  decoration: InputDecoration(
                                    labelText: 'Month',
                                    labelStyle: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white70
                                          : const Color(0xFF6B7280),
                                    ),
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: List.generate(
                                    12,
                                    (i) => DropdownMenuItem(
                                      value: i + 1,
                                      child: Text(
                                        _monthName(i + 1),
                                        style: TextStyle(
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.white
                                              : const Color(0xFF1E1B2E),
                                        ),
                                      ),
                                    ),
                                  ),
                                  onChanged: (v) =>
                                      setSheetState(() => month = v!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: year,
                                  style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white
                                        : const Color(0xFF1E1B2E),
                                  ),
                                  dropdownColor: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF1E1B2E)
                                      : Colors.white,
                                  decoration: InputDecoration(
                                    labelText: 'Year',
                                    labelStyle: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white70
                                          : const Color(0xFF6B7280),
                                    ),
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: List.generate(
                                    5,
                                    (i) => DropdownMenuItem(
                                      value: DateTime.now().year - 2 + i,
                                      child: Text(
                                        (DateTime.now().year - 2 + i).toString(),
                                        style: TextStyle(
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.white
                                              : const Color(0xFF1E1B2E),
                                        ),
                                      ),
                                    ),
                                  ),
                                  onChanged: (v) =>
                                      setSheetState(() => year = v!),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Payment Type chips
                          Text(
                            'Payment Type',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _TypeChip(
                                label: 'Full',
                                icon: Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                                selected: paymentType == 'full',
                                onTap: () {
                                  setSheetState(() {
                                    paymentType = 'full';
                                    updateAmount('full');
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              _TypeChip(
                                label: 'Half',
                                icon: Icons.remove_circle,
                                color: Colors.orange,
                                selected: paymentType == 'half',
                                onTap: () {
                                  setSheetState(() {
                                    paymentType = 'half';
                                    updateAmount('half');
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              _TypeChip(
                                label: 'Free',
                                icon: Icons.card_giftcard,
                                color: Theme.of(context).colorScheme.tertiary,
                                selected: paymentType == 'free',
                                onTap: () {
                                  setSheetState(() {
                                    paymentType = 'free';
                                    updateAmount('free');
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Amount
                          TextField(
                            controller: amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 15,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Amount (LKR)',
                              labelStyle: TextStyle(
                                color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                              ),
                              border: const OutlineInputBorder(),
                              prefixIcon: Icon(Icons.attach_money,
                                  color: isDark ? Colors.white70 : cs.primary),
                              filled: true,
                              fillColor: isDark
                                  ? (paymentType == 'free'
                                      ? const Color(0xFF16133A)
                                      : const Color(0xFF2A2740))
                                  : (paymentType == 'free'
                                      ? cs.surfaceContainerHighest
                                      : Colors.white),
                            ),
                            enabled: paymentType != 'free',
                          ),
                          const SizedBox(height: 24),

                          // Confirm button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              icon: isLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(context).colorScheme.onPrimary,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle_outline),
                              label: Text(
                                isLoading
                                    ? 'Saving…'
                                    : 'Confirm Payment — ${_shortMonth(month)} $year',
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                      final double amount = double.tryParse(
                                              amountCtrl.text.trim()) ??
                                          0.0;
                                      if (paymentType != 'free' && amount <= 0) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Please enter a valid amount.'),
                                          ),
                                        );
                                        return;
                                      }
                                      setSheetState(() => isLoading = true);
                                      try {
                                        await paymentProvider.addPayment(
                                          student.id,
                                          classId!,
                                          amount,
                                          paymentType,
                                          month: month,
                                          year: year,
                                          recordingDate: DateTime.now(),
                                        );
                                        if (ctx.mounted) {
                                          Navigator.pop(ctx);
                                        }
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  Icon(
                                                      Icons.check_circle_rounded,
                                                      color: Theme.of(context).colorScheme.onPrimary),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      '${student.name} — payment recorded (LKR ${amount.toStringAsFixed(0)}, ${_monthName(month)} $year)',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: Theme.of(context).colorScheme.primary,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                            ),
                                          );
                                          setState(() {}); // refresh list
                                        }
                                      } catch (e) {
                                        setSheetState(
                                            () => isLoading = false);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content:
                                                  Text('Failed: $e'),
                                              backgroundColor: Theme.of(context).colorScheme.error,
                                            ),
                                          );
                                        }
                                      }
                                    },
                            ),
                          ),
                        ],
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

  // ─── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0E17) : const Color(0xFFF5F5FA),
      body: SafeArea(
        child: Column(
          children: [
            // Gradient Header
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
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 20),
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
                        'Collect Payments',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Record student payments',
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
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                      tooltip: 'Refresh',
                      onPressed: _loadData,
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: Consumer3<PaymentProvider, StudentsProvider, ClassesProvider>(
        builder: (context, paymentProvider, studentsProvider, classesProvider,
            child) {
          final classes = classesProvider.classes;
          final allStudents = studentsProvider.students;
          final allPayments = paymentProvider.payments;

          final displayStudents =
              _filteredStudents(allStudents, allPayments);

          // Stats
          final classStudentsForStats = _selectedClassId == null
              ? allStudents
              : allStudents.where((s) {
                  final sel = _selectedClassId!.toString();
                  if (s.classId?.toString() == sel) return true;
                  if (s.classIds != null &&
                      s.classIds!.any((id) => id.toString() == sel)) return true;
                  return false;
                }).toList();

          final paidCount = classStudentsForStats
              .where((s) => _paymentFor(s, allPayments) != null)
              .length;
          final totalCount = classStudentsForStats.length;
          final unpaidCount = totalCount - paidCount;
          final double totalCollected = classStudentsForStats.fold(
              0,
              (sum, s) =>
                  sum + (_paymentFor(s, allPayments)?.amount ?? 0.0));

          return Column(
            children: [
              // ── Top filter bar ──────────────────────────────────────────
              Builder(builder: (context) {
              final dark = Theme.of(context).brightness == Brightness.dark;
              return Container(
                color: Colors.transparent,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  children: [
                    // Stats row
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF1E1B2E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: dark
                              ? const Color(0xFF4F46E5).withValues(alpha: 0.2)
                              : const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: dark ? 0.25 : 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _QuickStat(
                              label: 'Paid',
                              value: '$paidCount',
                              color: const Color(0xFF22C55E),
                              icon: Icons.check_circle,
                            ),
                          ),
                          _VerticalDivider(),
                          Expanded(
                            child: _QuickStat(
                              label: 'Unpaid',
                              value: '$unpaidCount',
                              color: Theme.of(context).colorScheme.error,
                              icon: Icons.cancel,
                            ),
                          ),
                          _VerticalDivider(),
                          Expanded(
                            child: _QuickStat(
                              label: 'Collected',
                              value: 'LKR ${totalCollected.toStringAsFixed(0)}',
                              color: const Color(0xFF4F46E5),
                              icon: Icons.account_balance_wallet,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Class selector + Month/Year
                    Row(
                      children: [
                        // Class dropdown
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String?>(
                            value: _selectedClassId,
                            style: TextStyle(
                              color: dark ? Colors.white : const Color(0xFF1E1B2E),
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Class',
                              labelStyle: TextStyle(color: dark ? Colors.white70 : const Color(0xFF6B7280)),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              isDense: true,
                              filled: true,
                              fillColor: dark ? const Color(0xFF2A2740) : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            dropdownColor: dark ? const Color(0xFF1E1B2E) : Colors.white,
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All Classes',
                                    style: TextStyle(color: dark ? Colors.white : const Color(0xFF1E1B2E))),
                              ),
                              ...classes.map(
                                (c) => DropdownMenuItem<String?>(
                                  value: c.id,
                                  child: Text(
                                    c.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: dark ? Colors.white : const Color(0xFF1E1B2E)),
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _selectedClassId = v),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Month
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<int>(
                            value: _selectedMonth,
                            style: TextStyle(
                              color: dark ? Colors.white : const Color(0xFF1E1B2E),
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Month',
                              labelStyle: TextStyle(color: dark ? Colors.white70 : const Color(0xFF6B7280)),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              isDense: true,
                              filled: true,
                              fillColor: dark ? const Color(0xFF2A2740) : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            dropdownColor: dark ? const Color(0xFF1E1B2E) : Colors.white,
                            items: List.generate(
                              12,
                              (i) => DropdownMenuItem(
                                value: i + 1,
                                child: Text(_shortMonth(i + 1),
                                    style: TextStyle(color: dark ? Colors.white : const Color(0xFF1E1B2E))),
                              ),
                            ),
                            onChanged: (v) =>
                                setState(() => _selectedMonth = v!),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Year
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<int>(
                            value: _selectedYear,
                            style: TextStyle(
                              color: dark ? Colors.white : const Color(0xFF1E1B2E),
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Year',
                              labelStyle: TextStyle(color: dark ? Colors.white70 : const Color(0xFF6B7280)),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              isDense: true,
                              filled: true,
                              fillColor: dark ? const Color(0xFF2A2740) : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            dropdownColor: dark ? const Color(0xFF1E1B2E) : Colors.white,
                            items: List.generate(
                              5,
                              (i) => DropdownMenuItem(
                                value: DateTime.now().year - 2 + i,
                                child: Text(
                                  (DateTime.now().year - 2 + i).toString(),
                                  style: TextStyle(color: dark ? Colors.white : const Color(0xFF1E1B2E)),
                                ),
                              ),
                            ),
                            onChanged: (v) =>
                                setState(() => _selectedYear = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Search
                    TextField(
                      controller: _searchController,
                      onChanged: (v) =>
                          setState(() => _searchText = v.toLowerCase()),
                      style: TextStyle(
                        color: dark ? Colors.white : const Color(0xFF1E1B2E),
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search students by name or ID…',
                        hintStyle: TextStyle(
                          color: dark ? Colors.white38 : const Color(0xFF9CA3AF),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: dark ? Colors.white54 : const Color(0xFF6B7280),
                        ),
                        suffixIcon: _searchText.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: dark ? Colors.white54 : const Color(0xFF6B7280),
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchText = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                        filled: true,
                        fillColor: dark ? const Color(0xFF2A2740) : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              );
            }),

              // Section label
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_monthName(_selectedMonth)} $_selectedYear',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${displayStudents.length} student${displayStudents.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Student list ────────────────────────────────────────────
              Expanded(
                child: studentsProvider.isLoading && studentsProvider.students.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : displayStudents.isEmpty
                        ? _EmptyState(searchText: _searchText)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                            itemCount: displayStudents.length,
                            itemBuilder: (context, index) {
                              final student = displayStudents[index];
                              final payment =
                                  _paymentFor(student, allPayments);
                              final isPaid = payment != null;

                              // Look up class name for display
                              String? classNameDisplay;
                              if (_selectedClassId != null) {
                                classNameDisplay = classes
                                    .firstWhere(
                                      (c) => c.id == _selectedClassId,
                                      orElse: () => class_model.Class(
                                          id: '',
                                          name: '',
                                          teacherId: ''),
                                    )
                                    .name;
                              } else {
                                final cid =
                                    student.classId ?? student.classIds?.firstOrNull;
                                if (cid != null) {
                                  classNameDisplay = classes
                                      .firstWhere(
                                        (c) => c.id == cid,
                                        orElse: () => class_model.Class(
                                            id: '',
                                            name: '',
                                            teacherId: ''),
                                      )
                                      .name;
                                }
                              }

                              return _StudentPaymentTile(
                                student: student,
                                payment: payment,
                                isPaid: isPaid,
                                className: classNameDisplay,
                                onMarkPaid: isPaid
                                    ? null
                                    : () => _showMarkAsPaidSheet(student),
                                onTapPaid: isPaid
                                    ? () => _showPaidDetailsSheet(
                                        student, payment, classes)
                                    : null,
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── paid-details sheet ────────────────────────────────────────────────────

  void _showPaidDetailsSheet(
    Student student,
    Payment payment,
    List<class_model.Class> classes,
  ) {
    final paymentProvider =
        Provider.of<PaymentProvider>(context, listen: false);
    final className = classes
        .firstWhere(
          (c) => c.id == payment.classId,
          orElse: () =>
              class_model.Class(id: '', name: 'Unknown', teacherId: ''),
        )
        .name;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1B2E)
              : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Paid badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'PAYMENT CONFIRMED',
                    style: TextStyle(
                      color: Color(0xFF22C55E),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              student.name,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            Text(
              'Student ID: ${student.studentId}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            _DetailRow(label: 'Class', value: className),
            _DetailRow(
                label: 'Month/Year',
                value:
                    '${_monthName(payment.month ?? payment.date.month)} ${payment.year ?? payment.date.year}'),
            _DetailRow(
              label: 'Payment Type',
              value: payment.type == 'full'
                  ? 'Full Payment'
                  : payment.type == 'half'
                      ? 'Half Payment'
                      : 'Free',
            ),
            _DetailRow(
                label: 'Amount',
                value: 'LKR ${payment.amount.toStringAsFixed(2)}'),
            _DetailRow(
              label: 'Recorded On',
              value: _formatDate(payment.date),
            ),
            const SizedBox(height: 24),
            // Delete option
            OutlinedButton.icon(
              icon: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
              label: Text(
                'Delete this payment record',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Theme.of(ctx).colorScheme.error),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    title: const Text('Delete Payment'),
                    content: Text(
                        'Are you sure you want to delete the payment record for ${student.name}?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dctx, false),
                          child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(dctx, true),
                        style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && mounted) {
                  try {
                    await paymentProvider.deletePayment(payment.id);
                    setState(() {});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Payment record deleted.'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to delete: $e'),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    // Convert UTC → device-local (GMT+5:30) for display
    final local = dt.isUtc ? dt.toLocal() : dt;
    final months = [
      '',
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${local.day} ${months[local.month]} ${local.year}  ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StudentPaymentTile extends StatelessWidget {
  final Student student;
  final Payment? payment;
  final bool isPaid;
  final String? className;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onTapPaid;

  const _StudentPaymentTile({
    required this.student,
    required this.payment,
    required this.isPaid,
    required this.className,
    this.onMarkPaid,
    this.onTapPaid,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPaid
              ? const Color(0xFF22C55E).withValues(alpha: 0.35)
              : const Color(0xFF4F46E5).withValues(alpha: 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isPaid ? onTapPaid : onMarkPaid,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPaid
                        ? const [Color(0xFF059669), Color(0xFF22C55E)]
                        : const [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: (isPaid
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF4F46E5))
                          .withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    student.name.isNotEmpty
                        ? student.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        'ID: ${student.studentId}',
                        if (className != null && className!.isNotEmpty)
                          className!,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (isPaid) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${_typeLabel(payment!.type)}  ·  LKR ${payment!.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ],
                ),
              ),

              // Status / action
              if (isPaid)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              color: Color(0xFF22C55E), size: 14),
                          SizedBox(width: 4),
                          Text(
                            'PAID',
                            style: TextStyle(
                              color: Color(0xFF22C55E),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'tap for details',
                      style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurface.withValues(alpha: 0.4)),
                    ),
                  ],
                )
              else
                GestureDetector(
                  onTap: onMarkPaid,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_circle_outline_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 5),
                        Text(
                          'Mark Paid',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'full':
        return 'Full';
      case 'half':
        return 'Half';
      case 'free':
        return 'Free';
      default:
        return t;
    }
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.35),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _QuickStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55),
              ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String searchText;

  const _EmptyState({required this.searchText});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            searchText.isNotEmpty
                ? Icons.search_off
                : Icons.people_outline,
            size: 72,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.25),
          ),
          const SizedBox(height: 16),
          Text(
            searchText.isNotEmpty
                ? 'No students matching "$searchText"'
                : 'No students in this class',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45),
                ),
          ),
        ],
      ),
    );
  }
}
