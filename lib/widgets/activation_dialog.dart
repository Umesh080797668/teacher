import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ActivationDialog extends StatefulWidget {
  final AuthProvider auth;
  final VoidCallback? onContinue;

  const ActivationDialog({super.key, required this.auth, this.onContinue});

  @override
  State<ActivationDialog> createState() => _ActivationDialogState();
}

class _ActivationDialogState extends State<ActivationDialog> {
  bool _isWaiting = false;
  bool _shouldContinuePolling = true;

  @override
  Widget build(BuildContext context) {
    if (_isWaiting) {
      return AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Activating Account',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Please wait while we activate your account...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This may take a few moments.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        )
      );
    }

    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Row(
        children: [
          Icon(
            widget.auth.isActivated ? Icons.verified : Icons.verified_outlined,
            color: widget.auth.isActivated ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 12),
          Text(
            'Account Activation',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.auth.isActivated) ...[
            Text(
              'Your account is currently active.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ] else ...[
            Text(
              'Your account needs activation to use all features.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose a subscription plan:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Plan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'LKR 1,000 per month',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yearly Plan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'LKR 8,000 per year',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'After making the payment, click "Payment Done" to wait for activation.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
        actions: [
          FilledButton(
            onPressed: () {
              setState(() {
                _isWaiting = true;
              });
              _waitForActivation();
            },
            child: const Text('Payment Done'),
          ),
        ],
    );
  }

  Future<void> _waitForActivation() async {
    _shouldContinuePolling = true;
    
    // Poll for activation status every 5 seconds for up to 5 minutes
    const int maxAttempts = 60; // 60 * 5 seconds = 5 minutes
    int attempts = 0;

    while (attempts < maxAttempts && mounted && _shouldContinuePolling) {
      await Future.delayed(const Duration(seconds: 5));
      
      try {
        // Call API to get fresh teacher status
        final statusData = await ApiService.getTeacherStatus(widget.auth.teacherId!);
        final isActive = statusData['status'] == 'active';
        
        if (isActive) {
          // Update the auth provider with the new status
          await widget.auth.updateActivationStatus(true);
          
          if (mounted) {
            Navigator.of(context).pop();
            widget.onContinue?.call();
          }
          return;
        }
      } catch (e) {
        // If API call fails, continue polling (maybe network issue)
        debugPrint('Failed to check activation status: $e');
      }
      
      attempts++;
    }

    // If we reach here, either timeout or cancelled
    if (mounted && _shouldContinuePolling) {
      setState(() {
        _isWaiting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activation is taking longer than expected. Please try again later or contact support.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }
}