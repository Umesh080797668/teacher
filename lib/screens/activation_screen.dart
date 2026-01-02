import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'subscription_screen.dart';
import 'pending_activation_screen.dart';
import 'subscription_upgrade_alert_screen.dart';

class ActivationScreen extends StatefulWidget {
  final String? selectedPlan;

  const ActivationScreen({super.key, this.selectedPlan});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  bool _isWaiting = false;
  String? _selectedPlan;
  bool _shouldContinuePolling = true;
  File? _paymentProof;
  bool _isSendingEmail = false;

  @override
  void initState() {
    super.initState();
    _selectedPlan = widget.selectedPlan;
  }

  Future<void> _pickPaymentProof() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _paymentProof = File(image.path);
      });
    }
  }

  Future<void> _submitPaymentProof() async {
    if (_paymentProof == null || _selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment proof is required. Please attach a payment proof image.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isSendingEmail = true;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userEmail = auth.userEmail;

      // Submit payment proof via API
      await ApiService.submitPaymentProof(
        userEmail!,
        _selectedPlan!,
        _paymentProof!.path,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment proof submitted successfully! You will receive a confirmation email and your account will be activated within 24 hours.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to submit payment proof: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit payment proof: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingEmail = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    if (_isWaiting) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const Text('Account Activation'),
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(),
              ),
              const SizedBox(height: 24),
              Text(
                'Activating Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please wait while we activate your account...',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This may take a few moments.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Account Activation'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        leading: widget.selectedPlan != null ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
            );
          },
        ) : null,
        automaticallyImplyLeading: widget.selectedPlan == null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  Icon(
                    widget.selectedPlan != null
                        ? Icons.payment
                        : Icons.verified_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.selectedPlan != null
                        ? 'Complete Your Subscription Setup'
                        : 'Subscription Expired',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.selectedPlan != null
                        ? 'Please complete the payment process to activate your subscription'
                        : 'Your subscription has ended. Please renew to continue using all features.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Subscription Plans
            Text(
              'Choose Your Plan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Select the plan that best fits your needs',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),

            const SizedBox(height: 24),

            // Monthly Plan
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPlan = 'monthly';
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _selectedPlan == 'monthly'
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedPlan == 'monthly'
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    width: _selectedPlan == 'monthly' ? 2 : 1,
                  ),
                  boxShadow: _selectedPlan == 'monthly'
                      ? [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Monthly Plan',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              if (_selectedPlan == 'monthly') ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 20,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'LKR 1,000 per month',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Perfect for trying out our features. Access to all features for one month.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Yearly Plan
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPlan = 'yearly';
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _selectedPlan == 'yearly'
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedPlan == 'yearly'
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    width: _selectedPlan == 'yearly' ? 2 : 1,
                  ),
                  boxShadow: _selectedPlan == 'yearly'
                      ? [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Yearly Plan',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              if (_selectedPlan == 'yearly') ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 20,
                                ),
                              ],
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                                ),
                                child: const Text(
                                  'SAVE 25%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'LKR 8,000 per year',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Best value for long-term users. Access to all features for one year with significant savings.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Payment Instructions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.payment,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Payment Process',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentStep(
                    context,
                    '1',
                    'Make the payment using the selected plan amount to our bank account',
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentStep(
                    context,
                    '2',
                    'Take a screenshot or note the transaction reference',
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentStep(
                    context,
                    '3',
                    'Attach payment proof (required) and submit, or click "I\'ve Made Payment" below',
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentStep(
                    context,
                    '4',
                    'Your account will be activated within 24 hours after verification',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Payment Proof Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.attach_file,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Payment Proof (Required)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Attach a screenshot or photo of your payment confirmation to speed up the activation process.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_paymentProof != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.image,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Payment proof attached',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _paymentProof = null;
                              });
                            },
                            icon: Icon(
                              Icons.close,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSendingEmail ? null : _submitPaymentProof,
                        icon: _isSendingEmail
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.send),
                        label: Text(_isSendingEmail ? 'Submitting...' : 'Submit Payment Proof'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          foregroundColor: Theme.of(context).colorScheme.onSecondary,
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickPaymentProof,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Attach Payment Proof'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Payment Done Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_selectedPlan != null && _paymentProof != null) ? _handlePaymentDone : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: (_selectedPlan != null && _paymentProof != null)
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                ),
                child: Text(
                  'I\'ve Made Payment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: (_selectedPlan != null && _paymentProof != null)
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Contact Support
            Center(
              child: TextButton(
                onPressed: () {
                  // TODO: Implement contact support
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Contact support feature coming soon'),
                    ),
                  );
                },
                child: Text(
                  'Need help? Contact Support',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePaymentDone() async {
    if (_selectedPlan == null) return;

    setState(() {
      _isWaiting = true;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final email = auth.userEmail;

      if (email == null) {
        throw Exception('User email not found');
      }

      // For first-time setup, don't activate subscription yet
      // Just send payment proof if attached and show waiting message
      if (widget.selectedPlan != null) {
        // Send payment proof via API if attached
        if (_paymentProof != null) {
          await _submitPaymentProof();
        }

        // Mark subscription setup as completed
        await auth.markSubscriptionSetupCompleted();

        // Clear the selected subscription plan since setup is complete
        await auth.clearSelectedSubscriptionPlan();

        // Show success message and navigate to pending activation screen
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment submitted successfully! Your account will be activated within 24 hours after verification.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 5),
            ),
          );

          // Navigate to pending activation screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const PendingActivationScreen()),
          );
        }
      } else {
        // For renewal, check if user currently has free access
        if (auth.isSubscriptionFree) {
          // User currently has free access, show alert that free access has been removed
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const SubscriptionUpgradeAlertScreen(),
              ),
            );
          }
          return;
        }

        // User doesn't have free access, activate subscription normally
        await ApiService.activateSubscription(email, _selectedPlan!);

        // Update the auth provider to reflect the activated subscription
        await auth.updateActivationStatus(true);
        await auth.updateSubscriptionExpiredStatus(false);
        await auth.markSubscriptionSetupCompleted();

        if (mounted) {
          Navigator.of(context).pop(); // Go back to home screen
        }
      }
    } catch (e) {
      debugPrint('Failed to process payment: $e');
      setState(() {
        _isWaiting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process payment: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _waitForActivation() async {
    _shouldContinuePolling = true;

    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Poll for activation status every 5 seconds for up to 5 minutes
    const int maxAttempts = 60; // 60 * 5 seconds = 5 minutes
    int attempts = 0;

    while (attempts < maxAttempts && mounted && _shouldContinuePolling) {
      await Future.delayed(const Duration(seconds: 5));

      try {
        // Call API to get fresh teacher status
        final statusData = await ApiService.getTeacherStatus(auth.teacherId!);
        final isActive = statusData['status'] == 'active';

        if (isActive) {
          // Update the auth provider with the new status
          await auth.updateActivationStatus(true);

          if (mounted) {
            Navigator.of(context).pop(); // Go back to home screen
          }
          return;
        }
      } catch (e) {
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

  @override
  void dispose() {
    _shouldContinuePolling = false;
    super.dispose();
  }
}

Widget _buildPaymentStep(BuildContext context, String number, String text) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            height: 1.4,
          ),
        ),
      ),
    ],
  );
}