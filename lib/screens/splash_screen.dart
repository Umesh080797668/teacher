import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.7, curve: Curves.elasticOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.8),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _rotationAnimation = Tween<double>(begin: -0.2, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // Wait for auth provider to load, then navigate
    _waitForAuthAndNavigate();
  }

  Future<void> _waitForAuthAndNavigate() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    // Wait for auth provider to finish loading
    while (auth.isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Minimum splash duration of 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check auth state and navigate accordingly
    final target = auth.isAuthenticated ? const HomeScreen() : const LoginScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => target,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Color.fromRGBO(0, 0, 0, 0.4),
              BlendMode.darken,
            ),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF6366F1).withValues(alpha: 0.8),
                const Color(0xFF8B5CF6).withValues(alpha: 0.7),
                const Color(0xFFEC4899).withValues(alpha: 0.6),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Animated Logo Container
                  RotationTransition(
                    turns: _rotationAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 40,
                                spreadRadius: 8,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.8),
                              width: 4,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/Gemini_Generated_Image_iirantiirantiira.png',
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),

                  // Animated Title Section
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          // Main Title
                          Text(
                            'Eduverse',
                            style: GoogleFonts.poppins(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  offset: const Offset(0, 4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Subtitle
                          Text(
                            'Teacher Panel',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.95),
                              letterSpacing: 0.8,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  offset: const Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Tagline
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Empowering Education Through Technology',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.9),
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Enhanced Loading Section
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        // Custom Loading Animation
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 3,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withValues(alpha: 0.9),
                              ),
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Initializing Eduverse...',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.9),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please wait while we set up your workspace',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
