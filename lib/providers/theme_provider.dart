import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
// Premium deep-indigo seed — richer, more professional than the default purple
const _kSeedColor = Color(0xFF4338CA); // Indigo 700
const _kRadius8  = Radius.circular(8);
const _kRadius12 = Radius.circular(12);
const _kRadius16 = Radius.circular(16);
const _kRadius20 = Radius.circular(20);
const _kRadius24 = Radius.circular(24);

BorderRadius get kCardRadius    => const BorderRadius.all(_kRadius16);
BorderRadius get kCardRadiusLg  => const BorderRadius.all(_kRadius20);
BorderRadius get kInputRadius   => const BorderRadius.all(_kRadius12);
BorderRadius get kButtonRadius  => const BorderRadius.all(_kRadius12);
BorderRadius get kChipRadius    => const BorderRadius.all(_kRadius8);
BorderRadius get kDialogRadius  => const BorderRadius.all(_kRadius20);
BorderRadius get kSheetRadius   => const BorderRadius.vertical(top: _kRadius24);

// ─── Gradient Palette ─────────────────────────────────────────────────────────
const kGradientPrimary = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
);
const kGradientOcean = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
);
const kGradientTeal = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF10B981), Color(0xFF059669)],
);
const kGradientAmber = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
);
const kGradientRose = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFEC4899), Color(0xFFEF4444)],
);
const kGradientSky = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0EA5E9), Color(0xFF10B981)],
);

// Hero header gradient (home screen, profile screen)
const kGradientHero = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF3730A3), Color(0xFF6D28D9), Color(0xFF7C3AED)],
  stops: [0.0, 0.55, 1.0],
);

// ─── Shadow Helpers ───────────────────────────────────────────────────────────
List<BoxShadow> kElevatedShadow(Color baseColor) => [
  BoxShadow(
    color: baseColor.withValues(alpha: 0.18),
    blurRadius: 20,
    spreadRadius: -2,
    offset: const Offset(0, 8),
  ),
  BoxShadow(
    color: baseColor.withValues(alpha: 0.10),
    blurRadius: 6,
    spreadRadius: 0,
    offset: const Offset(0, 2),
  ),
];

List<BoxShadow> kSubtleShadow() => [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.06),
    blurRadius: 16,
    spreadRadius: 0,
    offset: const Offset(0, 4),
  ),
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    blurRadius: 4,
    spreadRadius: 0,
    offset: const Offset(0, 1),
  ),
];

List<BoxShadow> kSubtleShadowDark() => [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.30),
    blurRadius: 16,
    spreadRadius: 0,
    offset: const Offset(0, 4),
  ),
];

// ──────────────────────────────────────────────────────────────────────────────

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getBool('dark_mode');
    if (savedTheme != null) {
      _isDarkMode = savedTheme;
    } else {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      _isDarkMode = brightness == Brightness.dark;
      await prefs.setBool('dark_mode', _isDarkMode);
    }
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    _isDarkMode = isDark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', isDark);
  }

  // ─── Light Theme ────────────────────────────────────────────────────────────
  ThemeData get lightTheme {
    final cs = ColorScheme.fromSeed(
      seedColor: _kSeedColor,
      brightness: Brightness.light,
    );
    return _buildTheme(cs);
  }

  // ─── Dark Theme ─────────────────────────────────────────────────────────────
  ThemeData get darkTheme {
    final cs = ColorScheme.fromSeed(
      seedColor: _kSeedColor,
      brightness: Brightness.dark,
    );
    return _buildTheme(cs);
  }

  // ─── Shared Theme Builder ────────────────────────────────────────────────────
  ThemeData _buildTheme(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,

      // ── Scaffold ──────────────────────────────────────────────────────────
      scaffoldBackgroundColor: cs.surface,

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: isDark
            ? Colors.black.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: 0.08),
        backgroundColor: isDark
            ? cs.surfaceContainerLow
            : cs.surface,
        foregroundColor: cs.onSurface,
        centerTitle: false,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: cs.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: cs.onSurface, size: 24),
        actionsIconTheme: IconThemeData(color: cs.onSurface, size: 24),
        toolbarHeight: 60,
      ),

      // ── Card ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: isDark ? 2 : 1,
        shadowColor: isDark
            ? Colors.black.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: 0.07),
        color: isDark ? cs.surfaceContainerHigh : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: kCardRadius,
          side: isDark
              ? BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))
              : BorderSide.none,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        clipBehavior: Clip.antiAlias,
      ),

      // ── Input Decoration ─────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
            : cs.surfaceContainerLowest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: kInputRadius,
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: kInputRadius,
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: kInputRadius,
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: kInputRadius,
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: kInputRadius,
          borderSide: BorderSide(color: cs.error, width: 2),
        ),
        labelStyle: TextStyle(color: cs.onSurfaceVariant),
        hintStyle:
            TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
        prefixIconColor: cs.onSurfaceVariant,
        suffixIconColor: cs.onSurfaceVariant,
        floatingLabelStyle: TextStyle(color: cs.primary),
      ),

      // ── Elevated Button ──────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          disabledBackgroundColor: cs.primary.withValues(alpha: 0.4),
          disabledForegroundColor: cs.onPrimary.withValues(alpha: 0.6),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, 52),
          shape:
              RoundedRectangleBorder(borderRadius: kButtonRadius),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // ── Filled Button ────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, 52),
          shape:
              RoundedRectangleBorder(borderRadius: kButtonRadius),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // ── Outlined Button ──────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.outline),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, 52),
          shape:
              RoundedRectangleBorder(borderRadius: kButtonRadius),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // ── Text Button ──────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── FAB ──────────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),

      // ── Chip ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: cs.secondaryContainer.withValues(alpha: 0.5),
        labelStyle: TextStyle(color: cs.onSecondaryContainer, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: kChipRadius),
        side: BorderSide.none,
        elevation: 0,
      ),

      // ── Dialog ───────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? cs.surfaceContainerHigh : cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: kDialogRadius),
        titleTextStyle: TextStyle(
          color: cs.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: cs.onSurface,
          fontSize: 14,
          height: 1.5,
        ),
      ),

      // ── Bottom Sheet ─────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? cs.surfaceContainerHigh : cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: kSheetRadius),
        showDragHandle: true,
        dragHandleColor: cs.onSurfaceVariant.withValues(alpha: 0.3),
        dragHandleSize: const Size(40, 4),
        modalElevation: 8,
        clipBehavior: Clip.antiAlias,
      ),

      // ── Navigation Bar ───────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: isDark
            ? cs.surfaceContainerHigh
            : cs.surfaceContainerLow,
        indicatorColor: cs.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
                color: cs.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600);
          }
          return TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: cs.onSecondaryContainer, size: 22);
          }
          return IconThemeData(color: cs.onSurfaceVariant, size: 22);
        }),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),

      // ── SnackBar ─────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        elevation: 4,
        backgroundColor: isDark ? cs.inverseSurface : cs.onSurface,
        actionTextColor: cs.inversePrimary,
      ),

      // ── List Tile ────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: TextStyle(
          color: cs.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 13,
        ),
        iconColor: cs.onSurfaceVariant,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ── Divider ──────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),

      // ── Switch ───────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? cs.onPrimary
                : cs.outline),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? cs.primary
                : cs.surfaceContainerHighest),
        trackOutlineColor:
            WidgetStateProperty.all(Colors.transparent),
      ),

      // ── Checkbox ─────────────────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? cs.primary : null),
        checkColor: WidgetStateProperty.all(cs.onPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: cs.outline),
      ),

      // ── Progress Indicator ───────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: cs.primaryContainer,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 6,
      ),

      // ── Tab Bar ──────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: cs.primary,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicatorColor: cs.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        dividerColor: cs.outlineVariant.withValues(alpha: 0.3),
        splashFactory: NoSplash.splashFactory,
      ),

      // ── PopupMenu ────────────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? cs.surfaceContainerHigh : cs.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelTextStyle: WidgetStateProperty.all(
            TextStyle(color: cs.onSurface, fontSize: 14)),
      ),
    );
  }
}
