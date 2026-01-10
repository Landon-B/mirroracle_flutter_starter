import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/streak_bar.dart';
import 'favorites_page.dart';

class ProfileOverlay extends StatelessWidget {
  const ProfileOverlay({
    super.key,
    required this.activeDates,
    required this.loadingStreak,
  });

  final Set<DateTime> activeDates;
  final bool loadingStreak;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4A3A36),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  _roundIcon(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  _roundIcon(
                    icon: Icons.settings,
                    onTap: () {},
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Profile',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 30,
                    color: const Color(0xFFF1E7DF),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StreakBar(
                activeDates: activeDates,
                loading: loadingStreak,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF4A3A36),
                ),
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  children: [
                    Text(
                      'Customize the app',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 22,
                        color: const Color(0xFFF1E7DF),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _gridRow(
                      left: _tile(
                        icon: Icons.auto_awesome,
                        label: 'App icon',
                      ),
                      right: _tile(
                        icon: Icons.notifications_none_rounded,
                        label: 'Reminders',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _gridRow(
                      left: _tile(
                        icon: Icons.widgets_outlined,
                        label: 'Home Screen widgets',
                      ),
                      right: _tile(
                        icon: Icons.lock_outline,
                        label: 'Lock Screen widgets',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _gridRow(
                      left: _tile(
                        icon: Icons.palette_outlined,
                        label: 'Themes',
                      ),
                      right: _tile(
                        icon: Icons.favorite_rounded,
                        label: 'Favorites',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const FavoritesPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundIcon({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF5A4742),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF8C7770), width: 1),
          ),
          child: Icon(icon, color: const Color(0xFFF1E7DF)),
        ),
      ),
    );
  }

  Widget _gridRow({required Widget left, required Widget right}) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final tile = Container(
      height: 130,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF5A4742),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFE7D7CF), size: 36),
          const Spacer(),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: const Color(0xFFF1E7DF),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return tile;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: tile,
      ),
    );
  }
}
