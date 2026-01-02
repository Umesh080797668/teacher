import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Reusable custom button with consistent styling
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
    Widget buttonChild;

    if (isLoading) {
      buttonChild = const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    } else if (icon != null) {
      buttonChild = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(text),
        ],
      );
    } else {
      buttonChild = Text(text);
    }

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.primary,
          foregroundColor: textColor ?? Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: buttonChild,
      ),
    );
  }
}

/// Reusable status badge
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 16, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'late':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Icons.check_circle;
      case 'absent':
        return Icons.cancel;
      case 'late':
        return Icons.access_time;
      default:
        return Icons.help;
    }
  }
}

/// Reusable info card
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
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable empty state widget
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Reusable loading overlay
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
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}

/// Custom app bar with gradient
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Color? backgroundColor;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      elevation: 0,
      backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Skeleton loading widget for student cards
class StudentCardSkeleton extends StatelessWidget {
  const StudentCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Shimmer.fromColors(
              baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              highlightColor: Theme.of(context).colorScheme.surface,
              child: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                radius: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Shimmer.fromColors(
                    baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    highlightColor: Theme.of(context).colorScheme.surface,
                    child: Container(
                      height: 16,
                      width: 120,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Shimmer.fromColors(
                    baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    highlightColor: Theme.of(context).colorScheme.surface,
                    child: Container(
                      height: 12,
                      width: 80,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              children: List.generate(
                3,
                (index) => Shimmer.fromColors(
                  baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  highlightColor: Theme.of(context).colorScheme.surface,
                  child: Container(
                    width: 44,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loading widget for class cards
class ClassCardSkeleton extends StatelessWidget {
  const ClassCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Shimmer.fromColors(
              baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              highlightColor: Theme.of(context).colorScheme.surface,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Shimmer.fromColors(
                    baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    highlightColor: Theme.of(context).colorScheme.surface,
                    child: Container(
                      height: 18,
                      width: 140,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Shimmer.fromColors(
                    baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    highlightColor: Theme.of(context).colorScheme.surface,
                    child: Container(
                      height: 14,
                      width: 100,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
            Shimmer.fromColors(
              baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              highlightColor: Theme.of(context).colorScheme.surface,
              child: Container(
                width: 80,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loading widget for list views
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
      itemBuilder: (context, index) => itemBuilder(context),
    );
  }
}

/// Skeleton loading widget for dashboard cards
class DashboardCardSkeleton extends StatelessWidget {
  const DashboardCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Shimmer.fromColors(
                  baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  highlightColor: Theme.of(context).colorScheme.surface,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Shimmer.fromColors(
                        baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        highlightColor: Theme.of(context).colorScheme.surface,
                        child: Container(
                          height: 16,
                          width: 100,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Shimmer.fromColors(
                        baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        highlightColor: Theme.of(context).colorScheme.surface,
                        child: Container(
                          height: 20,
                          width: 60,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loading widget for attendance statistics
class AttendanceStatsSkeleton extends StatelessWidget {
  const AttendanceStatsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCardSkeleton(context)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCardSkeleton(context)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCardSkeleton(context)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCardSkeleton(context)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCardSkeleton(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Shimmer.fromColors(
              baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              highlightColor: Theme.of(context).colorScheme.surface,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Shimmer.fromColors(
              baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              highlightColor: Theme.of(context).colorScheme.surface,
              child: Container(
                height: 20,
                width: 40,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 4),
            Shimmer.fromColors(
              baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              highlightColor: Theme.of(context).colorScheme.surface,
              child: Container(
                height: 14,
                width: 50,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loading widget for attendance cards
class AttendanceCardSkeleton extends StatelessWidget {
  const AttendanceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Shimmer.fromColors(
          baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          highlightColor: Theme.of(context).colorScheme.surface,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
          ),
        ),
        title: Shimmer.fromColors(
          baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          highlightColor: Theme.of(context).colorScheme.surface,
          child: Container(
            height: 16,
            width: 80,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
        subtitle: Shimmer.fromColors(
          baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          highlightColor: Theme.of(context).colorScheme.surface,
          child: Container(
            height: 14,
            width: 100,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
        trailing: Shimmer.fromColors(
          baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          highlightColor: Theme.of(context).colorScheme.surface,
          child: Container(
            height: 14,
            width: 40,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
    );
  }
}

/// Skeleton loading widget for payment cards
class PaymentCardSkeleton extends StatelessWidget {
  const PaymentCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Shimmer.fromColors(
          baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          highlightColor: Theme.of(context).colorScheme.surface,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Shimmer.fromColors(
              baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              highlightColor: Theme.of(context).colorScheme.surface,
              child: Container(
                height: 16,
                width: 120,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 4),
            Shimmer.fromColors(
              baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              highlightColor: Theme.of(context).colorScheme.surface,
              child: Container(
                height: 14,
                width: 80,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
        subtitle: Shimmer.fromColors(
          baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          highlightColor: Theme.of(context).colorScheme.surface,
          child: Container(
            height: 14,
            width: 60,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
        trailing: Shimmer.fromColors(
          baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          highlightColor: Theme.of(context).colorScheme.surface,
          child: Container(
            height: 16,
            width: 70,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
    );
  }
}
