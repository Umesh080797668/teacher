// ignore_for_file: use_build_context_synchronously
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tutorial_keys.dart';
import 'classes_screen.dart';
import 'students_screen.dart';
import 'attendance_mark_screen.dart';
import 'reports_screen.dart';
import 'payment_collection_screen.dart';
import 'payment_screen.dart';
import 'quiz_list_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'qr_scanner_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SharedPreferences helpers
// ─────────────────────────────────────────────────────────────────────────────
const _kTutorialDoneKey = 'tutorial_completed_v1';

Future<bool> hasTutorialBeenCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kTutorialDoneKey) ?? false;
}

Future<void> markTutorialCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kTutorialDoneKey, true);
}

Future<void> resetTutorial() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kTutorialDoneKey);
}

Future<void> _resetAllTutorials() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kTutorialDoneKey);
  await prefs.remove('all_tutorials_skipped');
  await prefs.remove('tutorial_classes_v1');
  await prefs.remove('tutorial_students_v1');
  await prefs.remove('tutorial_attendance_v1');
  await prefs.remove('tutorial_reports_v1');
  await prefs.remove('tutorial_payments_v1');
  await prefs.remove('tutorial_collect_payments_v1');
  await prefs.remove('tutorial_quiz_v1');
    await prefs.remove('tutorial_cd_v1');
    await prefs.remove('tutorial_sd_v1');
    await prefs.remove('tutorial_set_v1');
    await prefs.remove('tutorial_prof_v1');
    await prefs.remove('tutorial_qr_v1');
}

// ─────────────────────────────────────────────────────────────────────────────
// Coach-mark step definition
// ─────────────────────────────────────────────────────────────────────────────
enum _TutScreen { home, classes, students, attendance, reports, payments, paymentCollect, quizzes, settings, profile, webQr }
enum _SpotShape { circle, roundedRect, none }
enum _TooltipSide { top, bottom, center }

class _CoachStep {
  final GlobalKey? targetKey;   // null → full-screen "intro" card
  final _SpotShape shape;
  final double padding;
  final String title;
  final String body;
  final IconData icon;
  final Color accentColor;
  final _TooltipSide side;
  final bool hasDemo;
  final String? demoLabel;
  final _TutScreen screen;

  const _CoachStep({
    this.targetKey,
    this.shape = _SpotShape.roundedRect,
    this.padding = 12,
    required this.title,
    required this.body,
    required this.icon,
    this.accentColor = const Color(0xFF4F46E5),
    this.side = _TooltipSide.bottom,
    this.hasDemo = false,
    this.demoLabel,
    this.screen = _TutScreen.home,
  });
}

final List<_CoachStep> _steps = [
  // 0 – Welcome splash
  const _CoachStep(
    targetKey: null,
    shape: _SpotShape.none,
    title: 'Welcome!',
    body: 'Let\'s take a quick tour of the app so you know exactly where everything is.',
    icon: Icons.school_rounded,
    accentColor: Color(0xFF4F46E5),
    side: _TooltipSide.center,
    screen: _TutScreen.home,
  ),
  // 1 – Greeting / header
  _CoachStep(
    targetKey: tutorialKeyGreeting,
    shape: _SpotShape.roundedRect,
    padding: 12,
    title: 'Your Dashboard',
    body: 'This is your home. It shows your name, today\'s date, and live classroom stats.',
    icon: Icons.home_rounded,
    accentColor: const Color(0xFF7C3AED),
    side: _TooltipSide.bottom,
    screen: _TutScreen.home,
  ),
  // 2 – Search bar
  _CoachStep(
    targetKey: tutorialKeySearch,
    shape: _SpotShape.roundedRect,
    title: 'Global Search',
    body: 'Type any class, student name or feature here to jump straight to it.',
    icon: Icons.search_rounded,
    accentColor: const Color(0xFF0891B2),
    side: _TooltipSide.bottom,
    hasDemo: true,
    demoLabel: 'Try typing "Classes"',
    screen: _TutScreen.home,
  ),
  // 3 – Stats row
  _CoachStep(
    targetKey: tutorialKeyStatsRow,
    shape: _SpotShape.roundedRect,
    title: 'Overview Cards',
    body: 'At a glance: total students, today\'s attendance %, active classes and payment status.',
    icon: Icons.bar_chart_rounded,
    accentColor: const Color(0xFF059669),
    side: _TooltipSide.bottom,
    screen: _TutScreen.home,
  ),
  // 4 – Quick access grid
  _CoachStep(
    targetKey: tutorialKeyQuickAccess,
    shape: _SpotShape.roundedRect,
    title: 'Quick Access',
    body: 'Tap any tile to open that feature — Classes, Students, Mark Attendance, Payments, Reports and more.',
    icon: Icons.grid_view_rounded,
    accentColor: const Color(0xFFD97706),
    side: _TooltipSide.top,
    screen: _TutScreen.home,
  ),
  // 5 – FAB
  _CoachStep(
    targetKey: tutorialKeyFab,
    shape: _SpotShape.circle,
    title: 'Quick Actions',
    body: 'Tap the + button to quickly mark attendance or collect payments without opening a full screen.',
    icon: Icons.add_circle_rounded,
    accentColor: const Color(0xFFDB2777),
    side: _TooltipSide.top,
    hasDemo: true,
    demoLabel: 'Tap it to see the options',
    screen: _TutScreen.home,
  ),
  // 6 – Avatar / profile menu
  _CoachStep(
    targetKey: tutorialKeyAvatar,
    shape: _SpotShape.circle,
    title: 'Your Profile',
    body: 'Tap your initials to open Settings, view your profile, use the Web Login QR, or log out.',
    icon: Icons.person_rounded,
    accentColor: const Color(0xFF10B981),
    side: _TooltipSide.bottom,
    screen: _TutScreen.home,
  ),

  // ── Classes ──────────────────────────────────────────────────────────────
  // 7 – Classes intro (triggers navigation to ClassesScreen)
  const _CoachStep(
    targetKey: null,
    shape: _SpotShape.none,
    title: 'Classes',
    body: 'Next, let\'s explore your Classes screen — manage all your class schedules here.',
    icon: Icons.class_rounded,
    accentColor: Color(0xFF4F46E5),
    side: _TooltipSide.center,
    screen: _TutScreen.classes,
  ),
  // 8 – Class grid
  _CoachStep(
    targetKey: tutorialKeyClassGrid,
    shape: _SpotShape.roundedRect,
    title: 'Class Cards',
    body: 'Each card is one class. Tap to open details — students, attendance history, and payments. Long-press to delete.',
    icon: Icons.grid_view_rounded,
    accentColor: const Color(0xFF7C3AED),
    side: _TooltipSide.center,
    screen: _TutScreen.classes,
  ),
  // 9 – Add class FAB
  _CoachStep(
    targetKey: tutorialKeyClassFab,
    shape: _SpotShape.circle,
    title: 'Create a Class',
    body: 'Tap here to add a new class. Give it a name — e.g. "Grade 10 Science" or "Piano Batch A".',
    icon: Icons.add_circle_rounded,
    accentColor: const Color(0xFFDB2777),
    side: _TooltipSide.top,
    screen: _TutScreen.classes,
  ),

  // ── Students ─────────────────────────────────────────────────────────────
  // 10 – Students intro (triggers navigation to StudentsScreen)
  const _CoachStep(
    targetKey: null,
    shape: _SpotShape.none,
    title: 'Students',
    body: 'Now let\'s see the Students screen — your complete roster in one place.',
    icon: Icons.people_rounded,
    accentColor: Color(0xFF0891B2),
    side: _TooltipSide.center,
    screen: _TutScreen.students,
  ),
  // 11 – Search students
  _CoachStep(
    targetKey: tutorialKeyStudSearch,
    shape: _SpotShape.roundedRect,
    title: 'Search Students',
    body: 'Type a name, email or student ID to quickly find anyone in your roster.',
    icon: Icons.search_rounded,
    accentColor: const Color(0xFF0891B2),
    side: _TooltipSide.bottom,
    screen: _TutScreen.students,
  ),
  // 12 – Filter students
  _CoachStep(
    targetKey: tutorialKeyStudFilter,
    shape: _SpotShape.roundedRect,
    title: 'Filter by Status',
    body: 'Switch between All, Active and Restricted to focus on the students you need.',
    icon: Icons.filter_list_rounded,
    accentColor: const Color(0xFF7C3AED),
    side: _TooltipSide.bottom,
    screen: _TutScreen.students,
  ),
  // 13 – Student list
  _CoachStep(
    targetKey: tutorialKeyStudList,
    shape: _SpotShape.roundedRect,
    title: 'Student Cards',
    body: 'Tap a card to view full details. Swipe left on a card to restrict access or delete.',
    icon: Icons.person_rounded,
    accentColor: const Color(0xFF059669),
    side: _TooltipSide.center,
    screen: _TutScreen.students,
  ),
  // 14 – Add student FAB
  _CoachStep(
    targetKey: tutorialKeyStudFab,
    shape: _SpotShape.circle,
    title: 'Add a Student',
    body: 'Tap here to enrol a new student — fill in their name, ID, class and contact info.',
    icon: Icons.person_add_rounded,
    accentColor: const Color(0xFFDB2777),
    side: _TooltipSide.top,
    screen: _TutScreen.students,
  ),

  // ── Attendance ───────────────────────────────────────────────────────────
  // 15 – Attendance intro (triggers navigation to AttendanceMarkScreen)
  const _CoachStep(
    targetKey: null,
    shape: _SpotShape.none,
    title: 'Mark Attendance',
    body: 'Time to explore the Mark Attendance screen — record daily presence here.',
    icon: Icons.how_to_reg_rounded,
    accentColor: Color(0xFFD97706),
    side: _TooltipSide.center,
    screen: _TutScreen.attendance,
  ),
  // 16 – Date picker
  _CoachStep(
    targetKey: tutorialKeyAttDate,
    shape: _SpotShape.roundedRect,
    title: 'Select a Date',
    body: 'Choose the date you want to mark attendance for. Defaults to today.',
    icon: Icons.calendar_today_rounded,
    accentColor: const Color(0xFFD97706),
    side: _TooltipSide.bottom,
    screen: _TutScreen.attendance,
  ),
  // 17 – Class selector
  _CoachStep(
    targetKey: tutorialKeyAttClass,
    shape: _SpotShape.roundedRect,
    title: 'Pick a Class',
    body: 'Select which class you\'re marking attendance for today.',
    icon: Icons.class_rounded,
    accentColor: const Color(0xFF7C3AED),
    side: _TooltipSide.bottom,
    screen: _TutScreen.attendance,
  ),
  // 18 – Student attendance list
  _CoachStep(
    targetKey: tutorialKeyAttList,
    shape: _SpotShape.roundedRect,
    title: 'Mark Students',
    body: 'Tap each student to toggle Present / Absent / Late. Changes are saved automatically.',
    icon: Icons.checklist_rounded,
    accentColor: const Color(0xFF059669),
    side: _TooltipSide.center,
    screen: _TutScreen.attendance,
  ),

  // ── Reports ──────────────────────────────────────────────────────────────
  // 19 – Reports intro (triggers navigation to ReportsScreen)
  const _CoachStep(
    targetKey: null,
    shape: _SpotShape.none,
    title: 'Reports',
    body: 'Almost done! Let\'s check out the Reports screen for detailed insights.',
    icon: Icons.assessment_rounded,
    accentColor: Color(0xFF059669),
    side: _TooltipSide.center,
    screen: _TutScreen.reports,
  ),
  // 20 – Report tabs
  _CoachStep(
    targetKey: tutorialKeyRepTabBar,
    shape: _SpotShape.roundedRect,
    title: 'Report Tabs',
    body: 'Switch between Attendance and Payment reports using these tabs.',
    icon: Icons.tab_rounded,
    accentColor: const Color(0xFF0891B2),
    side: _TooltipSide.bottom,
    screen: _TutScreen.reports,
  ),
  // 21 – PDF export
  _CoachStep(
    targetKey: tutorialKeyRepPdf,
    shape: _SpotShape.roundedRect,
    title: 'Export to PDF',
    body: 'Generate a professional PDF report and share it with parents or management.',
    icon: Icons.picture_as_pdf_rounded,
    accentColor: const Color(0xFFDB2777),
    side: _TooltipSide.bottom,
    screen: _TutScreen.reports,
  ),

  // ── Payments ─────────────────────────────────────────────────────────────
  const _CoachStep(
    targetKey: null,
    shape: _SpotShape.none,
    title: 'Payments',
    body: 'Keep track of student fees and your revenue on the Payments screen.',
    icon: Icons.payments_rounded,
    accentColor: Color(0xFF4F46E5),
    side: _TooltipSide.center,
    screen: _TutScreen.payments,
  ),
  _CoachStep(
    targetKey: tutorialKeyPayRemind,
    shape: _SpotShape.circle,
    title: 'Send Reminders',
    body: 'Tap here to send payment reminders via WhatsApp.',
    icon: Icons.notifications_active,
    accentColor: const Color(0xFF7C3AED),
    side: _TooltipSide.bottom,
    screen: _TutScreen.payments,
  ),

  // ── Collect Payments ─────────────────────────────────────────────────────
  const _CoachStep(
    targetKey: null,
    shape: _SpotShape.none,
    title: 'Collect Payments',
    body: 'Quickly record physical payments in class.',
    icon: Icons.point_of_sale_rounded,
    accentColor: Color(0xFF0891B2),
    side: _TooltipSide.center,
    screen: _TutScreen.paymentCollect,
  ),

  // ── Quizzes ──────────────────────────────────────────────────────────────
  const _CoachStep(
    targetKey: null,
    shape: _SpotShape.none,
    title: 'Quizzes',
    body: 'View and manage student quizzes and their results.',
    icon: Icons.quiz_rounded,
    accentColor: Color(0xFFD97706),
    side: _TooltipSide.center,
    screen: _TutScreen.quizzes,
  ),

  // ── Settings ─────────────────────────────────────────────────────────────
  const _CoachStep(
    targetKey: null,
    shape: _SpotShape.none,
    title: 'Settings',
    body: 'Configure your app experience, including dark mode and app lock.',
    icon: Icons.settings_rounded,
    accentColor: Color(0xFF7C3AED),
    side: _TooltipSide.center,
    screen: _TutScreen.settings,
  ),

  // ── Profile ──────────────────────────────────────────────────────────────
  const _CoachStep(
    targetKey: null,
    shape: _SpotShape.none,
    title: 'Profile',
    body: 'Keep your personal details up to date on the profile page.',
    icon: Icons.person_rounded,
    accentColor: Color(0xFF059669),
    side: _TooltipSide.center,
    screen: _TutScreen.profile,
  ),

  // ── Web QR Login ─────────────────────────────────────────────────────────
  const _CoachStep(
    targetKey: null,
    shape: _SpotShape.none,
    title: 'Web Login',
    body: 'Scan a QR code to instantly sync and log into the web dashboard.',
    icon: Icons.qr_code_scanner_rounded,
    accentColor: Color(0xFFDB2777),
    side: _TooltipSide.center,
    screen: _TutScreen.webQr,
  ),

  // 22 – All done
  const _CoachStep(
    targetKey: null,
    shape: _SpotShape.none,
    title: "You're all set! 🎉",
    body: 'You\'ve explored everything! Start by creating a class and adding your students. Good luck!',
    icon: Icons.rocket_launch_rounded,
    accentColor: Color(0xFF4F46E5),
    side: _TooltipSide.center,
    screen: _TutScreen.home,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// ValueNotifier that drives the always-on-top tutorial layer in main.dart
// ─────────────────────────────────────────────────────────────────────────────
final ValueNotifier<NavigatorState?> _tutorialNavigator = ValueNotifier(null);

// ─────────────────────────────────────────────────────────────────────────────
// TutorialScreen — public API
// ─────────────────────────────────────────────────────────────────────────────
class TutorialScreen {
  /// Whether the full-app tutorial is currently running.
  /// Per-screen tutorials should check this before showing.
  static bool isRunning = false;

  /// Start the tutorial from a BuildContext (e.g. HomeScreen.initState).
  static void start(BuildContext context, {bool isReplay = false}) async {
    if (isReplay) await _resetAllTutorials();
    if (!context.mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    _launch(nav);
  }

  /// Start the tutorial when you have already captured the navigator
  /// (use this from Settings, capturing BEFORE popUntil).
  /// The [overlay] parameter is kept for backward-compatibility but is
  /// no longer used — the tutorial now lives in MaterialApp's builder Stack.
  static void startWithOverlay(
    OverlayState overlay, // kept for back-compat; ignored
    NavigatorState navigator, {
    bool isReplay = false,
  }) async {
    if (isReplay) await _resetAllTutorials();
    _launch(navigator);
  }

  /// Backward-compat alias used by older call sites.
  static Future<void> pushTransparent(BuildContext context,
      {bool isReplay = false}) async {
    start(context, isReplay: isReplay);
  }

  /// Programmatically stop / cancel the tutorial.
  static void stop() => _cleanup();

  /// Returns the always-on-top overlay widget to embed **once** inside
  /// [MaterialApp.builder] (in a [Stack] above the navigator child).
  /// It automatically shows / hides itself via [_tutorialNavigator].
  static Widget buildOverlayLayer() {
    return ValueListenableBuilder<NavigatorState?>(
      valueListenable: _tutorialNavigator,
      builder: (_, nav, __) {
        if (nav == null) return const SizedBox.shrink();
        return _TutOverlay(navigator: nav, onDone: _cleanup);
      },
    );
  }

  static void _launch(NavigatorState navigator) {
    isRunning = true;
    _tutorialNavigator.value = navigator;
  }

  static void _cleanup() {
    _tutorialNavigator.value = null;
    isRunning = false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TutOverlay — the actual animated overlay widget
// ─────────────────────────────────────────────────────────────────────────────
class _TutOverlay extends StatefulWidget {
  final NavigatorState navigator;
  final VoidCallback onDone;

  const _TutOverlay({required this.navigator, required this.onDone});

  @override
  State<_TutOverlay> createState() => _TutOverlayState();
}

class _TutOverlayState extends State<_TutOverlay> with TickerProviderStateMixin {
  int _step = 0;
  int _screensPushed = 0;

  // Spotlight animation
  late AnimationController _spotCtrl;
  late Animation<double>    _spotAnim;

  // Content card animation
  late AnimationController _cardCtrl;
  late Animation<double>    _cardFade;
  late Animation<Offset>    _cardSlide;

  // Pulse ring
  late AnimationController _pulseCtrl;
  late Animation<double>    _pulseAnim;

  bool _demoActive = false;
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();

    _spotCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _spotAnim = CurvedAnimation(parent: _spotCtrl, curve: Curves.easeOutCubic);

    _cardCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _cardFade  = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut);
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    WidgetsBinding.instance.addPostFrameCallback((_) => _animateToStep(0, first: true));
  }

  @override
  void dispose() {
    _spotCtrl.dispose();
    _cardCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Which screen does a given step index live on? ──────────────────────
  _TutScreen _screenOf(int step) => _steps[step].screen;

  // ── Navigate to a screen during tutorial ──────────────────────────────
  Future<void> _navigateTo(_TutScreen screen) async {
    Widget page;
    switch (screen) {
      case _TutScreen.classes:
        page = const ClassesScreen();
        break;
      case _TutScreen.students:
        page = const StudentsScreen();
        break;
      case _TutScreen.attendance:
        page = const AttendanceMarkScreen();
        break;
      case _TutScreen.reports:
        page = const ReportsScreen();
        break;
      case _TutScreen.payments:
        page = const PaymentScreen();
        break;
      case _TutScreen.paymentCollect:
        page = const PaymentCollectionScreen();
        break;
      case _TutScreen.quizzes:
        page = const QuizListScreen();
        break;
      case _TutScreen.settings:
        page = const SettingsScreen();
        break;
      case _TutScreen.profile:
        page = const ProfileScreen();
        break;
      case _TutScreen.webQr:
        page = const QRScannerScreen();
        break;
      case _TutScreen.home:
        return; // should not navigate "to" home; handled via popUntil
    }
    _screensPushed++;
    widget.navigator.push(MaterialPageRoute(builder: (_) => page));
    // Give the new screen time to build and attach its GlobalKeys
    await Future.delayed(const Duration(milliseconds: 650));
  }

  // ── Measure a GlobalKey's widget rect on screen ───────────────────────
  Rect? _measureKey(GlobalKey? key) {
    if (key == null) return null;
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  // ── Animate to a specific step (with optional cross-screen nav) ────────
  Future<void> _animateToStep(int step, {bool first = false}) async {
    if (!mounted) return;
    _demoActive = false;

    // Cross-screen navigation when moving forward
    if (!first && step > 0) {
      final prevScreen = _screenOf(step - 1);
      final nextScreen = _screenOf(step);
      if (prevScreen != nextScreen && nextScreen != _TutScreen.home) {
        // Briefly fade out current card while we navigate
        _cardCtrl.reverse();
        await _navigateTo(nextScreen);
      }
    }

    if (!mounted) return;

    final rect = _measureKey(_steps[step].targetKey);

    if (!first) await _spotCtrl.reverse();
    if (!mounted) return;

    setState(() {
      _step = step;
      _targetRect = rect;
    });
    _cardCtrl.reset();
    _spotCtrl.forward(from: 0);
    _cardCtrl.forward();
  }

  // ── Pop all screens pushed during the tutorial ─────────────────────────
  Future<void> _popTutorialScreens() async {
    if (_screensPushed > 0) {
      widget.navigator.popUntil((route) => route.isFirst);
      _screensPushed = 0;
      await Future.delayed(const Duration(milliseconds: 350));
    }
  }

  void _next() {
    if (_step < _steps.length - 1) {
      _animateToStep(_step + 1);
    } else {
      _finish();
    }
  }

  void _prev() {
    if (_step <= 0) return;

    final prevStep = _step - 1;
    final curScreen = _screenOf(_step);
    final prevScreen = _screenOf(prevStep);

    if (curScreen != prevScreen && _screensPushed > 0) {
      // Going back across a screen boundary — pop the current screen
      widget.navigator.pop();
      _screensPushed--;
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _animateToStepSameScreen(prevStep);
      });
    } else {
      _animateToStepSameScreen(prevStep);
    }
  }

  /// Animate to step WITHOUT cross-screen navigation (used for prev).
  void _animateToStepSameScreen(int step) async {
    if (!mounted) return;
    _demoActive = false;
    final rect = _measureKey(_steps[step].targetKey);
    await _spotCtrl.reverse();
    if (!mounted) return;
    setState(() {
      _step = step;
      _targetRect = rect;
    });
    _cardCtrl.reset();
    _spotCtrl.forward(from: 0);
    _cardCtrl.forward();
  }

  Future<void> _finish() async {
    await _popTutorialScreens();
    await markTutorialCompleted();
    widget.onDone();
  }

  Future<void> _skip() async {
    await _popTutorialScreens();
    await markTutorialCompleted();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("all_tutorials_skipped", true);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final step = _steps[_step];
    final isFirst = _step == 0;
    final isLast  = _step == _steps.length - 1;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ── Transparent tap-outside-to-advance layer ────────────
          Positioned.fill(
            child: GestureDetector(
              onTap: _next,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),

          // ── Dimmed overlay with spotlight cutout ──────────────────────
          AnimatedBuilder(
            animation: _spotAnim,
            builder: (_, __) {
              return CustomPaint(
                size: size,
                painter: _SpotlightPainter(
                  targetRect: _targetRect,
                  shape: step.shape,
                  padding: step.padding,
                  progress: _spotAnim.value,
                  isDark: isDark,
                ),
              );
            },
          ),

          // ── Pulse ring ────────────────────────────────────────────────
          if (_targetRect != null && step.shape != _SpotShape.none)
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) {
                final r = _targetRect!;
                final pad = step.padding + 4 + _pulseAnim.value * 20;
                final opacity = (1 - _pulseAnim.value) * 0.6;
                final rect = Rect.fromLTRB(
                  r.left - pad, r.top - pad, r.right + pad, r.bottom + pad);
                return CustomPaint(
                  size: size,
                  painter: _PulseRingPainter(
                    rect: rect,
                    shape: step.shape,
                    color: step.accentColor.withValues(alpha: opacity),
                  ),
                );
              },
            ),

          // ── Tooltip card ──────────────────────────────────────────────
          FadeTransition(
            opacity: _cardFade,
            child: SlideTransition(
              position: _cardSlide,
              child: _TooltipCard(
                step: step,
                stepIndex: _step,
                totalSteps: _steps.length,
                targetRect: _targetRect,
                screenSize: size,
                isDark: isDark,
                isFirst: isFirst,
                isLast: isLast,
                demoActive: _demoActive,
                onNext: _next,
                onPrev: _prev,
                onSkip: _skip,
                onDemoToggle: () => setState(() => _demoActive = !_demoActive),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// Spotlight painter — paints a semi-transparent overlay with a clear cutout
// ─────────────────────────────────────────────────────────────────────────────
class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;
  final _SpotShape shape;
  final double padding;
  final double progress;
  final bool isDark;

  const _SpotlightPainter({
    required this.targetRect,
    required this.shape,
    required this.padding,
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlayColor = isDark
        ? Colors.black.withValues(alpha: 0.78 * progress)
        : Colors.black.withValues(alpha: 0.62 * progress);

    if (targetRect == null || shape == _SpotShape.none) {
      canvas.drawRect(Offset.zero & size, Paint()..color = overlayColor);
      return;
    }

    final r = targetRect!;
    final pad = padding * progress;
    final spotRect = Rect.fromLTRB(
      r.left - pad, r.top - pad, r.right + pad, r.bottom + pad);

    final path = Path()..addRect(Offset.zero & size);

    if (shape == _SpotShape.circle) {
      final center = spotRect.center;
      final radius = spotRect.shortestSide / 2;
      path.addOval(Rect.fromCircle(center: center, radius: radius));
    } else {
      final radius = math.min(20.0 * progress, 20.0);
      path.addRRect(RRect.fromRectAndRadius(spotRect, Radius.circular(radius)));
    }

    canvas.drawPath(
      path..fillType = PathFillType.evenOdd,
      Paint()..color = overlayColor,
    );

    // Bright border around spotlight
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * progress
      ..color = Colors.white.withValues(alpha: 0.5 * progress);

    if (shape == _SpotShape.circle) {
      canvas.drawOval(spotRect, borderPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(spotRect, Radius.circular(20 * progress)),
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.progress != progress ||
      old.targetRect != targetRect ||
      old.shape != shape;
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulse ring painter
// ─────────────────────────────────────────────────────────────────────────────
class _PulseRingPainter extends CustomPainter {
  final Rect rect;
  final _SpotShape shape;
  final Color color;

  const _PulseRingPainter({
    required this.rect,
    required this.shape,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color;

    if (shape == _SpotShape.circle) {
      canvas.drawOval(rect, paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(24)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PulseRingPainter old) =>
      old.rect != rect || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tooltip / coach-mark card
// ─────────────────────────────────────────────────────────────────────────────
class _TooltipCard extends StatefulWidget {
  final _CoachStep step;
  final int stepIndex;
  final int totalSteps;
  final Rect? targetRect;
  final Size screenSize;
  final bool isDark;
  final bool isFirst;
  final bool isLast;
  final bool demoActive;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onSkip;
  final VoidCallback onDemoToggle;

  const _TooltipCard({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.targetRect,
    required this.screenSize,
    required this.isDark,
    required this.isFirst,
    required this.isLast,
    required this.demoActive,
    required this.onNext,
    required this.onPrev,
    required this.onSkip,
    required this.onDemoToggle,
  });

  @override
  State<_TooltipCard> createState() => _TooltipCardState();
}

class _TooltipCardState extends State<_TooltipCard>
    with SingleTickerProviderStateMixin {
  // Demo input controller
  final _demoCtrl = TextEditingController();
  bool _demoSubmitted = false;

  // Demo attendance state
  final List<Map<String, dynamic>> _attStudents = [
    {'name': 'Alice', 'status': null},
    {'name': 'Bob', 'status': null},
    {'name': 'Chami', 'status': null},
  ];

  @override
  void didUpdateWidget(_TooltipCard old) {
    super.didUpdateWidget(old);
    if (old.stepIndex != widget.stepIndex) {
      _demoCtrl.clear();
      _demoSubmitted = false;
      for (var s in _attStudents) { s['status'] = null; }
    }
  }

  @override
  void dispose() {
    _demoCtrl.dispose();
    super.dispose();
  }

  // ── Position the card above/below/center the target ─────────────────────
  Alignment _cardAlignment() {
    if (widget.step.side == _TooltipSide.center) return Alignment.center;
    if (widget.targetRect == null) return Alignment.bottomCenter;

    // Fallback if target is too large to fit the card above or below
    final r = widget.targetRect!;
    final spaceAbove = r.top;
    final spaceBelow = widget.screenSize.height - r.bottom;
    if (spaceAbove < 250 && spaceBelow < 250) {
      return Alignment.center;
    }

    final mid = widget.targetRect!.center.dy;
    final screen = widget.screenSize.height;

    if (widget.step.side == _TooltipSide.bottom) {
      return mid < screen * 0.5 ? Alignment.bottomCenter : Alignment.topCenter;
    }
    return mid > screen * 0.5 ? Alignment.topCenter : Alignment.bottomCenter;
  }

  EdgeInsets _cardPadding() {
    if (widget.targetRect == null || widget.step.shape == _SpotShape.none) {
      return const EdgeInsets.symmetric(horizontal: 24);
    }

    // Fallback if target is too large
    final r = widget.targetRect!;
    final spaceAbove = r.top;
    final spaceBelow = widget.screenSize.height - r.bottom;
    if (widget.step.side == _TooltipSide.center || (spaceAbove < 250 && spaceBelow < 250)) {
      return const EdgeInsets.symmetric(horizontal: 24);
    }

    final pad = widget.step.padding + 16.0;
    final screen = widget.screenSize;

    if (_cardAlignment() == Alignment.bottomCenter) {
      return EdgeInsets.fromLTRB(24, r.bottom + pad, 24, 0);
    } else if (_cardAlignment() == Alignment.topCenter) {
      return EdgeInsets.fromLTRB(24, 0, 24, screen.height - r.top + pad);
    }
    return const EdgeInsets.symmetric(horizontal: 24);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.step.accentColor;
    final align  = _cardAlignment();
    final cardPad = _cardPadding();

    return SafeArea(
      child: Align(
        alignment: align,
        child: Padding(
          padding: cardPad,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? const Color(0xFF1E1B2E).withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.25),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header row ──────────────────────────────────────
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [accent, accent.withValues(alpha: 0.6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(widget.step.icon, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.step.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: widget.isDark ? Colors.white : const Color(0xFF1E1B2E),
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Step counter dots
                              Row(
                                children: List.generate(widget.totalSteps, (i) {
                                  final active = i == widget.stepIndex;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 280),
                                    margin: const EdgeInsets.only(right: 3),
                                    width: active ? 16 : 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(3),
                                      color: active ? accent : accent.withValues(alpha: 0.25),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                        // Skip button
                        if (!widget.isLast)
                          TextButton(
                            onPressed: widget.onSkip,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Body text ───────────────────────────────────────
                    Text(
                      widget.step.body,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.55,
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.8)
                            : const Color(0xFF374151),
                      ),
                    ),

                    // ── Demo section ────────────────────────────────────
                    if (widget.step.hasDemo && widget.demoActive)
                      _buildDemo(accent),

                    const SizedBox(height: 18),

                    // ── Action row ──────────────────────────────────────
                    Row(
                      children: [
                        // Try-it chip
                        if (widget.step.hasDemo && !widget.demoActive) ...[
                          GestureDetector(
                            onTap: widget.onDemoToggle,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: accent.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_circle_fill_rounded, color: accent, size: 15),
                                  const SizedBox(width: 5),
                                  Text(
                                    widget.step.demoLabel ?? 'Try it',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: accent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                        ] else ...[
                          // Back button
                          if (!widget.isFirst)
                            IconButton(
                              onPressed: widget.onPrev,
                              style: IconButton.styleFrom(
                                backgroundColor: accent.withValues(alpha: 0.1),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.all(10),
                                minimumSize: const Size(42, 42),
                              ),
                              icon: Icon(Icons.arrow_back_rounded, color: accent, size: 20),
                            ),
                          const Spacer(),
                        ],

                        // Next / Finish button
                        GestureDetector(
                          onTap: widget.onNext,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [accent, accent.withValues(alpha: 0.75)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.4),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.isLast ? 'Get Started' : 'Next',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  widget.isLast
                                      ? Icons.rocket_launch_rounded
                                      : Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 17,
                                ),
                              ],
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
      ),
    );
  }

  Widget _buildDemo(Color accent) {
    // Step 2 = search demo  |  step 5 = FAB demo (attendance preview)
    final isSearchDemo = widget.stepIndex == 2;
    final isDark = widget.isDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      '⚡ Demo  —  nothing is saved',
                      style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (isSearchDemo) ...[
                // ── Search demo ──────────────────────────────────────
                if (!_demoSubmitted) ...[
                  TextField(
                    controller: _demoCtrl,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1E1B2E),
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type "Classes" or "Students"…',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(Icons.search_rounded, color: accent, size: 20),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2A2740) : const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (_) => setState(() => _demoSubmitted = true),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() => _demoSubmitted = true),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.7)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text('Search',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                  ),
                ] else ...[
                  // Fake results
                  _fakeResult(Icons.class_rounded, 'Classes', 'Manage class schedules', const Color(0xFF00796B), isDark),
                  const SizedBox(height: 6),
                  _fakeResult(Icons.people_rounded, 'Students', 'Manage student records', const Color(0xFF6750A4), isDark),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() { _demoSubmitted = false; _demoCtrl.clear(); }),
                    child: Text('← Try again', style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ] else ...[
                // ── FAB / attendance demo ────────────────────────────
                Text(
                  'Tap P / A / L to mark each student:',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ..._attStudents.asMap().entries.map((e) {
                  final i = e.key;
                  final s = e.value;
                  final status = s['status'] as String?;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: accent.withValues(alpha: 0.2),
                          child: Text(
                            s['name'][0],
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s['name'],
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isDark ? Colors.white : const Color(0xFF1E1B2E),
                            ),
                          ),
                        ),
                        // P / A / L buttons
                        _miniStatusBtn('P', Colors.green, status == 'present',
                            () => setState(() => _attStudents[i]['status'] = 'present')),
                        const SizedBox(width: 4),
                        _miniStatusBtn('A', Colors.red, status == 'absent',
                            () => setState(() => _attStudents[i]['status'] = 'absent')),
                        const SizedBox(width: 4),
                        _miniStatusBtn('L', Colors.orange, status == 'late',
                            () => setState(() => _attStudents[i]['status'] = 'late')),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _fakeResult(IconData icon, String title, String sub, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2740) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12,
                  color: isDark ? Colors.white : const Color(0xFF1E1B2E))),
              Text(sub, style: TextStyle(fontSize: 10,
                  color: isDark ? Colors.white54 : const Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStatusBtn(String label, Color color, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 30,
        height: 26,
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.35),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}
