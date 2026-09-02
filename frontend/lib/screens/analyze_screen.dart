import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math; // Used for random heart positions
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({super.key});

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> with TickerProviderStateMixin {
  final String baseUrl = dotenv.env['BACKEND_URL'] ?? '';
  final String apiKey = dotenv.env['CHOREO_API_KEY'] ?? '';

  // --- Data Controllers ---
  late TabController _tabController;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();       
  final TextEditingController locationController = TextEditingController(); 
  final TextEditingController textInputController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // --- Animation Controllers ---
  // Blobs
  late AnimationController _blobController1;
  late AnimationController _blobController2;
  late Animation<Offset> _blobAnim1;
  late Animation<Offset> _blobAnim2;

  // Heartbeat (Double Pump)
  late AnimationController _heartbeatController;
  late Animation<double> _heartbeatAnim;

  // Floating Hearts
  late AnimationController _floatController;
  final List<FloatingHeartModel> _hearts = [];
  final math.Random _random = math.Random();

  // --- State Variables ---
  String resultStatus = "Ready";
  String riskScore = "";
  String debugInfo = "";
  String historyAlert = "";
  bool isLoading = false;
  double rawRisk = 0.0;

  // --- Colors ---
  final Color colPinkDeep = const Color(0xFFEC4899);
  final Color colLavender = const Color(0xFFE0C3FC);
  final Color colTextMain = const Color(0xFF4A0E4E); // Deep purple for text

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 1. Blob Animations (Soft drifting)
    _blobController1 = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _blobAnim1 = Tween<Offset>(begin: Offset.zero, end: const Offset(0.05, 0.05)).animate(CurvedAnimation(parent: _blobController1, curve: Curves.easeInOut));

    _blobController2 = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
    _blobAnim2 = Tween<Offset>(begin: Offset.zero, end: const Offset(-0.05, 0.08)).animate(CurvedAnimation(parent: _blobController2, curve: Curves.easeInOut));

    // 2. Heartbeat Animation (Scale)
    _heartbeatController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _heartbeatAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2).chain(CurveTween(curve: Curves.easeOut)), weight: 10), // Pump 1
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 10),  // Relax
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2).chain(CurveTween(curve: Curves.easeOut)), weight: 10), // Pump 2
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 10),  // Relax
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60), // Pause
    ]).animate(_heartbeatController);

    // 3. Floating Hearts System
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
    for (int i = 0; i < 8; i++) {
      _hearts.add(_resetHeart(FloatingHeartModel(isNew: true)));
    }
  }

  FloatingHeartModel _resetHeart(FloatingHeartModel heart) {
    heart.x = _random.nextDouble(); // Random X (0.0 to 1.0)
    heart.y = heart.isNew ? _random.nextDouble() : 1.1; // Start at random height initially, else bottom
    heart.size = 15 + _random.nextDouble() * 20; // Size 15-35
    heart.speed = 0.001 + _random.nextDouble() * 0.003; // Speed
    heart.opacity = 0.3 + _random.nextDouble() * 0.4;
    heart.color = _random.nextBool() ? const Color(0xFFEC4899) : const Color(0xFFE0C3FC); // Pink or Lavender
    heart.isNew = false;
    return heart;
  }

  @override
  void dispose() {
    _blobController1.dispose();
    _blobController2.dispose();
    _heartbeatController.dispose();
    _floatController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Color getRiskColor(double score) {
    if (score < 0.30) return Colors.green; 
    if (score < 0.60) return Colors.orange;
    return const Color(0xFFFF007F);
  }

  // --- API LOGIC ---
  Future<void> uploadScreenshot() async {
    if (!_validateInputs()) return;
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    _startLoading();
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze-screenshot'));
      request.headers['API-Key'] = apiKey;
      request.fields['partner_name'] = nameController.text;
      request.fields['age'] = ageController.text.isNotEmpty ? ageController.text : "0";
      request.fields['location'] = locationController.text.isNotEmpty ? locationController.text : "unknown";
      request.fields['user_id'] = Supabase.instance.client.auth.currentUser?.id ?? "";
      var imageBytes = await image.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: 'upload.jpg'));
      var streamRes = await request.send();
      var response = await http.Response.fromStream(streamRes);
      _handleInitialResponse(response);
    } catch (e) { _handleError(e); }
  }

  Future<void> analyzeText() async {
    if (!_validateInputs()) return;
    if (textInputController.text.isEmpty) { _showSnack("Please paste text"); return; }
    FocusScope.of(context).unfocus();
    _startLoading();
    try {
      var response = await http.post(
        Uri.parse('$baseUrl/analyze-text'),
        headers: {"Content-Type": "application/json", "API-Key": apiKey},
        body: jsonEncode({
          "partner_name": nameController.text,
          "chat_text": textInputController.text,
          "age": ageController.text.isNotEmpty ? ageController.text : "0",
          "location": locationController.text.isNotEmpty ? locationController.text : "unknown",
          "user_id": Supabase.instance.client.auth.currentUser?.id ?? ""
        }),
      );
      _handleInitialResponse(response);
    } catch (e) { _handleError(e); }
  }

  // --- FIXED VALIDATION FUNCTION ---
  bool _validateInputs() {
    if (nameController.text.isEmpty) { 
      _showSnack("Please enter partner name"); 
      return false; // Correctly returning false now
    }
    return true;
  }

  void _startLoading() {
    setState(() {
      isLoading = true; resultStatus = "Starting..."; debugInfo = ""; historyAlert = ""; riskScore = "";
    });
  }

  void _handleInitialResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data.containsKey('error')) {
         setState(() { resultStatus = "Error"; debugInfo = data['error']; isLoading = false; });
      } else {
         String taskId = data['task_id'];
         setState(() { resultStatus = "Processing..."; });
         _pollForResult(taskId);
      }
    } else {
      setState(() { resultStatus = "Server Error: ${response.statusCode}"; isLoading = false; });
    }
  }

  Future<void> _pollForResult(String taskId) async {
    int attempts = 0; bool finished = false;
    while (attempts < 20 && !finished) {
      await Future.delayed(const Duration(seconds: 2)); 
      try {
        var response = await http.get(Uri.parse('$baseUrl/status/$taskId'), headers: {"API-Key": apiKey});
        var data = jsonDecode(response.body);
        if (data['status'] == 'Completed') {
          finished = true;
          var result = data['result']; 
          var extracted = result['extracted_data'] ?? {};
          if (mounted) {
            setState(() {
              isLoading = false;
              rawRisk = (result['risk_score'] ?? 0.0).toDouble();

              // A band, not a percentage. The model ranks conversations reliably but its
              // individual probabilities are not accurate enough to print: the largest
              // calibration gap measured was 0.05, and conversations scored in the top
              // band were ghosted 92% of the time rather than the 99% the raw score
              // implies. Displaying one decimal place would overstate the precision.
              riskScore = rawRisk >= 0.66 ? "HIGH" : (rawRisk >= 0.33 ? "MEDIUM" : "LOW");
              resultStatus = result['status_label'] ?? "Done";
              historyAlert = result['history_alert'] ?? "";

              // Report the signals the model scored on, so the user can see what
              // drove the result. Message count and emoji rate are not model inputs.
              final ratio = extracted['length_ratio'];
              final qRate = extracted['question_rate'];
              if (ratio != null && qRate != null) {
                final pct = (ratio * 100).round();
                final qPct = (qRate * 100).round();
                debugInfo = "What this is based on:\n"
                    "\u2022 Their replies are $pct% as long as yours\n"
                    "\u2022 They ask a question back in $qPct% of messages\n"
                    "\u2022 ${extracted['their_messages'] ?? 0} messages from them analysed";
              } else {
                debugInfo = "What this is based on:\n"
                    "\u2022 ${extracted['messages'] ?? 0} messages analysed\n"
                    "\u2022 Speakers could not be separated, so a simpler check was used";
              }
            });
          }
        } else if (data['status'] == 'Failed') {
          finished = true;
          if (mounted) setState(() { isLoading = false; resultStatus = "Analysis Failed"; debugInfo = data['error'] ?? "Unknown"; });
        }
      } catch (e) { debugPrint("Polling Error: $e"); }
      attempts++;
    }
    if (!finished && mounted) setState(() { isLoading = false; resultStatus = "Timeout"; debugInfo = "Server took too long."; });
  }

  void _handleError(Object e) { if (mounted) setState(() { resultStatus = "Failed"; debugInfo = "$e"; isLoading = false; }); }
  void _showSnack(String msg) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: colPinkDeep)); }

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
          child: Text("Ghost Guard", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white)),
        ),
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        iconTheme: IconThemeData(color: colTextMain),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colPinkDeep,
          labelColor: colPinkDeep, 
          unselectedLabelColor: Colors.grey,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [ 
            Tab(icon: Icon(Icons.favorite), text: "Screenshot"), 
            Tab(icon: Icon(Icons.chat_bubble), text: "Paste Text") 
          ],
        ),
      ),
      body: Stack(
        children: [
          // 1. BACKGROUND GRADIENT (White -> Lavender -> Pink)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.6, 1.0],
                colors: [
                  Color(0xFFFDFBFF), // White-ish
                  Color(0xFFF3E8FF), // Light Lavender
                  Color(0xFFFFE4F0), // Soft Pink
                ],
              ),
            ),
          ),

          // 2. ANIMATED BLOBS (Pastel)
          Positioned(
            top: -50, left: -50,
            child: SlideTransition(
              position: _blobAnim1,
              child: _buildBlurCircle(300, const Color(0xFFFFB6C1).withValues(alpha: 0.4)), // Light Pink Blob
            ),
          ),
          Positioned(
            bottom: 100, right: -80,
            child: SlideTransition(
              position: _blobAnim2,
              child: _buildBlurCircle(300, const Color(0xFFE6E6FA).withValues(alpha: 0.5)), // Lavender Blob
            ),
          ),

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

          // 4. MAIN CONTENT
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    
                    // IDENTITY FORM
                    _buildLightGlassCard(
                      child: Column(
                        children: [
                          _buildLightInput(nameController, "Partner's Name", Icons.person_outline),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(child: _buildLightInput(ageController, "Age", Icons.calendar_today_outlined, isNumber: true)),
                              const SizedBox(width: 15),
                              Expanded(child: _buildLightInput(locationController, "Location", Icons.location_on_outlined)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    SizedBox(
                      height: 320, 
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // TAB 1: Screenshot Upload (With Heartbeat)
                          _buildLightGlassCard(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: isLoading ? null : uploadScreenshot,
                                  child: Container(
                                    height: 160, width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: colPinkDeep.withValues(alpha: 0.3), width: 2),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        ScaleTransition(
                                          scale: _heartbeatAnim,
                                          child: Icon(Icons.favorite_rounded, size: 60, color: colPinkDeep),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          "Tap to Upload Chat", 
                                          style: GoogleFonts.poppins(color: colTextMain, fontWeight: FontWeight.w600, fontSize: 16)
                                        ),
                                        Text(
                                          "Analyze screenshots instantly", 
                                          style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // TAB 2: Text Paste
                          _buildLightGlassCard(
                            child: Column(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.6), 
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(color: colPinkDeep.withValues(alpha: 0.2))
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: TextField(
                                      controller: textInputController, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top,
                                      style: TextStyle(color: colTextMain),
                                      cursorColor: colPinkDeep,
                                      decoration: const InputDecoration(
                                        hintText: "Paste chat history here...", 
                                        hintStyle: TextStyle(color: Colors.black26),
                                        border: InputBorder.none
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                SizedBox(
                                  width: double.infinity, height: 50,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      gradient: LinearGradient(colors: [colPinkDeep, Colors.purpleAccent]),
                                      boxShadow: [
                                        BoxShadow(color: colPinkDeep.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))
                                      ]
                                    ),
                                    child: ElevatedButton(
                                      onPressed: isLoading ? null : analyzeText,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                      ),
                                      child: const Text("ANALYZE LOVE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // RESULTS DISPLAY
                    if (isLoading)
                       CircularProgressIndicator(color: colPinkDeep)
                    else if (riskScore.isNotEmpty)
                      _buildLightGlassCard(
                        child: Column(
                          children: [
                            if (historyAlert.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 15),
                                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(historyAlert, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
                                  ],
                                ),
                              ),
                            
                            Text("Ghosting Risk", style: GoogleFonts.poppins(color: Colors.grey)),
                            Text(
                              riskScore,
                              style: GoogleFonts.poppins(
                                fontSize: 48, fontWeight: FontWeight.bold,
                                color: getRiskColor(rawRisk)
                              )
                            ),
                            Text(resultStatus.toUpperCase(), 
                              style: GoogleFonts.poppins(
                                fontSize: 20, fontWeight: FontWeight.bold, 
                                color: getRiskColor(rawRisk)
                              )
                            ),
                            const SizedBox(height: 15),
                            Container(
                              width: double.infinity, padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                              child: Text(debugInfo, style: TextStyle(fontFamily: "monospace", fontSize: 12, color: colTextMain.withValues(alpha: 0.7))),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildLightInput(TextEditingController controller, String label, IconData icon, {bool isNumber = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8), 
        borderRadius: BorderRadius.circular(15), 
        boxShadow: [
          BoxShadow(color: Colors.pink.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))
        ],
        border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller, 
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: TextStyle(color: colTextMain, fontWeight: FontWeight.w600),
        cursorColor: colPinkDeep,
        decoration: InputDecoration(
          labelText: label, labelStyle: TextStyle(color: Colors.grey.shade500), 
          prefixIcon: Icon(icon, color: colPinkDeep), 
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
        boxShadow: [ BoxShadow(color: color, blurRadius: 80, spreadRadius: 10) ],
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
            color: Colors.white.withValues(alpha: 0.4), // Light frosted glass
            borderRadius: BorderRadius.circular(20), 
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(color: const Color(0xFFE0C3FC).withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 0)
            ]
          ),
          child: child,
        ),
      ),
    );
  }
}

// Simple Model class for floating hearts
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