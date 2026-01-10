// lib/pages/new_session/session_overlay.dart
import 'package:flutter/material.dart';

class SessionOverlay extends StatelessWidget {
  const SessionOverlay({
    super.key,
    required this.showLiveHud,
    required this.showSaving,
    required this.currentAffIdx,
    required this.totalAffirmations,
    required this.affirmationSpan,
    required this.fallbackText,
    required this.micNeedsRestart,
    required this.isMicListening,
    required this.isMicTransitioning,
    required this.onMicTap,

    // Favorite
    required this.onFavorite,
    required this.isFavorited,

    required this.onClose,
    required this.statusText,
  });

  final bool showLiveHud;
  final bool showSaving;
  final int currentAffIdx;
  final int totalAffirmations;
  final InlineSpan? affirmationSpan;
  final String fallbackText;

  final bool micNeedsRestart;
  final bool isMicListening;
  final bool isMicTransitioning;
  final VoidCallback onMicTap;

  // Favorite
  final VoidCallback onFavorite;
  final bool isFavorited;

  final VoidCallback onClose;
  final String? statusText;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0x66C8A34A),
                  Colors.transparent,
                  Colors.transparent,
                  const Color(0x88C8A34A),
                ],
                stops: const [0, 0.22, 0.78, 1],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (showLiveHud)
                Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${currentAffIdx + 1} of $totalAffirmations',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: onClose,
                          child: Ink(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              if (showLiveHud) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1F9),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFF2D59C),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'CONFIDENCE',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    letterSpacing: 1.2,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),

                          // Heart (favorite)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: onFavorite,
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  isFavorited
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: isFavorited
                                      ? Colors.redAccent
                                      : Colors.black54,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (affirmationSpan != null)
                        RichText(
                          textAlign: TextAlign.center,
                          text: affirmationSpan!,
                        )
                      else
                        Text(
                          fallbackText,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          totalAffirmations,
                          (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 6,
                            width: 6,
                            decoration: BoxDecoration(
                              color: i == currentAffIdx
                                  ? Colors.black54
                                  : Colors.black26,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: isMicTransitioning ? null : onMicTap,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.mic_rounded,
                          size: 28,
                          color: isMicListening
                              ? Colors.green
                              : (isMicTransitioning
                                  ? Colors.grey
                                  : Colors.redAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      micNeedsRestart
                          ? 'Mic paused. Tap to resume listening'
                          : 'Say each affirmation out loud 3 times',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ],
              if (showSaving)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(top: 12, bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText ?? 'Saving…',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
