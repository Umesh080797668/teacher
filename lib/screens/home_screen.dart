import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'students_screen.dart';
import 'attendance_mark_screen.dart';
import 'attendance_view_screen.dart';
import 'classes_screen.dart';
import 'payment_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'account_selection_screen.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/home_stats.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeStats? _stats;
  List<RecentActivity> _activities = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _refreshTimer;
  Timer? _timeUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Refresh data every 30 seconds for real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadData(silent: true);
    });
    // Update time displays every minute
    _timeUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      setState(() {}); // Force rebuild to update time displays
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshTimer?.cancel();
    _timeUpdateTimer?.cancel();
    super.dispose();
  }

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // Search through features
      final features = [
        {
          'type': 'feature',
          'title': 'Classes',
          'subtitle': 'Manage class schedules',
          'icon': Icons.class_rounded,
          'color': const Color(0xFF00796B),
          'screen': const ClassesScreen(),
        },
        {
          'type': 'feature',
          'title': 'Students',
          'subtitle': 'Manage student records',
          'icon': Icons.people_rounded,
          'color': const Color(0xFF6750A4),
          'screen': const StudentsScreen(),
        },
        {
          'type': 'feature',
          'title': 'Mark Attendance',
          'subtitle': 'Record daily attendance',
          'icon': Icons.check_circle_rounded,
          'color': const Color(0xFF00BFA5),
          'screen': const AttendanceMarkScreen(),
        },
        {
          'type': 'feature',
          'title': 'Payments',
          'subtitle': 'Manage payments and fees',
          'icon': Icons.payment_rounded,
          'color': const Color(0xFF6200EE),
          'screen': const PaymentScreen(),
        },
        {
          'type': 'feature',
          'title': 'View Records',
          'subtitle': 'Check attendance history',
          'icon': Icons.analytics_rounded,
          'color': const Color(0xFFFF6F00),
          'screen': const AttendanceViewScreen(),
        },
        {
          'type': 'feature',
          'title': 'Reports',
          'subtitle': 'Generate reports',
          'icon': Icons.assessment_rounded,
          'color': const Color(0xFFD32F2F),
          'screen': const ReportsScreen(),
        },
      ];

      // Search through students and classes
      final students = await ApiService.getStudents();
      final classes = await ApiService.getClasses();

      final results = <Map<String, dynamic>>[];
      final searchLower = query.toLowerCase();

      // Search features
      for (var feature in features) {
        if (feature['title'].toString().toLowerCase().contains(searchLower) ||
            feature['subtitle'].toString().toLowerCase().contains(
              searchLower,
            )) {
          results.add(feature);
        }
      }

      // Search students
      for (var student in students) {
        if (student.name.toLowerCase().contains(searchLower) ||
            (student.email?.toLowerCase().contains(searchLower) ?? false) ||
            student.studentId.toLowerCase().contains(searchLower)) {
          results.add({
            'type': 'student',
            'title': student.name,
            'subtitle': 'Student ID: ${student.studentId}',
            'icon': Icons.person,
            'color': const Color(0xFF6750A4),
            'data': student,
          });
        }
      }

      // Search classes
      for (var classItem in classes) {
        if (classItem.name.toLowerCase().contains(searchLower)) {
          results.add({
            'type': 'class',
            'title': classItem.name,
            'subtitle': 'Class',
            'icon': Icons.class_,
            'color': const Color(0xFF00796B),
            'data': classItem,
          });
        }
      }

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      // Handle search error silently
      setState(() {
        _searchResults = [];
      });
    }
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final teacherId = auth.teacherId;

      final stats = await ApiService.getHomeStats(teacherId: teacherId);
      final activities = await ApiService.getRecentActivities(teacherId: teacherId);

      setState(() {
        _stats = stats;
        _activities = activities;
        if (!silent) {
          _isLoading = false;
        }
      });
    } catch (e) {
      if (!silent) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${(difference.inDays / 7).floor()} weeks ago';
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'attendance':
        return Icons.check_circle;
      case 'student':
        return Icons.person_add;
      case 'payment':
        return Icons.payment;
      case 'report':
        return Icons.assessment;
      default:
        return Icons.info;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'attendance':
        return const Color(0xFF00BFA5);
      case 'student':
        return const Color(0xFF6750A4);
      case 'payment':
        return const Color(0xFF6200EE);
      case 'report':
        return const Color(0xFFD32F2F);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          if (auth.isGuest) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AttendanceMarkScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Mark Attendance'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.1),
                Theme.of(
                  context,
                ).colorScheme.secondaryContainer.withValues(alpha: 0.1),
                Theme.of(
                  context,
                ).colorScheme.tertiaryContainer.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: SafeArea(
            child: CustomScrollView(
              slivers: [
                // Header with Search
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Consumer<AuthProvider>(
                                    builder: (context, auth, child) {
                                      return Text(
                                        auth.isGuest
                                            ? 'Welcome, Guest!'
                                            : 'Welcome Back!',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
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
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.7),
                                            ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Consumer<AuthProvider>(
                              builder: (context, auth, child) {
                                return PopupMenuButton<String>(
                                  icon: CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    child: Icon(
                                      Icons.person,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                      size: 28,
                                    ),
                                  ),
                                  onSelected: (value) async {
                                    final authProvider =
                                        Provider.of<AuthProvider>(
                                          context,
                                          listen: false,
                                        );
                                    if (value == 'logout') {
                                      await authProvider.logout();
                                      if (context.mounted) {
                                        Navigator.of(
                                          context,
                                        ).pushAndRemoveUntil(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const AccountSelectionScreen(),
                                          ),
                                          (route) => false,
                                        );
                                      }
                                    } else if (value == 'login') {
                                      await authProvider
                                          .logout(); // Clear guest state
                                      if (context.mounted) {
                                        Navigator.of(
                                          context,
                                        ).pushAndRemoveUntil(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const AccountSelectionScreen(),
                                          ),
                                          (route) => false,
                                        );
                                      }
                                    } else if (value == 'profile') {
                                      if (context.mounted) {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const ProfileScreen(),
                                          ),
                                        );
                                      }
                                    } else if (value == 'settings') {
                                      if (context.mounted) {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const SettingsScreen(),
                                          ),
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
                                            Icon(
                                              Icons.person_outline,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                            const SizedBox(width: 12),
                                            const Text('Profile'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'settings',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.settings_outlined,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
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
                                            auth.isGuest
                                                ? Icons.login
                                                : Icons.logout,
                                            color: auth.isGuest
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.primary
                                                : Colors.red[700],
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            auth.isGuest
                                                ? 'Login / Register'
                                                : 'Logout',
                                            style: auth.isGuest
                                                ? null
                                                : TextStyle(
                                                    color: Colors.red[700],
                                                  ),
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
                        const SizedBox(height: 20),
                        // Search Bar
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.shadow.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              _performSearch(value);
                            },
                            decoration: InputDecoration(
                              hintText: 'Search features, students, classes...',
                              prefixIcon: Icon(
                                Icons.search,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        _performSearch('');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                            ),
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Search Results
                if (_isSearching && _searchResults.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            'Search Results (${_searchResults.length})',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                          ),
                          const SizedBox(height: 16),
                          ..._searchResults.map(
                            (result) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _SearchResultCard(
                                title: result['title'],
                                subtitle: result['subtitle'],
                                icon: result['icon'],
                                color: result['color'],
                                onTap: () {
                                  if (result['type'] == 'feature') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => result['screen'],
                                      ),
                                    );
                                  } else if (result['type'] == 'student') {
                                    // Navigate to students screen
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const StudentsScreen(),
                                      ),
                                    );
                                  } else if (result['type'] == 'class') {
                                    // Navigate to classes screen
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ClassesScreen(),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                if (_isSearching && _searchResults.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No results found',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Statistics Cards
                if (!_isSearching)
                  SliverToBoxAdapter(
                    child: Consumer<AuthProvider>(
                      builder: (context, auth, child) {
                        if (auth.isGuest) return const SizedBox.shrink();

                        if (_isLoading) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                              vertical: 32,
                            ),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (_error != null) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Failed to load data',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _loadData,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Overview',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 130,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    _StatisticsCard(
                                      title: 'Total Students',
                                      value: '${_stats?.totalStudents ?? 0}',
                                      icon: Icons.people,
                                      color: const Color(0xFF6750A4),
                                      trend: _stats?.studentsTrend ?? '0',
                                      trendColor:
                                          (_stats?.studentsPositive ?? true)
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    const SizedBox(width: 16),
                                    _StatisticsCard(
                                      title: 'Today\'s Attendance',
                                      value:
                                          '${(_stats?.todayAttendancePercentage ?? 0).toStringAsFixed(0)}%',
                                      icon: Icons.check_circle,
                                      color: const Color(0xFF00BFA5),
                                      trend: _stats?.attendanceTrend ?? '0%',
                                      trendColor:
                                          (_stats?.attendancePositive ?? true)
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    const SizedBox(width: 16),
                                    _StatisticsCard(
                                      title: 'Total Classes',
                                      value: '${_stats?.totalClasses ?? 0}',
                                      icon: Icons.class_,
                                      color: const Color(0xFF00796B),
                                      trend: _stats?.classesTrend ?? '0',
                                      trendColor:
                                          (_stats?.classesPositive ?? true)
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    const SizedBox(width: 16),
                                    _StatisticsCard(
                                      title: 'Payment Status',
                                      value:
                                          '${(_stats?.paymentStatusPercentage ?? 0).toStringAsFixed(0)}%',
                                      icon: Icons.payment,
                                      color: const Color(0xFF6200EE),
                                      trend: _stats?.paymentTrend ?? '0%',
                                      trendColor:
                                          (_stats?.paymentPositive ?? true)
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Recent Activity',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              ..._activities.map(
                                (activity) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _RecentActivityCard(
                                    title: activity.title,
                                    subtitle: activity.subtitle,
                                    time: _getTimeAgo(activity.timestamp),
                                    icon: _getActivityIcon(activity.type),
                                    color: _getActivityColor(activity.type),
                                  ),
                                ),
                              ),
                              if (_activities.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Text(
                                      'No recent activities',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                // Feature Cards
                if (!_isSearching)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.7,
                          ),
                      delegate: SliverChildListDelegate([
                        Consumer<AuthProvider>(
                          builder: (context, auth, child) {
                            return _FeatureCard(
                              title: 'Classes',
                              subtitle: auth.isGuest
                                  ? 'View class schedules'
                                  : 'Manage class schedules',
                              icon: Icons.class_rounded,
                              color: const Color(0xFF00796B),
                              onTap: auth.isGuest
                                  ? () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please login to manage classes',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ClassesScreen(),
                                        ),
                                      );
                                    },
                              isDisabled: auth.isGuest,
                            );
                          },
                        ),
                        Consumer<AuthProvider>(
                          builder: (context, auth, child) {
                            return _FeatureCard(
                              title: 'Students',
                              subtitle: auth.isGuest
                                  ? 'View student records'
                                  : 'Manage student records',
                              icon: Icons.people_rounded,
                              color: const Color(0xFF6750A4),
                              onTap: auth.isGuest
                                  ? () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please login to manage students',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const StudentsScreen(),
                                        ),
                                      );
                                    },
                              isDisabled: auth.isGuest,
                            );
                          },
                        ),
                        Consumer<AuthProvider>(
                          builder: (context, auth, child) {
                            return _FeatureCard(
                              title: 'Mark Attendance',
                              subtitle: 'Record daily attendance',
                              icon: Icons.check_circle_rounded,
                              color: const Color(0xFF00BFA5),
                              onTap: auth.isGuest
                                  ? () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please login to mark attendance',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const AttendanceMarkScreen(),
                                        ),
                                      );
                                    },
                              isDisabled: auth.isGuest,
                            );
                          },
                        ),
                        Consumer<AuthProvider>(
                          builder: (context, auth, child) {
                            return _FeatureCard(
                              title: 'Payments',
                              subtitle: 'Manage payments and fees',
                              icon: Icons.payment_rounded,
                              color: const Color(0xFF6200EE),
                              onTap: auth.isGuest
                                  ? () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please login to manage payments',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const PaymentScreen(),
                                        ),
                                      );
                                    },
                              isDisabled: auth.isGuest,
                            );
                          },
                        ),
                        Consumer<AuthProvider>(
                          builder: (context, auth, child) {
                            return _FeatureCard(
                              title: 'View Records',
                              subtitle: 'Check attendance history',
                              icon: Icons.analytics_rounded,
                              color: const Color(0xFFFF6F00),
                              onTap: auth.isGuest
                                  ? () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please login to view attendance records',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const AttendanceViewScreen(),
                                        ),
                                      );
                                    },
                              isDisabled: auth.isGuest,
                            );
                          },
                        ),
                        Consumer<AuthProvider>(
                          builder: (context, auth, child) {
                            return _FeatureCard(
                              title: 'Reports',
                              subtitle: auth.isGuest
                                  ? 'View reports'
                                  : 'Generate reports',
                              icon: Icons.assessment_rounded,
                              color: const Color(0xFFD32F2F),
                              onTap: auth.isGuest
                                  ? () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please login to generate reports',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ReportsScreen(),
                                        ),
                                      );
                                    },
                              isDisabled: auth.isGuest,
                            );
                          },
                        ),
                      ]),
                    ),
                  ),

                // Bottom padding
                SliverPadding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewPadding.bottom + 80,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatisticsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String trend;
  final Color trendColor;

  const _StatisticsCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.trend,
    required this.trendColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  trend,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: trendColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 28,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final Color color;

  const _RecentActivityCard({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            time,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 11,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SearchResultCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
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
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Card(
            elevation: widget.isDisabled ? 2 : 6,
            shadowColor: widget.color.withValues(
              alpha: widget.isDisabled ? 0.2 : 0.3,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: InkWell(
              onTap: widget.isDisabled
                  ? null
                  : () {
                      _animationController.forward().then((_) {
                        _animationController.reverse();
                        widget.onTap();
                      });
                    },
              onTapDown: widget.isDisabled
                  ? null
                  : (_) => _animationController.forward(),
              onTapUp: widget.isDisabled
                  ? null
                  : (_) => _animationController.reverse(),
              onTapCancel: widget.isDisabled
                  ? null
                  : () => _animationController.reverse(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.color.withValues(
                        alpha: widget.isDisabled ? 0.03 : 0.08,
                      ),
                      widget.color.withValues(
                        alpha: widget.isDisabled ? 0.01 : 0.04,
                      ),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(
                          alpha: widget.isDisabled ? 0.08 : 0.15,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.icon,
                        size: 32,
                        color: widget.isDisabled
                            ? widget.color.withValues(alpha: 0.4)
                            : widget.color,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: widget.isDisabled
                            ? Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.4)
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: widget.isDisabled
                            ? Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.3)
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    if (widget.isDisabled) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Login Required',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
