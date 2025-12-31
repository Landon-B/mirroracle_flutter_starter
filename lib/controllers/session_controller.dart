// lib/controllers/session_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../pages/session_summary_page.dart';
import '../pages/new_session/session_speech_matcher.dart';
import '../services/camera_service.dart';
import '../services/mic_service.dart';

enum SessionPhase { idle, countdown, live, saving, done }

sealed class SessionNavEvent {
  const SessionNavEvent();
}

class NavigateToSummary extends SessionNavEvent {
  final SessionSummaryData data;
  const NavigateToSummary(this.data);
}

class SessionController extends ChangeNotifier {
  SessionController({
    required CameraService camera,
    required MicService mic,
    required List<String> initialAffirmations,
  })  : _camera = camera,
        _mic = mic,
        _affirmations = initialAffirmations.isNotEmpty
            ? initialAffirmations
            : const ['I am present.', 'I am capable.', 'I finish what I start.'] {
    _speechMatcher.resetForText(_affirmations[_currentAffIdx]);
  }

  void _dbg(String msg) {
  if (kDebugMode) {
    debugPrint('[SESSION] $msg');
  }
}

  // deps
  final CameraService _camera;
  final MicService _mic;

  CameraService get camera => _camera;
  MicService get mic => _mic;

  // camera state (view-model)
  bool _cameraWarmingUp = true;
  bool get cameraWarmingUp => _cameraWarmingUp;

  bool get cameraAvailable => _camera.isAvailable;
  bool get cameraReady => _camera.isInitialized;

  // one-shot navigation events
  final _navCtrl = StreamController<SessionNavEvent>.broadcast();
  Stream<SessionNavEvent> get navEvents$ => _navCtrl.stream;

  // session state
  SessionPhase _phase = SessionPhase.idle;
  SessionPhase get phase => _phase;

  static const int kTargetSeconds = 90;

  int _elapsed = 0;
  int get elapsed => _elapsed;

  int _presenceSeconds = 0;
  int get presenceSeconds => _presenceSeconds;

  final List<String> _affirmations;
  List<String> get affirmations => List.unmodifiable(_affirmations);

  int _currentAffIdx = 0;
  int get currentAffIdx => _currentAffIdx;

  int _currentAffRep = 0;
  int get currentAffRep => _currentAffRep;

  static const int kRepsPerAffirmation = 3;
  int get repsPerAffirmation => kRepsPerAffirmation;

  final SessionSpeechMatcher _speechMatcher = SessionSpeechMatcher();
  SessionSpeechMatcher get speechMatcher => _speechMatcher;

  bool _micNeedsRestart = false;
  bool get micNeedsRestart => _micNeedsRestart;

  bool _listenTimedOut = false;
  bool get listenTimedOut => _listenTimedOut;

  String? _status;
  String? get status => _status;

  DateTime? _startedAt;

  Timer? _ticker;
  Timer? _listenTimeoutTimer;

  StreamSubscription<String>? _partialSub;
  StreamSubscription<String>? _finalSub;
  StreamSubscription<Object>? _errSub;
  StreamSubscription<MicState>? _micStateSub;

  bool _started = false;

  /// Call once from the page. This initializes camera and starts session.
  Future<void> initAndStart() async {
    if (_started) return;
    _started = true;

    _cameraWarmingUp = true;
    notifyListeners();

    try {
      await _camera.init();
    } catch (_) {
      // camera remains unavailable; session still runs
    } finally {
      _cameraWarmingUp = false;
      notifyListeners();
    }

    await start();
  }

  Future<void> start() async {
    _setPhase(SessionPhase.live);

    _elapsed = 0;
    _presenceSeconds = 0;
    _startedAt = DateTime.now().toUtc();

    _currentAffIdx = 0;
    _currentAffRep = 0;

    _micNeedsRestart = false;
    _listenTimedOut = false;
    _status = null;

    _speechMatcher.resetForText(_affirmations[_currentAffIdx]);

    notifyListeners();
    WakelockPlus.enable();

    await _wireMic();
    await _ensureMicReadyAndListen();

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed++;
      _presenceSeconds++;

      if (_elapsed >= kTargetSeconds) {
        finish();
        return;
      }
      notifyListeners();
    });
  }

  // ---------------- MIC WIRING ----------------

  Future<void> _wireMic() async {
    await _partialSub?.cancel();
    await _finalSub?.cancel();
    await _errSub?.cancel();
    await _micStateSub?.cancel();

    _dbg('Mic wired');

    _micStateSub = _mic.state$.listen((s) {
      _dbg('Mic state → $s');
      if (_phase != SessionPhase.live) return;

      if (s == MicState.ready && !_mic.isListening && !_micNeedsRestart) {
        _dbg('Mic returned to READY unexpectedly → restarting');
        _restartListeningSoon();
      }
    });

    _partialSub = _mic.partialText$.listen((raw) {
      if (_phase != SessionPhase.live) return;

      _dbg('PARTIAL (raw): "$raw"');
      _applySpeech(raw, allowAdvance: false);
    });

    _finalSub = _mic.finalText$.listen((raw) {
      if (_phase != SessionPhase.live) return;

      _dbg('FINAL (raw): "$raw"');
      _applySpeech(raw, allowAdvance: true);
    });

    _errSub = _mic.errors$.listen((e) {
      _dbg('Mic error: $e');
      if (_phase != SessionPhase.live) return;
      _micNeedsRestart = true;
      notifyListeners();
      _restartListeningSoon();
    });
  }

  Future<void> _ensureMicReadyAndListen() async {
    final ok = await _mic.init(debugLogging: false);
    if (!ok) {
      _micNeedsRestart = true;
      notifyListeners();
      return;
    }
    await _listen(resetMatcher: false);
  }

  /// Normalize STT text (fixes common iOS contractions like "I'm" => "I am").
  String _normalizeSpeechText(String s) {
    var t = s.trim();

    // Common contraction fixes for your affirmations (huge for "I am ...")
    // Do this BEFORE the matcher strips apostrophes, otherwise "I'm" becomes "im".
    t = t.replaceAll(RegExp(r"\b(i['’]m)\b", caseSensitive: false), "I am");
    t = t.replaceAll(RegExp(r"\b(i['’]ve)\b", caseSensitive: false), "I have");
    t = t.replaceAll(RegExp(r"\b(i['’]ll)\b", caseSensitive: false), "I will");
    t = t.replaceAll(RegExp(r"\b(i['’]d)\b", caseSensitive: false), "I would");

    return t;
  }

  void _applySpeech(String raw, {required bool allowAdvance}) {
    final normalized = _normalizeSpeechText(raw);

    _dbg('Normalized: "$normalized"');

    final spokenTokens = _speechMatcher.tokenizeSpeech(normalized);
    _dbg('Tokens: $spokenTokens');

    final before = _speechMatcher.activeToken;
    final changed = _speechMatcher.updateWithSpokenTokens(spokenTokens);
    final after = _speechMatcher.activeToken;

    if (changed) {
      _dbg(
        'Matcher advanced: $before → $after '
        '(target=${_speechMatcher.tokens})',
      );
      notifyListeners();
    }

    if (allowAdvance && _speechMatcher.isComplete) {
      _dbg('Affirmation COMPLETE');
      _advanceAffirmation();
    }
  }

  // ---------------- LISTEN LOOP ----------------

  Future<void> _listen({required bool resetMatcher}) async {
    if (_phase != SessionPhase.live) return;

    _dbg('Starting mic listen (resetMatcher=$resetMatcher)');

    _listenTimeoutTimer?.cancel();
    _listenTimedOut = false;
    _micNeedsRestart = false;

    if (resetMatcher) {
      _dbg('Resetting matcher for "${_affirmations[_currentAffIdx]}"');
      _speechMatcher.resetForText(_affirmations[_currentAffIdx]);
    }

    notifyListeners();

    try {
      if (_mic.isListening) {
        _dbg('Stopping existing mic session');
        await _mic.stop();
      } else {
        await _mic.cancel();
      }
    } catch (_) {}

    _listenTimeoutTimer = Timer(const Duration(minutes: 10), () {
      if (_phase != SessionPhase.live) return;
      _dbg('Mic listen timeout');
      _listenTimedOut = true;
      _micNeedsRestart = true;
      notifyListeners();
      _mic.stop();
    });

    try {
      await _mic.start(
        partialResults: true,
        cancelOnError: false,
        listenFor: const Duration(minutes: 10),
        pauseFor: const Duration(seconds: 1),
      );
      _dbg('Mic listening started');
    } catch (e) {
      _dbg('Mic start failed: $e');
      _micNeedsRestart = true;
      notifyListeners();
    }
  }

  void onMicTap() {
    if (_phase != SessionPhase.live) return;
    if (!_micNeedsRestart) return;
    _listen(resetMatcher: false);
  }

  void _restartListeningSoon() {
    Future.delayed(const Duration(milliseconds: 250), () {
      if (_phase != SessionPhase.live) return;
      if (!_mic.isListening && !_micNeedsRestart) {
        _listen(resetMatcher: false);
      }
    });
  }

  Future<void> restartListeningForNewAffirmation() async {
    if (_phase != SessionPhase.live) return;
    await _listen(resetMatcher: true);
  }

  // ---------------- AFFIRMATION ADVANCE ----------------

  void _advanceAffirmation() {
    if (_affirmations.isEmpty) return;

    if (_currentAffRep < kRepsPerAffirmation - 1) {
      _currentAffRep += 1;
      _speechMatcher.resetForText(_affirmations[_currentAffIdx]);
      notifyListeners();
      restartListeningForNewAffirmation();
      return;
    }

    final isLast = _currentAffIdx >= _affirmations.length - 1;
    if (isLast) {
      finish();
      return;
    }

    _currentAffIdx += 1;
    _currentAffRep = 0;
    _speechMatcher.resetForText(_affirmations[_currentAffIdx]);
    notifyListeners();
    restartListeningForNewAffirmation();
  }

  // ---------------- FINISH / ABORT ----------------

  Future<void> finish() async {
    if (_phase == SessionPhase.saving || _phase == SessionPhase.done) return;

    _ticker?.cancel();
    _listenTimeoutTimer?.cancel();
    await _mic.stop();
    WakelockPlus.disable();

    _setPhase(SessionPhase.saving);
    notifyListeners();

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) throw Exception('No user session');

      final endedAt = DateTime.now().toUtc();
      final localDate = (_startedAt ?? endedAt).toLocal();
      final duration = _elapsed;

      final presenceScore =
          (_presenceSeconds / (duration == 0 ? 1 : duration)).clamp(0.0, 1.0);

      final payload = <String, dynamic>{
        'user_id': uid,
        'started_at': _startedAt?.toIso8601String(),
        'ended_at': endedAt.toIso8601String(),
        'duration_s': duration,
        'presence_seconds': _presenceSeconds,
        'presence_score': presenceScore,
        'aff_count': _affirmations.length,
        'device_local_date': _formatLocalDate(localDate),
        'completed': true,
      };

      await Supabase.instance.client.from('sessions').insert(payload);

      _status =
          'Session saved • ${duration}s • presence ${(presenceScore * 100).toStringAsFixed(0)}%';
      _setPhase(SessionPhase.done);
      notifyListeners();

      _navCtrl.add(
        NavigateToSummary(
          SessionSummaryData(
            durationSec: duration,
            presenceScore: presenceScore.toDouble(),
            affirmations: List<String>.from(_affirmations),
            startedAtUtc: _startedAt ?? endedAt,
            endedAtUtc: endedAt,
          ),
        ),
      );
    } catch (e) {
      _status = 'Save failed: $e';
      _setPhase(SessionPhase.done);
      notifyListeners();
    }
  }

  Future<void> abort() async {
    _ticker?.cancel();
    _listenTimeoutTimer?.cancel();
    await _mic.stop();
    WakelockPlus.disable();
  }

  // lifecycle
  void onPaused() {
    _camera.pausePreview();
    _mic.stop();
  }

  void onResumed() {
    _camera.resumePreview();
    if (_phase == SessionPhase.live && !_mic.isListening) {
      _listen(resetMatcher: false);
    }
  }

  // helpers
  void _setPhase(SessionPhase p) => _phase = p;

  String _formatLocalDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _listenTimeoutTimer?.cancel();

    _partialSub?.cancel();
    _finalSub?.cancel();
    _errSub?.cancel();
    _micStateSub?.cancel();

    _navCtrl.close();
    super.dispose();
  }
}