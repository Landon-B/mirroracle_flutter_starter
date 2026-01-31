import 'package:characters/characters.dart';
import 'package:flutter/material.dart';

import '../services/text_alignment.dart';

/// Highlights spoken portion of an affirmation text in real-time.
class AffirmationHighlighter extends StatelessWidget {
  final String target;
  final String spokenPartial;
  final TextStyle? textStyle;

  const AffirmationHighlighter({
    super.key,
    required this.target,
    required this.spokenPartial,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final tgtNorm = TextAlignment.normalize(target);
    final spkNorm = TextAlignment.normalize(spokenPartial);

    // Allow off-by-one space drifts
    final k = TextAlignment.prefixMatchLen(tgtNorm, spkNorm);
    final ratio = tgtNorm.isEmpty ? 0.0 : (k / tgtNorm.length);

    final cut = (target.characters.length * ratio).floor();
    final done = target.characters.take(cut).toString();
    final rest = target.characters.skip(cut).toString();

    final base = (textStyle ?? Theme.of(context).textTheme.headlineMedium)
        ?.copyWith(color: Colors.white);

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: [
        TextSpan(
          text: done,
          style: base?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        TextSpan(
          text: rest,
          style: base?.copyWith(color: Colors.white70),
        ),
      ]),
    );
  }
}
