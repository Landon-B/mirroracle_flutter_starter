import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show Offset;

import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

/// CameraService is responsible for camera selection + lifecycle.
/// It does NOT know about UI or session timing.
class CameraService {
  static List<CameraDescription>? _cachedCameras;
  static final CameraService _instance = CameraService._internal();

  factory CameraService() => _instance;
  CameraService._internal();

  CameraController? _controller;
  Future<void>? _initFuture;
  CameraDescription? _selectedCamera;
  ResolutionPreset? _selectedPreset;
  bool _keepAlive = false;

  CameraController? get controller => _controller;
  Future<void>? get initFuture => _initFuture;

  bool get isInitialized => _controller?.value.isInitialized == true;
  bool get isAvailable => _controller != null;

  CameraDescription? get selectedCamera => _selectedCamera;
  ResolutionPreset? get selectedPreset => _selectedPreset;

  /// Initialize camera once and keep a stable initFuture.
  /// Safe to call multiple times.
  Future<void> init() {
    _initFuture ??= _initImpl();
    return _initFuture!;
  }

  /// Alias for init to support warm-start flows.
  Future<void> warmUp() async {
    _keepAlive = true;
    await init();
    await pausePreview();
  }

  Future<bool> ensureCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted) return true;
    status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<void> _initImpl() async {
    final cams = await _loadCameras();
    if (cams.isEmpty) {
      _controller = null;
      return;
    }

    final cam = _selectedCamera ??
        cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cams.first,
    );
    _selectedCamera = cam;

    final desiredPresets = _preferredPresets();

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
        _selectedPreset = preset;
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

  Future<List<CameraDescription>> _loadCameras() async {
    if (_cachedCameras != null) return _cachedCameras!;
    final cams = await availableCameras();
    _cachedCameras = cams;
    return cams;
  }

  List<ResolutionPreset> _preferredPresets() {
    if (Platform.isIOS) {
      return const [
        ResolutionPreset.veryHigh,
        ResolutionPreset.high,
        ResolutionPreset.ultraHigh,
        ResolutionPreset.medium,
        ResolutionPreset.low,
      ];
    }
    return const [
      ResolutionPreset.high,
      ResolutionPreset.medium,
      ResolutionPreset.veryHigh,
      ResolutionPreset.low,
    ];
  }

  Future<void> _postInitTuning() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    try {
      final minZoom = await c.getMinZoomLevel();
      final maxZoom = await c.getMaxZoomLevel();
      final targetZoom = (minZoom + 0.35).clamp(minZoom, maxZoom);
      await _setZoomSmooth(c, targetZoom);
    } catch (_) {}

    try {
      await c.setFocusMode(FocusMode.auto);
    } catch (_) {
      try {
        await c.setFocusMode(FocusMode.locked);
      } catch (_) {}
    }

    try {
      await c.setExposureMode(ExposureMode.auto);
    } catch (_) {
      try {
        await c.setExposureMode(ExposureMode.locked);
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      if (c.value.focusPointSupported) {
        await c.setFocusPoint(const Offset(0.5, 0.5));
      }
    } catch (_) {}

    try {
      if (c.value.exposurePointSupported) {
        await c.setExposurePoint(const Offset(0.5, 0.5));
      }
    } catch (_) {}

    try {
      await c.setFocusMode(FocusMode.locked);
    } catch (_) {}

    try {
      await c.setExposureMode(ExposureMode.locked);
    } catch (_) {}
  }

  Future<void> _setZoomSmooth(CameraController c, double target) async {
    double current;
    try {
      current = await c.getMinZoomLevel();
    } catch (_) {
      current = 1.0;
    }
    const steps = 3;
    for (int i = 1; i <= steps; i++) {
      final level = current + (target - current) * (i / steps);
      try {
        await c.setZoomLevel(level);
      } catch (_) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 40));
    }
  }

  Future<void> startImageStream(
    void Function(CameraImage image) onAvailable,
  ) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isStreamingImages) return;
    try {
      await c.startImageStream(onAvailable);
    } catch (_) {}
  }

  Future<void> stopImageStream() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (!c.value.isStreamingImages) return;
    try {
      await c.stopImageStream();
    } catch (_) {}
  }

  Future<void> tapToFocus(Offset point) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final dx = point.dx.clamp(0.0, 1.0);
    final dy = point.dy.clamp(0.0, 1.0);
    final normalized = Offset(dx, dy);

    try {
      await c.setFocusMode(FocusMode.auto);
    } catch (_) {}
    try {
      if (c.value.focusPointSupported) {
        await c.setFocusPoint(normalized);
      }
    } catch (_) {}

    try {
      await c.setExposureMode(ExposureMode.auto);
    } catch (_) {}
    try {
      if (c.value.exposurePointSupported) {
        await c.setExposurePoint(normalized);
      }
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 300));

    try {
      await c.setFocusMode(FocusMode.locked);
    } catch (_) {}
    try {
      await c.setExposureMode(ExposureMode.locked);
    } catch (_) {}
  }

  Future<void> recover() async {
    await dispose(force: true);
    await init();
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

  Future<void> dispose({bool force = false}) async {
    if (_keepAlive && !force) {
      await pausePreview();
      return;
    }
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
    _initFuture = null;
  }
}
