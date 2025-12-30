// lib/services/streak_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class StreakInfo {
  final int currentStreakDays;
  final int bestStreakDays;
  StreakInfo({required this.currentStreakDays, required this.bestStreakDays});
}

/// Fetch completed sessions for the user and compute:
/// - current streak (consecutive days ending today)
/// - best (max) streak
Future<StreakInfo> computeStreaks(SupabaseClient client, String userId) async {
  // Pull session dates (prefer device_local_date, fall back to timestamps)
  final rows = await client
      .from('sessions')
      .select('started_at, ended_at, device_local_date, completed')
      .eq('user_id', userId)
      .eq('completed', true)
      .order('started_at', ascending: false, nullsFirst: false);

  // Collect unique YYYY-MM-DD local dates where a session exists
  final dateSet = <DateTime>{};
  for (final r in (rows as List)) {
    final dynamic localDate = r['device_local_date'];
    if (localDate != null) {
      final parsed = localDate is DateTime
          ? localDate
          : DateTime.tryParse(localDate.toString());
      if (parsed != null) {
        dateSet.add(DateTime(parsed.year, parsed.month, parsed.day));
        continue;
      }
    }

    final dynamic started = r['started_at'];
    final dynamic ended = r['ended_at'];
    DateTime? dt;
    if (started != null) {
      dt = started is DateTime
          ? started
          : DateTime.tryParse(started.toString());
    }
    dt ??= (ended != null
        ? (ended is DateTime ? ended : DateTime.tryParse(ended.toString()))
        : null);
    if (dt == null) continue;

    // Normalize to local date (midnight)
    final local = dt.toLocal();
    dateSet.add(DateTime(local.year, local.month, local.day));
  }

  if (dateSet.isEmpty) {
    return StreakInfo(currentStreakDays: 0, bestStreakDays: 0);
  }

  // Best streak: scan all sorted days for longest consecutive run
  final sorted = dateSet.toList()..sort();
  int best = 1, run = 1;
  for (int i = 1; i < sorted.length; i++) {
    final prev = sorted[i - 1];
    final cur = sorted[i];
    if (cur.difference(prev).inDays == 1) {
      run += 1;
      if (run > best) best = run;
    } else {
      run = 1;
    }
  }

  // Current streak: count back from today
  final today = DateTime.now();
  DateTime cursor = DateTime(today.year, today.month, today.day);
  int current = 0;
  while (dateSet.contains(cursor)) {
    current += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return StreakInfo(currentStreakDays: current, bestStreakDays: best);
}
