import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../providers/payment_provider.dart';
import '../providers/students_provider.dart';
import '../providers/classes_provider.dart';
import '../providers/auth_provider.dart';
import '../models/student.dart';
import '../models/class.dart' as class_model;

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
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
    final studentsProvider = Provider.of<StudentsProvider>(context, listen: false);
    final classesProvider = Provider.of<ClassesProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      await paymentProvider.loadPayments();
      await studentsProvider.loadStudents();
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

  double _getPaymentAmount(String type, String classId) {
    // You can customize pricing based on class
    switch (type) {
      case 'full':
        return 100.0; // Full payment amount
      case 'half':
        return 50.0; // Half payment amount
      case 'free':
        return 0.0; // Free
      default:
        return 0.0;
    }
  }

  Future<void> _addPayment() async {
    if (_formKey.currentState!.validate() && _selectedStudentId != null && _selectedClassId != null) {
      final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
      final amount = _getPaymentAmount(_selectedPaymentType, _selectedClassId!);

      try {
        await paymentProvider.addPayment(
          _selectedStudentId!,
          _selectedClassId!,
          amount,
          _selectedPaymentType,
        );

        setState(() {
          _selectedStudentId = null;
          _selectedClassId = null;
          _selectedPaymentType = 'full';
          _showForm = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('Payment recorded successfully ($_selectedPaymentType)'),
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
      body: Column(
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
                final totalRevenue = provider.payments.fold<double>(0, (sum, payment) => sum + payment.amount);
                final fullPayments = provider.payments.where((p) => p.type == 'full').length;
                final halfPayments = provider.payments.where((p) => p.type == 'half').length;
                final freePayments = provider.payments.where((p) => p.type == 'free').length;

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatCard(
                          title: 'Total Revenue',
                          value: '\$${totalRevenue.toStringAsFixed(0)}',
                          icon: Icons.attach_money,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        _StatCard(
                          title: 'Total Payments',
                          value: '${provider.payments.length}',
                          icon: Icons.receipt,
                          color: Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _PaymentTypeCard(
                          title: 'Full',
                          count: fullPayments,
                          color: Colors.blue,
                        ),
                        _PaymentTypeCard(
                          title: 'Half',
                          count: halfPayments,
                          color: Colors.orange,
                        ),
                        _PaymentTypeCard(
                          title: 'Free',
                          count: freePayments,
                          color: Colors.purple,
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
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
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
                                    decoration: const InputDecoration(
                                      labelText: 'Select Class',
                                      prefixIcon: Icon(Icons.class_),
                                    ),
                                    items: classesProvider.classes.map((classObj) {
                                      return DropdownMenuItem<String>(
                                        value: classObj.id,
                                        child: Text(classObj.name),
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
                                    decoration: const InputDecoration(
                                      labelText: 'Select Student',
                                      prefixIcon: Icon(Icons.person),
                                    ),
                                    items: classStudents.map((student) {
                                      return DropdownMenuItem<String>(
                                        value: student.id,
                                        child: Text(student.name),
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

                              // Payment Type Selection
                              DropdownButtonFormField<String>(
                                initialValue: _selectedPaymentType,
                                decoration: const InputDecoration(
                                  labelText: 'Payment Type',
                                  prefixIcon: Icon(Icons.payment),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'full',
                                    child: Text('Full Payment'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'half',
                                    child: Text('Half Payment'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'free',
                                    child: Text('Free'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedPaymentType = value!;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),

                              // Amount Display
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Amount:',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '\$${_getPaymentAmount(_selectedPaymentType, _selectedClassId ?? '').toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
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

          // Payments List
          Expanded(
            child: Consumer<PaymentProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.payments.isEmpty) {
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
                          'No payments yet',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Record your first payment',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: provider.payments.length,
                  itemBuilder: (context, index) {
                    final payment = provider.payments[index];
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
                                    title: const Text('Delete Payment'),
                                    content: const Text('Are you sure you want to delete this payment record?'),
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
                                ],
                              );
                            },
                          ),
                          subtitle: Text(
                            '${payment.date.day}/${payment.date.month}/${payment.date.year}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          trailing: Text(
                            '\$${payment.amount.toStringAsFixed(2)}',
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
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}