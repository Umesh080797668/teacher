import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:url_launcher/url_launcher.dart'; // For calling/emailing
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/subscription_polling_service.dart';
import 'pending_activation_screen.dart';
import 'subscription_upgrade_alert_screen.dart';
import 'payment_rejected_screen.dart';

class ActivationScreen extends StatefulWidget {
  final String? selectedPlan;

  const ActivationScreen({super.key, this.selectedPlan});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  bool _isWaiting = false;
  String? _selectedPlan;
  File? _paymentProof;
  bool _isSendingEmail = false;
  bool _isPaymentSubmitted = false; // Track if payment was submitted
  bool _accountActivatedAfterSubmission = false; // Track if account was activated after payment
  bool _screenJustLoaded = true; // Track if screen just loaded to prevent immediate nav
  SubscriptionPollingService? _subscriptionPollingService;
  String? _currentSubscriptionType;
  int? _fileSize; // Store file size in bytes

  @override
  void initState() {
    super.initState();
    _selectedPlan = widget.selectedPlan;
    _initializeSubscriptionPolling();
    _restoreSavedState();
    
    // Check if payment proof was already submitted (user returning after app closed)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.hasSubmittedPaymentProof) {
        if (mounted) {
           Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const PendingActivationScreen()),
          );
        }
      }
    });
    
    // Allow polling navigation after screen is fully loaded (1 second delay)
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _screenJustLoaded = false;
        });
      }
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
      // Start polling in the background
      _subscriptionPollingService?.startPolling();
    }
  }

  void _handleSubscriptionStatusChange(Map<String, dynamic> status) {
    if (!mounted || _screenJustLoaded) return; // Don't navigate while screen is loading

    final newSubscriptionType = status['subscriptionType'] as String?;
    final isActive = status['isActive'] as bool? ?? false;
    final paymentRejected = status['_paymentRejected'] as bool? ?? false;
    final rejectionReason = status['paymentProofRejectionReason'] as String?;

    // Handle payment rejection - navigate to rejection screen
    if (paymentRejected && rejectionReason != null) {
      debugPrint('Payment was rejected in real-time!');
      _subscriptionPollingService?.stopPolling();
      
      // Clear payment submission status
      final auth = Provider.of<AuthProvider>(context, listen: false);
      auth.clearPaymentProofSubmitted();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your payment proof was rejected by the admin.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => PaymentRejectedScreen(
                rejectionReason: rejectionReason,
              ),
            ),
          );
        }
      });
      return;
    }

    // Check if subscription status has changed to paid or updated
    if (_currentSubscriptionType != newSubscriptionType) {
      setState(() {
        _currentSubscriptionType = newSubscriptionType;
      });

      debugPrint('Subscription status updated in real-time: $newSubscriptionType');
    }

    // ONLY navigate if account becomes ACTIVE - don't navigate on inactive status
    // This prevents redirect loop when user is on activation screen trying to submit payment
    if (!isActive) {
      // Account is not active yet, stay on activation screen
      return;
    }

    // Only navigate if account is active AND payment was submitted and approved
    if (isActive && _isPaymentSubmitted && !_accountActivatedAfterSubmission) {
      // Account was activated after payment submission
      setState(() {
        _accountActivatedAfterSubmission = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your payment has been approved! Your account is now active.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      // Stop polling and navigate to home
      _subscriptionPollingService?.stopPolling();
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      });
    } else if (isActive && !_isPaymentSubmitted && newSubscriptionType != null && newSubscriptionType != 'free') {
      // Account was activated by admin without payment submission (edge case)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your subscription has been activated successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      // Stop polling and navigate to home
      _subscriptionPollingService?.stopPolling();
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      });
    }
  }

  Future<void> _restoreSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Restore selected plan if not provided by widget
      if (_selectedPlan == null) {
        final savedPlan = prefs.getString('temp_selected_plan');
        if (savedPlan != null) {
          setState(() {
            _selectedPlan = savedPlan;
          });
        }
      }

      // Restore payment proof logic
      final path = prefs.getString('temp_payment_proof_path');
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          final size = await file.length();
          if (mounted) {
            setState(() {
              _paymentProof = file;
              _fileSize = size;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error restoring state: $e');
    }
  }

  Future<void> _pickPaymentProof({required ImageSource source}) async {
    try {
      final ImagePicker picker = ImagePicker();
      // Added imageQuality to compress the image
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 70, 
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        final file = File(image.path);
        final size = await file.length();
        
        setState(() {
          _paymentProof = file;
          _fileSize = size;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPaymentProof(source: ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPaymentProof(source: ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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

    // Check internet connection first
    bool hasConnection = false;
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        hasConnection = true;
      }
    } catch (_) {
      hasConnection = false;
    }

    if (!hasConnection) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection. Please check your network and try again.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
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
        // Mark that payment was submitted - now polling will wait for admin activation
        setState(() {
          _isPaymentSubmitted = true;
        });
        
        // Save payment proof submission status so user returns to this screen if app closes
        await auth.markPaymentProofSubmitted();
        
        // Clear temp storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('temp_payment_proof_path');
        await prefs.remove('temp_selected_plan');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment proof submitted successfully! Please wait for admin approval...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to Pending Activation Screen
        if (mounted) {
          _subscriptionPollingService?.stopPolling();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const PendingActivationScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to submit payment proof: $e');
      if (mounted) {
        String errorMessage = 'Failed to submit payment proof';
        if (e.toString().contains('Network error')) {
           errorMessage = 'Network error. Please check your connection.';
        } else if (e.toString().contains('413')) {
           errorMessage = 'Image too large. Please select a smaller image.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            action: SnackBarAction(
               label: 'Retry',
               onPressed: _submitPaymentProof,
               textColor: Colors.white,
            ),
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

  Future<bool> _onWillPop() async {
    if (_isSendingEmail) {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel Upload?'),
          content: const Text('Uploading payment proof. Are you sure you want to cancel?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );
      return shouldExit ?? false;
    }

    if (_paymentProof != null) {
       final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard Changes?'),
          content: const Text('You have attached a payment proof but haven\'t submitted it. Do you want to discard it and leave?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (shouldExit != true) return false;
    }
    
    // Stop polling
    _subscriptionPollingService?.stopPolling();
    return true;
  }

  @override
  Widget build(BuildContext context) {

    if (_isWaiting) {
      return WillPopScope(
        onWillPop: () async {
          // Stop polling when leaving screen
          _subscriptionPollingService?.stopPolling();
          return true;
        },
        child: Scaffold(
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
        ),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Account Activation'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        leading: widget.selectedPlan != null ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (await _onWillPop()) {
               if (context.mounted) Navigator.of(context).pop();
            }
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
              onTap: () async {
                setState(() {
                  _selectedPlan = 'monthly';
                });
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('temp_selected_plan', 'monthly');
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
              onTap: () async {
                setState(() {
                  _selectedPlan = 'yearly';
                });
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('temp_selected_plan', 'yearly');
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

            // Payment Details & Instructions
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
                        'Payment Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Bank Details Box
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bank Transfer',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildBankDetailRow(context, 'Bank', 'Commercial Bank'),
                        const SizedBox(height: 4),
                        _buildBankDetailRow(context, 'Branch', 'Colombo'),
                        const SizedBox(height: 4),
                        _buildBankDetailRow(context, 'Account Name', 'Attendance App'),
                        const SizedBox(height: 4),
                        _buildBankDetailRow(context, 'Account No', '1234567890'),
                      ],
                    ),
                  ),

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
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50, 
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  image: DecorationImage(
                                    image: FileImage(_paymentProof!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Payment proof attached',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (_fileSize != null)
                                      Text(
                                        _formatFileSize(_fileSize!),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Remove Image?'),
                                      content: const Text('Are you sure you want to remove the selected payment proof?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false), 
                                          child: const Text('Cancel')
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true), 
                                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                                          child: const Text('Remove')
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.remove('temp_payment_proof_path');
                                    setState(() {
                                      _paymentProof = null;
                                      _fileSize = null;
                                    });
                                  }
                                },
                                tooltip: 'Remove Image',
                                icon: Icon(
                                  Icons.close,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _showImageSourceDialog,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Change Image'),
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
                        onPressed: _showImageSourceDialog,
                        icon: const Icon(Icons.add_a_photo),
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
              child: TextButton.icon(
                onPressed: () async {
                  final Uri emailLaunchUri = Uri(
                    scheme: 'mailto',
                    path: 'support@attendanceapp.com', // Replace with actual email
                    queryParameters: const {'subject': 'Subscription Support Request'},
                  );
                  
                  try {
                    if (await canLaunchUrl(emailLaunchUri)) {
                      await launchUrl(emailLaunchUri);
                    } else {
                       if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not open email client')),
                        );
                       }
                    }
                  } catch (e) {
                    debugPrint('Error launching email: $e');
                  }
                },
                icon: const Icon(Icons.help_outline),
                label: const Text('Need help? Contact Support'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),

          ],
        ),
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

Widget _buildBankDetailRow(BuildContext context, String label, String value) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          if (value.isNotEmpty)
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label copied to clipboard'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Icon(
                  Icons.copy,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    ],
  );
}

  @override
  void dispose() {
    _subscriptionPollingService?.stopPolling();
    _subscriptionPollingService?.dispose();
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