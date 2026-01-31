import 'package:flutter/material.dart';

/// Action buttons for sharing and favoriting the current affirmation.
class AffirmationActions extends StatelessWidget {
  final bool isFavorited;
  final bool enabled;
  final VoidCallback? onShare;
  final VoidCallback? onFavorite;

  const AffirmationActions({
    super.key,
    required this.isFavorited,
    required this.enabled,
    this.onShare,
    this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.ios_share_rounded),
          color: const Color(0xFF5C4B42),
          onPressed: enabled ? onShare : null,
          tooltip: 'Share',
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: Icon(
            isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          ),
          color: const Color(0xFFE07A6B),
          onPressed: enabled ? onFavorite : null,
          tooltip: 'Favorite',
        ),
      ],
    );
  }
}
