import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui'; 

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with TickerProviderStateMixin {
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
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Blob Animation
    _blobController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _blobAnim = Tween<Offset>(begin: Offset.zero, end: const Offset(0.05, 0.05)).animate(CurvedAnimation(parent: _blobController, curve: Curves.easeInOut));

    _fetchLogs();
  }

  @override
  void dispose() {
    _blobController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await Supabase.instance.client
          .from('analysis_logs')
          .select('id, created_at, risk_score, message_count')
          .eq('auth_user_id', userId)    
          .filter('actual_outcome', 'is', null) 
          .order('created_at', ascending: false)
          .limit(20);

      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent));
        setState(() => _isLoading = false);
      }
    }
  }

  /// [ghosted] null means "Not sure": the analysis is removed from the queue but no
  /// outcome is written, so an uncertain guess never becomes training data.
  Future<void> _updateOutcome(String id, bool? ghosted) async {
    try {
      if (ghosted != null) {
        await Supabase.instance.client
            .from('analysis_logs')
            .update({'actual_outcome': ghosted})
            .eq('id', id);
      }

      setState(() {
        _logs.removeWhere((item) => item['id'] == id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ghosted == null
                ? "Skipped - no outcome recorded"
                : (ghosted ? "Marked as Ghosted 👻" : "Marked as Success 💖")),
            backgroundColor: ghosted == null
                ? Colors.blueGrey
                : (ghosted ? colPinkDeep : Colors.green),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating outcome: $e");
    }
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
          child: Text("Validate Predictions", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
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
                : _logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_edu, size: 60, color: colPinkDeep.withValues(alpha: 0.3)),
                            const SizedBox(height: 20),
                            Text(
                              "No pending validations.\nAnalyze a chat to see it here!",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final item = _logs[index];
                          final rawRisk = item['risk_score'] ?? 0;
                          final double risk = (rawRisk is int) ? rawRisk.toDouble() : rawRisk;
                          final date = DateTime.parse(item['created_at']).toLocal().toString().split('.')[0];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: _buildLightGlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Analysis on $date", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: risk > 0.5 ? colPinkDeep.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: risk > 0.5 ? colPinkDeep : Colors.green),
                                        ),
                                        child: Text(
                                          "${(risk * 100).toInt()}% Risk",
                                          style: TextStyle(color: risk > 0.5 ? colPinkDeep : Colors.green, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text("Did this person ghost you?", style: TextStyle(color: colTextMain, fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _updateOutcome(item['id'], false),
                                          icon: const Icon(Icons.favorite, color: Colors.white, size: 18),
                                          label: const Text("No, Success"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.greenAccent.shade400,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _updateOutcome(item['id'], true),
                                          icon: const Icon(Icons.heart_broken, color: Colors.white, size: 18),
                                          label: const Text("Yes, Ghosted"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: colPinkDeep,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: double.infinity,
                                    child: TextButton.icon(
                                      onPressed: () => _updateOutcome(item['id'], null),
                                      icon: const Icon(Icons.help_outline, size: 18),
                                      label: const Text("Not sure - skip this one"),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.blueGrey,
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                      ),
                                    ),
                                  ),
                                ],
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

  Widget _buildLightGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6), // Light frosted glass
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(color: colLavender.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 5))
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