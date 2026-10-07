// ============================================================
// info_page.dart
// About / How-it-works page — fully static, no backend/database.
// ============================================================

import 'package:flutter/material.dart';

import 'translations.dart';

// ============================================================
// SAFE TRANSLATION HELPER
// ------------------------------------------------------------
// Falls back to the given English string if the key hasn't
// been added to translations.dart yet (or t() throws for any
// reason), so this page never crashes on a missing key.
// ============================================================

String _tr(String key, String fallback) {
  try {
    final value = t(key);
    // t() returns the key itself when no translation exists for it —
    // treat that (or an empty string) as "not translated yet".
    if (value.trim().isEmpty || value == key) return fallback;
    return value;
  } catch (_) {
    return fallback;
  }
}

// ============================================================
// INFO PAGE
// ============================================================

class InfoPage extends StatelessWidget {
  final String language;

  const InfoPage({
    super.key,
    required this.language,
  });

  static const Color kGreen = Color(0xFF2D6A4F);
  static const Color kLightGreen = Color(0xFF52B788);
  static const Color kBg = Color(0xFFF0F7F4);
  static const Color kCard = Color(0xFFFFFFFF);

  // ------------------------------------------------------------
  // SECTION CARD
  // ------------------------------------------------------------

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD8F3DC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: kGreen, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: kGreen,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // NUMBERED STEP ROW
  // ------------------------------------------------------------

  Widget _stepRow(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: kLightGreen,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final steps = [
      _tr(
        'how_it_works_step1',
        'Capture or upload a groundnut leaf image.',
      ),
      _tr(
        'how_it_works_step2',
        'The image is sent to the disease detection model.',
      ),
      _tr(
        'how_it_works_step3',
        'EfficientNetV2 and ConvNeXt analyze the image.',
      ),
      _tr(
        'how_it_works_step4',
        'A Logistic Regression meta-classifier generates the final prediction.',
      ),
      _tr(
        'how_it_works_step5',
        'The application displays the predicted disease and confidence score.',
      ),
      _tr(
        'how_it_works_step6',
        'AI-powered disease information and recommendations are provided.',
      ),
    ];

    return Container(
      color: kBg,
      width: double.infinity,
      height: double.infinity,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth < 400 ? 14 : 20,
          vertical: 20,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // HEADER
                // ==========================================
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kGreen,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _tr('app_name', 'CropGuard'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: kGreen,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ==========================================
                // ABOUT
                // ==========================================
                _sectionCard(
                  icon: Icons.info_outline_rounded,
                  title: _tr('about_cropguard_title', 'ABOUT CROPGUARD'),
                  child: Text(
                    _tr(
                      'about_cropguard_body',
                      'CropGuard is an AI-powered crop leaf disease detection '
                          'application designed to help users identify groundnut '
                          'leaf diseases from images.',
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.5,
                    ),
                  ),
                ),

                // ==========================================
                // HOW IT WORKS
                // ==========================================
                _sectionCard(
                  icon: Icons.auto_awesome_rounded,
                  title: _tr('how_it_works_title', 'HOW IT WORKS'),
                  child: Column(
                    children: [
                      for (var i = 0; i < steps.length; i++)
                        _stepRow(i + 1, steps[i]),
                    ],
                  ),
                ),

                // ==========================================
                // MODEL & TECH
                // ==========================================
                _sectionCard(
                  icon: Icons.memory_rounded,
                  title: _tr('model_details_title', 'MODEL DETAILS'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kvRow(
                        _tr('model_base_learners', 'Base learners'),
                        'EfficientNetV2 + ConvNeXt',
                      ),
                      _kvRow(
                        _tr('model_meta_classifier', 'Meta-classifier'),
                        _tr('model_logistic_regression', 'Logistic Regression'),
                      ),
                      _kvRow(
                        _tr('model_categories', 'Disease categories'),
                        '7',
                      ),
                      _kvRow(
                        _tr('model_advice_engine', 'Advice engine'),
                        'Groq AI',
                      ),
                    ],
                  ),
                ),

                // ==========================================
                // SUPPORTED LANGUAGES
                // ==========================================
                _sectionCard(
                  icon: Icons.language_rounded,
                  title: _tr('supported_languages_title', 'SUPPORTED LANGUAGES'),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _langChip('English'),
                      _langChip('ಕನ್ನಡ (Kannada)'),
                      _langChip('हिन्दी (Hindi)'),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kvRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              key,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _langChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFD8F3DC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: kGreen,
        ),
      ),
    );
  }
}