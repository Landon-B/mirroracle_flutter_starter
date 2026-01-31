import 'package:flutter/foundation.dart';

import '../core/logger.dart';
import '../core/service_locator.dart';
import 'camera_service.dart';

/// Tracks the global camera ready state and notifies listeners.
///
/// This enables the UI to react to camera readiness changes without
/// causing rebuilds or jank. The camera can be pre-warmed in the background
/// and the UI will smoothly transition when ready.
class CameraReadyNotifier extends ChangeNotifier {
  CameraReadyNotifier();

  AppLogger get _log => sl<AppLogger>();

  bool _isWarming = false;
  bool _isReady = false;
  bool _permissionGranted = false;
  bool _warmUpAttempted = false;
  String? _errorMessage;

  /// Whether the camera is currently warming up.
  bool get isWarming => _isWarming;

  /// Whether the camera is initialized and ready to use.
  bool get isReady => _isReady;

  /// Whether camera permission was granted.
  bool get permissionGranted => _permissionGranted;

  /// Whether warm-up has been attempted at least once.
  bool get warmUpAttempted => _warmUpAttempted;

  /// Error message if warm-up failed.
  String? get errorMessage => _errorMessage;

  /// Warm up the camera in the background.
  ///
  /// This should be called once after the user logs in. It's safe to call
  /// multiple times - subsequent calls are ignored if already warming or ready.
  Future<void> warmUp() async {
    // Already warming or ready
    if (_isWarming || _isReady) return;

    _isWarming = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final camera = sl<CameraService>();

      // Check permission first
      _permissionGranted = await camera.ensureCameraPermission();
      if (!_permissionGranted) {
        _log.camera('Camera permission denied during warm-up', level: LogLevel.warning);
        _isWarming = false;
        _warmUpAttempted = true;
        _errorMessage = 'Camera permission denied';
        notifyListeners();
        return;
      }

      // Warm up the camera (initializes and pauses preview)
      await camera.warmUp();

      _isReady = camera.isInitialized;
      _isWarming = false;
      _warmUpAttempted = true;

      if (_isReady) {
        _log.camera('Camera warmed up successfully');
      } else {
        _errorMessage = 'Camera initialization failed';
        _log.camera('Camera warm-up completed but not ready', level: LogLevel.warning);
      }

      notifyListeners();
    } catch (e) {
      _log.camera('Camera warm-up failed', level: LogLevel.error, error: e);
      _isWarming = false;
      _warmUpAttempted = true;
      _errorMessage = 'Camera warm-up failed: $e';
      notifyListeners();
    }
  }

  /// Reset the notifier state (e.g., on logout).
  void reset() {
    _isWarming = false;
    _isReady = false;
    _permissionGranted = false;
    _warmUpAttempted = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Mark camera as ready (called when camera is initialized elsewhere).
  void markReady() {
    if (_isReady) return;
    _isReady = true;
    _isWarming = false;
    _warmUpAttempted = true;
    notifyListeners();
  }

  /// Mark camera as not ready (e.g., after dispose).
  void markNotReady() {
    _isReady = false;
    notifyListeners();
  }
}
