import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'registration_screen.dart';
import 'home_screen.dart';
import 'subscription_screen.dart';
import 'pending_activation_screen.dart';
import 'payment_rejected_screen.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'forgot_password_screen.dart';
import '../widgets/activation_dialog.dart';

class LoginScreen extends StatefulWidget {
  final String? initialEmail;

  const LoginScreen({super.key, this.initialEmail});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
    
    // Pre-fill email if provided
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
    
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final rememberMe = prefs.getBool('remember_me') ?? false;
    
    if (rememberMe && savedEmail != null && _emailController.text.isEmpty) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberMe = true;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Make API call to login using centralized service
      final data = await ApiService.login(_emailController.text, _passwordController.text);
      final teacher = data['teacher'];
      final token = data['token']; // Get JWT token from response
      
      // Commit autofill data for password manager to save credentials
      _emailController.text.isNotEmpty && _passwordController.text.isNotEmpty
          ? null
          : null; // Autofill will be saved automatically when login succeeds
      
      // Persist remember-me email preference and auth token
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_email', _emailController.text);
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('saved_email');
        await prefs.setBool('remember_me', false);
      }
      
      // Store JWT token for authenticated API requests
      if (token != null) {
        final FlutterSecureStorage storage = FlutterSecureStorage();
        await storage.write(key: 'auth_token', value: token);
      }

      if (!mounted) return; // avoid using BuildContext across async gap

      // Notify global auth provider of successful login
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.login(
        _emailController.text, 
        teacher['name'], 
        teacherId: teacher['teacherId'],
        teacherData: teacher,
      );

      if (mounted) {
        // Check subscription and account status
        final subscriptionStatus = teacher['subscriptionStatus'] as String?;
        final paymentProofStatus = teacher['paymentProofStatus'] as String?;
        final paymentProofRejectionReason = teacher['paymentProofRejectionReason'] as String?;
        final accountInactive = teacher['accountInactive'] as bool? ?? false;
        final isFirstLogin = teacher['isFirstLogin'] as bool? ?? false;
        final subscriptionType = teacher['subscriptionType'] as String? ?? 'monthly';
        
        // Scenario 1: Payment was rejected - show rejection screen
        if (paymentProofStatus == 'rejected' && paymentProofRejectionReason != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => PaymentRejectedScreen(
                rejectionReason: paymentProofRejectionReason,
              ),
            ),
          );
          return;
        }
        
        // Scenario 2: Payment is pending approval - show pending screen
        if (subscriptionStatus == 'pending' && paymentProofStatus == 'pending') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const PendingActivationScreen()),
          );
          return;
        }
        
        // Scenario 3: First login or no subscription set - show subscription screen
        if (isFirstLogin && subscriptionType != 'free') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
          );
          return;
        }
        
        // Scenario 4: Account inactive (moved from free to paid or other reasons)
        if (accountInactive && subscriptionType != 'free') {
          // Check if they need to setup subscription
          if (subscriptionStatus == 'none' || subscriptionStatus == null) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
            );
          } else if (subscriptionStatus == 'rejected') {
            // Show rejection screen if they had a rejected payment
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => PaymentRejectedScreen(
                  rejectionReason: paymentProofRejectionReason ?? 'Please resubmit payment proof',
                ),
              ),
            );
          } else {
            // Generic inactive screen
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Your account is inactive. Please complete the subscription process.'),
                backgroundColor: Colors.orange,
              ),
            );
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
            );
          }
          return;
        }
        
        // Scenario 5: Everything is fine - check normal activation
        if (!auth.isActivated) {
          // Show activation dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => ActivationDialog(
              auth: auth,
              onContinue: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              },
            ),
          );
        } else {
          // Navigate to home screen if activated
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;

      String errorMessage = e.message;
      
      // Customize error messages based on error codes and status codes
      if (e.errorCode == 'INVALID_CREDENTIALS') {
        errorMessage = 'Invalid email or password. Please check your credentials and try again.';
      } else if (e.errorCode == 'ACCOUNT_INACTIVE') {
        errorMessage = 'Your account is not active. Please contact support for assistance.';
      } else if (e.errorCode == 'MISSING_CREDENTIALS') {
        errorMessage = 'Please enter both email and password.';
      } else if (e.statusCode == 401) {
        errorMessage = 'Invalid email or password. Please try again.';
      } else if (e.statusCode == 429) {
        errorMessage = 'Too many login attempts. Please wait a few minutes and try again.';
      } else if (e.statusCode == 500 || e.statusCode == 502 || e.statusCode == 503) {
        errorMessage = 'Server is currently unavailable. Please try again later.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(errorMessage)),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      // Catch any other unexpected errors
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Unable to connect. Please check your internet connection and try again.'),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() => _isLoading = true);

    try {
      // Notify global auth provider of guest login
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.loginAsGuest();

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to continue as guest: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F0C29),
                    const Color(0xFF1E1B4B),
                    const Color(0xFF302B63),
                  ]
                : [
                    const Color(0xFF3730A3),
                    const Color(0xFF4F46E5),
                    const Color(0xFF7C3AED),
                  ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Logo area ─────────────────────────────────────
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 32,
                              spreadRadius: 0,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          size: 52,
                          color: Color(0xFF4338CA),
                        ),
                      ),

                      const SizedBox(height: 24),

                      Text(
                        'Eduverse',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          'Teacher Portal',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.9),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ── Login Form Card ───────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1B4B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.18),
                              blurRadius: 40,
                              spreadRadius: 0,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(28),
                        child: AutofillGroup(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Section label
                                Text(
                                  'Sign In',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  'Enter your credentials to continue',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.6)
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Email
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [
                                    AutofillHints.email,
                                    AutofillHints.username
                                  ],
                                  style: TextStyle(
                                      color: cs.onSurface, fontSize: 15),
                                  decoration: InputDecoration(
                                    labelText: 'Email address',
                                    prefixIcon: Icon(Icons.email_outlined,
                                        color: cs.primary),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!v.contains('@')) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 16),

                                // Password
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_isPasswordVisible,
                                  autofillHints: const [AutofillHints.password],
                                  style: TextStyle(
                                      color: cs.onSurface, fontSize: 15),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: Icon(Icons.lock_outline_rounded,
                                        color: cs.primary),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        color: cs.onSurfaceVariant,
                                      ),
                                      onPressed: () => setState(() =>
                                          _isPasswordVisible =
                                              !_isPasswordVisible),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    if (v.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 14),

                                // Remember me & Forgot password
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        onChanged: (v) => setState(
                                            () => _rememberMe = v ?? false),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Remember me',
                                      style: TextStyle(
                                          fontSize: 13, color: cs.onSurface),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const ForgotPasswordScreen(),
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                      ),
                                      child: Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 22),

                                // Sign In Button — gradient
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF4F46E5)
                                              .withValues(alpha: 0.40),
                                          blurRadius: 20,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'Signing in...',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Text(
                                              'Sign In',
                                              style: GoogleFonts.poppins(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Continue as Guest ─────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _continueAsGuest,
                          icon: const Icon(Icons.person_outline_rounded,
                              color: Colors.white, size: 20),
                          label: Text(
                            'Continue as Guest',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Colors.white, width: 1.5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Sign Up Link ──────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RegistrationScreen()),
                            ),
                            child: Text(
                              'Sign Up',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white,
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
      ),
    );
  }
}
