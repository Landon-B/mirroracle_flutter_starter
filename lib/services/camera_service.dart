import 'dart:io' show Platform;

import 'package:camera/camera.dart';

/// CameraService is responsible for camera selection + lifecycle.
/// It does NOT know about UI or session timing.
class CameraService {
  CameraController? _controller;
  Future<void>? _initFuture;

  CameraController? get controller => _controller;
  Future<void>? get initFuture => _initFuture;

  bool get isInitialized => _controller?.value.isInitialized == true;
  bool get isAvailable => _controller != null;

  /// Initialize camera once and keep a stable initFuture.
  /// Safe to call multiple times.
  Future<void> init() {
    _initFuture ??= _initImpl();
    return _initFuture!;
  }

  Future<void> _initImpl() async {
    final cams = await availableCameras();
    if (cams.isEmpty) {
      _controller = null;
      return;
    }

    final cam = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cams.first,
    );

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

        await controller.initialize();
        _controller = controller;
        lastErr = null;
        break;
      } on CameraException catch (e) {
        lastErr = e;
      }
    }

    if (_controller == null && lastErr != null) {
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