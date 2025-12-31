// lib/pages/new_session_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
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

  // Wrap the whole screen so Share captures camera + overlay
  final GlobalKey _captureKey = GlobalKey();

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

    WakelockPlus.disable();

    _controller.dispose();
    _micService.dispose();
    _cameraService.dispose();

    super.dispose();
  }

  Future<void> _shareScreenshot() async {
    // Ensure the frame is painted before capture.
    await WidgetsBinding.instance.endOfFrame;

    final ctx = _captureKey.currentContext;
    if (ctx == null) return;

    final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    try {
      final ui.Image image =
          await boundary.toImage(pixelRatio: ui.window.devicePixelRatio);

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/mirroracle_session_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Mirroracle ✨',
      );
    } catch (e) {
      // optional: show snack
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    await _controller.toggleFavoriteCurrentAffirmation();
    if (!mounted) return;

    final isFav = _controller.isCurrentAffirmationFavorited;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isFav ? 'Added to favorites' : 'Removed from favorites'),
        duration: const Duration(milliseconds: 900),
      ),
    );
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

  String _capitalizeFirst(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

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
          body: RepaintBoundary(
            key: _captureKey,
            child: Stack(
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
                  onShare: _shareScreenshot,
                  onClose: _abortSession,
                  statusText: _controller.status,

                  // ✅ requires the small SessionOverlay patch below
                  onFavorite: _toggleFavorite,
                  isFavorited: _controller.isCurrentAffirmationFavorited,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}