import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _isResending = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Timer variables
  int _remainingSeconds = 10 * 60; // 10 minutes in seconds
  bool _canResend = false;

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

    // Focus on first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });

    // Start countdown timer
    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
        _startCountdownTimer();
      } else if (mounted && _remainingSeconds == 0) {
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _resetPassword() async {
    if (_code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the complete 6-digit code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiService.resetPassword(widget.email, _code, _passwordController.text);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset successful! Please login with your new password.'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to login screen
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;

      String errorMessage = e.message;

      // Customize error messages based on error codes
      if (e.errorCode == 'INVALID_RESET_CODE') {
        errorMessage = 'Invalid reset code. Please check and try again.';
      } else if (e.errorCode == 'RESET_CODE_EXPIRED') {
        errorMessage = 'Reset code has expired. Please request a new one.';
      } else if (e.statusCode == 429) {
        errorMessage = 'Too many attempts. Please wait and try again.';
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
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Unable to reset password. Please check your connection and try again.'),
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

  Future<void> _resendCode() async {
    setState(() => _isResending = true);

    try {
      await ApiService.forgotPasswordRequest(widget.email);

      // Reset timer
      setState(() {
        _remainingSeconds = 15 * 60;
        _canResend = false;
      });
      _startCountdownTimer();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reset code sent successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } on ApiException catch (e) {
      String errorMessage = e.message;

      // Customize error messages based on error codes
      if (e.statusCode == 429) {
        errorMessage = 'Too many requests. Please wait before requesting another code.';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Unable to send code. Please check your connection and try again.'),
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
        setState(() => _isResending = false);
      }
    }
  }

  void _onCodeChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6366F1), // Indigo
              Color(0xFF8B5CF6), // Purple
              Color(0xFFA855F7), // Medium Purple
              Color(0xFFEC4899), // Pink
            ],
            stops: [0.0, 0.4, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Background pattern overlay
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.5,
                      colors: [
                        Colors.white,
                        Colors.transparent,
                      ],
                      stops: [0.0, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.lock_reset_rounded,
                              size: 40,
                              color: Color(0xFF6366F1),
                            ),
                          ),

                          const SizedBox(height: 24),

                          Text(
                            'Reset Password',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'Enter the 6-digit code sent to',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),

                          Text(
                            widget.email,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Code Input Fields
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(6, (index) {
                              return Container(
                                width: 45,
                                height: 55,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: _controllers[index],
                                  focusNode: _focusNodes[index],
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(1),
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF6366F1),
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    counterText: '',
                                  ),
                                  onChanged: (value) => _onCodeChanged(index, value),
                                ),
                              );
                            }),
                          ),

                          const SizedBox(height: 24),

                          // Password Field
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: TextFormField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                labelText: 'New Password',
                                labelStyle: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 16,
                                ),
                                floatingLabelStyle: const TextStyle(
                                  color: Color(0xFF6366F1),
                                  fontSize: 18,
                                ),
                                prefixIcon: Icon(Icons.lock_outlined, color: Colors.grey[700]),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.grey[700],
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                                border: InputBorder.none,
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.all(16),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Confirm Password Field
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: !_isConfirmPasswordVisible,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Confirm New Password',
                                labelStyle: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 16,
                                ),
                                floatingLabelStyle: const TextStyle(
                                  color: Color(0xFF6366F1),
                                  fontSize: 18,
                                ),
                                prefixIcon: Icon(Icons.lock_outlined, color: Colors.grey[700]),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isConfirmPasswordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.grey[700],
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                    });
                                  },
                                ),
                                border: InputBorder.none,
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.all(16),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Reset Password Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _resetPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF6366F1),
                                disabledBackgroundColor: Colors.white.withOpacity(0.7),
                                disabledForegroundColor: const Color(0xFF6366F1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: _isLoading
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            color: Color(0xFF6366F1),
                                            strokeWidth: 3,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Resetting...',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF6366F1),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      'Reset Password',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Timer and Resend Code
                          Column(
                            children: [
                              if (!_canResend)
                                Text(
                                  'Resend code in ${_formatTime(_remainingSeconds)}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                )
                              else
                                TextButton(
                                  onPressed: _isResending ? null : _resendCode,
                                  child: _isResending
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          'Didn\'t receive the code? Resend',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 14,
                                            decoration: TextDecoration.underline,
                                            decorationColor: Colors.white,
                                          ),
                                        ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Back to Forgot Password
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              'Change Email',
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
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