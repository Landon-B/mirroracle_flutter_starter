import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/mood_entry.dart';
import '../services/mood_service.dart';
import '../widgets/mood_checkin_sheet.dart';

class MoodTrendsPage extends StatefulWidget {
  const MoodTrendsPage({super.key});

  @override
  State<MoodTrendsPage> createState() => _MoodTrendsPageState();
}

class _MoodTrendsPageState extends State<MoodTrendsPage> {
  bool _loading = true;
  List<MoodEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final end = DateTime.now().toUtc();
      final start = end.subtract(const Duration(days: 30));
      final rows = await MoodService().fetchRange(startUtc: start, endUtc: end);
      if (!mounted) return;
      setState(() {
        _entries = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openCheckin() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return MoodCheckinSheet(
          title: 'Daily check-in',
          source: 'trends',
          onSaved: (entry) {
            setState(() {
              _entries = [entry, ..._entries];
            });
          },
        );
      },
    );
  }

  double _avgMood() {
    if (_entries.isEmpty) return 0;
    final sum = _entries.fold<int>(0, (acc, e) => acc + e.moodScore);
    return sum / _entries.length;
  }

  String _labelForScore(int score) {
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

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$m/$d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F6FB),
        elevation: 0,
        title: Text(
          'Mood trends',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 24,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openCheckin,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'New check-in',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _statTile(
                          label: '30-day avg',
                          value: _entries.isEmpty
                              ? '—'
                              : _avgMood().toStringAsFixed(1),
                        ),
                        const SizedBox(width: 12),
                        _statTile(
                          label: 'Check-ins',
                          value: _entries.length.toString(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Last 30 days',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_entries.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'No check-ins yet. Tap + to add your first one.',
                      ),
                    )
                  else
                    ..._entries
                        .take(30)
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                      final e = entry.value;
                      final barWidth =
                          60 + (e.moodScore.clamp(1, 5) * 22).toDouble();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 46,
                              child: Text(
                                _formatDate(e.createdAt),
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    height: 8,
                                    width: barWidth,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7C4DFF)
                                          .withOpacity(0.65),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _labelForScore(e.moodScore),
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _statTile({required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFD),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD7DEE6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
