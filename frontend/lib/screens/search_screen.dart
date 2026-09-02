import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math; // Added for hearts
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  // --- Backend URL ---
  final String baseUrl = dotenv.env['BACKEND_URL'] ?? '';
  final String apiKey = dotenv.env['CHOREO_API_KEY'] ?? '';

  // --- Controllers ---
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _locController = TextEditingController();

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

  // --- State Variables ---
  String _status = "";
  String _reports = "";
  String _risk = "";
  String _note = "";
  bool _isLoading = false;
  Color _statusColor = Colors.grey;

  /// True only when an actual profile was matched. Guards against "No Records Found"
  /// satisfying a `contains("Found")` test.
  bool get _hasRecord =>
      _status.contains("Found") && !_status.contains("No Records");

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
          heart.y -= heart.speed; 
          if (heart.y < -0.1) { 
            _resetHeart(heart);
          }
        }
      });
    });

    // Generate initial hearts
    for (int i = 0; i < 8; i++) {
      _hearts.add(_resetHeart(FloatingHeartModel(isNew: true)));
    }
  }

  FloatingHeartModel _resetHeart(FloatingHeartModel heart) {
    heart.x = _random.nextDouble(); 
    heart.y = heart.isNew ? _random.nextDouble() : 1.1; 
    heart.size = 10 + _random.nextDouble() * 20; 
    heart.speed = 0.001 + _random.nextDouble() * 0.002; 
    heart.opacity = 0.1 + _random.nextDouble() * 0.3; 
    heart.color = _random.nextBool() ? colPinkDeep : colLavender; 
    heart.isNew = false;
    return heart;
  }

  @override
  void dispose() {
    _blobController.dispose();
    _floatController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _locController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_nameController.text.isEmpty) return;
    
    // Dismiss keyboard
    FocusScope.of(context).unfocus();
    
    setState(() { _isLoading = true; _status = ""; _note = ""; });

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/search-ghost'));
      request.headers['API-Key'] = apiKey;
      request.fields['name'] = _nameController.text;
      request.fields['age'] = _ageController.text.isNotEmpty ? _ageController.text : "0";
      request.fields['location'] = _locController.text.isNotEmpty ? _locController.text : "unknown";

      var streamRes = await request.send();
      var response = await http.Response.fromStream(streamRes);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _status = data['status'];
          _reports = data['reports'].toString();
          
          // Banded rather than a percentage, for the same reason as the Analyze screen:
          // the underlying score ranks reliably but is not accurate to the point of a
          // printed figure. Here it is weaker still, since a profile average may rest
          // on only one or two reports.
          double score = (data['risk_score'] ?? 0.0).toDouble();
          int reportCount = int.tryParse(data['reports'].toString()) ?? 0;
          if (reportCount < 3) {
            _risk = score >= 0.66 ? "HIGH (few reports)" : (score >= 0.33 ? "MEDIUM (few reports)" : "LOW (few reports)");
          } else {
            _risk = score >= 0.66 ? "HIGH" : (score >= 0.33 ? "MEDIUM" : "LOW");
          }
          _note = data['note'] ?? "";

          if (_status.contains("No Records")) {
             // Neutral, not green: we know nothing about this person, which is not
             // the same as knowing they are safe.
             _statusColor = Colors.blueGrey;
          } else if (_status.contains("Found")) {
             _statusColor = score > 0.6 ? colPinkDeep : Colors.orangeAccent;
          } else {
             _statusColor = Colors.greenAccent.shade700;
          }
        });
      } else {
        setState(() { _status = "Error"; _note = "Server Error ${response.statusCode}"; _statusColor = Colors.red; });
      }
    } catch (e) {
      setState(() { _status = "Failed"; _note = e.toString(); _statusColor = Colors.red; });
    } finally {
      setState(() => _isLoading = false);
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
          child: Text("Ghost Search", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  _buildLightGlassCard(
                    child: Column(
                      children: [
                        _buildLightInput(_nameController, "Name (Required)", Icons.search_rounded),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(child: _buildLightInput(_ageController, "Age", Icons.cake_rounded, isNumber: true)),
                            const SizedBox(width: 15),
                            Expanded(child: _buildLightInput(_locController, "Location", Icons.map_rounded)),
                          ],
                        ),
                        const SizedBox(height: 25),
                        
                        SizedBox(
                          width: double.infinity, height: 55,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: LinearGradient(colors: [colPinkDeep, Colors.purpleAccent]),
                              boxShadow: [
                                BoxShadow(color: colPinkDeep.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))
                              ]
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _search,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              child: _isLoading 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                                : const Text("SEARCH DATABASE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // RESULTS
                  if (_status.isNotEmpty)
                    _buildLightGlassCard(
                      child: Column(
                        children: [
                          Icon(
                            _status.contains("No Records")
                                ? Icons.help_outline_rounded
                                : (_status.contains("Found")
                                    ? Icons.warning_rounded
                                    : Icons.check_circle_rounded),
                            size: 50,
                            color: _statusColor,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _status.toUpperCase(), 
                            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: _statusColor)
                          ),
                          const SizedBox(height: 10),
                          // "No Records Found" contains the word "Found", so every
                          // branch below must exclude it explicitly or the result card
                          // renders twice and shows a risk level for a person nobody
                          // has reported.
                          if (_hasRecord) ...[
                            _buildInfoRow("Reports", _reports),
                            _buildInfoRow("Ghosting Risk", _risk),
                          ],
                          if (_note.isNotEmpty) ...[
                            SizedBox(height: _hasRecord ? 15 : 4),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                              child: Text(
                                _note, 
                                textAlign: TextAlign.center, 
                                style: TextStyle(color: colTextMain.withValues(alpha: 0.8), fontSize: 13)
                              ),
                            ),
                          ]
                        ],
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("$label: ", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 16)),
          Text(value, style: GoogleFonts.poppins(color: colTextMain, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildLightInput(TextEditingController c, String label, IconData icon, {bool isNumber = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colPinkDeep.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: c,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: TextStyle(color: colTextMain, fontWeight: FontWeight.w600),
        cursorColor: colPinkDeep,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: colPinkDeep),
          hintText: label,
          hintStyle: TextStyle(color: Colors.grey.shade500),
          border: InputBorder.none, 
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildLightGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20), 
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(color: colLavender.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 5))
            ]
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

// Ensure this class is available
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