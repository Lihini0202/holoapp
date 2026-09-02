import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'home_page.dart'; 
import 'onboarding_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  bool _isLogin = true;

  // --- Animations ---
  late AnimationController _controller1;
  late AnimationController _controller2;
  late AnimationController _controller3;
  late AnimationController _heartBeatController;
  late AnimationController _cardEntranceController;
  late Animation<Offset> _animation1;
  late Animation<Offset> _animation2;
  late Animation<Offset> _animation3;
  late Animation<double> _heartBeatAnimation;
  late Animation<double> _cardScaleAnimation;
  late Animation<double> _cardOpacityAnimation;

  @override
  void initState() {
    super.initState();
    
    // Card entrance animation
    _cardEntranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _cardScaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _cardEntranceController, curve: Curves.easeOutBack)
    );
    _cardOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardEntranceController, curve: const Interval(0.0, 0.6))
    );
    _cardEntranceController.forward();

    // Floating animations
    _controller1 = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
    _animation1 = Tween<Offset>(begin: Offset.zero, end: const Offset(0.08, 0.08)).animate(
      CurvedAnimation(parent: _controller1, curve: Curves.easeInOut)
    );
    
    _controller2 = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
    _animation2 = Tween<Offset>(begin: Offset.zero, end: const Offset(-0.06, 0.1)).animate(
      CurvedAnimation(parent: _controller2, curve: Curves.easeInOut)
    );
    
    _controller3 = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat(reverse: true);
    _animation3 = Tween<Offset>(begin: Offset.zero, end: const Offset(0.06, -0.08)).animate(
      CurvedAnimation(parent: _controller3, curve: Curves.easeInOut)
    );

    // Heart beat animation
    _heartBeatController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _heartBeatAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _heartBeatController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    _heartBeatController.dispose();
    _cardEntranceController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- MODIFIED AUTH HANDLER ---
  Future<void> _handleAuthAction(Future<void> Function() authAction) async {
    setState(() => _isLoading = true);
    try {
      await authAction();
      if (mounted) {
        
        // 1. DETERMINE DESTINATION
        Widget nextScreen;
        if (_isLogin) {
          // If Logging In -> Go straight to Home
          nextScreen = const HomePage();
        } else {
          // If Signing Up -> Show User Manual (Onboarding)
          // Ensure 'UserManualScreen' is the class name in 'onboarding_screen.dart'
          nextScreen = const OnboardingScreen();
        }

        // 2. NAVIGATE
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => nextScreen), 
          (route) => false
        );
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      debugPrint("AUTH ERROR: $e");
      if (mounted) _showError("Authentication failed.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEC4899),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. PREMIUM GRADIENT BACKGROUND
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF1F8), // Very soft pink
                  Color(0xFFFCF4FF), // Ultra light lavender
                  Color(0xFFFFFFFF), // Pure white
                  Color(0xFFFDF2F8), // Hint of pink
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),

          // 2. PREMIUM BLOBS
          Positioned(
            top: -100,
            left: -80,
            child: SlideTransition(
              position: _animation1,
              child: _buildPremiumBlob(350, const Color(0xFFF0ABFC), const Color(0xFFFBCFE8)),
            ),
          ),
          Positioned(
            bottom: 40,
            right: -120,
            child: SlideTransition(
              position: _animation2,
              child: _buildPremiumBlob(400, const Color(0xFFDDD6FE), const Color(0xFFF3E8FF)),
            ),
          ),
          Positioned(
            top: 250,
            left: -40,
            child: SlideTransition(
              position: _animation3,
              child: _buildPremiumBlob(220, const Color(0xFFFDA4AF), const Color(0xFFFECDD3)),
            ),
          ),

          // 3. MAIN CARD
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ScaleTransition(
                scale: _cardScaleAnimation,
                child: FadeTransition(
                  opacity: _cardOpacityAnimation,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        padding: const EdgeInsets.all(36),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.85),
                              Colors.white.withValues(alpha: 0.75),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(
                            width: 1.5,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF0ABFC).withValues(alpha: 0.15),
                              blurRadius: 40,
                              spreadRadius: 10,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ANIMATED HEART ICON
                            ScaleTransition(
                              scale: _heartBeatAnimation,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(26),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFFFFE4F0),
                                      Color(0xFFF3E8FF),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFEC4899).withValues(alpha: 0.2),
                                      blurRadius: 20,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    colors: [
                                      Color(0xFFEC4899),
                                      Color(0xFFA855F7),
                                    ],
                                  ).createShader(bounds),
                                  child: const Icon(
                                    Icons.lock_person_rounded,
                                    size: 42,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Color(0xFFEC4899),
                                  Color(0xFFA855F7),
                                ],
                              ).createShader(bounds),
                              child: Text(
                                "Ghost Guard",
                                style: GoogleFonts.inter(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -1.0,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            Text(
                              _isLogin ? "Welcome Back" : "Create Account",
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: const Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            
                            const SizedBox(height: 32),

                            // EMAIL INPUT
                            TextField(
                              controller: _emailController,
                              style: GoogleFonts.inter(fontSize: 15),
                              decoration: InputDecoration(
                                labelText: "Email",
                                labelStyle: GoogleFonts.inter(color: const Color(0xFF6B7280)),
                                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFEC4899)),
                                filled: true,
                                fillColor: const Color(0xFFFCF4FF).withValues(alpha: 0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: const Color(0xFFF0ABFC).withValues(alpha: 0.2)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFEC4899), width: 2),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // PASSWORD INPUT
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              style: GoogleFonts.inter(fontSize: 15),
                              decoration: InputDecoration(
                                labelText: "Password",
                                labelStyle: GoogleFonts.inter(color: const Color(0xFF6B7280)),
                                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFA855F7)),
                                filled: true,
                                fillColor: const Color(0xFFFCF4FF).withValues(alpha: 0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: const Color(0xFFF0ABFC).withValues(alpha: 0.2)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFA855F7), width: 2),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 28),

                            // MAIN BUTTON
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : () {
                                  _handleAuthAction(() async {
                                    if (_isLogin) {
                                      await _authService.signInWithEmail(_emailController.text.trim(), _passwordController.text.trim());
                                    } else {
                                      await _authService.signUpWithEmail(_emailController.text.trim(), _passwordController.text.trim());
                                    }
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  padding: EdgeInsets.zero,
                                  elevation: 0,
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Color(0xFFEC4899),
                                        Color(0xFFA855F7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFEC4899).withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: _isLoading 
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Text(
                                          _isLogin ? "Log In" : "Sign Up",
                                          style: GoogleFonts.inter(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                            color: Colors.white,
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // GOOGLE BUTTON
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : () => _handleAuthAction(_authService.signInWithGoogle),
                                icon: Image.network(
                                  'https://www.google.com/favicon.ico',
                                  width: 24,
                                  height: 24,
                                  errorBuilder: (context, error, stackTrace) => 
                                    const Icon(Icons.g_mobiledata, size: 28, color: Colors.black87),
                                ),
                                label: Text(
                                  "Continue with Google",
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: const Color(0xFFE5E7EB)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // TOGGLE
                            TextButton(
                              onPressed: () => setState(() => _isLogin = !_isLogin),
                              child: RichText(
                                text: TextSpan(
                                  text: _isLogin ? "New here? " : "Have an account? ",
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF6B7280),
                                    fontSize: 15,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: _isLogin ? "Sign Up" : "Log In",
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFEC4899),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
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
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBlob(double size, Color innerColor, Color outerColor) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            outerColor.withValues(alpha: 0.5),
            innerColor.withValues(alpha: 0.25),
            innerColor.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: outerColor.withValues(alpha: 0.3),
            blurRadius: 80,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }
}