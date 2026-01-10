import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../providers/payment_provider.dart';
import '../providers/students_provider.dart';
import '../providers/classes_provider.dart';
import '../providers/auth_provider.dart';
import '../models/student.dart';
import '../models/class.dart' as class_model;
import '../widgets/custom_widgets.dart';
import 'package:intl/intl.dart';

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
      await paymentProvider.loadPayments(teacherId: auth.teacherId);
      await studentsProvider.loadStudents(teacherId: auth.teacherId);
      await classesProvider.loadClasses(teacherId: auth.teacherId);
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
        );

        setState(() {
          _selectedStudentId = null;
          _selectedClassId = null;
          _selectedPaymentType = 'full';
          _selectedMonth = DateTime.now().month;
          _selectedYear = DateTime.now().year;
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Payments'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with stats
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Consumer<PaymentProvider>(
                builder: (context, provider, child) {
                  final currentMonth = DateTime.now().month;
                  final currentYear = DateTime.now().year;
                  final monthlyPayments = provider.payments.where((p) => 
                    p.month == currentMonth && p.year == currentYear
                  ).toList();
                  
                  final totalRevenue = monthlyPayments.fold<double>(0, (sum, payment) => sum + payment.amount);
                  final fullPayments = monthlyPayments.where((p) => p.type == 'full').length;
                  final halfPayments = monthlyPayments.where((p) => p.type == 'half').length;
                  final freePayments = monthlyPayments.where((p) => p.type == 'free').length;

                  return Column(
                    children: [
                      // Total Revenue and Total Payments in one line
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Flexible(
                            child: _StatCard(
                              title: 'Total Revenue',
                              value: 'LKR ${totalRevenue.toStringAsFixed(0)}',
                              icon: Icons.attach_money,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: _StatCard(
                              title: 'Total Payments',
                              value: '${monthlyPayments.length}',
                              icon: Icons.receipt,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Full, Free, Half cards in one line
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Flexible(
                            child: _PaymentTypeCard(
                              title: 'Full',
                              count: fullPayments,
                              color: Colors.blue,
                            ),
                          ),
                          Flexible(
                            child: _PaymentTypeCard(
                              title: 'Half',
                              count: halfPayments,
                              color: Colors.orange,
                            ),
                          ),
                          Flexible(
                            child: _PaymentTypeCard(
                              title: 'Free',
                              count: freePayments,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),

            // Add Payment Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: !_showForm
                    ? ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showForm = true;
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Record New Payment'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : Card(
                        elevation: 4,
                        color: Theme.of(context).colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
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
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.close,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _showForm = false;
                                        });
                                      },
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
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.class_,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.person,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                          ),
                                          prefixIcon: Icon(
                                            Icons.calendar_month,
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                          ),
                                          prefixIcon: Icon(
                                            Icons.date_range,
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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

                                // Payment Type Selection
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedPaymentType,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  dropdownColor: Theme.of(context).colorScheme.surface,
                                  decoration: InputDecoration(
                                    labelText: 'Payment Type',
                                    labelStyle: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.payment,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.attach_money,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                    hintText: 'Enter payment amount',
                                    hintStyle: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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

                                ElevatedButton.icon(
                                  onPressed: _addPayment,
                                  icon: const Icon(Icons.save),
                                  label: const Text('Record Payment'),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 50),
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                  fillColor: Theme.of(context).colorScheme.surface,
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

                // Filter payments by search text
                final filteredPayments = _searchText.isEmpty
                    ? paymentProvider.payments
                    : paymentProvider.payments.where((payment) {
                        final student = studentsProvider.students.firstWhere(
                          (s) => s.id == payment.studentId,
                          orElse: () => Student(id: '', name: '', studentId: ''),
                        );
                        return student.name.toLowerCase().contains(_searchText) ||
                               (student.studentId.toLowerCase().contains(_searchText) ?? false);
                      }).toList();

                if (filteredPayments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.payment_outlined,
                          size: 80,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchText.isNotEmpty ? 'No payments found matching "$_searchText"' : 'No payments yet',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchText.isNotEmpty 
                              ? 'Try a different search term'
                              : 'Record your first payment',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
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
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            icon: Icons.delete,
                            label: 'Delete',
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ],
                      ),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: _getPaymentTypeColor(payment.type),
                            radius: 28,
                            child: Icon(
                              _getPaymentTypeIcon(payment.type),
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          title: Consumer2<StudentsProvider, ClassesProvider>(
                            builder: (context, studentsProvider, classesProvider, child) {
                              final student = studentsProvider.students.firstWhere(
                                (s) => s.id == payment.studentId,
                                orElse: () => Student(id: '', name: '', studentId: ''),
                              );
                              final classObj = classesProvider.classes.firstWhere(
                                (c) => c.id == payment.classId,
                                orElse: () => class_model.Class(id: '', name: '', teacherId: ''),
                              );

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${classObj.name} • ${_getPaymentTypeLabel(payment.type)}',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.outline,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatMonthYear(payment.month ?? payment.date.month, payment.year ?? payment.date.year),
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Recorded: ${_formatPaidDate(payment.date)}',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.outline,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: SizedBox.shrink(),
                          ),
                          trailing: Text(
                            'LKR ${payment.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
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

  String _formatPaidDate(DateTime date) {
    // Format as: 2026-January-10 14:26 (with time and local timezone)
    final months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final monthName = months[date.month];
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.year}-$monthName-$day $hour:$minute';
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

  String _formatPaymentMonthYear(DateTime date) {
    // Format as: january-2026 (lowercase month-year)
    final months = [
      '', 'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december'
    ];
    final monthName = months[date.month];
    return '$monthName-${date.year}';
  }

  String _formatPaymentMonth(int? month, int? year) {
    // Format as: 2025-December
    if (month == null || year == null) return '';
    final months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final monthName = months[month];
    return '$year-$monthName';
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
    return Container(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 160),
      padding: const EdgeInsets.all(12), // Reduced padding
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28), // Slightly smaller icon
          const SizedBox(height: 6), // Reduced spacing
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20, // Slightly smaller font
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2), // Reduced spacing
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              maxLines: 1,
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
      constraints: const BoxConstraints(minWidth: 70, maxWidth: 100),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Reduced padding
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 16, // Slightly smaller font
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 1), // Reduced spacing
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11, // Slightly smaller font
                color: color,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}