class MoodEntry {
  const MoodEntry({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.moodScore,
    this.tags = const [],
    this.note,
    this.source,
    this.context,
  });

  final String id;
  final String userId;
  final DateTime createdAt;
  final int moodScore;
  final List<String> tags;
  final String? note;
  final String? source;
  final String? context;

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    return MoodEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      moodScore: (json['mood_score'] as num).toInt(),
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      note: json['note'] as String?,
      source: json['source'] as String?,
      context: json['context'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'mood_score': moodScore,
      'tags': tags.isEmpty ? null : tags,
      'note': note,
      'source': source,
      'context': context,
    };
  }
}
