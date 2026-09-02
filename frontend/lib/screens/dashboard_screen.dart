import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
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
  bool _isLoading = true;
  String _debugMessage = "Initializing...";
  
  // Counts by risk band.
  int _countHealthy = 0;
  int _countWarning = 0;
  int _countFading = 0;
  int _total = 0;

  // Accuracy, from the conversations the user has confirmed an outcome for.
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    
    // Blob Animation
    _blobController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _blobAnim = Tween<Offset>(begin: Offset.zero, end: const Offset(0.05, 0.05)).animate(CurvedAnimation(parent: _blobController, curve: Curves.easeInOut));

    _fetchData();
  }

  @override
  void dispose() {
    _blobController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    
    // 1. Get the current User ID
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
       setState(() { _isLoading = false; _debugMessage = "User not logged in."; });
       return;
    }

    try {
      // 2. Fetch logs ONLY for this user using 'auth_user_id'
      final response = await Supabase.instance.client
          .from('analysis_logs')
          .select('risk_score, actual_outcome, created_at')
          .eq('auth_user_id', userId)
          .order('created_at', ascending: false)
          .limit(200);

      final List<dynamic> data = response as List<dynamic>;
      if (!mounted) return;

      if (data.isEmpty) {
        setState(() {
          _countHealthy = _countWarning = _countFading = 0;
          _total = _pending = 0;
          _isLoading = false;
          _debugMessage = "";
        });
        return;
      }

      int healthy = 0, warning = 0, fading = 0, pending = 0;

      for (final item in data) {
        final score = (item['risk_score'] as num?)?.toDouble();
        if (score == null) continue;

        if (score >= 0.66) {
          fading++;
        } else if (score >= 0.33) {
          warning++;
        } else {
          healthy++;
        }

        if (item['actual_outcome'] == null) pending++;
      }

      setState(() {
        _countHealthy = healthy;
        _countWarning = warning;
        _countFading = fading;
        _total = healthy + warning + fading;
        _pending = pending;
        _isLoading = false;
        _debugMessage = "";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _debugMessage = "Could not load insights.";
      });
      debugPrint('Insights: $e');
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
          child: Text("Love Insights", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colTextMain),
        automaticallyImplyLeading: false,
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
          Positioned(top: 100, left: -30, child: SlideTransition(position: _blobAnim, child: _buildBlurCircle(150, const Color(0xFFFFB6C1).withValues(alpha: 0.4)))),
          Positioned(bottom: 200, right: -50, child: SlideTransition(position: _blobAnim, child: _buildBlurCircle(200, const Color(0xFFE6E6FA).withValues(alpha: 0.5)))),

          // 3. CONTENT LAYER
          SafeArea(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: colPinkDeep))
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        
                        // Counts by risk band. Message count is deliberately not
                        // charted: it is not a model input, so it carries no meaning
                        // here.
                        _buildLightGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Your conversations",
                                  style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: colTextMain)),
                              Text("$_total analysed so far",
                                  style: GoogleFonts.poppins(
                                      fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 18),
                              if (_total == 0)
                                _emptyHint("Analyse a chat to see your first insight.")
                              else ...[
                                _bandRow("Looks healthy", _countHealthy,
                                    Colors.green.shade400),
                                const SizedBox(height: 10),
                                _bandRow("Some warning signs", _countWarning,
                                    Colors.orangeAccent),
                                const SizedBox(height: 10),
                                _bandRow("Strong signs of fading", _countFading,
                                    colPinkDeep),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (_pending > 0)
                          _buildLightGlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Help improve accuracy",
                                    style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: colTextMain)),
                                const SizedBox(height: 8),
                                Text(
                                    "$_pending ${_pending == 1 ? 'conversation has' : 'conversations have'} "
                                    "no outcome recorded. Telling us what happened is what "
                                    "makes future predictions better.",
                                    style: GoogleFonts.poppins(
                                        fontSize: 13, color: Colors.grey.shade600)),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => const HistoryScreen())),
                                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                                    label: Text("Review conversations",
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
                              ],
                            ),
                          ),

                        const SizedBox(height: 20),
                        Text(_debugMessage, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                        const SizedBox(height: 80), 
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// One band with a proportional bar, so the split is readable at a glance.
  Widget _bandRow(String label, int count, Color colour) {
    final fraction = _total == 0 ? 0.0 : count / _total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.poppins(fontSize: 13, color: colTextMain)),
            Text("$count",
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.bold, color: colour)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: Colors.grey.withValues(alpha: 0.15),
            color: colour,
          ),
        ),
      ],
    );
  }

  Widget _emptyHint(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
      );

  // --- Helper Widgets ---

  Widget _buildLightGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6), // Light frosted glass
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(color: colLavender.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildBlurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 80, spreadRadius: 10)],
      ),
    );
  }
}