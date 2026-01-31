import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/students_screen.dart';
import 'screens/classes_screen.dart';
import 'screens/attendance_view_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/subscription_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/students_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/classes_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/reports_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/admin_changes_provider.dart';
import 'services/background_update_service.dart';
import 'services/background_backup_service.dart';
import 'services/notification_service.dart';
import 'services/connectivity_service.dart';
import 'services/realtime_polling_service.dart';
import 'services/api_service.dart';
import 'widgets/offline_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  // Initialize Firebase
  try {
    if (kIsWeb) {
      // For web, Firebase SDK needs to be initialized with config
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyCQ0y34Rn0HK2PAABM9by117eGTK-O0Mfg",
          authDomain: "eduverse-teacher-app.firebaseapp.com",
          projectId: "eduverse-teacher-app",
          storageBucket: "eduverse-teacher-app.firebasestorage.app",
          messagingSenderId: "722907877028",
          appId: "1:722907877028:web:f75189df4ee478dfe42031",
          measurementId: "G-J65GXF20BL",
        ),
      );
    } else {
      // For mobile, initialize with default options
      await Firebase.initializeApp();
    }
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  
  // Initialize notification service with FCM
  await NotificationService().initialize();
  
  // Initialize background update service for periodic checks even when app is closed
  await BackgroundUpdateService.initialize();
  
  // Initialize background backup service for automatic backups every 24 hours
  await BackgroundBackupService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  
  // Global navigator key for notification navigation
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AuthProvider authProvider;
  late final StudentsProvider studentsProvider;
  late final AttendanceProvider attendanceProvider;
  late final ClassesProvider classesProvider;
  late final PaymentProvider paymentProvider;
  late final ReportsProvider reportsProvider;
  late final ThemeProvider themeProvider;
  late final AdminChangesProvider adminChangesProvider;
  late final ConnectivityService connectivityService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize services
    connectivityService = ConnectivityService();

    // Initialize providers
    authProvider = AuthProvider();
    studentsProvider = StudentsProvider();
    attendanceProvider = AttendanceProvider();
    classesProvider = ClassesProvider();
    paymentProvider = PaymentProvider();
    reportsProvider = ReportsProvider();
    themeProvider = ThemeProvider();
    adminChangesProvider = AdminChangesProvider();
  }

  @override
  void dispose() {
    connectivityService.dispose();
    RealTimePollingService().stopAttendancePolling();
    RealTimePollingService().stopStudentsPolling();
    RealTimePollingService().stopClassesPolling();
    RealTimePollingService().stopNotificationsPolling();
    RealTimePollingService().stopPaymentsPolling();
    ApiService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Check user status when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _checkUserStatusOnResume();
    }
  }

  Future<void> _checkUserStatusOnResume() async {
    // Only check if user is logged in
    if (authProvider.isAuthenticated && authProvider.isLoggedIn) {
      try {
        // Resume real-time updates when app comes to foreground
        await authProvider.checkStatusNow();
        adminChangesProvider.resumePolling();
      } catch (e) {
        debugPrint('Error checking user status on resume: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set navigator key for notification service
    NotificationService.setNavigatorKey(MyApp.navigatorKey);
    
    return MultiProvider(
      providers: [
        StreamProvider<bool>(
          create: (_) => connectivityService.connectionStatus,
          initialData: true,
        ),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: studentsProvider),
        ChangeNotifierProvider.value(value: attendanceProvider),
        ChangeNotifierProvider.value(value: classesProvider),
        ChangeNotifierProvider.value(value: paymentProvider),
        ChangeNotifierProvider.value(value: reportsProvider),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: adminChangesProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: MyApp.navigatorKey,
            title: 'Eduverse Teacher Panel',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.lightTheme.copyWith(
              textTheme: GoogleFonts.poppinsTextTheme(),
            ),
            darkTheme: themeProvider.darkTheme.copyWith(
              textTheme: GoogleFonts.poppinsTextTheme(),
            ),
            themeMode: themeProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            builder: (context, child) {
              return Column(
                children: [
                  const OfflineBanner(),
                  Expanded(child: child ?? const SizedBox()),
                ],
              );
            },
            home: const SplashScreen(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
              '/students': (context) => const StudentsScreen(),
              '/classes': (context) => const ClassesScreen(),
              '/attendance-view': (context) => const AttendanceViewScreen(),
              '/reports': (context) => const ReportsScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/subscription': (context) => const SubscriptionScreen(),
            },
          );
        },
      ),
    );
  }
}
