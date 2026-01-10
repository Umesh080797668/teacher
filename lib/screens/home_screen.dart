import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'students_screen.dart';
import 'attendance_mark_screen.dart';
import 'attendance_view_screen.dart';
import 'classes_screen.dart';
import 'payment_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'account_selection_screen.dart';
import 'qr_scanner_screen.dart';
import 'login_screen.dart';
import 'restriction_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/admin_changes_provider.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import '../services/subscription_polling_service.dart';
import '../models/home_stats.dart';
import '../widgets/custom_widgets.dart';
import 'activation_screen.dart';
import 'subscription_warning_screen.dart';
import 'subscription_screen.dart';
import 'pending_activation_screen.dart';

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
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _refreshTimer;
  Timer? _timeUpdateTimer;
  Timer? _updateCheckTimer;
  final UpdateService _updateService = UpdateService();
  SubscriptionPollingService? _subscriptionPollingService;
  
  // Track if activation notification has been shown
  bool _activationNotificationShown = false;
  
  // Safe references saved in didChangeDependencies
  AuthProvider? _authProvider;
  AdminChangesProvider? _adminChangesProvider;

  /// Load activation notification flag from SharedPreferences
  Future<void> _loadActivationNotificationFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final teacherId = _authProvider?.teacherId;
      if (teacherId != null) {
        _activationNotificationShown = prefs.getBool('activation_notification_shown_$teacherId') ?? false;
        debugPrint('Loaded activation notification flag: $_activationNotificationShown');
      }
    } catch (e) {
      debugPrint('Error loading activation notification flag: $e');
    }
  }

  /// Save activation notification flag to SharedPreferences
  Future<void> _saveActivationNotificationFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final teacherId = _authProvider?.teacherId;
      if (teacherId != null) {
        await prefs.setBool('activation_notification_shown_$teacherId', true);
        debugPrint('Saved activation notification flag for teacher: $teacherId');
      }
    } catch (e) {
      debugPrint('Error saving activation notification flag: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save provider references for safe access in dispose and callbacks
    final previousAuth = _authProvider;
    final previousAdminChanges = _adminChangesProvider;
    
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _adminChangesProvider = Provider.of<AdminChangesProvider>(context, listen: false);
    
    // Add listener only once
    if (previousAuth == null && _authProvider != null) {
      _authProvider!.addListener(_onAuthChanged);
    }
    
    // Add admin changes listener only once
    if (previousAdminChanges == null && _adminChangesProvider != null) {
      _adminChangesProvider!.addListener(_onAdminChangesDetected);
    }
  }

  @override
  void initState() {
    super.initState();
    // Ensure search field doesn't have focus when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      _searchFocusNode.unfocus();
      _loadData();
      
      // Start admin changes polling (covers restrictions and other admin actions)
      if (_authProvider?.teacherId != null && _adminChangesProvider != null) {
        _adminChangesProvider!.startPolling(
          context: context,
          userId: _authProvider!.teacherId!,
          userType: 'teacher',
          pollIntervalSeconds: 5,
          onUserNotFound: () async {
            if (_authProvider != null) {
              await _authProvider!.logout();
            }
            if (mounted && context.mounted) {
              Navigator.of(context).pushReplacementNamed('/login');
            }
          },
        );
      }
      
      // Load activation notification flag from SharedPreferences
      _loadActivationNotificationFlag();
      
      // Start subscription polling to detect plan changes from admin
      if (_authProvider?.userEmail != null) {
        _subscriptionPollingService = SubscriptionPollingService(
          pollingInterval: const Duration(seconds: 5),
          userEmail: _authProvider!.userEmail,
          onStatusChanged: _handleSubscriptionChange,
        );
        _subscriptionPollingService?.startPolling();
      }
    });
    // Refresh data every 30 seconds for real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadData(silent: true);
    });
    // Update time displays every minute
    _timeUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      setState(() {}); // Force rebuild to update time displays
    });
    // Check for updates every 30 minutes in the background
    _updateCheckTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _updateService.performBackgroundUpdateCheck();
    });
    // Perform initial background update check
    _updateService.performBackgroundUpdateCheck();
  }

  void _onAuthChanged() {
    if (!mounted || _authProvider == null) return;
    
    final auth = _authProvider!;
    
    // Schedule navigation for next frame to avoid state changes during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.mounted) return;
      
      if (!auth.isAuthenticated) {
        // User logged out, navigate to account selection
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AccountSelectionScreen()),
          (route) => false,
        );
      } else if (!auth.isActivated) {
        // User account not activated by admin yet
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const PendingActivationScreen()),
          (route) => false,
        );
      } else if (auth.subscriptionExpired) {
        // Navigate to activation screen
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const ActivationScreen()),
        );
      } else if (auth.shouldShowSubscriptionWarning) {
        // Navigate to subscription warning screen
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const SubscriptionWarningScreen()),
        );
      }
    });
  }
  
  /// Handle admin changes detected (restrictions, etc.)
  void _onAdminChangesDetected() {
    if (!mounted || _adminChangesProvider == null) return;
    
    final adminChanges = _adminChangesProvider!;
    
    // Check for restriction changes
    if (adminChanges.isRestricted) {
      // Teacher has been restricted - force logout and show restriction screen
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || !context.mounted) return;
        
        debugPrint('Teacher restricted detected - logging out');
        
        // Logout the teacher
        if (_authProvider != null) {
          await _authProvider!.logout();
        }
        
        // Navigate to restriction screen
        final teacherId = _authProvider?.teacherId;
        final restrictionReason = adminChanges.restrictionReason ?? 'Your account has been restricted';
        
        if (teacherId != null && mounted && context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => RestrictionScreen(
                teacherId: teacherId,
                initialReason: restrictionReason,
              ),
            ),
            (route) => false,
          );
        } else {
          // Fallback to login if no teacher ID
          Navigator.of(context).pushReplacementNamed('/login');
        }
      });
    }
  }
  
  void _handleSubscriptionChange(Map<String, dynamic> status) {
    if (!mounted) return;
    
    // Check if this is a subscription upgrade from free to paid
    final showSubscriptionScreen = status['_showSubscriptionScreen'] as bool? ?? false;
    final accountInactivated = status['_accountInactivated'] as bool? ?? false;
    final accountActivated = status['_accountActivated'] as bool? ?? false;
    final newType = status['subscriptionType'] as String?;
    final isActive = status['isActive'] as bool? ?? true;
    
    // Only navigate if we're on the home screen (not on subscription/activation screens)
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isOnSubscriptionScreen = currentRoute?.contains('subscription') ?? false;
    final isOnActivationScreen = currentRoute?.contains('activation') ?? false;
    
    // Don't navigate if already on subscription or activation screens
    if (isOnSubscriptionScreen || isOnActivationScreen) {
      debugPrint('Already on subscription/activation screen, skipping navigation');
      return;
    }
    
    // Handle account activation (payment approved) - only show once
    if (accountActivated && !_activationNotificationShown) {
      _activationNotificationShown = true;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account has been activated! You can now use all features.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      
      // Save flag to SharedPreferences so it persists across app restarts
      _saveActivationNotificationFlag();
      
      // Update auth provider
      if (_authProvider != null) {
        _authProvider!.checkStatusNow();
      }
      
      return;
    }
    
    // Handle subscription upgrade with account inactivation
    if (showSubscriptionScreen && (newType == 'monthly' || newType == 'yearly')) {
      // Update auth provider to reflect inactivation
      if (_authProvider != null && !isActive) {
        _authProvider!.checkStatusNow();
      }
      
      // Show notification
      String message = 'Your subscription has been updated to ${newType == 'monthly' ? 'Monthly' : 'Yearly'}!';
      if (!isActive) {
        message += ' Please complete your subscription setup and payment.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: !isActive ? Colors.orange : Colors.blue,
          duration: const Duration(seconds: 4),
        ),
      );
      
      // Navigate to subscription screen
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
            (route) => false, // Remove all previous routes
          );
        }
      });
    } else if (accountInactivated && !showSubscriptionScreen) {
      // Account inactivated without subscription change
      // Update auth provider
      if (_authProvider != null) {
        _authProvider!.checkStatusNow();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account has been inactivated. Please contact support.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      
      // Navigate to subscription screen or login
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
            (route) => false,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _refreshTimer?.cancel();
    _timeUpdateTimer?.cancel();
    _updateCheckTimer?.cancel();
    
    // Stop polling services - stop before notifying to avoid framework lock
    _subscriptionPollingService?.stopPolling();
    _subscriptionPollingService?.dispose();
    
    // Stop admin changes polling using saved reference
    // Don't notify listeners during disposal
    if (_adminChangesProvider != null) {
      _adminChangesProvider!.stopPolling();
    }
    
    // Remove auth listener using saved reference
    _authProvider?.removeListener(_onAuthChanged);
    
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
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final teacherId = auth.teacherId;

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

      // Search through students and classes for the current teacher
      final students = await ApiService.getStudents(teacherId: teacherId);
      final classes = await ApiService.getClasses(teacherId: teacherId);

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

    // Check user authentication status before loading data
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated && auth.isLoggedIn) {
      try {
        await auth.checkStatusNow();
        // If account was invalidated, auth.isAuthenticated will be false now
        if (!auth.isAuthenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Your account has been deactivated. Please login again.'),
                backgroundColor: Colors.red,
              ),
            );
            // Navigate to login screen
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('Error checking user status: $e');
        // Continue with operation if status check fails
      }
    }

    try {
      final teacherId = auth.teacherId;

      final stats = await ApiService.getHomeStats(teacherId: teacherId);
      final activities =
          await ApiService.getRecentActivities(teacherId: teacherId);

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

  void _showActivityDetails(BuildContext context, RecentActivity activity) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                _getActivityIcon(activity.type),
                color: _getActivityColor(activity.type),
              ),
              const SizedBox(width: 8),
              Text(
                activity.title,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : null,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color:
                            isDarkMode ? Colors.white.withOpacity(0.9) : null,
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.8)
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTimestamp(activity.timestamp),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.8)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.8),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.category,
                      size: 16,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.8)
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getActivityTypeLabel(activity.type),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.8)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.8),
                          ),
                    ),
                  ],
                ),
                if (activity.type == 'attendance') ...[
                  const SizedBox(height: 16),
                  Text(
                    'This activity represents attendance records that were marked for students.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.75),
                        ),
                  ),
                ],
                if (activity.type == 'student') ...[
                  const SizedBox(height: 16),
                  Text(
                    'A new student has been registered in the system.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.75),
                        ),
                  ),
                ],
                if (activity.type == 'payment') ...[
                  const SizedBox(height: 16),
                  Text(
                    'A payment has been recorded in the system.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.75),
                        ),
                  ),
                ],
                if (activity.type == 'class') ...[
                  const SizedBox(height: 16),
                  Text(
                    'A new class has been created in the system.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.75),
                        ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(timestamp);
    }
  }

  String _getActivityTypeLabel(String type) {
    switch (type) {
      case 'attendance':
        return 'Attendance';
      case 'student':
        return 'Student Management';
      case 'payment':
        return 'Payment';
      case 'class':
        return 'Class Management';
      case 'report':
        return 'Reports';
      default:
        return 'Activity';
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
      case 'class':
        return Icons.class_;
      case 'report':
        return Icons.assessment;
      default:
        return Icons.info;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'attendance':
        return Colors.green;
      case 'student':
        return Colors.blue;
      case 'payment':
        return Colors.purple;
      case 'class':
        return Colors.orange;
      case 'report':
        return Colors.teal;
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        color: Theme.of(context).colorScheme.primary,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(
                  context,
                ).colorScheme.primaryContainer.withOpacity(0.1),
                Theme.of(
                  context,
                ).colorScheme.secondaryContainer.withOpacity(0.1),
                Theme.of(
                  context,
                ).colorScheme.tertiaryContainer.withOpacity(0.05),
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
                                      // Extract first name from full name
                                      String getFirstName(String? fullName) {
                                        if (fullName == null ||
                                            fullName.isEmpty) {
                                          return '';
                                        }
                                        return fullName.split(' ').first;
                                      }

                                      String welcomeMessage;
                                      if (auth.isGuest) {
                                        welcomeMessage = 'Welcome, Guest!';
                                      } else {
                                        final firstName =
                                            getFirstName(auth.userName);
                                        welcomeMessage = firstName.isNotEmpty
                                            ? 'Welcome back, $firstName!'
                                            : 'Welcome Back!';
                                      }

                                      return Text(
                                        welcomeMessage,
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
                                                  .withOpacity(0.7),
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
                                    } else if (value == 'qr_scanner') {
                                      if (context.mounted) {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const QRScannerScreen(),
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
                                      PopupMenuItem<String>(
                                        value: 'qr_scanner',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.qr_code_scanner,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                            const SizedBox(width: 12),
                                            const Text('Web Login QR'),
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
                                ).colorScheme.shadow.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            autofocus: false,
                            onChanged: (value) {
                              _performSearch(value);
                            },
                            decoration: InputDecoration(
                              hintText: 'Search features, students, classes...',
                              prefixIcon: Icon(
                                Icons.search,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.6),
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.6),
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
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
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
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
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
                              ).colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No results found',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.5),
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
                            child: Column(
                              children: List.generate(
                                4,
                                (index) => const Padding(
                                  padding: EdgeInsets.only(bottom: 16.0),
                                  child: DashboardCardSkeleton(),
                                ),
                              ),
                            ),
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
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
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
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
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
                                    activity: activity,
                                    onTap: () =>
                                        _showActivityDetails(context, activity),
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
                                                .withOpacity(0.5),
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
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: trendColor.withOpacity(0.1),
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
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 24,
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
                    ).colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 12,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  final RecentActivity activity;
  final VoidCallback? onTap;

  const _RecentActivityCard({
    required this.activity,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
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
                color: _getActivityColor(activity.type)
                    .withOpacity(isDarkMode ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_getActivityIcon(activity.type),
                  color: _getActivityColor(activity.type), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activity.subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.9)
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.85),
                          fontSize: 12,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _getTimeAgo(activity.timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                    fontSize: 11,
                  ),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'attendance':
        return Icons.check_circle;
      case 'student':
        return Icons.person_add;
      case 'payment':
        return Icons.payment;
      case 'class':
        return Icons.class_;
      case 'report':
        return Icons.assessment;
      default:
        return Icons.info;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'attendance':
        return Colors.green;
      case 'student':
        return Colors.blue;
      case 'payment':
        return Colors.purple;
      case 'class':
        return Colors.orange;
      case 'report':
        return Colors.teal;
      default:
        return Colors.grey;
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
              ).colorScheme.shadow.withOpacity(0.05),
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
                color: color.withOpacity(0.1),
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
                          ).colorScheme.onSurface.withOpacity(0.7),
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
              ).colorScheme.onSurface.withOpacity(0.3),
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
            shadowColor: widget.color.withOpacity(
              widget.isDisabled ? 0.2 : 0.3,
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
                      widget.color.withOpacity(
                        widget.isDisabled ? 0.03 : 0.08,
                      ),
                      widget.color.withOpacity(
                        widget.isDisabled ? 0.01 : 0.04,
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
                        color: widget.color.withOpacity(
                          widget.isDisabled ? 0.08 : 0.15,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.icon,
                        size: 32,
                        color: widget.isDisabled
                            ? widget.color.withOpacity(0.4)
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
                                  ).colorScheme.onSurface.withOpacity(0.4)
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
                                  ).colorScheme.onSurface.withOpacity(0.3)
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
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
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Login Required',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
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
