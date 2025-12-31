import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../controllers/session_controller.dart';
import '../services/camera_service.dart';
import '../services/mic_service.dart';

import 'session_summary_page.dart';
import 'new_session/session_camera_preview.dart';
import 'new_session/session_overlay.dart';

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

    // controller now owns camera init + start
    _controller.initAndStart();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller.onPaused();
    } else if (state == AppLifecycleState.resumed) {
      _controller.onResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _navSub?.cancel();

    // Defensive: controller disables wakelock on finish/abort, but keep this.
    WakelockPlus.disable();

    _controller.dispose();
    _micService.dispose();
    _cameraService.dispose();

    super.dispose();
  }

  Future<void> _shareAffirmation() async {
    final affs = _controller.affirmations;
    if (affs.isEmpty) return;
    await Share.share(affs[_controller.currentAffIdx]);
  }

  Future<void> _abortSession() async {
    await _controller.abort();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  InlineSpan _buildAffirmationSpans(BuildContext context) {
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
      final isCurr = i == matcher.activeToken && matcher.activeToken < matcher.tokens.length;
      final style = isCurr ? currStyle : (isDone ? doneStyle : todoStyle);

      children.add(TextSpan(text: w, style: style));
      if (i != matcher.displayTokens.length - 1) {
        children.add(TextSpan(text: ' ', style: style));
      }
    }

    return TextSpan(children: children);
  }

  String _capitalizeFirst(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final phase = _controller.phase;

        final showLiveHud =
            phase == SessionPhase.live || phase == SessionPhase.countdown;
        final showSaving =
            phase == SessionPhase.saving || phase == SessionPhase.done;

        final affs = _controller.affirmations;
        final currentText =
            affs.isNotEmpty ? affs[_controller.currentAffIdx] : '';

        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              SessionCameraPreview(
                controller: _cameraService.controller,
                initFuture: _cameraService.initFuture,
                warmingUp: _controller.cameraWarmingUp,
              ),
              SessionOverlay(
                showLiveHud: showLiveHud,
                showSaving: showSaving,
                currentAffIdx: _controller.currentAffIdx,
                totalAffirmations: affs.length,
                affirmationSpan: _controller.speechMatcher.tokens.isNotEmpty
                    ? _buildAffirmationSpans(context)
                    : null,
                fallbackText: _capitalizeFirst(currentText),
                micNeedsRestart: _controller.micNeedsRestart,
                onMicTap: _controller.onMicTap,
                onShare: _shareAffirmation,
                onClose: _abortSession,
                statusText: _controller.status,
              ),
            ],
          ),
        );
      },
    );
  }
}