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
    this.debugMic = false,
  })  : _camera = camera,
        _mic = mic,
        _affirmations = initialAffirmations.isNotEmpty
            ? initialAffirmations
            : const ['I am present.', 'I am capable.', 'I finish what I start.'] {
    _speechMatcher.resetForText(_affirmations[_currentAffIdx]);
  }

  // deps
  final CameraService _camera;
  final MicService _mic;

  // Toggle to print recognized speech
  final bool debugMic;

  CameraService get camera => _camera;
  MicService get mic => _mic;

  // camera state
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

  // Current affirmation index (0..n-1)
  int _currentAffIdx = 0;
  int get currentAffIdx => _currentAffIdx;

  // We keep this getter because UI may reference it, but we now use it as "round index".
  // 0 = first round, 1 = second round, 2 = third round
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
  StreamSubscription<MicState>? _stateSub;

  bool _started = false;

  // ---- NEW: ignore tail-end mic results right after switching affirmations ----
  DateTime _ignoreMicUntil = DateTime.fromMillisecondsSinceEpoch(0);

  bool _shouldIgnoreMicResult() {
    return DateTime.now().isBefore(_ignoreMicUntil);
  }

  void _armMicIgnoreWindow([Duration d = const Duration(milliseconds: 650)]) {
    // 650ms is enough to drop the "I am ..." spillover + any late plugin callbacks.
    _ignoreMicUntil = DateTime.now().add(d);
  }

  /// Call once from the page. Initializes camera (best-effort) and starts session.
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

    _speechMatcher.resetForText(_affirmations[_currentAffIdx]);
    _armMicIgnoreWindow(); // avoid instant carry-over on session start
    notifyListeners();

    await WakelockPlus.enable();

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

  /// Wire subscriptions once per session start, and guard by phase.
  Future<void> _wireMic() async {
    await _partialSub?.cancel();
    await _finalSub?.cancel();
    await _errSub?.cancel();
    await _stateSub?.cancel();

    _partialSub = _mic.partialText$.listen((text) {
      if (_phase != SessionPhase.live) return;
      if (_shouldIgnoreMicResult()) return;

      if (debugMic) {
        debugPrint('[mic][partial] $text');
      }

      final spokenTokens = _speechMatcher.tokenizeSpeech(text);
      final changed = _speechMatcher.updateWithSpokenTokens(spokenTokens);
      if (changed) notifyListeners();
    });

    _finalSub = _mic.finalText$.listen((text) {
      if (_phase != SessionPhase.live) return;
      if (_shouldIgnoreMicResult()) return;

      if (debugMic) {
        debugPrint('[mic][final] $text');
      }

      final spokenTokens = _speechMatcher.tokenizeSpeech(text);
      final changed = _speechMatcher.updateWithSpokenTokens(spokenTokens);
      if (changed) notifyListeners();

      if (_speechMatcher.isComplete) {
        _advanceAffirmation();
      }
    });

    _errSub = _mic.errors$.listen((err) {
      if (_phase != SessionPhase.live) return;
      if (debugMic) debugPrint('[mic][error] $err');
      _restartListeningSoon();
    });

    // Minimal recovery only (don’t fight MicService keep-alive).
    _stateSub = _mic.state$.listen((s) {
      if (_phase != SessionPhase.live) return;
      if (debugMic) debugPrint('[mic][state] $s');

      // If we’re live and fell back to ready (not listening), softly re-start.
      if (s == MicState.ready && !_mic.isListening) {
        _restartListeningSoon();
      }
    });
  }

  Future<void> _ensureMicReadyAndListen() async {
    final ok = await _mic.init(debugLogging: false);
    debugPrint('[mic][init] ok=$ok');
    if (!ok) {
      _micNeedsRestart = true;
      notifyListeners();
      return;
    }
    _listen();
  }

  /// For keep-alive MicService, just start if not already listening.
  void _listen() async {
    if (_phase != SessionPhase.live) return;

    _listenTimeoutTimer?.cancel();
    _listenTimedOut = false;
    _micNeedsRestart = false;
    notifyListeners();

    _listenTimeoutTimer = Timer(const Duration(minutes: 10), () {
      if (_phase != SessionPhase.live) return;
      _listenTimedOut = true;
      _micNeedsRestart = true;
      notifyListeners();
      _mic.stop();
    });

    try {
      if (!_mic.isListening) {
        await _mic.start(
          localeId: 'en_US',
          partialResults: true,
          cancelOnError: false,
          listenFor: const Duration(minutes: 10),
          pauseFor: const Duration(seconds: 6),
        );
      }
    } catch (e) {
      if (debugMic) debugPrint('[mic][listen start failed] $e');
      _micNeedsRestart = true;
      notifyListeners();
    }
  }

  void onMicTap() {
    if (_phase != SessionPhase.live) return;
    if (!_micNeedsRestart) return;
    _listen();
  }

  void _restartListeningSoon() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_phase != SessionPhase.live) return;
      if (!_mic.isListening && !_micNeedsRestart) {
        _listen();
      }
    });
  }

  // ---- UPDATED: round-robin affirmations across 3 rounds ----
  // Order: A1, A2, A3, A1, A2, A3, A1, A2, A3
  void _advanceAffirmation() {
    if (_affirmations.isEmpty) return;

    // Move to next affirmation
    final nextIdx = _currentAffIdx + 1;

    if (nextIdx < _affirmations.length) {
      _currentAffIdx = nextIdx;
      _speechMatcher.resetForText(_affirmations[_currentAffIdx]);
      _armMicIgnoreWindow(); // prevents "I am" carry-over
      notifyListeners();
      return;
    }

    // End of list => advance the round
    final nextRound = _currentAffRep + 1;

    if (nextRound < kRepsPerAffirmation) {
      _currentAffRep = nextRound;
      _currentAffIdx = 0;
      _speechMatcher.resetForText(_affirmations[_currentAffIdx]);
      _armMicIgnoreWindow();
      notifyListeners();
      return;
    }

    // All rounds done
    finish();
  }

  Future<void> finish() async {
    if (_phase == SessionPhase.saving || _phase == SessionPhase.done) return;

    _ticker?.cancel();
    _listenTimeoutTimer?.cancel();

    await _mic.stop();
    await WakelockPlus.disable();

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
    await WakelockPlus.disable();
  }

  void onPaused() {
    _camera.pausePreview();
    _mic.stop();
  }

  void onResumed() {
    _camera.resumePreview();
    if (_phase == SessionPhase.live && !_mic.isListening) {
      _listen();
    }
  }

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
    _stateSub?.cancel();

    _navCtrl.close();
    super.dispose();
  }
}