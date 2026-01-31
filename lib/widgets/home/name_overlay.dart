import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// An overlay dialog prompting the user to enter their first name.
/// Used for existing test accounts that don't have a name set.
class NameOverlay extends StatelessWidget {
  final TextEditingController controller;
  final String? errorMessage;
  final bool isSaving;
  final VoidCallback onSubmit;

  const NameOverlay({
    super.key,
    required this.controller,
    required this.errorMessage,
    required this.isSaving,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black45,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF4ECE4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFE5D6CB),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 24,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2F2624),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'TEST MODE',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Add your first name',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 24,
                    color: const Color(0xFF2F2624),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This is temporary and only for existing test accounts.',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    height: 1.35,
                    color: const Color(0xFF6B5B52),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    hintText: 'First name',
                    hintStyle: GoogleFonts.manrope(
                      color: Colors.black38,
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black26),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black87, width: 1.6),
                    ),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorMessage!,
                    style: GoogleFonts.manrope(
                      color: Colors.redAccent,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: isSaving ? null : onSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save name'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
