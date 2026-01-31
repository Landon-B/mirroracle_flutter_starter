import 'package:flutter/material.dart';

/// The main "Practice" button that starts a new affirmation session.
class PracticeButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  const PracticeButton({
    super.key,
    required this.enabled,
    this.onPressed,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFF7F1EB),
          foregroundColor: const Color(0xFF2F2624),
          elevation: 6,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22),
        ),
        onPressed: enabled ? onPressed : null,
        onLongPress: onLongPress,
        icon: const Icon(Icons.self_improvement_outlined),
        label: const Text(
          'Practice',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
