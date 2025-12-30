import 'dart:async';
import 'text_alignment.dart';

class PresenceTick {
  final double onTask;        // 0..1 (you set 1 while live)
  final double affAlignment;  // 0..1 matched chars ratio
  final double continuity;    // 0..1 (1 if no long silence)
  final double clarity;       // 0..1 scaled sound level
  PresenceTick(this.onTask, this.affAlignment, this.continuity, this.clarity);
}

class PresenceScorer {
  final String target;
  final double w1, w2, w3, w4;
  final _ticks = <double>[];

  // rolling state
  String _spokenNorm = '';
  DateTime _lastSpeechAt = DateTime.now();
  double _level = 0;

  PresenceScorer(this.target, {this.w1=0.3, this.w2=0.5, this.w3=0.1, this.w4=0.1});

  void onPartial(String text) {
    _spokenNorm = TextAlignment.normalize(text);
    _lastSpeechAt = DateTime.now();
  }

  void onSoundLevel(double level) {
    _level = level; // typically 0..~120, device-dependent
  }

  /// Call once per second during the live session.
  double tick() {
    final tgt = TextAlignment.normalize(target);
    final matchLen = TextAlignment.prefixMatchLen(tgt, _spokenNorm);
    final affAlign = tgt.isEmpty ? 0.0 : (matchLen / tgt.length);

    final since = DateTime.now().difference(_lastSpeechAt).inMilliseconds;
    final continuity = (since <= 1500) ? 1.0 : (since >= 6000 ? 0.0 : 1.0 - (since-1500)/4500);

    // naive clarity scaler; calibrate per device
    final clarity = (_level / 60.0).clamp(0.0, 1.0);

    final score = (w1*1.0) + (w2*affAlign) + (w3*continuity) + (w4*clarity);
    _ticks.add(score);
    return score;
  }

  double finalScore() => _ticks.isEmpty ? 0.0 : _ticks.reduce((a,b)=>a+b) / _ticks.length;
}