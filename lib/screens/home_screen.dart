import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'students_screen.dart';
import 'attendance_mark_screen.dart';
import 'attendance_view_screen.dart';
import 'classes_screen.dart';
import 'payment_screen.dart';
import 'payment_collection_screen.dart';
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
import '../services/cache_service.dart';
import '../models/home_stats.dart';
import '../widgets/custom_widgets.dart';
import 'activation_screen.dart';
import 'subscription_warning_screen.dart';
import 'subscription_screen.dart';
import 'pending_activation_screen.dart';
import 'quiz_list_screen.dart';
import 'lms_manager_screen.dart';
import 'tutorial_keys.dart';
import 'tutorial_screen.dart';

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

  // Speed-dial FAB
  bool _fabExpanded = false;
  
  // Safe references saved in didChangeDependencies
  AuthProvider? _authProvider;
  AdminChangesProvider? _adminChangesProvider;

  bool get _isTutorialBlockingNavigation => TutorialScreen.isRunning;

  /// Check if the tutorial should run and start it if needed.
  /// Called from initState → postFrameCallback so GlobalKeys are attached.
  Future<void> _maybeStartTutorial() async {
    final done = await hasTutorialBeenCompleted();
    if (!done && mounted) {
      // Wait for the initial data load (which includes auth/subscription checks)
      // to finish before launching the tutorial.  This prevents races where
      // e.g. a subscription-expired navigation fires right after the tutorial
      // starts and hides it behind the new screen.
      int waited = 0;
      while (_isLoading && mounted && waited < 15) {
        await Future.delayed(const Duration(milliseconds: 200));
        waited++;
      }
      if (!mounted) return;

      // Extra settling delay so any auth-triggered route push can complete.
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      // Only start when HomeScreen is still the topmost route.
      // If a subscription / activation screen was pushed on top, skip.
      if (ModalRoute.of(context)?.isCurrent != true) return;

      TutorialScreen.start(context);
    }
  }

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

      // ── Auto-start tutorial on first launch (works in both debug & release) ──
      _maybeStartTutorial();
      
      // Start admin changes polling (covers restrictions and other admin actions)
      // Do not poll for guest users
      if (_authProvider?.teacherId != null && !(_authProvider!.isGuest) && _adminChangesProvider != null) {
        _adminChangesProvider!.startPolling(
          context: context,
          userId: _authProvider!.teacherId!,
          userType: 'teacher',
          pollIntervalSeconds: 5,
          onUserNotFound: () async {
            if (_isTutorialBlockingNavigation) return;
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
    if (_isTutorialBlockingNavigation) return;
    
    final auth = _authProvider!;

    // Don't perform redirects in guest mode
    if (auth.isGuest) return;
    
    // Schedule navigation for next frame to avoid state changes during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.mounted) return;
      if (_isTutorialBlockingNavigation) return;
      
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
    if (_isTutorialBlockingNavigation) return;
    
    final adminChanges = _adminChangesProvider!;
    
    // Check for restriction changes
    if (adminChanges.isRestricted) {
      // Teacher has been restricted - force logout and show restriction screen
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || !context.mounted) return;
        if (_isTutorialBlockingNavigation) return;
        
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
    if (_isTutorialBlockingNavigation) return;
    
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
        if (mounted && !_isTutorialBlockingNavigation) {
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
        if (mounted && !_isTutorialBlockingNavigation) {
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
          'title': 'Collect Payments',
          'subtitle': 'Mark paid/unpaid per class & month',
          'icon': Icons.payments_outlined,
          'color': const Color(0xFF00897B),
          'screen': const PaymentCollectionScreen(),
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
            if (!_isTutorialBlockingNavigation) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            }
          }
          return;
        }
      } catch (e) {
        debugPrint('Error checking user status: $e');
        // Continue with operation if status check fails
      }
    }

    try {
      if (auth.isGuest) {
         // Mock Home Data
         await Future.delayed(const Duration(milliseconds: 500)); // Simulate delay
         final stats = HomeStats(
            totalStudents: 30,
            todayAttendancePercentage: 85.0,
            totalClasses: 2,
            paymentStatusPercentage: 70.0,
            studentsTrend: '+2%',
            attendanceTrend: '-5%',
            classesTrend: '0',
            paymentTrend: '+10%',
         );
         final activities = [
            RecentActivity(
              id: '1',
              type: 'attendance',
              title: 'Attendance Marked',
              subtitle: 'Mathematics 101 - 25 present',
              timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
            ),
             RecentActivity(
              id: '2',
              type: 'payment',
              title: 'Payment Received',
              subtitle: 'John Doe - \$50.00',
              timestamp: DateTime.now().subtract(const Duration(hours: 2)),
            ),
         ];
          setState(() {
            _stats = stats;
            _activities = activities;
            if (!silent) {
              _isLoading = false;
            }
          });
          return;
      }

      final teacherId = auth.teacherId;
      
      // SOLUTION FOR PROBLEM 1: Load cached data first (instant display)
      bool hasCachedData = false;
      if (!silent) {
        try {
          final cachedStatsData = await CacheService.getOfflineCachedData('home_stats_$teacherId');
          final cachedActivitiesData = await CacheService.getOfflineCachedData('recent_activities_$teacherId');
          
          if (cachedStatsData != null && cachedActivitiesData != null) {
            final statsJson = json.decode(cachedStatsData);
            final activitiesJson = json.decode(cachedActivitiesData) as List;
            
            setState(() {
              _stats = HomeStats.fromJson(statsJson);
              _activities = activitiesJson.map((json) => RecentActivity.fromJson(json)).toList();
              _isLoading = false; // Show cached data immediately, stop loading indicator
            });
            
            hasCachedData = true;
            debugPrint('✓ Loaded cached home data instantly');
          }
        } catch (e) {
          debugPrint('Error loading cached data: $e');
        }
      }

      // SOLUTION FOR PROBLEM 2: Fetch fresh data in parallel with shorter timeout
      try {
        // Fetch both API calls in parallel for faster loading
        final results = await Future.wait([
          ApiService.getHomeStats(teacherId: teacherId).timeout(const Duration(seconds: 20)),
          ApiService.getRecentActivities(teacherId: teacherId).timeout(const Duration(seconds: 20)),
        ]);
        
        final stats = results[0] as HomeStats;
        final activities = results[1] as List<RecentActivity>;

        // Save to offline cache for next time (in background, don't wait)
        CacheService.cacheOfflineData('home_stats_$teacherId', json.encode(stats.toJson()));
        CacheService.cacheOfflineData('recent_activities_$teacherId', 
            json.encode(activities.map((a) => a.toJson()).toList()));

        setState(() {
          _stats = stats;
          _activities = activities;
          if (!silent) {
            _isLoading = false;
          }
        });
        
        debugPrint('✓ Loaded fresh home data successfully in ${hasCachedData ? 'background' : 'foreground'}');
      } on TimeoutException {
        // Weak connection - use cached data if we haven't already
        if (silent || _stats == null) {
          final cachedStatsData = await CacheService.getOfflineCachedData('home_stats_$teacherId');
          final cachedActivitiesData = await CacheService.getOfflineCachedData('recent_activities_$teacherId');
          
          if (cachedStatsData != null && cachedActivitiesData != null) {
            try {
              final statsJson = json.decode(cachedStatsData);
              final activitiesJson = json.decode(cachedActivitiesData) as List;
              
              setState(() {
                _stats = HomeStats.fromJson(statsJson);
                _activities = activitiesJson.map((json) => RecentActivity.fromJson(json)).toList();
                if (!silent) {
                  _isLoading = false;
                }
              });
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Showing cached data - connection is slow'),
                    duration: Duration(seconds: 2),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
              debugPrint('⚠️ Using cached data due to timeout');
              return;
            } catch (e) {
              debugPrint('Error loading cached data: $e');
            }
          }
        }
        
        // Only show error if we have no data to display at all
        if (!silent && _stats == null) {
          setState(() {
            _error = 'Connection timeout. Please check your internet.';
            _isLoading = false;
          });
        } else if (!silent) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      // SOLUTION FOR PROBLEM 2: Fallback to cache on any error
      final teacherId = auth.teacherId;
      if (teacherId != null) {
        final cachedStatsData = await CacheService.getOfflineCachedData('home_stats_$teacherId');
        final cachedActivitiesData = await CacheService.getOfflineCachedData('recent_activities_$teacherId');
        
        if (cachedStatsData != null && cachedActivitiesData != null) {
          try {
            final statsJson = json.decode(cachedStatsData);
            final activitiesJson = json.decode(cachedActivitiesData) as List;
            
            setState(() {
              _stats = HomeStats.fromJson(statsJson);
              _activities = activitiesJson.map((json) => RecentActivity.fromJson(json)).toList();
              if (!silent) {
                _isLoading = false;
              }
            });
            
            if (mounted && !silent) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Showing cached data - unable to connect'),
                  duration: Duration(seconds: 2),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            debugPrint('⚠️ Using cached data due to error: $e');
            return;
          } catch (e2) {
            debugPrint('Error loading cached data: $e2');
          }
        }
      }
      
      // Only show error if we have no data to display
      if (!silent && _stats == null) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      } else if (!silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
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

  // ─── Speed-dial FAB ─────────────────────────────────────────────────────────

  Widget _buildSpeedDial(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Mini FAB: Collect Payments
        AnimatedScale(
          scale: _fabExpanded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _fabExpanded ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 180),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Label bubble
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Text(
                      'Collect Payments',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    heroTag: 'fab_collect_payments',
                    onPressed: () {
                      setState(() => _fabExpanded = false);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const PaymentCollectionScreen(),
                        ),
                      );
                    },
                    backgroundColor:
                        Theme.of(context).colorScheme.secondary,
                    foregroundColor:
                        Theme.of(context).colorScheme.onSecondary,
                    child: const Icon(Icons.payments_outlined),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Mini FAB: Mark Attendance
        AnimatedScale(
          scale: _fabExpanded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _fabExpanded ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 140),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Text(
                      'Mark Attendance',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    heroTag: 'fab_mark_attendance',
                    onPressed: () {
                      setState(() => _fabExpanded = false);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AttendanceMarkScreen(),
                        ),
                      );
                    },
                    backgroundColor:
                        Theme.of(context).colorScheme.primary,
                    foregroundColor:
                        Theme.of(context).colorScheme.onPrimary,
                    child: const Icon(Icons.check_circle_outline),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Main FAB (toggle)
        FloatingActionButton(
          key: tutorialKeyFab,
          heroTag: 'fab_main',
          onPressed: () =>
              setState(() => _fabExpanded = !_fabExpanded),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          child: AnimatedRotation(
            turns: _fabExpanded ? 0.125 : 0.0,
            duration: const Duration(milliseconds: 220),
            child: const Icon(Icons.add, size: 28),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (_fabExpanded) {
          setState(() => _fabExpanded = false);
        }
      },
      child: Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0E17) : const Color(0xFFF5F5FA),
      floatingActionButton: _buildSpeedDial(context),
      body: RefreshIndicator(
        onRefresh: _loadData,
        backgroundColor: cs.surface,
        color: cs.primary,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F0E17) : const Color(0xFFF5F5FA),
          ),
          child: SafeArea(
            top: false,
            child: CustomScrollView(
              slivers: [
                // ── Premium Gradient Header ────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1E1A2E), Color(0xFF2D2660), Color(0xFF1E1A2E)],
                            )
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF3730A3), Color(0xFF6D28D9), Color(0xFF7C3AED)],
                              stops: [0.0, 0.55, 1.0],
                            ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 20, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                key: tutorialKeyGreeting,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Consumer<AuthProvider>(
                                    builder: (context, auth, child) {
                                      String getFirstName(String? fullName) {
                                        if (fullName == null || fullName.isEmpty) return '';
                                        return fullName.split(' ').first;
                                      }
                                      String welcomeMessage;
                                      if (auth.isGuest) {
                                        welcomeMessage = 'Hello, Guest!';
                                      } else {
                                        final firstName = getFirstName(auth.userName);
                                        welcomeMessage = firstName.isNotEmpty
                                            ? 'Hello, $firstName!'
                                            : 'Welcome Back!';
                                      }
                                      return Text(
                                        welcomeMessage,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                          height: 1.2,
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
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.75),
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Consumer<AuthProvider>(
                              builder: (context, auth, child) {
                                // Avatar with first letter of name
                                final name = auth.userName ?? 'T';
                                final initial = name.isNotEmpty ? name[0].toUpperCase() : 'T';
                                return PopupMenuButton<String>(
                                  child: Container(
                                    key: tutorialKeyAvatar,
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(alpha: 0.2),
                                      border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.4),
                                          width: 2),
                                    ),
                                    child: Center(
                                      child: Text(
                                        initial,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  onSelected: (value) async {
                                    final authProvider =
                                        Provider.of<AuthProvider>(context, listen: false);
                                    if (value == 'logout') {
                                      await authProvider.logout();
                                      if (context.mounted) {
                                        Navigator.of(context).pushAndRemoveUntil(
                                          MaterialPageRoute(
                                              builder: (context) => const AccountSelectionScreen()),
                                          (route) => false,
                                        );
                                      }
                                    } else if (value == 'login') {
                                      await authProvider.logout();
                                      if (context.mounted) {
                                        Navigator.of(context).pushAndRemoveUntil(
                                          MaterialPageRoute(
                                              builder: (context) => const AccountSelectionScreen()),
                                          (route) => false,
                                        );
                                      }
                                    } else if (value == 'profile') {
                                      if (context.mounted) {
                                        Navigator.of(context).push(MaterialPageRoute(
                                            builder: (context) => const ProfileScreen()));
                                      }
                                    } else if (value == 'settings') {
                                      if (context.mounted) {
                                        Navigator.of(context).push(MaterialPageRoute(
                                            builder: (context) => const SettingsScreen()));
                                      }
                                    } else if (value == 'qr_scanner') {
                                      if (context.mounted) {
                                        Navigator.of(context).push(MaterialPageRoute(
                                            builder: (context) => const QRScannerScreen()));
                                      }
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => [
                                    if (!auth.isGuest) ...[
                                      PopupMenuItem<String>(
                                        value: 'profile',
                                        child: Row(children: [
                                          Icon(Icons.person_outline, color: cs.primary),
                                          const SizedBox(width: 12),
                                          const Text('Profile'),
                                        ]),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'settings',
                                        child: Row(children: [
                                          Icon(Icons.settings_outlined, color: cs.primary),
                                          const SizedBox(width: 12),
                                          const Text('Settings'),
                                        ]),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'qr_scanner',
                                        child: Row(children: [
                                          Icon(Icons.qr_code_scanner, color: cs.primary),
                                          const SizedBox(width: 12),
                                          const Text('Web Login QR'),
                                        ]),
                                      ),
                                      const PopupMenuDivider(),
                                    ],
                                    PopupMenuItem<String>(
                                      value: auth.isGuest ? 'login' : 'logout',
                                      child: Row(children: [
                                        Icon(
                                          auth.isGuest ? Icons.login : Icons.logout,
                                          color: auth.isGuest ? cs.primary : Colors.red[700],
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          auth.isGuest ? 'Login / Register' : 'Logout',
                                          style: auth.isGuest
                                              ? null
                                              : TextStyle(color: Colors.red[700]),
                                        ),
                                      ]),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Search Bar inside header
                        Container(
                          key: tutorialKeySearch,
                          height: 50,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            autofocus: false,
                            onChanged: (value) => _performSearch(value),
                            onTapOutside: (_) => _searchFocusNode.unfocus(),
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search features, students, classes...',
                              hintStyle: TextStyle(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.55)
                                    : const Color(0xFF6B7280),
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : const Color(0xFF4F46E5),
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.7)
                                            : const Color(0xFF6B7280),
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        _performSearch('');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                              ).colorScheme.onSurface.withValues(alpha: 0.3),
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

                        if (_error != null && _stats == null) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
                                const SizedBox(height: 12),
                                Text(
                                  'Could not load data',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Check your internet connection',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                                      ),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: _loadData,
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section Label
                              Row(
                                children: [
                                  Text(
                                    'Overview',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context).colorScheme.onSurface,
                                          letterSpacing: -0.3,
                                        ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    DateFormat('MMM dd').format(DateTime.now()),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.75),
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // Gradient stat cards row
                              SizedBox(
                                key: tutorialKeyStatsRow,
                                height: 120,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  clipBehavior: Clip.none,
                                  children: [
                                    _GradientStatCard(
                                      title: 'Students',
                                      value: '${_stats?.totalStudents ?? 0}',
                                      icon: Icons.people_alt_rounded,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      trend: _stats?.studentsTrend ?? '0',
                                      positive: _stats?.studentsPositive ?? true,
                                    ),
                                    const SizedBox(width: 12),
                                    _GradientStatCard(
                                      title: "Today's",
                                      value: '${(_stats?.todayAttendancePercentage ?? 0).toStringAsFixed(0)}%',
                                      icon: Icons.check_circle_rounded,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF0EA5E9), Color(0xFF10B981)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      trend: _stats?.attendanceTrend ?? '0%',
                                      positive: _stats?.attendancePositive ?? true,
                                    ),
                                    const SizedBox(width: 12),
                                    _GradientStatCard(
                                      title: 'Classes',
                                      value: '${_stats?.totalClasses ?? 0}',
                                      icon: Icons.class_rounded,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF059669), Color(0xFF0EA5E9)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      trend: _stats?.classesTrend ?? '0',
                                      positive: _stats?.classesPositive ?? true,
                                    ),
                                    const SizedBox(width: 12),
                                    _GradientStatCard(
                                      title: 'Payments',
                                      value: '${(_stats?.paymentStatusPercentage ?? 0).toStringAsFixed(0)}%',
                                      icon: Icons.account_balance_wallet_rounded,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      trend: _stats?.paymentTrend ?? '0%',
                                      positive: _stats?.paymentPositive ?? true,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Recent Activity label
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Recent Activity',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context).colorScheme.onSurface,
                                          letterSpacing: -0.3,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (_activities.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF1E1B2E)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white.withValues(alpha: 0.06)
                                          : Colors.grey.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.history_rounded,
                                            size: 40,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.3)),
                                        const SizedBox(height: 8),
                                        Text(
                                          'No recent activities',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.5),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                ...List.generate(_activities.length, (i) {
                                  final activity = _activities[i];
                                  final isLast = i == _activities.length - 1;
                                  final actColor = _getActivityColor(activity.type);
                                  return IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Timeline indicator
                                        SizedBox(
                                          width: 36,
                                          child: Column(
                                            children: [
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: actColor.withValues(alpha: 0.15),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                      color: actColor.withValues(alpha: 0.5),
                                                      width: 2),
                                                ),
                                                child: Icon(
                                                  _getActivityIcon(activity.type),
                                                  size: 15,
                                                  color: actColor,
                                                ),
                                              ),
                                              if (!isLast)
                                                Expanded(
                                                  child: Center(
                                                    child: Container(
                                                      width: 2,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurface
                                                          .withValues(alpha: 0.12),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        // Content
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                                            child: GestureDetector(
                                              child: Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).brightness == Brightness.dark
                                                      ? const Color(0xFF1E1B2E)
                                                      : Colors.white,
                                                  borderRadius: BorderRadius.circular(14),
                                                  boxShadow: Theme.of(context).brightness == Brightness.dark
                                                      ? []
                                                      : [
                                                          BoxShadow(
                                                            color: Colors.black.withValues(alpha: 0.05),
                                                            blurRadius: 10,
                                                            offset: const Offset(0, 2),
                                                          )
                                                        ],
                                                  border: Border.all(
                                                    color: actColor.withValues(alpha: 0.2),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            activity.title,
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.w600,
                                                              fontSize: 14,
                                                              color: Theme.of(context).colorScheme.onSurface,
                                                            ),
                                                          ),
                                                          if (activity.subtitle.isNotEmpty)
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 2),
                                                              child: Text(
                                                                activity.subtitle,
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Theme.of(context)
                                                                      .colorScheme
                                                                      .onSurfaceVariant,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                    Column(
                                                      crossAxisAlignment: CrossAxisAlignment.end,
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(
                                                              horizontal: 8, vertical: 3),
                                                          decoration: BoxDecoration(
                                                            color: actColor.withValues(alpha: 0.12),
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Text(
                                                            _getTimeAgo(activity.timestamp),
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w600,
                                                              color: actColor,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              const SizedBox(height: 24),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                // Feature Cards
                if (!_isSearching)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Row(
                        key: tutorialKeyQuickAccess,
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Quick Access',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  letterSpacing: -0.3,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),

                if (!_isSearching)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.05,
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
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ClassesScreen(),
                                  ),
                                );
                              },
                              isDisabled: false,
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
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const StudentsScreen(),
                                  ),
                                );
                              },
                              isDisabled: false,
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
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AttendanceMarkScreen(),
                                  ),
                                );
                              },
                              isDisabled: false,
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
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const PaymentScreen(),
                                  ),
                                );
                              },
                              isDisabled: false,
                            );
                          },
                        ),
                        Consumer<AuthProvider>(
                          builder: (context, auth, child) {
                            return _FeatureCard(
                              title: 'Collect Payments',
                              subtitle: 'Mark paid/unpaid per class',
                              icon: Icons.payments_outlined,
                              color: const Color(0xFF00897B),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const PaymentCollectionScreen(),
                                  ),
                                );
                              },
                              isDisabled: false,
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
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AttendanceViewScreen(),
                                  ),
                                );
                              },
                              isDisabled: false,
                            );
                          },
                        ),
                        if (auth.hasFeature("reports")) Consumer<AuthProvider>(
                          builder: (context, auth, child) {
                            return _FeatureCard(
                              title: 'Reports',
                              subtitle: auth.isGuest
                                  ? 'View reports'
                                  : 'Generate reports',
                              icon: Icons.assessment_rounded,
                              color: const Color(0xFFD32F2F),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ReportsScreen(),
                                  ),
                                );
                              },
                              isDisabled: false,
                            );
                          },
                        ),
                        if (auth.hasFeature("lms")) Consumer<AuthProvider>(
                          builder: (context, auth, child) {
                            return _FeatureCard(
                              title: 'Quizzes',
                              subtitle: 'Create and Manage Quizzes',
                              icon: Icons.quiz_rounded,
                              color: Colors.pink,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        QuizListScreen(),
                                  ),
                                );
                              },
                              isDisabled: false,
                            );
                          },
                        ),
                        Consumer<AuthProvider>(
                          builder: (context, auth, child) {
                            return _FeatureCard(
                              title: 'LMS Manager',
                              subtitle: 'Manage Study Materials',
                              icon: Icons.library_books_rounded,
                              color: Colors.deepPurple,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LmsManagerScreen(),
                                  ),
                                );
                              },
                              isDisabled: false,
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
      ),
    );
  }
}


class _GradientStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final LinearGradient gradient;
  final String trend;
  final bool positive;

  const _GradientStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.trend,
    this.positive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  trend,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.06))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                          fontSize: 13.5,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: color,
              ),
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
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: widget.isDisabled
                ? null
                : (_) => _animationController.forward(),
            onTapUp: widget.isDisabled
                ? null
                : (_) {
                    _animationController.reverse();
                    widget.onTap();
                  },
            onTapCancel: widget.isDisabled
                ? null
                : () => _animationController.reverse(),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: widget.isDisabled
                    ? []
                    : isDark
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: widget.color.withValues(alpha: 0.12),
                              blurRadius: 18,
                              offset: const Offset(0, 5),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                border: isDark
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                        width: 1,
                      )
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gradient icon badge
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: widget.isDisabled
                            ? null
                            : LinearGradient(
                                colors: [
                                  widget.color,
                                  widget.color.withValues(alpha: 0.7),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: widget.isDisabled
                            ? cs.surfaceContainerHigh
                            : null,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: widget.isDisabled
                            ? []
                            : [
                                BoxShadow(
                                  color:
                                      widget.color.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                      ),
                      child: Icon(
                        widget.icon,
                        size: 26,
                        color: widget.isDisabled
                            ? cs.onSurface.withValues(alpha: 0.3)
                            : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: widget.isDisabled
                                ? cs.onSurface.withValues(alpha: 0.4)
                                : cs.onSurface,
                            fontSize: 14,
                            letterSpacing: -0.2,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: widget.isDisabled
                                    ? cs.onSurface.withValues(alpha: 0.28)
                                    : cs.onSurfaceVariant,
                                fontSize: 11,
                              ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.isDisabled) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Login Required',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
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
