import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_page.dart'; 

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _onIntroEnd(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()), 
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Theme Colors ---
    final Color colPinkDeep = const Color(0xFFEC4899);
    final Color colTextMain = const Color(0xFF4A0E4E);
    
    // --- Typography ---
    final titleStyle = GoogleFonts.poppins(
      fontSize: 26.0, 
      fontWeight: FontWeight.w700, 
      color: colTextMain
    );
    final bodyStyle = GoogleFonts.poppins(
      fontSize: 16.0, 
      color: Colors.grey[600],
      height: 1.5 // Better readability
    );

    // --- Page Decoration Helper ---
    PageDecoration pageDecoration = PageDecoration(
      titleTextStyle: titleStyle,
      bodyTextStyle: bodyStyle,
      bodyPadding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Colors.white, // Keep background clean white for contrast
      imagePadding: const EdgeInsets.only(top: 80, bottom: 20),
      contentMargin: const EdgeInsets.symmetric(horizontal: 16),
    );

    return IntroductionScreen(
      globalBackgroundColor: Colors.white,
      allowImplicitScrolling: true,
      
      pages: [
        // --- SLIDE 1: WELCOME ---
        PageViewModel(
          title: "Predict Your Love Life",
          body: "Upload chat screenshots to analyze ghosting risk using our advanced AI love detector.",
          image: _buildImage(Icons.favorite_rounded, colPinkDeep),
          decoration: pageDecoration,
        ),

        // --- SLIDE 2: IDENTITY ---
        PageViewModel(
          title: "Know Who You're Dating",
          body: "We use Name, Age, and Location to differentiate partners.\n\nEnsure 'Anne from Colombo' isn't confused with 'Anne from Kandy'.",
          image: _buildImage(Icons.person_pin_circle_rounded, const Color(0xFFE0C3FC)), // Lavender
          decoration: pageDecoration,
        ),

        // --- SLIDE 3: RISK SCORES ---
        PageViewModel(
          title: "Understand the Vibe",
          body: "🟢 Safe: Green flags all around.\n🟠 Caution: Mixed signals detected.\n🔴 High Risk: High chance of ghosting.",
          image: _buildImage(Icons.volunteer_activism_rounded, Colors.orangeAccent),
          decoration: pageDecoration,
        ),

        // --- SLIDE 4: COMMUNITY ---
        PageViewModel(
          title: "Community Protection",
          body: "Search our database to see if a partner has been flagged by other users before you catch feelings.",
          image: _buildImage(Icons.search_rounded, colPinkDeep),
          decoration: pageDecoration,
        ),
      ],

      onDone: () => _onIntroEnd(context),
      onSkip: () => _onIntroEnd(context),
      showSkipButton: true,
      skipOrBackFlex: 0,
      nextFlex: 0,
      showBackButton: false,
      
      // --- BUTTON STYLES ---
      skip: Text('Skip', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: colPinkDeep)),
      next: Icon(Icons.arrow_forward_rounded, color: colPinkDeep),
      done: Text('Get Started', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: colPinkDeep)),
      
      // --- DOTS DECORATION ---
      dotsDecorator: DotsDecorator(
        size: const Size(10.0, 10.0),
        color: const Color(0xFFE0C3FC), // Lavender inactive
        activeSize: const Size(22.0, 10.0),
        activeShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
        activeColor: colPinkDeep, // Deep Pink active
      ),
    );
  }

  // --- Helper to build consistent large icons ---
  Widget _buildImage(IconData icon, Color color) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 80.0, color: color),
    );
  }
}