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
                            Text(
                              'Welcome Back!',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage your classroom attendance',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        PopupMenuButton<String>(
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
                            if (value == 'logout') {
                              final authProvider = Provider.of<AuthProvider>(context, listen: false);
                              await authProvider.logout();
                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                  (route) => false,
                                );
                              }
                            }
                          },
                          itemBuilder: (BuildContext context) => [
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
                            PopupMenuItem<String>(
                              value: 'logout',
                              child: Row(
                                children: [
                                  Icon(Icons.logout, color: Colors.red[700]),
                                  const SizedBox(width: 12),
                                  Text('Logout', style: TextStyle(color: Colors.red[700])),
                                ],
                              ),
                            ),
                          ],
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
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom + 24),
                    children: [
                      _FeatureCard(
                        title: 'Classes',
                        subtitle: 'Manage class schedules',
                        icon: Icons.class_rounded,
                        color: const Color(0xFF00796B),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ClassesScreen()),
                          );
                        },
                      ),
                      _FeatureCard(
                        title: 'Students',
                        subtitle: 'Manage student records',
                        icon: Icons.people_rounded,
                        color: const Color(0xFF6750A4),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const StudentsScreen()),
                          );
                        },
                      ),
                      _FeatureCard(
                        title: 'Mark Attendance',
                        subtitle: 'Record daily attendance',
                        icon: Icons.check_circle_rounded,
                        color: const Color(0xFF00BFA5),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AttendanceMarkScreen()),
                          );
                        },
                      ),
                      _FeatureCard(
                        title: 'Payments',
                        subtitle: 'Manage payments and fees',
                        icon: Icons.payment_rounded,
                        color: const Color(0xFF6200EE),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PaymentScreen()),
                          );
                        },
                      ),
                      _FeatureCard(
                        title: 'View Records',
                        subtitle: 'Check attendance history',
                        icon: Icons.analytics_rounded,
                        color: const Color(0xFFFF6F00),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AttendanceViewScreen()),
                          );
                        },
                      ),
                      _FeatureCard(
                        title: 'Reports',
                        subtitle: 'Generate reports',
                        icon: Icons.assessment_rounded,
                        color: const Color(0xFFD32F2F),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ReportsScreen()),
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

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
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
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}