import 'package:flutter/material.dart';
import 'dart:async';
import '../services/restriction_service.dart';

class RestrictionScreen extends StatefulWidget {
  final String teacherId;
  final String? initialReason;

  const RestrictionScreen({
    Key? key,
    required this.teacherId,
    this.initialReason,
  }) : super(key: key);

  @override
  State<RestrictionScreen> createState() => _RestrictionScreenState();
}

class _RestrictionScreenState extends State<RestrictionScreen> with WidgetsBindingObserver {
  final RestrictionService _restrictionService = RestrictionService();
  Timer? _pollTimer;
  String? _restrictionReason;
  DateTime? _restrictedAt;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restrictionReason = widget.initialReason;
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // When app comes to foreground, restart polling
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      // When app goes to background, stop polling to save battery
      _pollTimer?.cancel();
    }
  }

  void _startPolling() {
    // Check immediately
    _checkRestrictionStatus();
    
    // Then check every 5 seconds
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkRestrictionStatus();
    });
  }

  Future<void> _checkRestrictionStatus() async {
    try {
      final status = await _restrictionService.checkTeacherRestrictionStatus(widget.teacherId);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // If no longer restricted, navigate to login page
        if (!status['isRestricted']) {
          _pollTimer?.cancel();
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account has been unrestricted. Please log in again.'),
              duration: Duration(seconds: 3),
            ),
          );
          // Navigate to login page
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted && context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
          }
        } else {
          setState(() {
            _restrictionReason = status['restrictionReason'];
            _restrictedAt = status['restrictedAt'] != null 
                ? DateTime.parse(status['restrictedAt']) 
                : null;
          });
        }
      }
    } catch (e) {
      print('Error checking restriction status: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Builder(
                builder: (bCtx) {
                  final cs = Theme.of(bCtx).colorScheme;
                  final isDark = Theme.of(bCtx).brightness == Brightness.dark;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Restriction Icon
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.block,
                          size: 60,
                          color: cs.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Title
                      Text(
                        'Account Restricted',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: cs.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Message
                      Text(
                        'Your account has been temporarily restricted by the administrator.',
                        style: TextStyle(
                          fontSize: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Reason Card
                      if (_restrictionReason != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: isDark
                                ? null
                                : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: cs.error, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Reason:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _restrictionReason!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              if (_restrictedAt != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Restricted on: ${_formatDateTime(_restrictedAt!)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 32),

                      // Contact Info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.tertiaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.contact_support,
                              color: cs.onTertiaryContainer,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Need Help?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: cs.onTertiaryContainer,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Please contact your administrator for more information.',
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.onTertiaryContainer,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Loading indicator during polling
                      if (_isLoading)
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.sync,
                              size: 16,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Checking status...',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
