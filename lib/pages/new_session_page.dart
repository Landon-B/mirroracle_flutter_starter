// lib/pages/new_session_page.dart
import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'session_summary_page.dart';
import 'new_session/session_camera_preview.dart';
import 'new_session/session_overlay.dart';
import 'new_session/session_speech_matcher.dart';

/// Simple state machine: idle -> countdown -> live -> saving -> done
enum SessionPhase { idle, countdown, live, saving, done }

class NewSessionPage extends StatefulWidget {
  final List<String> initialAffirmations; // pass 3 from Home, or empty to use defaults
  const NewSessionPage({super.key, this.initialAffirmations = const []});

  @override
  State<NewSessionPage> createState() => _NewSessionPageState();
}

class _NewSessionPageState extends State<NewSessionPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  SessionPhase _phase = SessionPhase.idle;

  // Camera
  CameraController? _controller;
  Future<void>? _initCam;
  List<CameraDescription> _cameras = const [];

  // Session timing
  static const int kTargetSeconds = 90;
  int _elapsed = 0;
  Timer? _ticker;

  // Presence proxy
  int _presenceSeconds = 0;

  // Affirmations & per-word highlighting
  late List<String> _affirmations; // 3 items
  int _currentAffIdx = 0;
  int _currentAffRep = 0;
  static const int kRepsPerAffirmation = 3;
  final SessionSpeechMatcher _speechMatcher = SessionSpeechMatcher();
  Timer? _affTimer;

  // Speech
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _sttReady = false;
  bool _micNeedsRestart = false;
  bool _listenTimedOut = false;
  Timer? _listenTimeoutTimer;

  // Supabase save
  DateTime? _startedAt;
  String? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _affirmations = widget.initialAffirmations.isNotEmpty
        ? widget.initialAffirmations
        : const ['I am present.', 'I am capable.', 'I finish what I start.'];

    _prepareSpeech();
    _prepareCamera().then((_) {
      if (!mounted) return;
      _startLive();
    });
  }

  // ---------------- Camera ----------------

  Future<bool> _isEmulator() async {
    try {
      final info = await DeviceInfoPlugin().deviceInfo;
      if (info is IosDeviceInfo) return info.isPhysicalDevice == false;
      if (info is AndroidDeviceInfo) return info.isPhysicalDevice == false;
    } catch (_) {}
    return false;
  }

  Future<void> _prepareCamera() async {
    try {
      _cameras = await availableCameras();

      final cam = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      final onEmulator = await _isEmulator();
      final List<ResolutionPreset> desiredPresets = onEmulator
          ? const [ResolutionPreset.low, ResolutionPreset.medium]
          : const [
              ResolutionPreset.max,
              ResolutionPreset.ultraHigh,
              ResolutionPreset.veryHigh,
              ResolutionPreset.high,
              ResolutionPreset.medium,
            ];

      CameraController? controller;
      Future<void>? init;
      CameraException? lastErr;

      for (final preset in desiredPresets) {
        try {
          controller?.dispose();
          controller = CameraController(
            cam,
            preset,
            enableAudio: false,
            imageFormatGroup: Platform.isIOS
                ? ImageFormatGroup.bgra8888
                : ImageFormatGroup.yuv420,
          );
          init = controller.initialize();
          await init;
          _controller = controller;
          _initCam = init;
          lastErr = null;
          break;
        } on CameraException catch (e) {
          lastErr = e;
        }
      }

      if (lastErr != null && (_controller == null || _initCam == null)) {
        throw lastErr;
      }

      try {
        await _controller!.setExposureMode(ExposureMode.auto);
        await _controller!.setFocusMode(FocusMode.auto);
        final minZoom = await _controller!.getMinZoomLevel();
        final maxZoom = await _controller!.getMaxZoomLevel();
        final targetZoom = (minZoom + 0.35).clamp(minZoom, maxZoom);
        await _controller!.setZoomLevel(targetZoom);
        try {
          await Future.delayed(const Duration(milliseconds: 300));
          await _controller!.setFocusMode(FocusMode.locked);
          await _controller!.setExposureMode(ExposureMode.locked);
        } catch (_) {}
      } catch (_) {}
    } catch (_) {
      _controller = null;
      _initCam = null;
    }
  }

  // ---------------- Countdown -> Live -> Finish ----------------

  // Countdown is handled in onboarding; mirror session starts immediately.

  void _startLive() async {
    setState(() {
      _phase = SessionPhase.live;
      _elapsed = 0;
      _presenceSeconds = 0;
      _startedAt = DateTime.now().toUtc();
      _currentAffIdx = 0;
      _currentAffRep = 0;
      _speechMatcher.resetForText(_affirmations[_currentAffIdx]);
      _micNeedsRestart = false;
    });
    WakelockPlus.enable();

    await _prepareSpeech();
    if (_sttReady) {
      _listen();
    } else if (mounted) {
      setState(() => _micNeedsRestart = true);
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _elapsed++;
        _presenceSeconds++;
        if (_elapsed >= kTargetSeconds) {
          _finish();
        }
      });
    });

    _affTimer?.cancel();
  }

  Future<void> _finish() async {
    _ticker?.cancel();
    _affTimer?.cancel();
    await _stopSpeech();
    WakelockPlus.disable();

    setState(() => _phase = SessionPhase.saving);
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

      if (!mounted) return;
      setState(() {
        _phase = SessionPhase.done;
        _status =
            'Session saved • ${duration}s • presence ${(presenceScore * 100).toStringAsFixed(0)}%';
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SessionSummaryPage(
            data: SessionSummaryData(
              durationSec: duration,
              presenceScore: presenceScore.toDouble(),
              affirmations: List<String>.from(_affirmations),
              startedAtUtc: _startedAt ?? endedAt,
              endedAtUtc: endedAt,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = SessionPhase.done;
        _status = 'Save failed: $e';
      });
    }
  }

  Future<void> _abortSession() async {
    _ticker?.cancel();
    _affTimer?.cancel();
    await _stopSpeech();
    WakelockPlus.disable();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _shareAffirmation() async {
    if (_affirmations.isEmpty) return;
    final text = _affirmations[_currentAffIdx];
    await Share.share(text);
  }

  void _advanceAffirmation() {
    if (_affirmations.isEmpty) return;
    if (_currentAffRep < kRepsPerAffirmation - 1) {
      setState(() {
        _currentAffRep += 1;
        _speechMatcher.resetForText(_affirmations[_currentAffIdx]);
      });
      _restartSpeechForNewAffirmation();
      return;
    }

    final isLastAffirmation = _currentAffIdx >= _affirmations.length - 1;
    if (isLastAffirmation) {
      _finish();
      return;
    }

    setState(() {
      _currentAffIdx += 1;
      _currentAffRep = 0;
      _speechMatcher.resetForText(_affirmations[_currentAffIdx]);
    });
    _restartSpeechForNewAffirmation();
  }

  // ---------------- Speech: init, listen, align, highlight ----------------

  Future<void> _prepareSpeech() async {
    if (_sttReady) return;
    try {
      _sttReady = await _stt.initialize(
        onStatus: (status) {
          if ((status == 'notListening' || status == 'done') &&
              _phase == SessionPhase.live) {
            if (!mounted) return;
            if (_listenTimedOut) return;
            _restartSpeechSoon();
          }
        },
        onError: (error) {
          if (!mounted) return;
          final msg = error.errorMsg.toLowerCase();
          final isTimeout = msg.contains('timeout') || msg.contains('no match');
          final isHardFailure = msg.contains('permission') ||
              msg.contains('denied') ||
              msg.contains('not available') ||
              msg.contains('busy') ||
              msg.contains('engine');
          if (error.permanent && !isTimeout && isHardFailure) {
            setState(() {
              _listenTimedOut = true;
              _micNeedsRestart = true;
            });
          } else {
            _restartSpeechSoon();
          }
        },
      );

      if (!_sttReady) return;
    } catch (_) {
      // Mic failures shouldn't break the session
    }
  }

  void _listen() {
    if (!_sttReady) return;

    _listenTimeoutTimer?.cancel();
    setState(() {
      _listenTimedOut = false;
      _micNeedsRestart = false;
    });
    _listenTimeoutTimer = Timer(const Duration(minutes: 10), () {
      if (!mounted || _phase != SessionPhase.live) return;
      setState(() {
        _listenTimedOut = true;
        _micNeedsRestart = true;
      });
      _stopSpeech();
    });
    _stt.listen(
      onResult: (result) {
        final spokenTokens =
            _speechMatcher.tokenizeSpeech(result.recognizedWords);
        final isFinal = result.finalResult;
        final changed = _speechMatcher.updateWithSpokenTokens(spokenTokens);
        if (changed && mounted) {
          setState(() {});
        }

        // If user said the whole line and engine gives a final result,
        // advance to the next affirmation.
        if (_speechMatcher.isComplete && isFinal) {
          _advanceAffirmation();
        }
      },
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: false,
      listenFor: const Duration(minutes: 10),
      pauseFor: const Duration(seconds: 1),
      localeId: null, // device default
    );
  }

  void _restartSpeechSoon() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted || _phase != SessionPhase.live) return;
      if (!_stt.isListening && !_micNeedsRestart) {
        _listen();
      }
    });
  }

  Future<void> _restartSpeechForNewAffirmation() async {
    if (!_sttReady) return;
    try {
      if (_stt.isListening) {
        await _stt.stop();
      }
    } catch (_) {}
    if (_phase == SessionPhase.live) {
      _listen(); // restart to reset listenFor timer per affirmation
    }
  }

  Future<void> _stopSpeech() async {
    try {
      _listenTimeoutTimer?.cancel();
      if (_stt.isListening) {
        await _stt.stop();
      }
    } catch (_) {}
  }

  String _formatLocalDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  // ---------------- Lifecycle ----------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      c.pausePreview();
      _stopSpeech();
    } else if (state == AppLifecycleState.resumed) {
      c.resumePreview();
      if (_phase == SessionPhase.live && !_stt.isListening) {
        _listen();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _affTimer?.cancel();
    _listenTimeoutTimer?.cancel();
    _stopSpeech();
    WakelockPlus.disable();
    _controller?.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------

  Widget _buildCameraPreview() {
    return SessionCameraPreview(
      controller: _controller,
      initFuture: _initCam,
    );
  }

  InlineSpan _buildAffirmationSpans() {
    // Build spans word-by-word with highlight
    final theme = Theme.of(context);
    final base = theme.textTheme.headlineMedium ??
        const TextStyle(fontSize: 28, fontWeight: FontWeight.w700);

    final doneStyle = base.copyWith(color: Colors.black54);
    final currStyle = base.copyWith(
      color: Colors.black,
      decoration: TextDecoration.underline,
      decorationThickness: 2,
    );
    final todoStyle = base.copyWith(color: Colors.black);

    final children = <TextSpan>[];
    for (int i = 0; i < _speechMatcher.displayTokens.length; i++) {
      final w = _speechMatcher.displayTokens[i];
      final isDone = i < _speechMatcher.activeToken;
      final isCurr = i == _speechMatcher.activeToken;
      final style = isCurr ? currStyle : (isDone ? doneStyle : todoStyle);
      children.add(TextSpan(text: w, style: style));
      if (i != _speechMatcher.displayTokens.length - 1) {
        children.add(TextSpan(text: ' ', style: style));
      }
    }

    return TextSpan(children: children);
  }

  @override
  Widget build(BuildContext context) {
    final overlay = _buildOverlay();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraPreview(),
          overlay,
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    final showLiveHud =
        _phase == SessionPhase.live || _phase == SessionPhase.countdown;
    final showSaving =
        _phase == SessionPhase.saving || _phase == SessionPhase.done;

    return SessionOverlay(
      showLiveHud: showLiveHud,
      showSaving: showSaving,
      currentAffIdx: _currentAffIdx,
      totalAffirmations: _affirmations.length,
      affirmationSpan: _speechMatcher.tokens.isNotEmpty
          ? _buildAffirmationSpans()
          : null,
      fallbackText: _capitalizeFirst(_affirmations[_currentAffIdx]),
      micNeedsRestart: _micNeedsRestart,
      onMicTap: _listen,
      onShare: _shareAffirmation,
      onClose: _abortSession,
      statusText: _status,
    );
  }
}
