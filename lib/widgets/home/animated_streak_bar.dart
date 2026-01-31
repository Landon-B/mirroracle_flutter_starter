import 'package:flutter/material.dart';
import '../streak_bar.dart';

/// An animated wrapper for the StreakBar that slides in/out.
class AnimatedStreakBar extends StatelessWidget {
  final bool visible;
  final Set<DateTime> activeDates;
  final bool loading;

  const AnimatedStreakBar({
    super.key,
    required this.visible,
    required this.activeDates,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        offset: visible ? Offset.zero : const Offset(0, -0.4),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: visible ? 1 : 0,
          child: StreakBar(
            activeDates: activeDates,
            loading: loading,
          ),
        ),
      ),
    );
  }
}
