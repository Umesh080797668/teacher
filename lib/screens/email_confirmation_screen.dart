import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_screen.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class EmailConfirmationScreen extends StatefulWidget {
  final String email;
  final String name;
  final String phone;
  final String password;

  const EmailConfirmationScreen({
    super.key,
    required this.email,
    required this.name,
    required this.phone,
    required this.password,
  });

  @override
  State<EmailConfirmationScreen> createState() => _EmailConfirmationScreenState();
}

class _EmailConfirmationScreenState extends State<EmailConfirmationScreen> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(5, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(5, (_) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
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

    // Focus on first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _verifyCode() async {
    if (_code.length != 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the complete 5-digit code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://teacher-psi-drab.vercel.app/api/auth/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': widget.email,
          'code': _code,
        }),
      );

      if (response.statusCode == 200) {
        // Code verified, now register the teacher
        await _registerTeacher();
      } else {
        String errorMessage = 'Invalid verification code';
        try {
          final error = json.decode(response.body);
          errorMessage = error['error'] ?? 'Invalid verification code';
        } catch (e) {
          // If response body is not JSON (e.g., 404 HTML page), use status code
          if (response.statusCode == 404) {
            errorMessage = 'Verification service not available. Please try again later.';
          } else if (response.statusCode == 500) {
            errorMessage = 'Server error. Please try again later.';
          } else {
            errorMessage = 'Verification failed (${response.statusCode})';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _registerTeacher() async {
    try {
      final response = await http.post(
        Uri.parse('https://teacher-psi-drab.vercel.app/api/teachers'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': widget.name,
          'email': widget.email,
          'phone': widget.phone,
          'password': widget.password,
        }),
      );

      if (response.statusCode == 201) {
        if (!mounted) return;

        final auth = Provider.of<AuthProvider>(context, listen: false);
        await auth.login(widget.email, widget.name);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        String errorMessage = 'Registration failed';
        try {
          final error = json.decode(response.body);
          errorMessage = error['error'] ?? 'Registration failed';
        } catch (e) {
          // If response body is not JSON (e.g., 404 HTML page), use status code
          if (response.statusCode == 404) {
            errorMessage = 'Registration service not available. Please try again later.';
          } else if (response.statusCode == 500) {
            errorMessage = 'Server error. Please try again later.';
          } else {
            errorMessage = 'Registration failed (${response.statusCode})';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);

    try {
      final response = await http.post(
        Uri.parse('https://teacher-psi-drab.vercel.app/api/auth/send-verification-code'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': widget.email}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        String errorMessage = 'Failed to resend code';
        try {
          final error = json.decode(response.body);
          errorMessage = error['error'] ?? 'Failed to resend code';
        } catch (e) {
          // If response body is not JSON (e.g., 404 HTML page), use status code
          if (response.statusCode == 404) {
            errorMessage = 'Resend service not available. Please try again later.';
          } else if (response.statusCode == 500) {
            errorMessage = 'Server error. Please try again later.';
          } else {
            errorMessage = 'Failed to resend code (${response.statusCode})';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _onCodeChanged(int index, String value) {
    if (value.isNotEmpty && index < 4) {
      _focusNodes[index + 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF6750A4),
              const Color(0xFF8B7AB8),
            ],
          ),
        ),
        child: SafeArea(
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
                          Icons.email_rounded,
                          size: 40,
                          color: Color(0xFF6750A4),
                        ),
                      ),

                      const SizedBox(height: 24),

                      Text(
                        'Verify Your Email',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'We sent a 5-digit code to',
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
                        children: List.generate(5, (index) {
                          return Container(
                            width: 50,
                            height: 60,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
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
                                color: const Color(0xFF6750A4),
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

                      const SizedBox(height: 32),

                      // Verify Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF6750A4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF6750A4),
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Verify Email',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Resend Code
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

                      const SizedBox(height: 16),

                      // Back to Registration
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
      ),
    );
  }
}