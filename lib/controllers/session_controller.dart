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

  // camera state (controller as view-model)
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

  /// NEW: we track *rounds* across the full list instead of repeating each aff 3x in a row.
  int _round = 0; // 0..kRepsPerAffirmation-1
  int get currentAffRep => _round; // keep existing API surface if your UI uses it

  static const int kRepsPerAffirmation = 3;
  int get repsPerAffirmation => kRepsPerAffirmation;

  final SessionSpeechMatcher _speechMatcher = SessionSpeechMatcher();
  SessionSpeechMatcher get speechMatcher => _speechMatcher;

  bool _micNeedsRestart = false;
  bool get micNeedsRestart => _micNeedsRestart;

  String? _status;
  String? get status => _status;

  DateTime? _startedAt;

  Timer? _ticker;

  StreamSubscription<String>? _partialSub;
  StreamSubscription<String>? _finalSub;
  StreamSubscription<Object>? _errSub;
  StreamSubscription<MicState>? _stateSub;

  bool _started = false;

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
    _round = 0;

    _micNeedsRestart = false;

    _speechMatcher.resetForText(_affirmations[_currentAffIdx]);
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

      if (debugMic) {
        debugPrint('[mic][partial] $text');
      }

      final spokenTokens = _speechMatcher.tokenizeSpeech(text);
      final changed = _speechMatcher.updateWithSpokenTokens(spokenTokens);
      if (changed) notifyListeners();
    });

    _finalSub = _mic.finalText$.listen((text) {
      if (_phase != SessionPhase.live) return;

      if (debugMic) {
        debugPrint('[mic][final] $text');
      }

      final spokenTokens = _speechMatcher.tokenizeSpeech(text);
      final changed = _speechMatcher.updateWithSpokenTokens(spokenTokens);
      if (changed) notifyListeners();

      if (_speechMatcher.isComplete) {
        _advanceAffirmation(); // NOTE: does NOT stop/restart mic anymore
      }
    });

    _errSub = _mic.errors$.listen((err) {
      if (_phase != SessionPhase.live) return;
      if (debugMic) debugPrint('[mic][error] $err');

      // Treat errors as “mic might need manual restart” (UI turns red).
      _micNeedsRestart = true;
      notifyListeners();
    });

    _stateSub = _mic.state$.listen((s) {
      if (_phase != SessionPhase.live) return;
      if (debugMic) debugPrint('[mic][state] $s');

      // IMPORTANT: do NOT auto-stop or auto-restart here.
      // Your MicService keep-alive handles iOS “done/notListening” transitions.

      // If we ever see we’re actively listening again, clear the UI “paused” flag.
      if (s == MicState.listening) {
        if (_micNeedsRestart) {
          _micNeedsRestart = false;
          notifyListeners();
        }
      }
    });
  }

  Future<void> _ensureMicReadyAndListen() async {
    final ok = await _mic.init(debugLogging: false);
    if (debugMic) debugPrint('[mic][init] ok=$ok');

    if (!ok) {
      _micNeedsRestart = true;
      notifyListeners();
      return;
    }

    await _listen();
  }

  /// Start listening (do NOT hard-stop first).
  /// Let MicService keep-alive manage its internal restart behavior on iOS.
  Future<void> _listen() async {
    if (_phase != SessionPhase.live) return;

    _micNeedsRestart = false;
    notifyListeners();

    try {
      // If already listening, do nothing.
      if (_mic.isListening) return;

      await _mic.start(
        localeId: 'en_US',
        partialResults: true,
        cancelOnError: false,
        listenFor: const Duration(minutes: 10),
        pauseFor: const Duration(seconds: 6),
      );
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

  /// NEW: cycles affirmations across rounds:
  /// round 0: aff0, aff1, aff2...
  /// round 1: aff0, aff1, aff2...
  /// round 2: aff0, aff1, aff2...
  void _advanceAffirmation() {
    if (_affirmations.isEmpty) return;

    final lastAffIdx = _affirmations.length - 1;
    final isEndOfRound = _currentAffIdx == lastAffIdx;

    if (isEndOfRound) {
      final isLastRound = _round >= kRepsPerAffirmation - 1;
      if (isLastRound) {
        finish();
        return;
      }
      _round += 1;
      _currentAffIdx = 0;
    } else {
      _currentAffIdx += 1;
    }

    _speechMatcher.resetForText(_affirmations[_currentAffIdx]);
    notifyListeners();

    // IMPORTANT: do NOT stop/restart mic here.
    // MicService keep-alive continues listening across transitions.
  }

  Future<void> finish() async {
    if (_phase == SessionPhase.saving || _phase == SessionPhase.done) return;

    _ticker?.cancel();

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

    _partialSub?.cancel();
    _finalSub?.cancel();
    _errSub?.cancel();
    _stateSub?.cancel();

    _navCtrl.close();
    super.dispose();
  }
}