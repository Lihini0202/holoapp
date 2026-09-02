import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with TickerProviderStateMixin {
  // --- Theme Colors ---
  final Color colPinkDeep = const Color(0xFFEC4899);
  final Color colLavender = const Color(0xFFE0C3FC);
  final Color colTextMain = const Color(0xFF4A0E4E);
  final Color colBgTop = const Color(0xFFFDFBFF);
  final Color colBgBot = const Color(0xFFFFE4F0);

  // --- Controllers ---
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _countryController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // --- Animation Controllers ---
  late AnimationController _blobController;
  late Animation<Offset> _blobAnim;

  DateTime? _selectedDate;
  bool _isLoading = true;
  // Populated once when the profile loads.
  // ignore: prefer_final_fields
  String _email = '';
  String? _avatarUrl;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    
    // Blob Animation
    _blobController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _blobAnim = Tween<Offset>(begin: Offset.zero, end: const Offset(0.05, 0.05)).animate(CurvedAnimation(parent: _blobController, curve: Curves.easeInOut));

    _loadProfile();
  }

  @override
  void dispose() {
    _blobController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _countryController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('user_hash', userId)
          .maybeSingle();

      if (data != null) {
        setState(() {
          _firstNameController.text = data['first_name'] ?? '';
          _lastNameController.text = data['last_name'] ?? '';
          _countryController.text = data['country'] ?? '';
          _avatarUrl = data['avatar_url'];
          if (data['birthdate'] != null) {
            _selectedDate = DateTime.parse(data['birthdate']);
          }
        });
      }
    } catch (e) {
      // A missing row is normal on first use; anything else is worth seeing.
      debugPrint('Profile load: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Pick an image and upload it to the `avatars` bucket.
  ///
  /// The path is `<auth-uid>/avatar.<ext>`, which is what the storage policies check:
  /// the first path segment must equal auth.uid(), so a user can only write their own
  /// file. `upsert` replaces any previous photo rather than accumulating files.
  Future<void> _pickAvatar() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _uploadingAvatar = true);

      final bytes = await picked.readAsBytes();
      if (bytes.lengthInBytes > 2 * 1024 * 1024) {
        throw 'Image is larger than 2 MB. Please choose a smaller one.';
      }

      final userId = Supabase.instance.client.auth.currentUser!.id;
      final ext = picked.name.split('.').last.toLowerCase();
      final safeExt = ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
      final path = '$userId/avatar.$safeExt';

      await Supabase.instance.client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/${safeExt == "jpg" ? "jpeg" : safeExt}',
            ),
          );

      // A cache-buster is needed because the path is stable across replacements.
      final url = '${Supabase.instance.client.storage.from('avatars').getPublicUrl(path)}'
          '?v=${DateTime.now().millisecondsSinceEpoch}';

      await Supabase.instance.client.from('user_profiles').upsert({
        'id': userId,
        'avatar_url': url,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        setState(() => _avatarUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text("Photo updated"), backgroundColor: colPinkDeep));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Could not upload: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      
      // user_profiles, not profiles: the latter is the ghosted-partner ledger that
      // Ghost Search reads, and writing an app user into it would make them appear
      // there as a reported partner.
      await Supabase.instance.client.from('user_profiles').upsert({
        'id': userId,
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'country': _countryController.text.trim(),
        'birthdate': _selectedDate?.toIso8601String().split('T').first,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (_passwordController.text.isNotEmpty) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: _passwordController.text.trim()),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Profile Updated! 💕"), backgroundColor: colPinkDeep));
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: colPinkDeep, 
              onPrimary: Colors.white, 
              onSurface: colTextMain
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [colPinkDeep, Colors.purpleAccent],
          ).createShader(bounds),
          child: Text("Edit Profile", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
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
          Positioned(top: -50, right: -30, child: SlideTransition(position: _blobAnim, child: _buildBlurCircle(200, const Color(0xFFFFB6C1).withValues(alpha: 0.4)))),
          Positioned(bottom: 100, left: -50, child: SlideTransition(position: _blobAnim, child: _buildBlurCircle(250, const Color(0xFFE6E6FA).withValues(alpha: 0.5)))),

          // 3. CONTENT LAYER
          SafeArea(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator(color: colPinkDeep))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // Tap to change the profile photo.
                      GestureDetector(
                        onTap: _uploadingAvatar ? null : _pickAvatar,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 100, height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: colLavender.withValues(alpha: 0.5), blurRadius: 20)],
                                border: Border.all(color: colPinkDeep.withValues(alpha: 0.2), width: 3),
                                image: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                    ? DecorationImage(
                                        image: NetworkImage(_avatarUrl!), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                                  ? Icon(Icons.person, size: 50, color: colPinkDeep.withValues(alpha: 0.5))
                                  : null,
                            ),
                            if (_uploadingAvatar)
                              Container(
                                width: 100, height: 100,
                                decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
                                child: const Center(
                                    child: CircularProgressIndicator(color: Colors.white)),
                              ),
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: colPinkDeep,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt,
                                    size: 15, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text("Tap the photo to change it",
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.grey.shade600)),
                      const SizedBox(height: 14),

                      // The signed-in address, shown read-only. It comes from Supabase
                      // auth rather than the profile row, and changing it would require
                      // re-verification, so it is displayed rather than edited here.
                      if (_email.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colPinkDeep.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.mail_outline, size: 20,
                                  color: colPinkDeep.withValues(alpha: 0.7)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Signed in as",
                                        style: GoogleFonts.poppins(
                                            fontSize: 11, color: Colors.grey.shade600)),
                                    Text(_email,
                                        style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: colTextMain)),
                                  ],
                                ),
                              ),
                              Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),

                      _buildLightGlassInput(_firstNameController, "First Name", Icons.person_outline),
                      const SizedBox(height: 15),
                      _buildLightGlassInput(_lastNameController, "Last Name", Icons.person_outline),
                      const SizedBox(height: 15),
                      
                      // Date Picker
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: colPinkDeep.withValues(alpha: 0.1)),
                            boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, color: colPinkDeep),
                              const SizedBox(width: 15),
                              Text(
                                _selectedDate == null 
                                  ? "Select Birthdate" 
                                  : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                                style: GoogleFonts.poppins(
                                  color: _selectedDate == null ? Colors.grey : colTextMain,
                                  fontWeight: FontWeight.w500
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 15),
                      _buildLightGlassInput(_countryController, "Country", Icons.public),
                      const SizedBox(height: 30),
                      
                      const Divider(color: Colors.black12),
                      const SizedBox(height: 10),
                      
                      _buildLightGlassInput(_passwordController, "New Password (Optional)", Icons.lock_reset_rounded, obscure: true),
                      
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            gradient: LinearGradient(colors: [colPinkDeep, Colors.purpleAccent]),
                            boxShadow: [
                              BoxShadow(color: colPinkDeep.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))
                            ]
                          ),
                          child: ElevatedButton(
                            onPressed: _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            child: const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildLightGlassInput(TextEditingController controller, String label, IconData icon, {bool obscure = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colPinkDeep.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: TextStyle(color: colTextMain, fontWeight: FontWeight.w600),
        cursorColor: colPinkDeep,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500),
          prefixIcon: Icon(icon, color: colPinkDeep),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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