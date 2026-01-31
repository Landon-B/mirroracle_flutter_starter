import 'package:flutter/material.dart';

import '../models/mood_entry.dart';
import '../services/mood_service.dart';

class MoodCheckinSheet extends StatefulWidget {
  const MoodCheckinSheet({
    super.key,
    required this.source,
    required this.onSaved,
    this.title = 'Daily check-in',
    this.initialScore,
    this.initialTags = const [],
    this.initialNote,
  });

  final String source;
  final String title;
  final int? initialScore;
  final List<String> initialTags;
  final String? initialNote;
  final void Function(MoodEntry entry) onSaved;

  @override
  State<MoodCheckinSheet> createState() => _MoodCheckinSheetState();
}

class _MoodCheckinSheetState extends State<MoodCheckinSheet> {
  static const _tags = <String>[
    'calm',
    'anxious',
    'grounded',
    'overwhelmed',
    'grateful',
    'tired',
    'hopeful',
    'focused',
  ];

  late int _score;
  late final Set<String> _selectedTags;
  late final TextEditingController _noteCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _score = widget.initialScore ?? 3;
    _selectedTags = widget.initialTags.toSet();
    _noteCtrl = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final entry = await MoodService().saveMood(
        moodScore: _score,
        tags: _selectedTags.toList(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        source: widget.source,
      );
      if (!mounted) return;
      widget.onSaved(entry);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save check-in: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

  IconData _iconForScore(int score) {
    switch (score) {
      case 1:
        return Icons.sentiment_very_dissatisfied;
      case 2:
        return Icons.sentiment_dissatisfied;
      case 3:
        return Icons.sentiment_neutral;
      case 4:
        return Icons.sentiment_satisfied;
      case 5:
        return Icons.sentiment_very_satisfied;
      default:
        return Icons.sentiment_neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pick what fits best.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (i) {
                final score = i + 1;
                final selected = _score == score;
                return IconButton(
                  onPressed: () => setState(() => _score = score),
                  icon: Icon(
                    _iconForScore(score),
                    color: selected ? Colors.black87 : Colors.black38,
                  ),
                  tooltip: _labelForScore(score),
                );
              }),
            ),
            Text(
              _labelForScore(_score),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tags',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((tag) {
                final selected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Add a note (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save check-in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
