// ============================================================
// main.dart
// Groundnut Leaf Disease Recognition
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'translations.dart';
import 'history_page.dart';
import 'info_page.dart';

// ============================================================
// NETWORK CONFIG
// ============================================================
//
// IMPORTANT:
// Replace this with your deployed FastAPI HTTPS URL.
//
// Example:
// const String baseUrl =
//     "https://groundnut-disease-api.onrender.com";
//
// DO NOT use:
// localhost
// 127.0.0.1
// 192.168.x.x
//
// for the final deployed application.
// ============================================================

const String baseUrl = "https://leaf-disease-prediction-deployment-5.onrender.com";
// ============================================================
// ENTRY POINT
// ============================================================

void main() {
  runApp(const MyApp());
}

// ============================================================
// APP
// ============================================================

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _language = "en";
  void _changeLanguage(String lang) {
    setState(() {
      _language = lang;
      currentLanguage = lang;
    });
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        fontFamily: 'Georgia',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D6A4F),
        ),
      ),

      home: RootShell(
        language: _language,
        onLanguageChanged: _changeLanguage,
      ),
    );
  }
}

// ============================================================
// ROOT SHELL
// ------------------------------------------------------------
// Owns the bottom navigation and the in-memory (session-only)
// prediction history. Uses IndexedStack so switching tabs does
// NOT rebuild/reset the Home page's camera/prediction state.
// No database, no backend endpoint — history lives only in
// this widget's memory for the current app session.
// ============================================================

class RootShell extends StatefulWidget {
  final String language;
  final Function(String) onLanguageChanged;

  const RootShell({
    super.key,
    required this.language,
    required this.onLanguageChanged,
  });

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _selectedIndex = 0;

  final List<PredictionHistoryItem> _history = [];

  static const Color kGreen = Color(0xFF2D6A4F);
  static const Color kBg = Color(0xFFF0F7F4);

  void _addHistoryItem(PredictionHistoryItem item) {
    setState(() {
      // Newest prediction first.
      _history.insert(0, item);
    });
  }

  void _clearHistory() {
    setState(() {
      _history.clear();
    });
  }

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,

      // ========================================================
      // BOTTOM NAVIGATION
      // ========================================================

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,

        onTap: _onNavTap,

        selectedItemColor: kGreen,

        unselectedItemColor: Colors.grey,

        backgroundColor: Colors.white,

        elevation: 12,

        type: BottomNavigationBarType.fixed,

        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_rounded),
            label: t("home"),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history_rounded),
            label: t("history"),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.info_rounded),
            label: t("info"),
          ),
        ],
      ),

      // ========================================================
      // BODY  —  IndexedStack keeps each tab's state alive
      // ========================================================

      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            HomePage(
              language: widget.language,
              onLanguageChanged: widget.onLanguageChanged,
              onPredictionAdded: _addHistoryItem,
            ),
            HistoryPage(
              history: _history,
              onClear: _clearHistory,
              language: widget.language,
            ),
            InfoPage(
              language: widget.language,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DATA MODEL
// ============================================================

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

// ============================================================
// PARSE API RESPONSE
// ============================================================

DiseaseResult parseResult(Map<String, dynamic> data) {
  final disease = data['disease']?.toString() ?? 'Unknown';

  final confidenceValue = data['confidence'];

  double confidence = 0;

  if (confidenceValue is num) {
    confidence = confidenceValue.toDouble();
  } else {
    confidence = double.tryParse(
          confidenceValue?.toString() ?? '0',
        ) ??
        0;
  }

  final suggestions = data['suggestions']?.toString() ?? '';

  String cause = '';
  String prevention = '';
  String treatment = '';
  String advice = '';

  String currentSection = '';

  for (var line in suggestions.split('\n')) {
    final cleaned = line
        .replaceAll(RegExp(r'\*+'), '')
        .trim();

    if (cleaned.isEmpty) {
      continue;
    }

    final lower = cleaned.toLowerCase();

    if (lower.startsWith('cause:')) {
      currentSection = 'cause';

      cause = cleaned
          .replaceFirst(
            RegExp(r'cause:', caseSensitive: false),
            '',
          )
          .trim();
    } else if (lower.startsWith('prevention:')) {
      currentSection = 'prevention';

      prevention = cleaned
          .replaceFirst(
            RegExp(r'prevention:', caseSensitive: false),
            '',
          )
          .trim();
    } else if (lower.startsWith('treatment:')) {
      currentSection = 'treatment';

      treatment = cleaned
          .replaceFirst(
            RegExp(r'treatment:', caseSensitive: false),
            '',
          )
          .trim();
    } else if (lower.startsWith('advice:')) {
      currentSection = 'advice';

      advice = cleaned
          .replaceFirst(
            RegExp(r'advice:', caseSensitive: false),
            '',
          )
          .trim();
    } else {
      if (currentSection == 'cause') {
        cause += ' $cleaned';
      }

      if (currentSection == 'prevention') {
        prevention += ' $cleaned';
      }

      if (currentSection == 'treatment') {
        treatment += ' $cleaned';
      }

      if (currentSection == 'advice') {
        advice += ' $cleaned';
      }
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

// ============================================================
// HOME PAGE
// ------------------------------------------------------------
// NOTE: This widget now returns its content WITHOUT its own
// Scaffold/BottomNavigationBar — RootShell provides those so
// that Home/History/Info can share one bottom nav bar. All
// camera/gallery/predict/multilingual logic is unchanged.
// ============================================================

class HomePage extends StatefulWidget {
  final String language;
  final Function(String) onLanguageChanged;
  final void Function(PredictionHistoryItem) onPredictionAdded;

  const HomePage({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    required this.onPredictionAdded,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

// ============================================================
// HOME PAGE STATE
// ============================================================

class _HomePageState extends State<HomePage> {
  File? _image;

  Uint8List? _imageBytes;

  DiseaseResult? _result;

  bool _isLoading = false;

  String _statusMessage = "";

  final ImagePicker picker = ImagePicker();

  // ============================================================
  // COLORS
  // ============================================================

  static const Color kGreen = Color(0xFF2D6A4F);

  static const Color kLightGreen = Color(0xFF52B788);

  static const Color kBg = Color(0xFFF0F7F4);

  static const Color kCard = Color(0xFFFFFFFF);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _statusMessage = t("status_default");
  }

  // ============================================================
  // LANGUAGE CHANGE
  // ============================================================

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.language != widget.language) {
      setState(() {
        _statusMessage = t("status_default");
      });
    }
  }

  // ============================================================
  // CAMERA
  // ============================================================

  Future<void> captureImage() async {
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (pickedFile == null) {
        return;
      }

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();

        if (!mounted) return;

        setState(() {
          _imageBytes = bytes;
          _image = null;
          _result = null;
          _statusMessage = t("status_captured");
        });
      } else {
        if (!mounted) return;

        setState(() {
          _image = File(pickedFile.path);
          _imageBytes = null;
          _result = null;
          _statusMessage = t("status_captured");
        });
      }
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        "${t('status_error')} $e",
      );
    }
  }

  // ============================================================
  // GALLERY
  // ============================================================

  Future<void> pickFromGallery() async {
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile == null) {
        return;
      }

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();

        if (!mounted) return;

        setState(() {
          _imageBytes = bytes;
          _image = null;
          _result = null;
          _statusMessage = t("status_selected");
        });
      } else {
        if (!mounted) return;

        setState(() {
          _image = File(pickedFile.path);
          _imageBytes = null;
          _result = null;
          _statusMessage = t("status_selected");
        });
      }
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        "${t('status_error')} $e",
      );
    }
  }

  // ============================================================
  // PREDICT
  // ============================================================

  Future<void> uploadImage() async {
    if (_image == null && _imageBytes == null) {
      _showSnackBar(
        t("select_image_first"),
      );

      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = t("status_analyzing");
    });

    try {
      final cleanBaseUrl = baseUrl.endsWith("/")
          ? baseUrl.substring(
              0,
              baseUrl.length - 1,
            )
          : baseUrl;

      final uri = Uri.parse(
        "$cleanBaseUrl/predict",
      ).replace(
        queryParameters: {
          "language": widget.language,
        },
      );

      final request = http.MultipartRequest(
        "POST",
        uri,
      );

      // --------------------------------------------------------
      // WEB IMAGE
      // --------------------------------------------------------

      if (kIsWeb && _imageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            _imageBytes!,
            filename: "groundnut_leaf.jpg",
          ),
        );
      }

      // --------------------------------------------------------
      // NATIVE IMAGE
      // --------------------------------------------------------

      else if (!kIsWeb && _image != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            _image!.path,
          ),
        );
      }

      // --------------------------------------------------------
      // SEND REQUEST
      // --------------------------------------------------------

      final streamedResponse = await request
          .send()
          .timeout(
            const Duration(seconds: 60),
          );

      final responseBody =
          await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode < 200 ||
          streamedResponse.statusCode >= 300) {
        throw Exception(
          "Server error: ${streamedResponse.statusCode}\n"
          "$responseBody",
        );
      }

      final decoded = json.decode(
        responseBody,
      );

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          "Invalid response from server.",
        );
      }

      final parsedResult = parseResult(
        decoded,
      );

      // --------------------------------------------------------
      // BUILD THUMBNAIL BYTES FOR HISTORY  (web + native)
      // --------------------------------------------------------

      Uint8List thumbnailBytes;

      if (kIsWeb && _imageBytes != null) {
        thumbnailBytes = _imageBytes!;
      } else if (!kIsWeb && _image != null) {
        thumbnailBytes = await _image!.readAsBytes();
      } else {
        thumbnailBytes = Uint8List(0);
      }

      if (!mounted) return;

      setState(() {
        _result = parsedResult;
        _statusMessage = t("status_done");
        _isLoading = false;
      });

      // --------------------------------------------------------
      // ADD TO SESSION HISTORY  (in-memory only, no database)
      // --------------------------------------------------------

      widget.onPredictionAdded(
        PredictionHistoryItem(
          imageBytes: thumbnailBytes,
          disease: parsedResult.disease,
          confidence: parsedResult.confidence,
          timestamp: DateTime.now(),
        ),
      );
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _statusMessage = t("status_error");
      });

      _showSnackBar(
        "${t('status_error')} "
        "Request timed out. Please check your backend.",
      );
    } on SocketException {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _statusMessage = t("status_error");
      });

      _showSnackBar(
        "${t('status_error')} "
        "Could not connect to the server.",
      );
    } on FormatException {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _statusMessage = t("status_error");
      });

      _showSnackBar(
        "${t('status_error')} "
        "Invalid response received from server.",
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _statusMessage = t("status_error");
      });

      _showSnackBar(
        "${t('status_error')} $e",
      );
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ============================================================
  // LANGUAGE DROPDOWN
  // ============================================================

  Widget _languageDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kLightGreen,
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: widget.language,

          icon: const Icon(
            Icons.language_rounded,
            color: kGreen,
            size: 18,
          ),

          style: const TextStyle(
            color: kGreen,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),

          items: availableLanguages.map(
            (lang) {
              return DropdownMenuItem<String>(
                value: lang["code"],
                child: Text(
                  lang["label"]!,
                ),
              );
            },
          ).toList(),

          onChanged: (val) {
            if (val != null) {
              currentLanguage = val;

              widget.onLanguageChanged(
                val,
              );
            }
          },
        ),
      ),
    );
  }

  // ============================================================
  // INFO CARD
  // ============================================================

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Container(
            width: 44,
            height: 44,

            decoration: BoxDecoration(
              color: iconBg,
              borderRadius:
                  BorderRadius.circular(12),
            ),

            child: Icon(
              icon,
              color: iconColor,
              size: 22,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500],
                    letterSpacing: 1.0,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  content.isEmpty
                      ? t("no_info")
                      : content,

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

  // ============================================================
  // DISEASE BANNER
  // ============================================================

  Widget _diseaseBanner(
    DiseaseResult result,
  ) {
    final isHealthy =
        result.disease.toLowerCase() ==
            'healthy';

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.symmetric(
        vertical: 20,
        horizontal: 20,
      ),

      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHealthy
              ? const [
                  Color(0xFF40916C),
                  Color(0xFF52B788),
                ]
              : const [
                  Color(0xFFB5451B),
                  Color(0xFFE76F51),
                ],

          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        borderRadius:
            BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: (isHealthy
                    ? const Color(0xFF40916C)
                    : const Color(0xFFB5451B))
                .withOpacity(0.3),

            blurRadius: 12,

            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,

            decoration: BoxDecoration(
              color:
                  Colors.white.withOpacity(0.2),

              borderRadius:
                  BorderRadius.circular(14),
            ),

            child: Icon(
              isHealthy
                  ? Icons.check_circle
                  : Icons.coronavirus,

              color: Colors.white,

              size: 30,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  t("detected_disease"),

                  style: TextStyle(
                    color:
                        Colors.white.withOpacity(0.8),

                    fontSize: 12,

                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  translateDisease(
                    result.disease,
                  ).toUpperCase(),

                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),

                  overflow:
                      TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Column(
            children: [
              Text(
                "${result.confidence.toStringAsFixed(1)}%",

                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Text(
                t("confidence"),

                style: TextStyle(
                  color:
                      Colors.white.withOpacity(0.8),

                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTION BUTTON
  // ============================================================

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

        icon: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),

        label: FittedBox(
          fit: BoxFit.scaleDown,

          child: Text(
            label,

            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        style: ElevatedButton.styleFrom(
          backgroundColor: color,

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),

          elevation: 3,

          shadowColor:
              color.withOpacity(0.4),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _header(double width) {
    final bool isSmallScreen =
        width < 450;

    if (isSmallScreen) {
      return Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.all(10),

                decoration: BoxDecoration(
                  color: kGreen,
                  borderRadius:
                      BorderRadius.circular(14),
                ),

                child: const Icon(
                  Icons.eco_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      t("app_name"),

                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                        color: kGreen,
                      ),

                      overflow:
                          TextOverflow.ellipsis,
                    ),

                    Text(
                      t("app_subtitle"),

                      style: TextStyle(
                        color:
                            Colors.grey[600],
                        fontSize: 12,
                      ),

                      overflow:
                          TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _languageDropdown(),
        ],
      );
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),

          decoration: BoxDecoration(
            color: kGreen,
            borderRadius:
                BorderRadius.circular(14),
          ),

          child: const Icon(
            Icons.eco_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Text(
                t("app_name"),

                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: kGreen,
                ),

                overflow:
                    TextOverflow.ellipsis,
              ),

              Text(
                t("app_subtitle"),

                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),

                overflow:
                    TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        _languageDropdown(),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ------------------------------------------------------------
  // NOTE: Scaffold + BottomNavigationBar were moved up to
  // RootShell so Home/History/Info can share one nav bar.
  // Everything else below is unchanged from the original.
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    final screenHeight =
        MediaQuery.of(context).size.height;

    final previewHeight =
        (screenHeight * 0.26)
            .clamp(160.0, 240.0);

    return Container(
      color: kBg,
      width: double.infinity,
      height: double.infinity,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal:
              screenWidth < 400 ? 14 : 20,
          vertical: 20,
        ),

        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 640,
            ),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                // ==================================================
                // HEADER
                // ==================================================

                _header(screenWidth),

                const SizedBox(height: 24),

                // ==================================================
                // IMAGE PREVIEW
                // ==================================================

                Container(
                  height: previewHeight,

                  width: double.infinity,

                  decoration:
                      BoxDecoration(
                    color: Colors.white,

                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),

                    border: Border.all(
                      color: (_image != null ||
                              _imageBytes != null)
                          ? kLightGreen
                          : Colors
                              .grey
                              .shade200,

                      width: 2,
                    ),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(0.06),

                        blurRadius: 12,

                        offset:
                            const Offset(0, 4),
                      ),
                    ],
                  ),

                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),

                    child:
                        kIsWeb &&
                                _imageBytes !=
                                    null
                            ? Image.memory(
                                _imageBytes!,
                                fit: BoxFit.cover,
                              )
                            : !kIsWeb &&
                                    _image !=
                                        null
                                ? Image.file(
                                    _image!,
                                    fit: BoxFit
                                        .cover,
                                  )
                                : Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .center,

                                    children: [
                                      Icon(
                                        Icons
                                            .add_photo_alternate_rounded,

                                        size: 60,

                                        color: Colors
                                            .grey[300],
                                      ),

                                      const SizedBox(
                                        height: 12,
                                      ),

                                      Text(
                                        t(
                                          "no_image",
                                        ),

                                        style:
                                            TextStyle(
                                          color: Colors
                                              .grey[400],

                                          fontSize:
                                              15,
                                        ),
                                      ),

                                      const SizedBox(
                                        height: 6,
                                      ),

                                      Padding(
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                          horizontal:
                                              20,
                                        ),

                                        child: Text(
                                          t(
                                            "no_image_sub",
                                          ),

                                          style:
                                              TextStyle(
                                            color: Colors
                                                .grey[300],

                                            fontSize:
                                                12,
                                          ),

                                          textAlign:
                                              TextAlign
                                                  .center,
                                        ),
                                      ),
                                    ],
                                  ),
                  ),
                ),

                const SizedBox(height: 14),

                // ==================================================
                // STATUS
                // ==================================================

                Center(
                  child: Text(
                    _statusMessage,

                    style: TextStyle(
                      color:
                          Colors.grey[600],
                      fontSize: 13,
                    ),

                    textAlign:
                        TextAlign.center,
                  ),
                ),

                const SizedBox(height: 16),

                // ==================================================
                // CAMERA + GALLERY
                // ==================================================

                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        icon: Icons
                            .camera_alt_rounded,

                        label:
                            t("camera"),

                        color: kGreen,

                        onPressed:
                            captureImage,
                      ),
                    ),

                    const SizedBox(
                      width: 12,
                    ),

                    Expanded(
                      child: _actionButton(
                        icon: Icons
                            .photo_library_rounded,

                        label:
                            t("gallery"),

                        color:
                            const Color(
                          0xFF2B7DB5,
                        ),

                        onPressed:
                            pickFromGallery,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ==================================================
                // PREDICT BUTTON
                // ==================================================

                SizedBox(
                  width: double.infinity,
                  height: 54,

                  child:
                      ElevatedButton.icon(
                    onPressed:
                        _isLoading
                            ? null
                            : uploadImage,

                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,

                            child:
                                CircularProgressIndicator(
                              color:
                                  Colors.white,

                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons
                                .analytics_rounded,
                            color:
                                Colors.white,
                          ),

                    label: Text(
                      _isLoading
                          ? t("analyzing")
                          : t("predict"),

                      style:
                          const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Colors.white,
                      ),
                    ),

                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(
                        0xFFE76F00,
                      ),

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),

                      elevation: 4,

                      shadowColor:
                          const Color(
                        0xFFE76F00,
                      ).withOpacity(0.4),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ==================================================
                // RESULTS
                // ==================================================

                if (_result != null) ...[
                  Text(
                    t("analysis_result"),

                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Colors.grey[500],
                      letterSpacing: 1.5,
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  _diseaseBanner(
                    _result!,
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  Text(
                    t("disease_information"),

                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Colors.grey[500],
                      letterSpacing: 1.5,
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  // ------------------------------------------------
                  // CAUSE
                  // ------------------------------------------------

                  _infoCard(
                    icon:
                        Icons.biotech_rounded,

                    title:
                        t("cause"),

                    content:
                        _result!.cause,

                    iconColor:
                        const Color(
                      0xFFD62828,
                    ),

                    iconBg:
                        const Color(
                      0xFFFFEDED,
                    ),
                  ),

                  // ------------------------------------------------
                  // PREVENTION
                  // ------------------------------------------------

                  _infoCard(
                    icon:
                        Icons.shield_rounded,

                    title:
                        t("prevention"),

                    content:
                        _result!.prevention,

                    iconColor:
                        const Color(
                      0xFF2D6A4F,
                    ),

                    iconBg:
                        const Color(
                      0xFFD8F3DC,
                    ),
                  ),

                  // ------------------------------------------------
                  // TREATMENT
                  // ------------------------------------------------

                  _infoCard(
                    icon:
                        Icons.healing_rounded,

                    title:
                        t("treatment"),

                    content:
                        _result!.treatment,

                    iconColor:
                        const Color(
                      0xFF0077B6,
                    ),

                    iconBg:
                        const Color(
                      0xFFDBEEF8,
                    ),
                  ),

                  // ------------------------------------------------
                  // ADVICE
                  // ------------------------------------------------

                  _infoCard(
                    icon: Icons
                        .tips_and_updates_rounded,

                    title:
                        t("advice"),

                    content:
                        _result!.advice,

                    iconColor:
                        const Color(
                      0xFFE07C00,
                    ),

                    iconBg:
                        const Color(
                      0xFFFFF3E0,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}