import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CustomButton — Primary action button
// ─────────────────────────────────────────────────────────────────────────────
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isLoading;
  final bool isFullWidth;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.isLoading = false,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool useGradient = backgroundColor == null;
    final bg = backgroundColor ?? cs.primary;
    final fg = textColor ?? Colors.white;

    Widget inner;
    if (isLoading) {
      inner = SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
      );
    } else if (icon != null) {
      inner = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      );
    } else {
      inner = Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      );
    }

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: 52,
      child: GestureDetector(
        onTap: (isLoading) ? null : onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            gradient: useGradient
                ? const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: useGradient ? null : bg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isLoading
                ? []
                : [
                    BoxShadow(
                      color: (useGradient
                              ? const Color(0xFF4F46E5)
                              : bg)
                          .withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: inner,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  StatusBadge — Attendance / payment status chip
// ─────────────────────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String status;
  final Color? color;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.status,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? _getStatusColor(status);
    final badgeIcon = icon ?? _getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 14, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return const Color(0xFF22C55E);
      case 'absent':
        return const Color(0xFFEF4444);
      case 'late':
        return const Color(0xFFF97316);
      case 'paid':
        return const Color(0xFF22C55E);
      case 'unpaid':
        return const Color(0xFFEF4444);
      case 'active':
        return const Color(0xFF22C55E);
      case 'inactive':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Icons.check_circle_rounded;
      case 'absent':
        return Icons.cancel_rounded;
      case 'late':
        return Icons.schedule_rounded;
      case 'paid':
        return Icons.check_circle_rounded;
      case 'unpaid':
        return Icons.pending_rounded;
      case 'active':
        return Icons.radio_button_checked_rounded;
      case 'inactive':
        return Icons.radio_button_unchecked_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  InfoCard — Metric / stat card
// ─────────────────────────────────────────────────────────────────────────────
class InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const InfoCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
          border: isDark
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.06))
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EmptyState — No-data placeholder
// ─────────────────────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary,
                    cs.primary.withValues(alpha: 0.65),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, size: 44, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 28),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LoadingOverlay — Dim + spinner over a child widget
// ─────────────────────────────────────────────────────────────────────────────
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: cs.scrim.withValues(alpha: 0.35),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.15),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: CircularProgressIndicator(color: cs.primary),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CustomAppBar — Delegates to theme; kept for backward compat
// ─────────────────────────────────────────────────────────────────────────────
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final dynamic title; // Can be String or Widget
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final bool automaticallyImplyLeading;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.bottom,
    this.backgroundColor,
    this.automaticallyImplyLeading = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Widget titleWidget;
    if (title is Widget) {
      titleWidget = title as Widget;
    } else {
      titleWidget = Text(
        title.toString(),
        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
      );
    }

    return AppBar(
      title: titleWidget,
      centerTitle: true,
      automaticallyImplyLeading: automaticallyImplyLeading,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: actions,
      leading: leading,
      bottom: bottom,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: [Color(0xFF1E1A2E), Color(0xFF2D2660)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFF3730A3), Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));
}

// ─────────────────────────────────────────────────────────────────────────────
//  _shimmerWidget — Helper for skeleton shimmer blocks
// ─────────────────────────────────────────────────────────────────────────────
Widget _shimmer(
  BuildContext context,
  Widget child,
) {
  final cs = Theme.of(context).colorScheme;
  return Shimmer.fromColors(
    baseColor: cs.surfaceContainerHighest,
    highlightColor: cs.surfaceContainerLow,
    child: child,
  );
}

Widget _shimmerBox(
  BuildContext context, {
  required double width,
  required double height,
  double radius = 8,
}) {
  return _shimmer(
    context,
    Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
  );
}

Widget _shimmerCircle(BuildContext context, double radius) {
  return _shimmer(
    context,
    Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  StudentCardSkeleton
// ─────────────────────────────────────────────────────────────────────────────
class StudentCardSkeleton extends StatelessWidget {
  const StudentCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? null
            : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          _shimmerCircle(context, 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(context, width: 140, height: 15),
                const SizedBox(height: 6),
                _shimmerBox(context, width: 90, height: 12),
              ],
            ),
          ),
          _shimmerBox(context, width: 70, height: 30, radius: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ClassCardSkeleton
// ─────────────────────────────────────────────────────────────────────────────
class ClassCardSkeleton extends StatelessWidget {
  const ClassCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? null
            : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          _shimmerBox(context, width: 48, height: 48, radius: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(context, width: 130, height: 15),
                const SizedBox(height: 6),
                _shimmerBox(context, width: 80, height: 12),
              ],
            ),
          ),
          _shimmerBox(context, width: 36, height: 36, radius: 10),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ListSkeleton
// ─────────────────────────────────────────────────────────────────────────────
class ListSkeleton extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext) itemBuilder;

  const ListSkeleton({
    super.key,
    this.itemCount = 5,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, _) => itemBuilder(context),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DashboardCardSkeleton
// ─────────────────────────────────────────────────────────────────────────────
class DashboardCardSkeleton extends StatelessWidget {
  const DashboardCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? null
            : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          _shimmerCircle(context, 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(context, width: 100, height: 14),
                const SizedBox(height: 6),
                _shimmerBox(context, width: 60, height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AttendanceStatsSkeleton
// ─────────────────────────────────────────────────────────────────────────────
class AttendanceStatsSkeleton extends StatelessWidget {
  const AttendanceStatsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard(context)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(context)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard(context)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(context)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _shimmerCircle(context, 18),
          const SizedBox(height: 8),
          _shimmerBox(context, width: 40, height: 20),
          const SizedBox(height: 4),
          _shimmerBox(context, width: 50, height: 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AttendanceCardSkeleton
// ─────────────────────────────────────────────────────────────────────────────
class AttendanceCardSkeleton extends StatelessWidget {
  const AttendanceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _shimmerCircle(context, 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(context, width: 100, height: 14),
                const SizedBox(height: 5),
                _shimmerBox(context, width: 70, height: 11),
              ],
            ),
          ),
          _shimmerBox(context, width: 55, height: 26, radius: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PaymentCardSkeleton
// ─────────────────────────────────────────────────────────────────────────────
class PaymentCardSkeleton extends StatelessWidget {
  const PaymentCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? null
            : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          _shimmerCircle(context, 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(context, width: 120, height: 15),
                const SizedBox(height: 6),
                _shimmerBox(context, width: 80, height: 12),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _shimmerBox(context, width: 70, height: 15),
              const SizedBox(height: 5),
              _shimmerBox(context, width: 50, height: 24, radius: 20),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  QuizListTileSkeleton
// ─────────────────────────────────────────────────────────────────────────────
class QuizListTileSkeleton extends StatelessWidget {
  const QuizListTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? null
            : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          _shimmerBox(context, width: 44, height: 44, radius: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(context, width: 160, height: 15),
                const SizedBox(height: 7),
                _shimmerBox(context, width: 110, height: 12),
              ],
            ),
          ),
          _shimmerBox(context, width: 28, height: 28, radius: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  QuizResultTileSkeleton
// ─────────────────────────────────────────────────────────────────────────────
class QuizResultTileSkeleton extends StatelessWidget {
  const QuizResultTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? null
            : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          _shimmerCircle(context, 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(context, width: 150, height: 15),
                const SizedBox(height: 7),
                _shimmerBox(context, width: 100, height: 12),
              ],
            ),
          ),
          _shimmerBox(context, width: 56, height: 28, radius: 14),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  NoticeCardSkeleton
// ─────────────────────────────────────────────────────────────────────────────
class NoticeCardSkeleton extends StatelessWidget {
  const NoticeCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? null
            : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmerCircle(context, 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(context, width: 140, height: 15),
                const SizedBox(height: 8),
                _shimmerBox(context, width: double.infinity, height: 11),
                const SizedBox(height: 5),
                _shimmerBox(context, width: 200, height: 11),
                const SizedBox(height: 8),
                _shimmerBox(context, width: 80, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ResourceCardSkeleton
// ─────────────────────────────────────────────────────────────────────────────
class ResourceCardSkeleton extends StatelessWidget {
  const ResourceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? null
            : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          _shimmerCircle(context, 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(context, width: 150, height: 15),
                const SizedBox(height: 7),
                _shimmerBox(context, width: 90, height: 12),
              ],
            ),
          ),
          _shimmerBox(context, width: 32, height: 32, radius: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LinkedDeviceSkeleton
// ─────────────────────────────────────────────────────────────────────────────
class LinkedDeviceSkeleton extends StatelessWidget {
  const LinkedDeviceSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? null
            : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          _shimmerBox(context, width: 44, height: 44, radius: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(context, width: 130, height: 15),
                const SizedBox(height: 7),
                _shimmerBox(context, width: 90, height: 12),
                const SizedBox(height: 5),
                _shimmerBox(context, width: 60, height: 11),
              ],
            ),
          ),
          _shimmerBox(context, width: 60, height: 26, radius: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BackupItemSkeleton
// ─────────────────────────────────────────────────────────────────────────────
class BackupItemSkeleton extends StatelessWidget {
  const BackupItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? null
            : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          _shimmerCircle(context, 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(context, width: 120, height: 15),
                const SizedBox(height: 7),
                _shimmerBox(context, width: 80, height: 12),
              ],
            ),
          ),
          _shimmerBox(context, width: 28, height: 28, radius: 8),
        ],
      ),
    );
  }
}
