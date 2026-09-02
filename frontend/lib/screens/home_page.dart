import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// Import each screen from its OWN file
import 'analyze_screen.dart';
import 'search_screen.dart';
import 'coach_screen.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // --- Theme Colors ---
  final Color colPinkDeep = const Color(0xFFEC4899);
  final Color colTextMain = const Color(0xFF4A0E4E);

  // The 5 Main Interfaces
  final List<Widget> _screens = [
    const AnalyzeScreen(),   // Tab 0
    const SearchScreen(),    // Tab 1
    const CoachScreen(),     // Tab 2
    const DashboardScreen(), // Tab 3
    const ProfileScreen(),   // Tab 4
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, 
      body: _screens[_currentIndex],

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9), // Frosted white background
          border: Border(top: BorderSide(color: colPinkDeep.withValues(alpha: 0.1), width: 1)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE0C3FC).withValues(alpha: 0.2), // Lavender shadow
              blurRadius: 20,
              offset: const Offset(0, -5)
            )
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          
          backgroundColor: Colors.transparent,
          elevation: 0,
          
          // Theme Colors
          selectedItemColor: colPinkDeep, 
          unselectedItemColor: Colors.grey.shade400,
          
          selectedLabelStyle: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w400),
          
          type: BottomNavigationBarType.fixed, 
          
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.document_scanner_outlined), 
              activeIcon: Icon(Icons.document_scanner_rounded),
              label: "Analyze"
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              activeIcon: Icon(Icons.search_rounded),
              label: "Search"
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              activeIcon: Icon(Icons.chat_bubble_rounded),
              label: "Coach"
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              activeIcon: Icon(Icons.bar_chart_rounded),
              label: "Insights"
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: "Profile"
            ),
          ],
        ),
      ),
    );
  }
}