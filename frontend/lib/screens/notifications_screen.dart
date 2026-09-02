import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'history_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with TickerProviderStateMixin {
  // --- Theme Colors ---
  final Color colPinkDeep = const Color(0xFFEC4899);
  final Color colLavender = const Color(0xFFE0C3FC);
  final Color colTextMain = const Color(0xFF4A0E4E);
  final Color colBgTop = const Color(0xFFFDFBFF);
  final Color colBgBot = const Color(0xFFFFE4F0);

  // --- Animation Controllers ---
  late AnimationController _blobController;
  late Animation<Offset> _blobAnim;

  // --- Data State ---
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Blob Animation
    _blobController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _blobAnim = Tween<Offset>(begin: Offset.zero, end: const Offset(0.05, 0.05)).animate(CurvedAnimation(parent: _blobController, curve: Curves.easeInOut));

    _fetchNotifications();
  }

  @override
  void dispose() {
    _blobController.dispose();
    super.dispose();
  }

  /// Outcome requests are tagged "[log:<id>]" by the backend so it can tell which
  /// analyses have already been asked about. That marker is bookkeeping and is not
  /// shown to the user.
  static final RegExp _marker = RegExp(r'\s*\[log:[^\]]+\]\s*');

  String _clean(String message) => message.replaceAll(_marker, ' ').trim();

  bool _isOutcomeRequest(Map<String, dynamic> n) =>
      (n['message'] ?? '').toString().contains('[log:');

  /// Opens Validate Predictions, where the outcome is recorded. A notification asks
  /// the question; a single screen writes the answer, so only one code path updates
  /// the outcome column.
  Future<void> _openValidation(Map<String, dynamic> item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
    try {
      await Supabase.instance.client
          .from('notifications')
          .delete()
          .eq('id', item['id']);
    } catch (_) {
      // Not critical - the prompt simply remains until next time.
    }
    if (mounted) _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_hash', user.id) 
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Notification Error: $e");
    }
  }

  Future<void> _markAsRead(String id) async {
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id);
    _fetchNotifications(); 
  }

  Future<void> _deleteNotification(String id) async {
    await Supabase.instance.client
        .from('notifications')
        .delete()
        .eq('id', id);
    
    setState(() {
      _notifications.removeWhere((n) => n['id'] == id);
    });
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
          child: Text("Notifications", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
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
                : _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_off_outlined, size: 60, color: colPinkDeep.withValues(alpha: 0.3)),
                            const SizedBox(height: 20),
                            Text("No new notifications", style: GoogleFonts.poppins(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final item = _notifications[index];
                          final isRead = item['is_read'] ?? false;
                          
                          return Dismissible(
                            key: Key(item['id']),
                            onDismissed: (direction) => _deleteNotification(item['id']),
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 15),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20)
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete_outline, color: Colors.white, size: 30),
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 15),
                              child: _buildLightGlassCard(
                                isRead: isRead,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      isRead ? Icons.notifications_none : Icons.notifications_active,
                                      color: isRead ? Colors.grey : colPinkDeep, 
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['title'],
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              color: colTextMain,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            _clean(item['message'] ?? ''),
                                            style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13),
                                          ),
                                          if (_isOutcomeRequest(item))
                                            Padding(
                                              padding: const EdgeInsets.only(top: 12),
                                              child: SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton.icon(
                                                  onPressed: () => _openValidation(item),
                                                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                                                  label: Text("Answer",
                                                      style: GoogleFonts.poppins(
                                                          fontWeight: FontWeight.w600)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: colPinkDeep,
                                                    foregroundColor: Colors.white,
                                                    elevation: 0,
                                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (!isRead)
                                      IconButton(
                                        icon: Icon(Icons.check_circle_outline, color: colPinkDeep.withValues(alpha: 0.6)),
                                        onPressed: () => _markAsRead(item['id']),
                                      )
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildLightGlassCard({required Widget child, bool isRead = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isRead ? Colors.white.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isRead ? Colors.white.withValues(alpha: 0.2) : colPinkDeep.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: isRead ? Colors.transparent : colLavender.withValues(alpha: 0.2), 
                blurRadius: 15, 
                offset: const Offset(0, 5)
              )
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