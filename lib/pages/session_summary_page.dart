// lib/pages/session_summary_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page.dart';
import 'profile_overlay.dart';
import '../services/streak_service.dart';
import '../services/mood_service.dart';
import '../models/mood_entry.dart';
import '../widgets/mood_checkin_sheet.dart';

class SessionSummaryData {
  final int durationSec;
  final double presenceScore; // 0..1
  final List<String> affirmations;
  final DateTime startedAtUtc;
  final DateTime endedAtUtc;

  const SessionSummaryData({
    required this.durationSec,
    required this.presenceScore,
    required this.affirmations,
    required this.startedAtUtc,
    required this.endedAtUtc,
  });
}

class SessionSummaryPage extends StatefulWidget {
  final SessionSummaryData data;
  const SessionSummaryPage({super.key, required this.data});

  @override
  State<SessionSummaryPage> createState() => _SessionSummaryPageState();
}

class _SessionSummaryPageState extends State<SessionSummaryPage> {
  StreakInfo? _streak;
  bool _loadingStreak = true;
  bool _loadingStats = true;
  int _totalSessions = 0;
  int _affirmationsSpoken = 0;
  String _topCategory = 'Confidence';
  MoodEntry? _todayMood;
  bool _loadingMood = true;

  @override
  void initState() {
    super.initState();
    _loadStreaks();
    _loadProgressStats();
    _loadTodayMood();
  }

  Future<void> _loadStreaks() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) throw Exception('No user session');
      final s = await computeStreaks(Supabase.instance.client, uid);
      if (!mounted) return;
      setState(() {
        _streak = s;
        _loadingStreak = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingStreak = false);
    }
  }

  Future<void> _loadProgressStats() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) throw Exception('No user session');
      final rows = await Supabase.instance.client
          .from('sessions')
          .select('aff_count')
          .eq('user_id', uid)
          .eq('completed', true);
      final list = (rows as List? ?? const []);
      int total = list.length;
      int affs = 0;
      for (final r in list) {
        final count = (r as Map)['aff_count'];
        if (count is int) {
          affs += count * 3;
        } else {
          final parsed = int.tryParse(count?.toString() ?? '');
          if (parsed != null) affs += parsed * 3;
        }
      }
      if (!mounted) return;
      setState(() {
        _totalSessions = total;
        _affirmationsSpoken = affs;
        _loadingStats = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingStats = false);
    }
  }

  Future<void> _loadTodayMood() async {
    try {
      final entry = await MoodService().fetchForLocalDay(DateTime.now());
      if (!mounted) return;
      setState(() {
        _todayMood = entry;
        _loadingMood = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMood = false);
    }
  }

  void _openMoodCheckin() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return MoodCheckinSheet(
          title: 'How do you feel now?',
          source: 'post_session',
          initialScore: _todayMood?.moodScore,
          initialTags: _todayMood?.tags ?? const [],
          initialNote: _todayMood?.note,
          onSaved: (entry) {
            setState(() => _todayMood = entry);
          },
        );
      },
    );
  }

  void _openProfileOverlay() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Profile',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) {
        return ProfileOverlay(
          activeDates: _streak?.activeDates ?? const {},
          loadingStreak: _loadingStreak,
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final streakDays = _streak?.currentStreakDays ?? 0;
    final favorite = d.affirmations.isNotEmpty ? d.affirmations.first : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F6FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),
            Text(
              'Reflection Room',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 30,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "See how you're growing from within",
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            _sectionCard(
              title: 'Progress',
              child: _loadingStats || _loadingStreak
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        _progressRow(
                          'Your Self-Devotion Streak',
                          '$streakDays days',
                        ),
                        _progressRow(
                          'Total Sessions Completed',
                          '$_totalSessions',
                        ),
                        _progressRow(
                          'Affirmations Spoken Aloud',
                          '$_affirmationsSpoken',
                        ),
                        _progressRow(
                          'Top Affirmation Category',
                          _topCategory,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 18),
            _sectionCard(
              title: 'Mood',
              child: Column(
                children: [
                  Text(
                    _todayMood == null
                        ? 'Want to check in on your mood?'
                        : 'Checked in today: ${_moodLabel(_todayMood!.moodScore)}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      onPressed: _loadingMood ? null : _openMoodCheckin,
                      child: Text(
                        _todayMood == null ? 'Check in now' : 'Update check-in',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _sectionCard(
              title: 'Favorites',
              child: favorite == null
                  ? Text(
                      'No favorites yet.',
                      style: GoogleFonts.manrope(color: Colors.black54),
                    )
                  : Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0E0FA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _topCategory,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '"$favorite"',
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Saved today',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: Colors.black45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const HomePage()),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.home_rounded, size: 28),
                  ),
                  IconButton(
                    onPressed: null,
                    icon: const Icon(Icons.grid_view_rounded, size: 26),
                  ),
                  IconButton(
                    onPressed: _openProfileOverlay,
                    icon: const Icon(Icons.person_rounded, size: 28),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7DEE6), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _progressRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _moodLabel(int score) {
    switch (score) {
      case 1:
        return 'Struggling';
      case 2:
        return 'Low';
      case 3:
        return 'Steady';
      case 4:
        return 'Good';
      case 5:
        return 'Great';
      default:
        return 'Steady';
    }
  }
}
