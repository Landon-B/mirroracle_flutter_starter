import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;
  Future<void>? _initFuture;

  CameraController? get controller => _controller;
  Future<void>? get initFuture => _initFuture;

  bool get isInitialized => _controller?.value.isInitialized == true;

  Future<void> init() async {
    final cams = await availableCameras();

    final cam = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cams.first,
    );

    // Start high, fall back if device can’t handle it.
    const desiredPresets = <ResolutionPreset>[
      ResolutionPreset.ultraHigh,
      ResolutionPreset.veryHigh,
      ResolutionPreset.high,
      ResolutionPreset.medium,
      ResolutionPreset.low,
    ];

    CameraController? controller;
    CameraException? lastErr;

    for (final preset in desiredPresets) {
      try {
        await controller?.dispose();

        controller = CameraController(
          cam,
          preset,
          enableAudio: false,
          imageFormatGroup:
              Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
        );

        final init = controller.initialize();
        _initFuture = init;
        await init;

        _controller = controller;
        lastErr = null;
        break;
      } on CameraException catch (e) {
        lastErr = e;
      }
    }

    if (lastErr != null && _controller == null) {
      throw lastErr;
    }

    await _postInitTuning();
  }

  Future<void> _postInitTuning() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    try {
      await c.setExposureMode(ExposureMode.auto);
      await c.setFocusMode(FocusMode.auto);

      final minZoom = await c.getMinZoomLevel();
      final maxZoom = await c.getMaxZoomLevel();
      final targetZoom = (minZoom + 0.35).clamp(minZoom, maxZoom);
      await c.setZoomLevel(targetZoom);

      // Lock after a beat for stability.
      await Future.delayed(const Duration(milliseconds: 300));
      try {
        await c.setFocusMode(FocusMode.locked);
        await c.setExposureMode(ExposureMode.locked);
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> pausePreview() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.pausePreview();
    } catch (_) {}
  }

  Future<void> resumePreview() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.resumePreview();
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
    _initFuture = null;
  }
}