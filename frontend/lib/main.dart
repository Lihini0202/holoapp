import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HoloLove',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildTheme() {
    var baseTheme = ThemeData(brightness: Brightness.light); 

    // --- LOVE THEME PALETTE ---
    const primaryColor = Color(0xFFEC4899);    // Deep Pink
    const secondaryColor = Color(0xFF4A0E4E);  // Deep Purple (Text)
    const accentColor = Color(0xFFE0C3FC);     // Lavender
    const backgroundColor = Color(0xFFFDFBFF); // Soft White (Background)
    const errorColor = Color(0xFFFF007F);      // Hot Pink (Error)

    return baseTheme.copyWith(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor, 
      
      // 1. Text Theme (Deep Purple text for readability)
      textTheme: GoogleFonts.poppinsTextTheme(baseTheme.textTheme).apply(
        bodyColor: secondaryColor,
        displayColor: secondaryColor,
      ),
      
      // 2. Input Fields (Soft Frosted Style)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white, 
        hintStyle: TextStyle(color: Colors.grey.shade400),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),

      // 3. Button Styling
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor, // Pink Button
          foregroundColor: Colors.white, // White Text
          elevation: 5,
          shadowColor: primaryColor.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      
      // 4. Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: accentColor,
        surface: Colors.white,
        onSurface: secondaryColor,
        error: errorColor,
      ),
      
      // 5. Icon Theme
      iconTheme: const IconThemeData(color: primaryColor),
    );
  }
}