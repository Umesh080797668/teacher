import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/subscription_polling_service.dart';
import 'activation_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = false;
  String? _selectedPlan;
  SubscriptionPollingService? _subscriptionPollingService;
  String? _currentSubscriptionType;

  @override
  void initState() {
    super.initState();
    // Load previously selected plan if any
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.hasSelectedSubscriptionPlan && auth.selectedSubscriptionPlan != null) {
        setState(() {
          _selectedPlan = auth.selectedSubscriptionPlan;
        });
      }
      // Initialize real-time polling for subscription status updates
      _initializeSubscriptionPolling();
    });
  }

  void _initializeSubscriptionPolling() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.userEmail != null) {
      _subscriptionPollingService = SubscriptionPollingService(
        pollingInterval: const Duration(seconds: 3),
        userEmail: auth.userEmail,
        onStatusChanged: _handleSubscriptionStatusChange,
      );
      // Start polling to detect when admin changes subscription in real-time
      _subscriptionPollingService?.startPolling();
      debugPrint('Subscription polling started on subscription screen');
    }
  }

  void _handleSubscriptionStatusChange(Map<String, dynamic> status) {
    if (!mounted) return;

    final newSubscriptionType = status['subscriptionType'] as String?;
    final isActive = status['isActive'] as bool? ?? false;
    final accountActivated = status['_accountActivated'] as bool? ?? false;

    // Handle account activation (admin approved payment)
    if (accountActivated && isActive) {
      debugPrint('Real-time update: Account activated');
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your payment has been approved! Redirecting to home...'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Navigate to home screen
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _subscriptionPollingService?.stopPolling();
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      });
      
      return;
    }

    // Detect if subscription type has changed to paid
    if (newSubscriptionType != null && newSubscriptionType != 'free' && newSubscriptionType != _currentSubscriptionType) {
      setState(() {
        _currentSubscriptionType = newSubscriptionType;
        // Pre-select the plan set by admin
        _selectedPlan = newSubscriptionType;
      });

      debugPrint('Real-time update: Subscription changed to $newSubscriptionType');

      // Show notification if subscription was updated
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Admin has set your subscription to ${newSubscriptionType == 'monthly' ? 'Monthly' : 'Yearly'}. Please proceed to payment.'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Choose Subscription Plan'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        automaticallyImplyLeading: false, // Prevent back button
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome message
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.star,
                        size: 50,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      auth.isActivated
                          ? 'Manage Subscription'
                          : 'Complete Your Subscription',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      auth.isActivated
                          ? 'Update your subscription plan'
                          : 'Your account needs activation. Please select a plan and complete payment.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (!auth.isActivated)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Account inactive - Payment required',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Subscription Plans
              Text(
                'Subscription Plans',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 20),

              // Monthly Plan
              Card(
                color: _selectedPlan == 'monthly'
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPlan = 'monthly';
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Radio<String>(
                          value: 'monthly',
                          groupValue: _selectedPlan,
                          onChanged: (value) {
                            setState(() {
                              _selectedPlan = value;
                            });
                          },
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Monthly Plan',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'LKR 1,000 per month',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Perfect for trying out our services',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Yearly Plan
              Card(
                color: _selectedPlan == 'yearly'
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPlan = 'yearly';
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Radio<String>(
                          value: 'yearly',
                          groupValue: _selectedPlan,
                          onChanged: (value) {
                            setState(() {
                              _selectedPlan = value;
                            });
                          },
                        ),
                        const SizedBox(width: 16),
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
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Save 33%',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
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
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Best value for long-term commitment',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Payment Instructions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.payment,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Payment Instructions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '1. Make payment to the following account:',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bank: Commercial Bank',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Account Name: A.G.I.U.L.B Aldeniya',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Account Number: 123456789',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '2. Take a screenshot of the payment proof',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '3. Click "Continue" below to proceed',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Continue Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedPlan != null && !_isLoading ? _continueToActivation : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Continue to Payment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _continueToActivation() async {
    if (_selectedPlan == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);

      // Save the selected subscription plan
      await auth.setSelectedSubscriptionPlan(_selectedPlan!);

      // Stop polling before navigating away
      _subscriptionPollingService?.stopPolling();

      // Small delay to ensure everything is ready
      await Future.delayed(const Duration(milliseconds: 100));

      // Navigate to activation screen with selected plan
      // Using push instead of pushReplacement to maintain navigation stack
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ActivationScreen(selectedPlan: _selectedPlan),
          ),
        );
        
        // When coming back from activation, check auth status
        // Don't restart polling if user was activated (they shouldn't be here)
        if (mounted) {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          if (!auth.isActivated) {
            // User came back without completing activation, restart polling
            _initializeSubscriptionPolling();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _subscriptionPollingService?.stopPolling();
    _subscriptionPollingService?.dispose();
    super.dispose();
  }
}