import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'session_summary_page.dart';
import 'new_session/session_camera_preview.dart';
import 'new_session/session_overlay.dart';

import '../controllers/session_controller.dart';
import '../services/camera_service.dart';
import '../services/mic_service.dart';

class NewSessionPage extends StatefulWidget {
  final List<String> initialAffirmations;
  const NewSessionPage({super.key, this.initialAffirmations = const []});

  @override
  State<NewSessionPage> createState() => _NewSessionPageState();
}

class _NewSessionPageState extends State<NewSessionPage>
    with WidgetsBindingObserver {
  late final CameraService _cameraService;
  late final MicService _micService;
  late final SessionController _controller;

  StreamSubscription<SessionNavEvent>? _navSub;

  Future<void>? _initCam;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _cameraService = CameraService();
    _micService = MicService();

    _controller = SessionController(
      camera: _cameraService,
      mic: _micService,
      initialAffirmations: widget.initialAffirmations,
    );

    _controller.addListener(_onControllerChanged);

    _initCam = _cameraService.init().catchError((_) {});
    _initCam!.then((_) async {
      if (!mounted) return;

      // start session when camera is ready (same behavior as before)
      await _controller.start();
    });

    _navSub = _controller.navEvents$.listen((evt) {
      if (!mounted) return;
      if (evt is NavigateToSummary) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SessionSummaryPage(data: evt.data),
          ),
        );
      }
    });
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraService.pausePreview();
      _controller.onPaused();
    } else if (state == AppLifecycleState.resumed) {
      _cameraService.resumePreview();
      _controller.onResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _navSub?.cancel();
    _controller.removeListener(_onControllerChanged);

    // stop wakelock defensively (controller already does on finish/abort)
    WakelockPlus.disable();

    _controller.dispose();
    _micService.dispose();
    _cameraService.dispose();

    super.dispose();
  }

  Future<void> _shareAffirmation() async {
    final affs = _controller.affirmations;
    if (affs.isEmpty) return;
    final txt = affs[_controller.currentAffIdx];
    await Share.share(txt);
  }

  Future<void> _abortSession() async {
    await _controller.abort();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  InlineSpan _buildAffirmationSpans() {
    final matcher = _controller.speechMatcher;
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
    for (int i = 0; i < matcher.displayTokens.length; i++) {
      final w = matcher.displayTokens[i];
      final isDone = i < matcher.activeToken;
      final isCurr = i == matcher.activeToken;
      final style = isCurr ? currStyle : (isDone ? doneStyle : todoStyle);
      children.add(TextSpan(text: w, style: style));
      if (i != matcher.displayTokens.length - 1) {
        children.add(TextSpan(text: ' ', style: style));
      }
    }

    return TextSpan(children: children);
  }

  String _capitalizeFirst(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final overlay = _buildOverlay();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          SessionCameraPreview(
            controller: _cameraService.controller,
            initFuture: _cameraService.initFuture,
          ),
          overlay,
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    final phase = _controller.phase;

    final showLiveHud = phase == SessionPhase.live || phase == SessionPhase.countdown;
    final showSaving = phase == SessionPhase.saving || phase == SessionPhase.done;

    final affs = _controller.affirmations;
    final currentText = affs.isNotEmpty ? affs[_controller.currentAffIdx] : '';

    return SessionOverlay(
      showLiveHud: showLiveHud,
      showSaving: showSaving,
      currentAffIdx: _controller.currentAffIdx,
      totalAffirmations: affs.length,
      affirmationSpan: _controller.speechMatcher.tokens.isNotEmpty
          ? _buildAffirmationSpans()
          : null,
      fallbackText: _capitalizeFirst(currentText),
      micNeedsRestart: _controller.micNeedsRestart,
      onMicTap: _controller.onMicTap,
      onShare: _shareAffirmation,
      onClose: _abortSession,
      statusText: _controller.status,
    );
  }
}