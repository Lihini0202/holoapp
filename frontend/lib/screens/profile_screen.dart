import 'dart:ui';
import 'dart:math' as math; // For random hearts
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_profile_screen.dart'; 
import 'history_screen.dart';       
import 'notifications_screen.dart';
import 'help_support_screen.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key}); 

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  // --- Theme Colors ---
  final Color colPinkDeep = const Color(0xFFEC4899);
  final Color colLavender = const Color(0xFFE0C3FC);
  final Color colTextMain = const Color(0xFF4A0E4E);
  final Color colBgTop = const Color(0xFFFDFBFF);
  final Color colBgBot = const Color(0xFFFFE4F0);

  // --- Animation Controllers ---
  late AnimationController _blobController;
  late Animation<Offset> _blobAnim;

  // --- Heart Animation Controllers ---
  late AnimationController _floatController;
  final List<FloatingHeartModel> _hearts = [];
  final math.Random _random = math.Random();

  String _displayName = "Loading...";
  String _displayDetails = "";
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    
    // 1. Blob Animation
    _blobController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _blobAnim = Tween<Offset>(begin: Offset.zero, end: const Offset(0.05, 0.05)).animate(CurvedAnimation(parent: _blobController, curve: Curves.easeInOut));

    // 2. Floating Hearts System
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _floatController.addListener(() {
      setState(() {
        for (var heart in _hearts) {
          heart.y -= heart.speed; // Move up
          if (heart.y < -0.1) { // Reset if goes off top
            _resetHeart(heart);
          }
        }
      });
    });

    // Generate initial hearts (fewer for profile to keep it clean)
    for (int i = 0; i < 6; i++) {
      _hearts.add(_resetHeart(FloatingHeartModel(isNew: true)));
    }

    _getUserData();
  }

  FloatingHeartModel _resetHeart(FloatingHeartModel heart) {
    heart.x = _random.nextDouble(); 
    heart.y = heart.isNew ? _random.nextDouble() : 1.1; 
    heart.size = 10 + _random.nextDouble() * 15; 
    heart.speed = 0.0005 + _random.nextDouble() * 0.0015; // Slower for profile
    heart.opacity = 0.1 + _random.nextDouble() * 0.2; // Very subtle
    heart.color = _random.nextBool() ? colPinkDeep : colLavender; 
    heart.isNew = false;
    return heart;
  }

  @override
  void dispose() {
    _blobController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _getUserData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        // user_profiles, keyed on the auth id. The `profiles` table is the ledger of
        // reported partners and never contains a row for the signed-in user, so
        // reading it here always missed and fell through to "New User".
        final data = await Supabase.instance.client
            .from('user_profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        setState(() {
          final first = (data?['first_name'] ?? '').toString().trim();
          final last = (data?['last_name'] ?? '').toString().trim();
          final country = (data?['country'] ?? '').toString().trim();
          _avatarUrl = data?['avatar_url'] as String?;

          if (first.isNotEmpty || last.isNotEmpty) {
            _displayName = [first, last].where((p) => p.isNotEmpty).join(' ');
          } else {
            // No saved profile yet. "New User" was misleading for long-standing
            // accounts that simply never filled the form in, so fall back to the
            // name Google or signup supplied, then to the email local part.
            final meta = (user.userMetadata?['full_name'] ??
                          user.userMetadata?['name'] ?? '').toString().trim();
            if (meta.isNotEmpty) {
              _displayName = meta;
            } else {
              final local = (user.email ?? '').split('@').first.replaceAll(RegExp(r'[._]+'), ' ');
              _displayName = local.isEmpty
                  ? "Your Profile"
                  : local.split(' ')
                      .where((w) => w.isNotEmpty)
                      .map((w) => w[0].toUpperCase() + w.substring(1))
                      .join(' ');
            }
          }

          _displayDetails = country.isNotEmpty
              ? "$country • ${user.email}"
              : (user.email ?? "");
        });
      } catch (e) {
        debugPrint('Profile load: $e');
        setState(() {
          _displayName = "Your Profile";
          _displayDetails = user.email ?? "";
        });
      }
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [colPinkDeep, Colors.purpleAccent],
          ).createShader(bounds),
          child: Text("My Profile", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colTextMain),
      ),
      body: Stack(
        children: [
          // 1. BACKGROUND GRADIENT
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [colBgTop, const Color(0xFFF3E8FF), colBgBot],
                ),
              ),
            ),
          ),

          // 2. ANIMATED BLOBS
          Positioned(top: -50, left: -50, child: SlideTransition(position: _blobAnim, child: _buildBlurCircle(200, const Color(0xFFFFB6C1).withValues(alpha: 0.4)))),
          Positioned(bottom: 100, right: -50, child: SlideTransition(position: _blobAnim, child: _buildBlurCircle(250, const Color(0xFFE6E6FA).withValues(alpha: 0.5)))),

          // 3. FLOATING HEARTS OVERLAY
          IgnorePointer(
            child: Stack(
              children: _hearts.map((heart) {
                return Positioned(
                  left: heart.x * size.width,
                  top: heart.y * size.height,
                  child: Opacity(
                    opacity: heart.opacity,
                    child: Icon(Icons.favorite, size: heart.size, color: heart.color),
                  ),
                );
              }).toList(),
            ),
          ),

          // 4. CONTENT LAYER
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // Avatar with Glow
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [colPinkDeep, colLavender]),
                      boxShadow: [BoxShadow(color: colPinkDeep.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 5)],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFFF3E8FF),
                        backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                            ? NetworkImage(_avatarUrl!)
                            : null,
                        child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                            ? Icon(Icons.person, size: 50, color: colPinkDeep)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Name Info
                  Text(
                    _displayName,
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: colTextMain),
                  ),
                  Text(
                    _displayDetails,
                    style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
                  ),

                  const SizedBox(height: 30),

                  // Menu Card
                  _buildLightGlassCard(
                    child: Column(
                      children: [
                        _buildSettingsItem(
                          Icons.edit_rounded, "Edit Profile", 
                          onTap: () async {
                            final result = await Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (context) => const EditProfileScreen())
                            );
                            if (result == true) _getUserData();
                          }
                        ),
                        Divider(color: colPinkDeep.withValues(alpha: 0.1)),
                        _buildSettingsItem(
                          Icons.history_edu_rounded, "Validation History", 
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen()))
                        ),
                        Divider(color: colPinkDeep.withValues(alpha: 0.1)),
                        _buildSettingsItem(
                          Icons.notifications_active_rounded, 
                          "Notifications",
                          onTap: () {
                            Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (context) => const NotificationsScreen())
                            );
                          }
                        ),
                        Divider(color: colPinkDeep.withValues(alpha: 0.1)),
                        _buildSettingsItem(
                          Icons.favorite_border_rounded, 
                          "Help & Support", 
                          onTap: () {
                           Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => const HelpSupportScreen())
                           );
                          }
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Logout
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.8),
                        foregroundColor: Colors.redAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.2)),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text("Log Out"),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colLavender.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10)
        ),
        child: Icon(icon, color: colPinkDeep),
      ),
      title: Text(title, style: GoogleFonts.poppins(color: colTextMain, fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: colPinkDeep.withValues(alpha: 0.5)),
      onTap: onTap,
    );
  }

  Widget _buildLightGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6), // Light frosted
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(color: colLavender.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 5))
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildBlurCircle(double size, Color color) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 80, spreadRadius: 10)],
      ),
    );
  }
}

// Simple Model class for floating hearts (ensure this is in the file or imported)
class FloatingHeartModel {
  double x = 0;
  double y = 0;
  double size = 0;
  double speed = 0;
  double opacity = 0;
  Color color = Colors.pink;
  bool isNew;
  FloatingHeartModel({this.isNew = true});
}