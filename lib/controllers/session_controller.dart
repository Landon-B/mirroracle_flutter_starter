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
  bool get isMicListening => _mic.isListening;
  bool _micTransitioning = false;
  bool get isMicTransitioning => _micTransitioning;

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

  // ---- ignore tail-end mic results right after switching affirmations ----
  DateTime _ignoreMicUntil = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _advanceTimer;
  bool _awaitingNewUtterance = false;
  DateTime _lastMicEventAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _minGapForNewUtterance = Duration(milliseconds: 700);

  bool _shouldIgnoreMicResult() => DateTime.now().isBefore(_ignoreMicUntil);

  void _armMicIgnoreWindow([Duration d = const Duration(milliseconds: 250)]) {
    _ignoreMicUntil = DateTime.now().add(d);
  }

  void _resetMatcherAndShieldForNewAffirmation() {
    _speechMatcher.resetForText(_affirmations[_currentAffIdx]);
    _armMicIgnoreWindow();
    _awaitingNewUtterance = true;
    notifyListeners();
  }

  void _handleAffirmationComplete() {
    if (!_speechMatcher.isComplete) return;
    if (_micTransitioning) return;
    _micTransitioning = true;
    _awaitingNewUtterance = true;
    notifyListeners();
    _advanceAffirmation();
  }

  // ---------------------------
  // Favorites (Supabase)
  // ---------------------------
  final Set<String> _favoriteAffirmationIds = <String>{};
  bool _favoritesLoaded = false;

  bool get favoritesLoaded => _favoritesLoaded;

  String get currentAffirmationText {
    if (_affirmations.isEmpty) return '';
    return _affirmations[_currentAffIdx];
  }

  bool get isCurrentAffirmationFavorited {
    final id = _affirmationIdCache[currentAffirmationText];
    if (id == null) return false;
    return _favoriteAffirmationIds.contains(id);
  }

  // Cache: affirmation text -> affirmation.id
  final Map<String, String> _affirmationIdCache = <String, String>{};

  Future<String?> _getAffirmationIdForText(String text) async {
    if (text.trim().isEmpty) return null;

    final cached = _affirmationIdCache[text];
    if (cached != null) return cached;

    final resp = await Supabase.instance.client
        .from('affirmations')
        .select('id')
        .eq('text', text)
        .limit(1)
        .maybeSingle();

    final id = resp?['id'] as String?;
    if (id != null) _affirmationIdCache[text] = id;
    return id;
  }

  Future<void> _loadFavoritesIfNeeded() async {
    if (_favoritesLoaded) return;

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      _favoritesLoaded = true;
      return;
    }

    final rows = await Supabase.instance.client
        .from('favorite_affirmations')
        .select('affirmation_id')
        .eq('user_id', uid);

    _favoriteAffirmationIds
      ..clear()
      ..addAll(
        rows.map((r) => r['affirmation_id'] as String).where((s) => s.isNotEmpty),
      );

    _favoritesLoaded = true;
    notifyListeners();
  }

  Future<void> toggleFavoriteCurrentAffirmation() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      _status = 'Please sign in to favorite affirmations.';
      notifyListeners();
      return;
    }

    final text = currentAffirmationText;
    final affId = await _getAffirmationIdForText(text);

    if (affId == null) {
      _status = 'Could not favorite: affirmation not found in DB.';
      notifyListeners();
      return;
    }

    final isFav = _favoriteAffirmationIds.contains(affId);

    try {
      if (isFav) {
        await Supabase.instance.client
            .from('favorite_affirmations')
            .delete()
            .eq('user_id', uid)
            .eq('affirmation_id', affId);

        _favoriteAffirmationIds.remove(affId);
      } else {
        // If you have a unique constraint on (user_id, affirmation_id), this is safe.
        await Supabase.instance.client.from('favorite_affirmations').upsert(
          {
            'user_id': uid,
            'affirmation_id': affId,
          },
          onConflict: 'user_id,affirmation_id',
        );

        _favoriteAffirmationIds.add(affId);
      }

      notifyListeners();
    } catch (e) {
      _status = 'Favorite failed: $e';
      notifyListeners();
    }
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

    await _loadFavoritesIfNeeded();
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

    _resetMatcherAndShieldForNewAffirmation();

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

  Future<void> _wireMic() async {
    await _partialSub?.cancel();
    await _finalSub?.cancel();
    await _errSub?.cancel();
    await _stateSub?.cancel();

    _partialSub = _mic.partialText$.listen((text) {
      if (_phase != SessionPhase.live) return;
      if (_shouldIgnoreMicResult()) return;
      final now = DateTime.now();
      if (_awaitingNewUtterance &&
          now.difference(_lastMicEventAt) < _minGapForNewUtterance) {
        _lastMicEventAt = now;
        return;
      }
      _awaitingNewUtterance = false;

      if (debugMic) debugPrint('[mic][partial] $text');

      final spokenTokens = _speechMatcher.tokenizeSpeechForCurrent(text);
      final changed = _speechMatcher.updateWithSpokenTokens(spokenTokens);
      if (changed) notifyListeners();
      _handleAffirmationComplete();
      _lastMicEventAt = now;
    });

    _finalSub = _mic.finalText$.listen((text) {
      if (_phase != SessionPhase.live) return;
      if (_shouldIgnoreMicResult()) return;
      final now = DateTime.now();
      if (_awaitingNewUtterance &&
          now.difference(_lastMicEventAt) < _minGapForNewUtterance) {
        _lastMicEventAt = now;
        return;
      }
      _awaitingNewUtterance = false;

      if (debugMic) debugPrint('[mic][final] $text');

      final spokenTokens = _speechMatcher.tokenizeSpeechForCurrent(text);
      final changed = _speechMatcher.updateWithSpokenTokens(spokenTokens);
      if (changed) notifyListeners();

      _handleAffirmationComplete();
      _lastMicEventAt = now;
    });

    _errSub = _mic.errors$.listen((err) {
      if (_phase != SessionPhase.live) return;
      if (debugMic) debugPrint('[mic][error] $err');
      _restartListeningSoon();
    });

    _stateSub = _mic.state$.listen((s) {
      if (_phase != SessionPhase.live) return;
      if (debugMic) debugPrint('[mic][state] $s');

      notifyListeners();

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

  void _listen() async {
    if (_phase != SessionPhase.live) return;

    _micTransitioning = false;
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
          keepAlive: true,
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
    if (_mic.isListening) return;
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

  void _advanceAffirmation() {
    if (_affirmations.isEmpty) return;

    _advanceTimer?.cancel();
    _advanceTimer = null;

    if (_phase != SessionPhase.live) return;

    final nextIdx = _currentAffIdx + 1;

    if (nextIdx < _affirmations.length) {
      _currentAffIdx = nextIdx;
      _resetMatcherAndShieldForNewAffirmation();
      _micTransitioning = false;
      notifyListeners();
      _restartMicForNextAffirmation();
      return;
    }

    final nextRound = _currentAffRep + 1;

    if (nextRound < kRepsPerAffirmation) {
      _currentAffRep = nextRound;
      _currentAffIdx = 0;
      _resetMatcherAndShieldForNewAffirmation();
      _micTransitioning = false;
      notifyListeners();
      _restartMicForNextAffirmation();
      return;
    }

    finish();
  }

  void _restartMicForNextAffirmation() {
    if (_phase != SessionPhase.live) return;
    // Hard reset STT so partials from the previous affirmation don't carry over.
    _mic.stop();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (_phase != SessionPhase.live) return;
      _listen();
    });
  }

  Future<void> finish() async {
    if (_phase == SessionPhase.saving || _phase == SessionPhase.done) return;

    _ticker?.cancel();
    _listenTimeoutTimer?.cancel();
    _advanceTimer?.cancel();
    _advanceTimer = null;
    _micTransitioning = false;

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
    _advanceTimer?.cancel();
    _advanceTimer = null;
    _micTransitioning = false;

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
    _advanceTimer?.cancel();

    _partialSub?.cancel();
    _finalSub?.cancel();
    _errSub?.cancel();
    _stateSub?.cancel();

    _navCtrl.close();
    super.dispose();
  }
}
