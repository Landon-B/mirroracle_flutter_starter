import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show Offset;

import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/constants.dart';
import '../core/logger.dart';
import '../core/service_locator.dart';

/// CameraService is responsible for camera selection + lifecycle.
/// It does NOT know about UI or session timing.
class CameraService {
  static List<CameraDescription>? _cachedCameras;
  static final CameraService _instance = CameraService._internal();

  factory CameraService() => _instance;
  CameraService._internal();

  AppLogger get _log => sl<AppLogger>();

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
      _log.camera('No cameras available on device', level: LogLevel.warning);
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
        _log.camera('Initialized with preset: $preset');
        break;
      } on CameraException catch (e) {
        _log.camera('Failed to init with preset $preset', level: LogLevel.warning, error: e);
        lastErr = e;
      }
    }

    if (_controller == null && lastErr != null) {
      _log.camera('All presets failed', level: LogLevel.error, error: lastErr);
      throw lastErr;
    }

    // Temporarily disabled to isolate camera lag.
    // await _postInitTuning();
  }

  Future<List<CameraDescription>> _loadCameras() async {
    if (_cachedCameras != null) return _cachedCameras!;
    try {
      final cams = await availableCameras();
      _cachedCameras = cams;
      return cams;
    } catch (e) {
      _log.camera('Failed to load cameras', level: LogLevel.error, error: e);
      return [];
    }
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
      final targetZoom = (minZoom + kCameraZoomOffset).clamp(minZoom, maxZoom);
      await _setZoomSmooth(c, targetZoom);
    } catch (e) {
      _log.camera('Failed to set zoom', level: LogLevel.debug, error: e);
    }

    try {
      await c.setFocusMode(FocusMode.auto);
    } catch (e) {
      _log.camera('Auto focus not supported, trying locked', level: LogLevel.debug, error: e);
      try {
        await c.setFocusMode(FocusMode.locked);
      } catch (e2) {
        _log.camera('Locked focus also failed', level: LogLevel.debug, error: e2);
      }
    }

    try {
      await c.setExposureMode(ExposureMode.auto);
    } catch (e) {
      _log.camera('Auto exposure not supported, trying locked', level: LogLevel.debug, error: e);
      try {
        await c.setExposureMode(ExposureMode.locked);
      } catch (e2) {
        _log.camera('Locked exposure also failed', level: LogLevel.debug, error: e2);
      }
    }

    await Future.delayed(kCameraPostInitDelay);

    try {
      if (c.value.focusPointSupported) {
        await c.setFocusPoint(const Offset(0.5, 0.5));
      }
    } catch (e) {
      _log.camera('Failed to set focus point', level: LogLevel.debug, error: e);
    }

    try {
      if (c.value.exposurePointSupported) {
        await c.setExposurePoint(const Offset(0.5, 0.5));
      }
    } catch (e) {
      _log.camera('Failed to set exposure point', level: LogLevel.debug, error: e);
    }

    try {
      await c.setFocusMode(FocusMode.locked);
    } catch (e) {
      _log.camera('Failed to lock focus', level: LogLevel.debug, error: e);
    }

    try {
      await c.setExposureMode(ExposureMode.locked);
    } catch (e) {
      _log.camera('Failed to lock exposure', level: LogLevel.debug, error: e);
    }
  }

  Future<void> _setZoomSmooth(CameraController c, double target) async {
    double current;
    try {
      current = await c.getMinZoomLevel();
    } catch (e) {
      _log.camera('Failed to get min zoom, defaulting to 1.0', level: LogLevel.debug, error: e);
      current = 1.0;
    }
    for (int i = 1; i <= kCameraZoomSteps; i++) {
      final level = current + (target - current) * (i / kCameraZoomSteps);
      try {
        await c.setZoomLevel(level);
      } catch (e) {
        _log.camera('Zoom step $i failed', level: LogLevel.debug, error: e);
        break;
      }
      await Future.delayed(kCameraZoomStepDelay);
    }
  }

  Future<void> startImageStream(
    void Function(CameraImage image) onAvailable,
  ) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      _log.camera('Cannot start stream: controller not initialized', level: LogLevel.warning);
      return;
    }
    if (c.value.isStreamingImages) return;
    try {
      await c.startImageStream(onAvailable);
    } catch (e) {
      _log.camera('Failed to start image stream', level: LogLevel.error, error: e);
    }
  }

  Future<void> stopImageStream() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (!c.value.isStreamingImages) return;
    try {
      await c.stopImageStream();
    } catch (e) {
      _log.camera('Failed to stop image stream', level: LogLevel.warning, error: e);
    }
  }

  Future<void> tapToFocus(Offset point) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final dx = point.dx.clamp(0.0, 1.0);
    final dy = point.dy.clamp(0.0, 1.0);
    final normalized = Offset(dx, dy);

    try {
      await c.setFocusMode(FocusMode.auto);
    } catch (e) {
      _log.camera('tap-to-focus: auto focus failed', level: LogLevel.debug, error: e);
    }
    try {
      if (c.value.focusPointSupported) {
        await c.setFocusPoint(normalized);
      }
    } catch (e) {
      _log.camera('tap-to-focus: set focus point failed', level: LogLevel.debug, error: e);
    }

    try {
      await c.setExposureMode(ExposureMode.auto);
    } catch (e) {
      _log.camera('tap-to-focus: auto exposure failed', level: LogLevel.debug, error: e);
    }
    try {
      if (c.value.exposurePointSupported) {
        await c.setExposurePoint(normalized);
      }
    } catch (e) {
      _log.camera('tap-to-focus: set exposure point failed', level: LogLevel.debug, error: e);
    }

    await Future.delayed(kCameraFocusLockDelay);

    try {
      await c.setFocusMode(FocusMode.locked);
    } catch (e) {
      _log.camera('tap-to-focus: lock focus failed', level: LogLevel.debug, error: e);
    }
    try {
      await c.setExposureMode(ExposureMode.locked);
    } catch (e) {
      _log.camera('tap-to-focus: lock exposure failed', level: LogLevel.debug, error: e);
    }
  }

  Future<void> recover() async {
    _log.camera('Recovering camera...');
    await dispose(force: true);
    await init();
  }

  Future<void> pausePreview() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.pausePreview();
    } catch (e) {
      _log.camera('Failed to pause preview', level: LogLevel.warning, error: e);
    }
  }

  Future<void> resumePreview() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.resumePreview();
    } catch (e) {
      _log.camera('Failed to resume preview', level: LogLevel.warning, error: e);
    }
  }

  Future<void> dispose({bool force = false}) async {
    if (_keepAlive && !force) {
      await pausePreview();
      return;
    }
    try {
      await _controller?.dispose();
    } catch (e) {
      _log.camera('Error during dispose', level: LogLevel.warning, error: e);
    }
    _controller = null;
    _initFuture = null;
  }
}
