import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionsFeedPage extends StatefulWidget {
  const SessionsFeedPage({super.key});

  @override
  State<SessionsFeedPage> createState() => _SessionsFeedPageState();
}

class _SessionsFeedPageState extends State<SessionsFeedPage> {
  late Future<List<Map<String, dynamic>>> _future;

  Future<List<Map<String, dynamic>>> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('No user');
    final rows = await Supabase.instance.client
        .from('sessions')
        .select()
        .eq('user_id', userId)
        .order('started_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  String _fmtNum(num? n) => n == null ? '-' : (n is int ? '$n' : n.toStringAsFixed(2));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Sessions')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final data = snap.data ?? const [];
          if (data.isEmpty) {
            return const Center(child: Text('No sessions yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: data.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final r = data[i];
              final startedAt = DateTime.tryParse('${r['started_at']}');
              final when = startedAt == null ? '' : '${startedAt.toLocal()}';
              return ListTile(
                leading: const Icon(Icons.event_available),
                title: Text('Presence: ${_fmtNum(r['presence_score'])} • Aff: ${r['aff_count']}'),
                subtitle: Text(when),
                trailing: Text('${_fmtNum(r['duration_s'])}s'),
              );
            },
          );
        },
      ),
    );
  }
}