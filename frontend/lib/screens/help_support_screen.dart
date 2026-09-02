import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> with TickerProviderStateMixin {
  // --- Theme Colors ---
  final Color colPinkDeep = const Color(0xFFEC4899);
  final Color colLavender = const Color(0xFFE0C3FC);
  final Color colTextMain = const Color(0xFF4A0E4E);
  final Color colBgTop = const Color(0xFFFDFBFF);
  final Color colBgBot = const Color(0xFFFFE4F0);

  // --- Animation Controllers ---
  late AnimationController _blobController;
  late Animation<Offset> _blobAnim;

  @override
  void initState() {
    super.initState();
    // Blob Animation
    _blobController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _blobAnim = Tween<Offset>(begin: Offset.zero, end: const Offset(0.05, 0.05)).animate(CurvedAnimation(parent: _blobController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _blobController.dispose();
    super.dispose();
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
          child: Text("Help & Support", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Text
                  Text(
                    "Frequently Asked Questions",
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: colTextMain),
                  ),
                  const SizedBox(height: 15),

                  // FAQ Section (Light Glass Card)
                  _buildLightGlassCard(
                    child: Column(
                      children: [
                        _buildFaqItem(
                          "How is the Risk Score calculated?",
                          "We use a machine learning model trained on thousands of dating conversations. It analyzes factors like response time, message length, and emoji usage patterns."
                        ),
                        Divider(color: colPinkDeep.withValues(alpha: 0.1)),
                        _buildFaqItem(
                          "Is my data private?",
                          "Yes. We anonymize all names using cryptographic hashing before they touch our servers. Your chats are analyzed instantly."
                        ),
                        Divider(color: colPinkDeep.withValues(alpha: 0.1)),
                        _buildFaqItem(
                          "What is the 'Vibe Check'?",
                          "The Vibe Check uses AI Sentiment Analysis to determine the emotional tone. Pink/Green means positive/happy, while Grey/Red can indicate tension."
                        ),
                        Divider(color: colPinkDeep.withValues(alpha: 0.1)),
                        _buildFaqItem(
                          "Can I delete my history?",
                          "Currently, history is used to improve the prediction model. You can contact support to request a full data wipe."
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Contact Section
                  Text(
                    "Contact Us",
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: colTextMain),
                  ),
                  const SizedBox(height: 15),
                  
                  _buildLightGlassCard(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white, 
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: colPinkDeep.withValues(alpha: 0.2), blurRadius: 10)]
                            ),
                            child: Icon(Icons.email_rounded, color: colPinkDeep),
                          ),
                          title: Text("Email Support", style: GoogleFonts.poppins(color: colTextMain, fontWeight: FontWeight.w600)),
                          subtitle: Text("support@ghostguard.ai", style: GoogleFonts.poppins(color: Colors.grey)),
                        ),
                        const SizedBox(height: 10),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white, 
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: colPinkDeep.withValues(alpha: 0.2), blurRadius: 10)]
                            ),
                            child: Icon(Icons.bug_report_rounded, color: colPinkDeep),
                          ),
                          title: Text("Report a Bug", style: GoogleFonts.poppins(color: colTextMain, fontWeight: FontWeight.w600)),
                          subtitle: Text("Found an issue? Let us know.", style: GoogleFonts.poppins(color: Colors.grey)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  
                  // Version Info
                  Center(
                    child: Text(
                      "Ghost Guard v1.0.0 (Research Edition)\n© 2025",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: colTextMain.withValues(alpha: 0.4), fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return ExpansionTile(
      title: Text(question, style: GoogleFonts.poppins(color: colTextMain, fontWeight: FontWeight.w600, fontSize: 14)),
      iconColor: colPinkDeep, 
      collapsedIconColor: Colors.grey,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            answer,
            style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 13, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildLightGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
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