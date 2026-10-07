// ============================================================
// history_page.dart
// Prediction History — in-memory only, no database/backend.
// ============================================================

import 'dart:typed_data';

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
// HISTORY ITEM MODEL
// ============================================================

class PredictionHistoryItem {
  final Uint8List imageBytes;
  final String disease;
  final double confidence;
  final DateTime timestamp;

  PredictionHistoryItem({
    required this.imageBytes,
    required this.disease,
    required this.confidence,
    required this.timestamp,
  });
}

// ============================================================
// DATE FORMAT HELPER  (no intl dependency)
// ============================================================

String _formatTimestamp(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  final day = dt.day.toString().padLeft(2, '0');
  final month = months[dt.month - 1];
  final year = dt.year;

  int hour = dt.hour % 12;
  if (hour == 0) hour = 12;

  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';

  return '$day $month $year, $hour:$minute $period';
}

// ============================================================
// HISTORY PAGE
// ============================================================

class HistoryPage extends StatelessWidget {
  final List<PredictionHistoryItem> history;
  final VoidCallback onClear;
  final String language;

  const HistoryPage({
    super.key,
    required this.history,
    required this.onClear,
    required this.language,
  });

  static const Color kGreen = Color(0xFF2D6A4F);
  static const Color kBg = Color(0xFFF0F7F4);
  static const Color kCard = Color(0xFFFFFFFF);

  // ------------------------------------------------------------
  // CLEAR CONFIRMATION
  // ------------------------------------------------------------

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          _tr('clear_history_confirm_title', 'Clear history?'),
        ),
        content: Text(
          _tr(
            'clear_history_confirm_body',
            'This will remove all prediction results from this session. This cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(_tr('cancel', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              _tr('clear', 'Clear'),
              style: const TextStyle(color: Color(0xFFD62828)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onClear();
    }
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

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
                        Icons.history_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _tr('prediction_history', 'Prediction History'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: kGreen,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (history.isNotEmpty)
                      IconButton(
                        tooltip: _tr('clear_history', 'Clear history'),
                        onPressed: () => _confirmClear(context),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFD62828),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // ==========================================
                // EMPTY STATE
                // ==========================================
                if (history.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200, width: 2),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _tr('no_predictions_yet', 'No predictions yet'),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          child: Text(
                            _tr(
                              'no_predictions_sub',
                              'Your disease detection results will appear here.',
                            ),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  )

                // ==========================================
                // HISTORY LIST
                // ==========================================
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[index];
                      final isHealthy = item.disease.toLowerCase() == 'healthy';

                      String displayName = item.disease;
                      try {
                        displayName = translateDisease(item.disease);
                      } catch (_) {
                        displayName = item.disease;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: item.imageBytes.isNotEmpty
                                  ? Image.memory(
                                      item.imageBytes,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 56,
                                      height: 56,
                                      color: kBg,
                                      child: Icon(
                                        Icons.image_not_supported_rounded,
                                        color: Colors.grey[300],
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isHealthy
                                          ? const Color(0xFF2D6A4F)
                                          : const Color(0xFFB5451B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_tr('confidence', 'Confidence')}: '
                                    '${item.confidence.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatTimestamp(item.timestamp),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}