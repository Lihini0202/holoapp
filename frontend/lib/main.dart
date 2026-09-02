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

  /// The layouts are designed for a phone. Stretched across a desktop window the
  /// cards span the full width and the screens read as mostly empty space, so on
  /// wide viewports the app is held to this width and centred.
  static const double _phoneWidth = 430;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HoloLove',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      // Applied in the builder rather than around `home`, so it covers every
      // pushed route and any dialog as well.
      builder: (context, child) => _PhoneFrame(maxWidth: _phoneWidth, child: child),
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
/// Holds the app to a phone-sized column on wide viewports.
///
/// Below the threshold the child is returned untouched, so phones and narrow
/// browser windows behave exactly as before. Above it, the app is centred at a
/// fixed width against a tinted backdrop.
///
/// MediaQuery is overridden with the constrained width. Without that, layouts
/// that branch on `MediaQuery.of(context).size.width` would still see the full
/// window and lay out for a desktop inside a phone-width column.
class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (child == null || media.size.width <= maxWidth) {
      return child ?? const SizedBox.shrink();
    }

    return ColoredBox(
      color: const Color(0xFFF6EEF8),
      child: Center(
        child: Container(
          width: maxWidth,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A0E4E).withValues(alpha: 0.10),
                blurRadius: 32,
                spreadRadius: 2,
              ),
            ],
          ),
          child: MediaQuery(
            data: media.copyWith(size: Size(maxWidth, media.size.height)),
            child: child!,
          ),
        ),
      ),
    );
  }
}
