import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Georgia',
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF2D6A4F)),
      ),
      home: HomePage(),
    );
  }
}

// -------- Data Model --------
class DiseaseResult {
  final String disease;
  final double confidence;
  final String cause;
  final String prevention;
  final String treatment;
  final String advice;

  DiseaseResult({
    required this.disease,
    required this.confidence,
    required this.cause,
    required this.prevention,
    required this.treatment,
    required this.advice,
  });
}

// -------- Parse Suggestions Text --------
DiseaseResult parseResult(Map<String, dynamic> data) {
  final disease = data['disease'] ?? 'Unknown';
  final confidence = (data['confidence'] ?? 0).toDouble();
  final suggestions = data['suggestions'] ?? '';

  String cause = '';
  String prevention = '';
  String treatment = '';
  String advice = '';

  // Parse markdown-style bullet sections
  final lines = suggestions.split('\n');
  String currentSection = '';

  for (var line in lines) {
    final cleaned = line.replaceAll(RegExp(r'\*+'), '').trim();
    if (cleaned.isEmpty) continue;

    final lower = cleaned.toLowerCase();

    if (lower.startsWith('cause:')) {
      currentSection = 'cause';
      cause = cleaned.replaceFirst(RegExp(r'cause:', caseSensitive: false), '').trim();
    } else if (lower.startsWith('prevention:')) {
      currentSection = 'prevention';
      prevention = cleaned.replaceFirst(RegExp(r'prevention:', caseSensitive: false), '').trim();
    } else if (lower.startsWith('treatment:')) {
      currentSection = 'treatment';
      treatment = cleaned.replaceFirst(RegExp(r'treatment:', caseSensitive: false), '').trim();
    } else if (lower.startsWith('advice:')) {
      currentSection = 'advice';
      advice = cleaned.replaceFirst(RegExp(r'advice:', caseSensitive: false), '').trim();
    } else {
      // Continuation of previous section
      if (currentSection == 'cause') cause += ' $cleaned';
      if (currentSection == 'prevention') prevention += ' $cleaned';
      if (currentSection == 'treatment') treatment += ' $cleaned';
      if (currentSection == 'advice') advice += ' $cleaned';
    }
  }

  return DiseaseResult(
    disease: disease,
    confidence: confidence,
    cause: cause.trim(),
    prevention: prevention.trim(),
    treatment: treatment.trim(),
    advice: advice.trim(),
  );
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _image;
  Uint8List? _imageBytes;
  DiseaseResult? _result;
  bool _isLoading = false;
  String _statusMessage = "Upload or capture a leaf image to detect disease";
  final picker = ImagePicker();

  // -------- Capture from Camera --------
  Future captureImage() async {
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      if (kIsWeb) {
        _imageBytes = await pickedFile.readAsBytes();
      } else {
        _image = File(pickedFile.path);
      }
      setState(() {
        _result = null;
        _statusMessage = "Photo captured. Tap Predict to analyze.";
      });
    }
  }

  // -------- Select from Gallery --------
  Future pickFromGallery() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kIsWeb) {
        _imageBytes = await pickedFile.readAsBytes();
      } else {
        _image = File(pickedFile.path);
      }
      setState(() {
        _result = null;
        _statusMessage = "Image selected. Tap Predict to analyze.";
      });
    }
  }

  // -------- Upload & Predict --------
  Future uploadImage() async {
    if ((_image == null && _imageBytes == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select an image first")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Analyzing image...";
    });

    try {
      var uri = kIsWeb
          ? Uri.parse("http://127.0.0.1:8000/predict")
          : Uri.parse("http://192.168.X.X:8000/predict"); // ← replace with your IP

      var request = http.MultipartRequest("POST", uri);

      if (kIsWeb && _imageBytes != null) {
        request.files.add(http.MultipartFile.fromBytes('file', _imageBytes!, filename: "image.jpg"));
      } else if (_image != null) {
        request.files.add(await http.MultipartFile.fromPath('file', _image!.path));
      }

      var response = await request.send();
      var res = await response.stream.bytesToString();
      var data = json.decode(res);

      setState(() {
        _result = parseResult(data);
        _statusMessage = "Analysis complete!";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "Error: ${e.toString()}";
      });
    }
  }

  // -------- Colors --------
  static const Color kGreen = Color(0xFF2D6A4F);
  static const Color kLightGreen = Color(0xFF52B788);
  static const Color kBg = Color(0xFFF0F7F4);
  static const Color kCard = Color(0xFFFFFFFF);

  // -------- Info Card Widget --------
  Widget _infoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          SizedBox(width: 14),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500],
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  content.isEmpty ? "No information available." : content,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[800],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------- Disease Badge --------
  Widget _diseaseBanner(DiseaseResult result) {
    final isHealthy = result.disease.toLowerCase() == 'healthy';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHealthy
              ? [Color(0xFF40916C), Color(0xFF52B788)]
              : [Color(0xFFB5451B), Color(0xFFE76F51)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isHealthy ? Color(0xFF40916C) : Color(0xFFB5451B)).withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 6),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isHealthy ? Icons.check_circle : Icons.coronavirus,
              color: Colors.white,
              size: 30,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Detected Disease",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  result.disease.toUpperCase().replaceAll('_', ' '),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Confidence badge
          Column(
            children: [
              Text(
                "${result.confidence.toStringAsFixed(1)}%",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "Confidence",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------- Main UI --------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: kGreen,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 12,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: "History"),
          BottomNavigationBarItem(icon: Icon(Icons.info_rounded), label: "Info"),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // -------- Header --------
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kGreen,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.eco_rounded, color: Colors.white, size: 28),
                  ),
                  SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Leaf",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: kGreen,
                        ),
                      ),
                      Text(
                        "Disease Predictor",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 24),

              // -------- Image Card --------
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (_image != null || _imageBytes != null)
                        ? kLightGreen
                        : Colors.grey.shade200,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: kIsWeb && _imageBytes != null
                      ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                      : !kIsWeb && _image != null
                          ? Image.file(_image!, fit: BoxFit.cover)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_rounded,
                                    size: 60, color: Colors.grey[300]),
                                SizedBox(height: 12),
                                Text(
                                  "No image selected",
                                  style: TextStyle(color: Colors.grey[400], fontSize: 15),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  "Use buttons below to add a leaf photo",
                                  style: TextStyle(color: Colors.grey[300], fontSize: 12),
                                ),
                              ],
                            ),
                ),
              ),

              SizedBox(height: 16),

              // -------- Status Text --------
              Center(
                child: Text(
                  _statusMessage,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),

              SizedBox(height: 16),

              // -------- Action Buttons --------
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      icon: Icons.camera_alt_rounded,
                      label: "Camera",
                      color: kGreen,
                      onPressed: captureImage,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _actionButton(
                      icon: Icons.photo_library_rounded,
                      label: "Gallery",
                      color: Color(0xFF2B7DB5),
                      onPressed: pickFromGallery,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              // -------- Predict Button --------
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : uploadImage,
                  icon: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(Icons.analytics_rounded, color: Colors.white),
                  label: Text(
                    _isLoading ? "Analyzing..." : "Predict Disease",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFE76F00),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                    shadowColor: Color(0xFFE76F00).withOpacity(0.4),
                  ),
                ),
              ),

              SizedBox(height: 28),

              // -------- Results Section --------
              if (_result != null) ...[
                Text(
                  "ANALYSIS RESULT",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500],
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 12),

                // Disease banner
                _diseaseBanner(_result!),
                SizedBox(height: 20),

                Text(
                  "DISEASE INFORMATION",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500],
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 12),

                // Info cards
                _infoCard(
                  icon: Icons.biotech_rounded,
                  title: "CAUSE",
                  content: _result!.cause,
                  iconColor: Color(0xFFD62828),
                  iconBg: Color(0xFFFFEDED),
                ),
                _infoCard(
                  icon: Icons.shield_rounded,
                  title: "PREVENTION",
                  content: _result!.prevention,
                  iconColor: Color(0xFF2D6A4F),
                  iconBg: Color(0xFFD8F3DC),
                ),
                _infoCard(
                  icon: Icons.healing_rounded,
                  title: "TREATMENT",
                  content: _result!.treatment,
                  iconColor: Color(0xFF0077B6),
                  iconBg: Color(0xFFDBEEF8),
                ),
                _infoCard(
                  icon: Icons.tips_and_updates_rounded,
                  title: "ADVICE",
                  content: _result!.advice,
                  iconColor: Color(0xFFE07C00),
                  iconBg: Color(0xFFFFF3E0),
                ),

                SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(
          label,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
          shadowColor: color.withOpacity(0.4),
        ),
      ),
    );
  }
}