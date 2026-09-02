import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart'; 
import 'home_page.dart';  

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;
  late AnimationController _controller3;
  late AnimationController _heartBeatController;
  late AnimationController _floatingHeartsController;
  late AnimationController _shimmerController;
  late AnimationController _cardEntranceController;
  late Animation<Offset> _animation1;
  late Animation<Offset> _animation2;
  late Animation<Offset> _animation3;
  late Animation<double> _heartBeatAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _cardScaleAnimation;
  late Animation<double> _cardOpacityAnimation;

  @override
  void initState() {
    super.initState();
    
    // Card entrance animation
    _cardEntranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _cardScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _cardEntranceController, curve: Curves.easeOutBack)
    );
    _cardOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardEntranceController, curve: const Interval(0.0, 0.6))
    );
    _cardEntranceController.forward();

    // Setup Floating Animations (smoother)
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

    // Refined heart beat
    _heartBeatController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _heartBeatAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _heartBeatController, curve: Curves.easeInOut));

    // Shimmer effect for title
    _shimmerController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _shimmerAnimation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut)
    );

    // Floating hearts
    _floatingHeartsController = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  }

  void _onGetStarted() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    _heartBeatController.dispose();
    _floatingHeartsController.dispose();
    _shimmerController.dispose();
    _cardEntranceController.dispose();
    super.dispose();
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

          // 2. SUBTLE MESH GRADIENT BLOBS
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

          // 3. ELEGANT FLOATING HEARTS
          ...List.generate(10, (index) => _buildPremiumFloatingHeart(index)),

          // 4. PREMIUM GLASS CARD WITH ENTRANCE ANIMATION
          Center(
            child: ScaleTransition(
              scale: _cardScaleAnimation,
              child: FadeTransition(
                opacity: _cardOpacityAnimation,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.88,
                      padding: const EdgeInsets.all(40),
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
                          // PREMIUM ANIMATED HEART ICON
                          ScaleTransition(
                            scale: _heartBeatAnimation,
                            child: Container(
                              padding: const EdgeInsets.all(26),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
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
                                    blurRadius: 25,
                                    spreadRadius: 5,
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    blurRadius: 15,
                                    offset: const Offset(-5, -5),
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
                                  Icons.favorite_rounded,
                                  size: 54,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 36),

                          // PREMIUM TITLE WITH SHIMMER
                          AnimatedBuilder(
                            animation: _shimmerAnimation,
                            builder: (context, child) {
                              return ShaderMask(
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: const [
                                      Color(0xFFEC4899),
                                      Color(0xFFF472B6),
                                      Color(0xFFA855F7),
                                      Color(0xFFC084FC),
                                    ],
                                    stops: [
                                      (_shimmerAnimation.value - 1).clamp(0.0, 1.0),
                                      (_shimmerAnimation.value - 0.5).clamp(0.0, 1.0),
                                      (_shimmerAnimation.value).clamp(0.0, 1.0),
                                      (_shimmerAnimation.value + 0.5).clamp(0.0, 1.0),
                                    ],
                                  ).createShader(bounds);
                                },
                                child: Text(
                                  "Ghost Guard",
                                  style: GoogleFonts.inter(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -1.5,
                                    height: 1.1,
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 12),

                          // ELEGANT TAGLINE
                          Text(
                            "Your dating safety companion",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: const Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),

                          const SizedBox(height: 44),

                          // PREMIUM BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: ElevatedButton(
                              onPressed: _onGetStarted,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(29),
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
                                  borderRadius: BorderRadius.circular(29),
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
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Get Started",
                                        style: GoogleFonts.inter(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ],
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

  Widget _buildPremiumFloatingHeart(int index) {
    final random = (index * 41 + 17) % 100;
    final leftPosition = (random % 100).toDouble() / 100 * MediaQuery.of(context).size.width;
    final animationDelay = (index * 500);
    final duration = 4000 + (random % 2000);
    final size = 10.0 + (random % 6).toDouble();
    
    return AnimatedBuilder(
      animation: _floatingHeartsController,
      builder: (context, child) {
        final progress = (_floatingHeartsController.value + (animationDelay / duration)) % 1.0;
        final yPosition = MediaQuery.of(context).size.height * (1.1 - progress * 1.2);
        final opacity = progress < 0.15 
            ? progress / 0.15 
            : (progress > 0.85 ? (1 - progress) / 0.15 : 1.0);
        final drift = 25 * (0.5 - progress);
        
        return Positioned(
          left: leftPosition + drift,
          top: yPosition,
          child: Opacity(
            opacity: opacity * 0.25,
            child: Icon(
              Icons.favorite_rounded,
              color: index % 3 == 0 
                  ? const Color(0xFFEC4899)
                  : (index % 3 == 1 ? const Color(0xFFF0ABFC) : const Color(0xFFA855F7)),
              size: size,
            ),
          ),
        );
      },
    );
  }
}