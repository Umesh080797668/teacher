import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../providers/payment_provider.dart';
import '../providers/students_provider.dart';
import '../providers/classes_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart'; // Added for WhatsApp Integration
import '../models/student.dart';
import '../models/class.dart' as class_model;
import '../widgets/custom_widgets.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedStudentId;
  String? _selectedClassId;
  String _selectedPaymentType = 'full';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  DateTime _selectedRecordingDate = DateTime.now();
  final TextEditingController _amountController = TextEditingController();
  bool _showForm = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
    final studentsProvider = Provider.of<StudentsProvider>(context, listen: false);
    final classesProvider = Provider.of<ClassesProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      // Load all data in parallel for faster response
      await Future.wait([
        paymentProvider.loadPayments(teacherId: auth.teacherId),
        studentsProvider.loadStudents(teacherId: auth.teacherId),
        classesProvider.loadClasses(teacherId: auth.teacherId),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double _getDefaultPaymentAmount(String type) {
    // Default amounts for reference, but users can override
    switch (type) {
      case 'full':
        return 5000.0; // Default full payment in LKR
      case 'half':
        return 2500.0; // Default half payment in LKR
      case 'free':
        return 0.0; // Free
      default:
        return 0.0;
    }
  }

  Future<void> _showReminderDialog() async {
    final classesProvider = Provider.of<ClassesProvider>(context, listen: false);
    final classes = classesProvider.classes;
    
    if (classes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No classes found to send reminders.')));
      }
      return;
    }
    
    String? selectedRemindClassId = classes.isNotEmpty ? classes.first.id : null;
    int selectedRemindMonth = DateTime.now().month;
    int selectedRemindYear = DateTime.now().year;
    
    await showModalBottomSheet(
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
                            gradient: const LinearGradient(colors: [Color(0xFF25D366), Color(0xFF128C7E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [BoxShadow(color: const Color(0xFF25D366).withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('WhatsApp Reminders', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: cs.onSurface)),
                            Text('Send payment reminders to students', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          ]),
                        ),
                        IconButton(onPressed: () => Navigator.pop(sheetCtx), icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        'Reminders will be sent to all students who haven\'t paid for the selected month.',
                        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedRemindClassId,
                      dropdownColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                      style: TextStyle(color: cs.onSurface),
                      isExpanded: true,
                      items: classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: TextStyle(color: cs.onSurface)))).toList(),
                      onChanged: (val) => setSheetState(() => selectedRemindClassId = val),
                      decoration: InputDecoration(
                        labelText: 'Class',
                        labelStyle: TextStyle(color: cs.onSurfaceVariant),
                        prefixIcon: const Icon(Icons.class_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selectedRemindMonth,
                            dropdownColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                            style: TextStyle(color: cs.onSurface),
                            items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text(_getMonthName(m), style: TextStyle(color: cs.onSurface)))).toList(),
                            onChanged: (val) => setSheetState(() => selectedRemindMonth = val!),
                            decoration: InputDecoration(labelText: 'Month', labelStyle: TextStyle(color: cs.onSurfaceVariant)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selectedRemindYear,
                            dropdownColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                            style: TextStyle(color: cs.onSurface),
                            items: List.generate(5, (i) => DateTime.now().year - 2 + i).map((y) => DropdownMenuItem(value: y, child: Text(y.toString(), style: TextStyle(color: cs.onSurface)))).toList(),
                            onChanged: (val) => setSheetState(() => selectedRemindYear = val!),
                            decoration: InputDecoration(labelText: 'Year', labelStyle: TextStyle(color: cs.onSurfaceVariant)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () async {
                        if (selectedRemindClassId == null) return;
                        Navigator.pop(sheetCtx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Row(children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)), SizedBox(width: 12), Text('Sending reminders...')]), duration: Duration(seconds: 2)),
                          );
                        }
                        try {
                          final result = await ApiService.sendPaymentReminders(classId: selectedRemindClassId!, month: selectedRemindMonth, year: selectedRemindYear);
                          if (mounted) {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            final msg = result['message'] ?? 'Reminders sent!';
                            final count = result['remindedCount'] ?? 0;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$msg ($count sent)'), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
                          }
                        }
                      },
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF25D366), Color(0xFF128C7E)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: const Color(0xFF25D366).withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 5))],
                        ),
                        child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text('Send Reminders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
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

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  Future<void> _addPayment() async {
    if (_formKey.currentState!.validate() && _selectedStudentId != null && _selectedClassId != null) {
      final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
      final amount = double.tryParse(_amountController.text) ?? 0.0;

      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid amount greater than 0'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        await paymentProvider.addPayment(
          _selectedStudentId!,
          _selectedClassId!,
          amount,
          _selectedPaymentType,
          month: _selectedMonth,
          year: _selectedYear,
          recordingDate: _selectedRecordingDate,
        );

        setState(() {
          _selectedStudentId = null;
          _selectedClassId = null;
          _selectedPaymentType = 'full';
          _selectedMonth = DateTime.now().month;
          _selectedYear = DateTime.now().year;
          _selectedRecordingDate = DateTime.now();
          _amountController.clear();
          _showForm = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('Payment recorded successfully (LKR ${amount.toStringAsFixed(2)})'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to record payment: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deletePayment(String paymentId) async {
    final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
    try {
      await paymentProvider.deletePayment(paymentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.delete, color: Colors.white),
                SizedBox(width: 12),
                Text('Payment deleted successfully'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete payment: $e'),
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
                        'Payments',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Track & manage payments',
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
                      icon: const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                      tooltip: 'Send Payment Reminders',
                      onPressed: _showReminderDialog,
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
                      onPressed: _loadData,
                    ),
                  ),
                ],
              ),
            ),
            // Scrollable body
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
            // Header with stats
            Consumer<PaymentProvider>(
              builder: (context, provider, _) {
                final cs = Theme.of(context).colorScheme;
                final currentMonth = DateTime.now().month;
                final currentYear = DateTime.now().year;
                final monthlyPayments = provider.payments.where((p) =>
                  p.month == currentMonth && p.year == currentYear
                ).toList();
                final totalRevenue = monthlyPayments.fold<double>(0, (sum, p) => sum + p.amount);
                final fullPayments = monthlyPayments.where((p) => p.type == 'full').length;
                final halfPayments = monthlyPayments.where((p) => p.type == 'half').length;
                final freePayments = monthlyPayments.where((p) => p.type == 'free').length;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'Revenue',
                              value: 'LKR ${totalRevenue.toStringAsFixed(0)}',
                              icon: Icons.attach_money_rounded,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              title: 'Total',
                              value: '${monthlyPayments.length}',
                              icon: Icons.receipt_rounded,
                              color: const Color(0xFF22C55E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _PaymentTypeCard(title: 'Full', count: fullPayments, color: Colors.blue)),
                          const SizedBox(width: 8),
                          Expanded(child: _PaymentTypeCard(title: 'Half', count: halfPayments, color: Colors.orange)),
                          const SizedBox(width: 8),
                          Expanded(child: _PaymentTypeCard(title: 'Free', count: freePayments, color: Colors.purple)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            // Add Payment Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: !_showForm
                    ? SizedBox(
                        key: const ValueKey('btn'),
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: () => setState(() => _showForm = true),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Record New Payment'),
                        ),
                      )
                    : Builder(
                        key: const ValueKey('form'),
                        builder: (context) {
                          final cs = Theme.of(context).colorScheme;
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          return Container(
                            decoration: BoxDecoration(
                              color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(20),
                              border: isDark ? null : Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Record Payment',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    onPressed: () => setState(() => _showForm = false),
                                  ),
                                ],
                              ),
                                const SizedBox(height: 16),

                                // Class Selection
                                Consumer<ClassesProvider>(
                                  builder: (context, classesProvider, child) {
                                    return DropdownButtonFormField<String>(
                                      initialValue: _selectedClassId,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                      dropdownColor: Theme.of(context).colorScheme.surface,
                                      decoration: InputDecoration(
                                        labelText: 'Select Class',
                                        labelStyle: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.class_,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                      items: classesProvider.classes.map((classObj) {
                                        return DropdownMenuItem<String>(
                                          value: classObj.id,
                                          child: Text(
                                            classObj.name,
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedClassId = value;
                                          _selectedStudentId = null; // Reset student selection
                                        });
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please select a class';
                                        }
                                        return null;
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Student Selection (filtered by class)
                                Consumer2<StudentsProvider, ClassesProvider>(
                                  builder: (context, studentsProvider, classesProvider, child) {
                                    final classStudents = studentsProvider.students
                                        .where((student) => student.classId == _selectedClassId)
                                        .toList();

                                    return DropdownButtonFormField<String>(
                                      initialValue: _selectedStudentId,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                      dropdownColor: Theme.of(context).colorScheme.surface,
                                      decoration: InputDecoration(
                                        labelText: 'Select Student',
                                        labelStyle: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.person,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                      items: classStudents.map((student) {
                                        return DropdownMenuItem<String>(
                                          value: student.id,
                                          child: Text(
                                            student.name,
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: _selectedClassId != null ? (value) {
                                        setState(() {
                                          _selectedStudentId = value;
                                        });
                                      } : null,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please select a student';
                                        }
                                        return null;
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Month and Year Selection
                                Row(
                                  children: [
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
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                          ),
                                          prefixIcon: Icon(
                                            Icons.calendar_month,
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                        items: List.generate(12, (index) {
                                          final months = ['January', 'February', 'March', 'April', 'May', 'June',
                                                         'July', 'August', 'September', 'October', 'November', 'December'];
                                          return DropdownMenuItem<int>(
                                            value: index + 1,
                                            child: Text(
                                              months[index],
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                            ),
                                          );
                                        }),
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
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                        dropdownColor: Theme.of(context).colorScheme.surface,
                                        decoration: InputDecoration(
                                          labelText: 'Year',
                                          labelStyle: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                          ),
                                          prefixIcon: Icon(
                                            Icons.date_range,
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                        items: List.generate(6, (index) {
                                          final year = DateTime.now().year - index;
                                          return DropdownMenuItem<int>(
                                            value: year,
                                            child: Text(
                                              year.toString(),
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                            ),
                                          );
                                        }),
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
                                const SizedBox(height: 12),

                                // Recording Date Picker
                                GestureDetector(
                                  onTap: () async {
                                    final pickedDate = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedRecordingDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (pickedDate != null) {
                                      // Add current time to the selected date
                                      final now = DateTime.now();
                                      final dateTimeWithCurrentTime = DateTime(
                                        pickedDate.year,
                                        pickedDate.month,
                                        pickedDate.day,
                                        now.hour,
                                        now.minute,
                                        now.second,
                                      );
                                      setState(() {
                                        _selectedRecordingDate = dateTimeWithCurrentTime;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.outline,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Recording Date',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatPaymentRecordingDate(_selectedRecordingDate),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Icon(
                                          Icons.calendar_today,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedPaymentType,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  dropdownColor: Theme.of(context).colorScheme.surface,
                                  decoration: InputDecoration(
                                    labelText: 'Payment Type',
                                    labelStyle: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.payment,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'full',
                                      child: Text(
                                        'Full Payment',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'half',
                                      child: Text(
                                        'Half Payment',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'free',
                                      child: Text(
                                        'Free',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedPaymentType = value!;
                                      // Set default amount based on type
                                      if (_amountController.text.isEmpty || _amountController.text == '0') {
                                        _amountController.text = _getDefaultPaymentAmount(_selectedPaymentType).toStringAsFixed(2);
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Amount Input
                                TextFormField(
                                  controller: _amountController,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Amount (LKR)',
                                    labelStyle: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.attach_money,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                    hintText: 'Enter payment amount',
                                    hintStyle: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter an amount';
                                    }
                                    final amount = double.tryParse(value);
                                    if (amount == null || amount <= 0) {
                                      return 'Please enter a valid amount greater than 0';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: FilledButton.icon(
                                    onPressed: _addPayment,
                                    icon: const Icon(Icons.save_rounded),
                                    label: const Text('Record Payment'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          );
                        },
                      ),
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchText = value.toLowerCase();
                  });
                },
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Search payments by student name...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchText = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surfaceContainerHigh
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                ),
              ),
            ),

            // Payments List
            Consumer3<PaymentProvider, StudentsProvider, ClassesProvider>(
              builder: (context, paymentProvider, studentsProvider, classesProvider, child) {
                if (paymentProvider.isLoading) {
                  return ListSkeleton(
                    itemCount: 5,
                    itemBuilder: (context) => const PaymentCardSkeleton(),
                  );
                }

                debugPrint('PaymentScreen: PaymentProvider has ${paymentProvider.payments.length} payments');
                debugPrint('PaymentScreen: Search text: "$_searchText"');

                // Filter payments by search text
                final filteredPayments = _searchText.isEmpty
                    ? paymentProvider.payments
                    : paymentProvider.payments.where((payment) {
                        final student = studentsProvider.students.firstWhere(
                          (s) => s.id == payment.studentId,
                          orElse: () => Student(id: '', name: '', studentId: ''),
                        );
                        return student.name.toLowerCase().contains(_searchText) ||
                               student.studentId.toLowerCase().contains(_searchText);
                      }).toList();

                if (filteredPayments.isEmpty) {
                  return EmptyState(
                    icon: _searchText.isNotEmpty ? Icons.search_off_rounded : Icons.payment_outlined,
                    title: _searchText.isNotEmpty ? 'No Results Found' : 'No Payments Yet',
                    message: _searchText.isNotEmpty
                        ? 'No payments match "$_searchText"'
                        : 'Record your first payment using the button above',
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredPayments.length,
                  itemBuilder: (context, index) {
                    final payment = filteredPayments[index];
                    return Slidable(
                      endActionPane: ActionPane(
                        motion: const ScrollMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (context) {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text('Delete Payment', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                    content: Text('Are you sure you want to delete this payment record?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          _deletePayment(payment.id);
                                        },
                                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            backgroundColor: Theme.of(context).colorScheme.error,
                            foregroundColor: Theme.of(context).colorScheme.onError,
                            icon: Icons.delete_rounded,
                            label: 'Delete',
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ],
                      ),
                      child: Builder(builder: (bCtx) {
                          final cs = Theme.of(bCtx).colorScheme;
                          final isDark = Theme.of(bCtx).brightness == Brightness.dark;
                          return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: isDark ? null : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {},
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: _getPaymentTypeColor(payment.type).withValues(alpha: 0.15),
                                    radius: 24,
                                    child: Icon(
                                      _getPaymentTypeIcon(payment.type),
                                      color: _getPaymentTypeColor(payment.type),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Consumer2<StudentsProvider, ClassesProvider>(
                                      builder: (context, sp, cp, _) {
                                        final student = sp.students.firstWhere(
                                          (s) => s.id == payment.studentId,
                                          orElse: () => Student(id: '', name: '', studentId: ''),
                                        );
                                        final classObj = cp.classes.firstWhere(
                                          (c) => c.id == payment.classId,
                                          orElse: () => class_model.Class(id: '', name: '', teacherId: ''),
                                        );
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(student.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.onSurface)),
                                            const SizedBox(height: 2),
                                            Text('${classObj.name} • ${_getPaymentTypeLabel(payment.type)}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                            const SizedBox(height: 1),
                                            Text(_formatMonthYear(payment.month ?? payment.date.month, payment.year ?? payment.date.year), style: TextStyle(color: cs.primary, fontSize: 11, fontWeight: FontWeight.w500)),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  Text(
                                    'LKR ${payment.amount.toStringAsFixed(0)}',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: cs.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                        }),
                    );
                  },
                );
              },
            ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Color _getPaymentTypeColor(String type) {
    switch (type) {
      case 'full':
        return Colors.blue;
      case 'half':
        return Colors.orange;
      case 'free':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getPaymentTypeIcon(String type) {
    switch (type) {
      case 'full':
        return Icons.attach_money;
      case 'half':
        return Icons.money_off;
      case 'free':
        return Icons.card_giftcard;
      default:
        return Icons.payment;
    }
  }

  String _getPaymentTypeLabel(String type) {
    switch (type) {
      case 'full':
        return 'Full Payment';
      case 'half':
        return 'Half Payment';
      case 'free':
        return 'Free';
      default:
        return type;
    }
  }

  String _formatMonthYear(int month, int year) {
    // Format as: december-2025 (lowercase month-year)
    final months = [
      '', 'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december'
    ];
    return '${months[month]}-$year';
  }

  String _formatPaymentRecordingDate(DateTime date) {
    // Format as: 10 January 2026 14:26 (with time)
    final months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final monthName = months[date.month];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} $monthName ${date.year} $hour:$minute';
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? null : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800, color: color)),
                ),
                Text(title,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTypeCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _PaymentTypeCard({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count.toString(),
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(title,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}