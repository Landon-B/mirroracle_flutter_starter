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
    required this.onMicTap,
    required this.onShare,
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
  final VoidCallback onMicTap;
  final VoidCallback onShare;
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
                          borderRadius: BorderRadius.circular(10),
                          onTap: onShare,
                          child: Ink(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.ios_share_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: onClose,
                          child: Ink(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 18),
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
                          const Icon(Icons.favorite_border_rounded,
                              color: Colors.black54, size: 18),
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
                      onTap: micNeedsRestart ? onMicTap : null,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.mic_rounded,
                          size: 28,
                          color:
                              micNeedsRestart ? Colors.redAccent : Colors.black87,
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
