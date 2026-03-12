import 'package:flutter/material.dart';

/// App-wide color constants for consistent theming
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF6750A4);
  static const Color primaryLight = Color(0xFFE8DEF8);
  static const Color primaryDark = Color(0xFF4F378B);

  // Status Colors
  static const Color success = Color(0xFF00C853);
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFFF6F00);
  static const Color info = Color(0xFF00BFA5);

  // Attendance Status Colors
  static const Color present = Color(0xFF4CAF50);
  static const Color absent = Color(0xFFE53935);
  static const Color late = Color(0xFFFF9800);

  // Neutral Colors
  static const Color background = Color(0xFFFFFBFE);
  static const Color surface = Color(0xFFFFFBFE);
  static const Color outline = Color(0xFF79747E);

  // Gradient Colors
  static List<Color> get primaryGradient => [
    primary.withValues(alpha: 0.3),
    info.withValues(alpha: 0.3),
  ];

  static List<Color> get cardGradient => [
    primary.withValues(alpha: 0.1),
    primary.withValues(alpha: 0.05),
  ];
}

/// App-wide text styles
class AppTextStyles {
  static const String fontFamily = 'Poppins';

  static const TextStyle headline1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    fontFamily: fontFamily,
  );

  static const TextStyle headline2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    fontFamily: fontFamily,
  );

  static const TextStyle subtitle1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
  );

  static const TextStyle body1 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    fontFamily: fontFamily,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    fontFamily: fontFamily,
  );
}

/// App-wide spacing constants
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// App-wide border radius constants
class AppBorderRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double round = 100.0;
}

/// App-wide elevation constants
class AppElevation {
  static const double none = 0.0;
  static const double sm = 2.0;
  static const double md = 4.0;
  static const double lg = 8.0;
  static const double xl = 16.0;
}
