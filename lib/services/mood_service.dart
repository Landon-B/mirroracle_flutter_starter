import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mood_entry.dart';

class MoodService {
  static const _table = 'mood_checkins';

  SupabaseClient get _client => Supabase.instance.client;

  Future<MoodEntry?> fetchLatest() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    final row = await _client
        .from(_table)
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    return MoodEntry.fromJson(row);
  }

  Future<MoodEntry?> fetchForLocalDay(DateTime dayLocal) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    final start = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final end = start.add(const Duration(days: 1));

    final row = await _client
        .from(_table)
        .select()
        .eq('user_id', uid)
        .gte('created_at', start.toUtc().toIso8601String())
        .lt('created_at', end.toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    return MoodEntry.fromJson(row);
  }

  Future<List<MoodEntry>> fetchRange({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];

    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', uid)
        .gte('created_at', startUtc.toIso8601String())
        .lt('created_at', endUtc.toIso8601String())
        .order('created_at');

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(MoodEntry.fromJson)
        .toList(growable: false);
  }

  Future<MoodEntry> saveMood({
    required int moodScore,
    List<String> tags = const [],
    String? note,
    String? source,
    String? context,
    DateTime? createdAt,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw const AuthException('Not signed in');
    }

    final entry = MoodEntry(
      id: '',
      userId: uid,
      createdAt: createdAt ?? DateTime.now(),
      moodScore: moodScore,
      tags: tags,
      note: note,
      source: source,
      context: context,
    );

    final row = await _client
        .from(_table)
        .insert(entry.toInsertJson())
        .select()
        .single();

    return MoodEntry.fromJson(row);
  }

  /// Placeholder: later map mood/tags to affirmation selection rules.
  Future<List<String>> fetchSuggestedAffirmationIds({
    required int moodScore,
    List<String> tags = const [],
    int limit = 6,
  }) async {
    var query = _client.from('affirmations').select('id').eq('active', true);

    final rows = await query.order('created_at').limit(limit);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => r['id'] as String)
        .toList(growable: false);
  }
}
