import 'package:flutter/material.dart';

/// Data model for an affirmation item displayed on the home page.
class AffirmationItem {
  final String id;
  final String text;
  final String category;
  final String? themeId;
  final String? themeName;

  const AffirmationItem({
    required this.id,
    required this.text,
    required this.category,
    this.themeId,
    this.themeName,
  });

  String get displayTheme {
    final name = themeName?.trim();
    if (name == null || name.isEmpty) return '';
    return name.toUpperCase();
  }

  AffirmationItem copyWith({String? themeName}) {
    return AffirmationItem(
      id: id,
      text: text,
      category: category,
      themeId: themeId,
      themeName: themeName ?? this.themeName,
    );
  }

  factory AffirmationItem.fromRow(Map row) {
    return AffirmationItem(
      id: row['id']?.toString() ?? '',
      text: row['text']?.toString().trim() ?? '',
      category: row['category']?.toString().trim() ?? 'daily focus',
      themeId: row['theme_id']?.toString(),
    );
  }
}

/// A card displaying a single affirmation with theme label and styling.
class AffirmationCard extends StatelessWidget {
  final AffirmationItem item;
  final double opacity;
  final double scale;
  final GlobalKey? repaintKey;

  const AffirmationCard({
    super.key,
    required this.item,
    this.opacity = 1.0,
    this.scale = 1.0,
    this.repaintKey,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final themeLabel = item.displayTheme;

    return Center(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.12),
            child: RepaintBoundary(
              key: repaintKey,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6EEE7),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFE5D6CB),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (themeLabel.isNotEmpty)
                      Text(
                        themeLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.4,
                          color: Color(0xFF8B7C73),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (themeLabel.isNotEmpty) const SizedBox(height: 10),
                    Text(
                      item.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 30,
                        height: 1.3,
                        fontFamily: 'serif',
                        color: Color(0xFF4B3C36),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
