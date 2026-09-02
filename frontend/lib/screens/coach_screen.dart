import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math; // Added for random hearts
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> with TickerProviderStateMixin {
  // --- Backend URL ---
  final String baseUrl = dotenv.env['BACKEND_URL'] ?? '';
  final String apiKey = dotenv.env['CHOREO_API_KEY'] ?? '';
  
  // --- Controllers ---
  final _draftController = TextEditingController();
  late AnimationController _blobController;
  late Animation<Offset> _blobAnim;

  // --- Heart Animation Controllers ---
  late AnimationController _floatController;
  final List<FloatingHeartModel> _hearts = [];
  final math.Random _random = math.Random();

  // --- Theme Colors ---
  final Color colPinkDeep = const Color(0xFFEC4899);
  final Color colLavender = const Color(0xFFE0C3FC);
  final Color colTextMain = const Color(0xFF4A0E4E);
  final Color colBgTop = const Color(0xFFFDFBFF);
  final Color colBgBot = const Color(0xFFFFE4F0);

  // --- State Variables ---
  List<dynamic> _advice = [];
  String _improvedDraft = "";
  double _riskScore = 0.0;
  String _riskBand = "";
  bool _isAnalyzing = false;

  /// Banded rather than shown as a percentage, for the same reason as the Analyze
  /// screen: this is a judgement about one message, not a measurement, and a figure
  /// like "73%" claims a precision nothing supports.
  Color get _riskColour => _riskBand == "HIGH"
      ? colPinkDeep
      : (_riskBand == "MEDIUM" ? Colors.orangeAccent : Colors.green);

  @override
  void initState() {
    super.initState();
    // 1. Gentle floating animation for background blobs
    _blobController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _blobAnim = Tween<Offset>(begin: Offset.zero, end: const Offset(0.05, 0.05)).animate(CurvedAnimation(parent: _blobController, curve: Curves.easeInOut));

    // 2. Floating Hearts System
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
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

    // Generate initial hearts
    for (int i = 0; i < 12; i++) { // Added 12 hearts for this screen
      _hearts.add(_resetHeart(FloatingHeartModel(isNew: true)));
    }
  }

  FloatingHeartModel _resetHeart(FloatingHeartModel heart) {
    heart.x = _random.nextDouble(); 
    heart.y = heart.isNew ? _random.nextDouble() : 1.1; 
    heart.size = 10 + _random.nextDouble() * 15; // Slightly smaller hearts for this screen
    heart.speed = 0.001 + _random.nextDouble() * 0.002; 
    heart.opacity = 0.2 + _random.nextDouble() * 0.3; // Subtler opacity
    heart.color = _random.nextBool() ? colPinkDeep : colLavender; 
    heart.isNew = false;
    return heart;
  }

  @override
  void dispose() {
    _blobController.dispose();
    _floatController.dispose();
    _draftController.dispose();
    super.dispose();
  }

  Future<void> _analyzeDraft() async {
    String text = _draftController.text;
    if (text.isEmpty) return;
    
    FocusScope.of(context).unfocus();
    if (mounted) setState(() => _isAnalyzing = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/coach-reply'));
      request.headers['API-Key'] = apiKey;
      request.fields['draft'] = text;
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (!mounted) return;

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          _advice = data['advice'] ?? [];
          final rawRisk = data['risk_increase'];
          _riskScore = rawRisk == null
              ? 0.0
              : (rawRisk is int ? rawRisk.toDouble() : (rawRisk as num).toDouble());
          _riskBand = (data['risk_band'] ?? "").toString().toUpperCase();
          _improvedDraft = data['improved_draft'] ?? "";
        });
      } else {
        _showSnack("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) _showSnack("Error: $e");
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: colPinkDeep));
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevent background resize on keyboard
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [colPinkDeep, Colors.purpleAccent],
          ).createShader(bounds),
          child: Text("Love Coach", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colTextMain),
      ),
      body: Stack(
        children: [
          // 1. BACKGROUND GRADIENT (White -> Lavender -> Pink)
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
          
          // 2. ANIMATED BLOBS (Pastel)
          Positioned(top: -50, right: -30, child: SlideTransition(position: _blobAnim, child: _buildBlurCircle(200, const Color(0xFFFFB6C1).withValues(alpha: 0.4)))),
          Positioned(bottom: 100, left: -50, child: SlideTransition(position: _blobAnim, child: _buildBlurCircle(250, const Color(0xFFE6E6FA).withValues(alpha: 0.5)))),

          // 3. FLOATING HEARTS OVERLAY (Added back!)
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
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Draft Your Message", style: GoogleFonts.poppins(color: Colors.grey, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        
                        // INPUT CARD
                        _buildLightGlassCard(
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: colPinkDeep.withValues(alpha: 0.1)),
                                  boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                                child: TextField(
                                  controller: _draftController,
                                  maxLines: 4,
                                  style: TextStyle(color: colTextMain, fontSize: 16),
                                  cursorColor: colPinkDeep,
                                  decoration: const InputDecoration(
                                    hintText: "Type what you want to say...",
                                    hintStyle: TextStyle(color: Colors.black26),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    gradient: LinearGradient(colors: [colPinkDeep, Colors.purpleAccent]),
                                    boxShadow: [
                                      BoxShadow(color: colPinkDeep.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))
                                    ]
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: _isAnalyzing ? null : _analyzeDraft,
                                    icon: _isAnalyzing 
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                                        : const Icon(Icons.auto_fix_high, color: Colors.white),
                                    label: const Text("IMPROVE MY MESSAGE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 30),

                        // RESULTS SECTION
                        if (_improvedDraft.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Ghosting Risk", style: GoogleFonts.poppins(color: colTextMain, fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _riskColour,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(color: _riskColour.withValues(alpha: 0.3), blurRadius: 8)]
                                ),
                                child: Text(
                                  _riskBand.isEmpty ? "UNKNOWN" : _riskBand,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _riskScore,
                              backgroundColor: Colors.grey.withValues(alpha: 0.2),
                              color: _riskColour,
                              minHeight: 10,
                            ),
                          ),
                          const SizedBox(height: 25),

                          // AI SUGGESTION CARD
                          _buildLightGlassCard(
                            borderColor: colLavender,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("✨ Better Version", style: TextStyle(color: colPinkDeep, fontWeight: FontWeight.bold, fontSize: 16)),
                                    InkWell(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: _improvedDraft));
                                        _showSnack("Copied to clipboard! 💕");
                                      },
                                      child: Icon(Icons.copy_rounded, size: 20, color: colPinkDeep),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  _improvedDraft,
                                  style: GoogleFonts.poppins(fontSize: 18, color: colTextMain, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          Text("Coach Tips", style: GoogleFonts.poppins(color: Colors.grey, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                          ..._advice.map((tip) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: colLavender.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lightbulb_rounded, color: Colors.orangeAccent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(child: Text(tip.toString(), style: GoogleFonts.poppins(color: colTextMain.withValues(alpha: 0.8), fontSize: 14))),
                              ],
                            ),
                          )),
                        ],
                        
                        SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helpers ---

  Widget _buildLightGlassCard({required Widget child, Color? borderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor ?? Colors.white.withValues(alpha: 0.6)),
            boxShadow: [BoxShadow(color: colLavender.withValues(alpha: 0.1), blurRadius: 20)]
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

// Ensure this class is available in your file (or imported if shared)
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