import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/students_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/classes_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/reports_provider.dart';
import 'providers/theme_provider.dart';
import 'services/background_update_service.dart';
import 'services/background_backup_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  // Initialize background update service for periodic checks even when app is closed
  await BackgroundUpdateService.initialize();
  
  // Initialize background backup service for automatic backups every 24 hours
  await BackgroundBackupService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Only check if user is logged in
    if (authProvider.isAuthenticated && authProvider.isLoggedIn) {
      try {
        await authProvider.checkStatusNow();
      } catch (e) {
        debugPrint('Error checking user status on resume: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StudentsProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => ClassesProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => ReportsProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
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
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
