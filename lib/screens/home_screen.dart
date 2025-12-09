import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'students_screen.dart';
import 'attendance_mark_screen.dart';
import 'attendance_view_screen.dart';
import 'classes_screen.dart';
import 'payment_screen.dart';
import 'reports_screen.dart';
import 'login_screen.dart';
import '../providers/auth_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Consumer<AuthProvider>(
                              builder: (context, auth, child) {
                                return Text(
                                  auth.isGuest ? 'Welcome, Guest!' : 'Welcome Back!',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Consumer<AuthProvider>(
                              builder: (context, auth, child) {
                                return Text(
                                  auth.isGuest 
                                    ? 'Browse attendance records (read-only)'
                                    : 'Manage your classroom attendance',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        Consumer<AuthProvider>(
                          builder: (context, auth, child) {
                            return PopupMenuButton<String>(
                              icon: CircleAvatar(
                                radius: 28,
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                child: Icon(
                                  Icons.person,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  size: 28,
                                ),
                              ),
                              onSelected: (value) async {
                                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                if (value == 'logout') {
                                  await authProvider.logout();
                                  if (context.mounted) {
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                                      (route) => false,
                                    );
                                  }
                                } else if (value == 'login') {
                                  await authProvider.logout(); // Clear guest state
                                  if (context.mounted) {
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                                      (route) => false,
                                    );
                                  }
                                }
                              },
                              itemBuilder: (BuildContext context) => [
                                if (!auth.isGuest) ...[
                                  PopupMenuItem<String>(
                                    value: 'profile',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_outline, color: Theme.of(context).colorScheme.primary),
                                        const SizedBox(width: 12),
                                        const Text('Profile'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'settings',
                                    child: Row(
                                      children: [
                                        Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.primary),
                                        const SizedBox(width: 12),
                                        const Text('Settings'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                ],
                                PopupMenuItem<String>(
                                  value: auth.isGuest ? 'login' : 'logout',
                                  child: Row(
                                    children: [
                                      Icon(
                                        auth.isGuest ? Icons.login : Icons.logout, 
                                        color: auth.isGuest ? Theme.of(context).colorScheme.primary : Colors.red[700]
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        auth.isGuest ? 'Login / Register' : 'Logout', 
                                        style: auth.isGuest ? null : TextStyle(color: Colors.red[700])
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Feature Cards
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Consumer<AuthProvider>(
                    builder: (context, auth, child) {
                      return GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom + 24),
                        children: [
                          _FeatureCard(
                            title: 'Classes',
                            subtitle: auth.isGuest ? 'View class schedules' : 'Manage class schedules',
                            icon: Icons.class_rounded,
                            color: const Color(0xFF00796B),
                            onTap: auth.isGuest ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please login to manage classes'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            } : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ClassesScreen()),
                              );
                            },
                            isDisabled: auth.isGuest,
                          ),
                          _FeatureCard(
                            title: 'Students',
                            subtitle: auth.isGuest ? 'View student records' : 'Manage student records',
                            icon: Icons.people_rounded,
                            color: const Color(0xFF6750A4),
                            onTap: auth.isGuest ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please login to manage students'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            } : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const StudentsScreen()),
                              );
                            },
                            isDisabled: auth.isGuest,
                          ),
                          _FeatureCard(
                            title: 'Mark Attendance',
                            subtitle: 'Record daily attendance',
                            icon: Icons.check_circle_rounded,
                            color: const Color(0xFF00BFA5),
                            onTap: auth.isGuest ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please login to mark attendance'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            } : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AttendanceMarkScreen()),
                              );
                            },
                            isDisabled: auth.isGuest,
                          ),
                          _FeatureCard(
                            title: 'Payments',
                            subtitle: 'Manage payments and fees',
                            icon: Icons.payment_rounded,
                            color: const Color(0xFF6200EE),
                            onTap: auth.isGuest ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please login to manage payments'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            } : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const PaymentScreen()),
                              );
                            },
                            isDisabled: auth.isGuest,
                          ),
                          _FeatureCard(
                            title: 'View Records',
                            subtitle: 'Check attendance history',
                            icon: Icons.analytics_rounded,
                            color: const Color(0xFFFF6F00),
                            onTap: auth.isGuest ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please login to view attendance records'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            } : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AttendanceViewScreen()),
                              );
                            },
                            isDisabled: auth.isGuest,
                          ),
                          _FeatureCard(
                            title: 'Reports',
                            subtitle: auth.isGuest ? 'View reports' : 'Generate reports',
                            icon: Icons.assessment_rounded,
                            color: const Color(0xFFD32F2F),
                            onTap: auth.isGuest ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please login to generate reports'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            } : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ReportsScreen()),
                              );
                            },
                            isDisabled: auth.isGuest,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDisabled;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isDisabled ? 2 : 4,
      shadowColor: color.withOpacity(isDisabled ? 0.2 : 0.4),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(isDisabled ? 0.05 : 0.1),
                color.withOpacity(isDisabled ? 0.02 : 0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(isDisabled ? 0.1 : 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isDisabled ? color.withOpacity(0.5) : color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDisabled 
                    ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                    : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDisabled 
                    ? Theme.of(context).colorScheme.onSurface.withOpacity(0.4)
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (isDisabled) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Login Required',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}