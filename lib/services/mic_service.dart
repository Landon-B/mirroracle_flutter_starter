// lib/services/mic_service.dart
import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum MicState { idle, initializing, ready, listening, stopping, disposed }

class MicService {
  final stt.SpeechToText _stt = stt.SpeechToText();

  final _partialCtrl = StreamController<String>.broadcast();
  final _finalCtrl = StreamController<String>.broadcast();
  final _levelCtrl = StreamController<double>.broadcast();
  final _errorCtrl = StreamController<Object>.broadcast();
  final _stateCtrl = StreamController<MicState>.broadcast();
  final _statusCtrl = StreamController<String>.broadcast();

  Stream<String> get partialText$ => _partialCtrl.stream;
  Stream<String> get finalText$ => _finalCtrl.stream;
  Stream<double> get soundLevel$ => _levelCtrl.stream;
  Stream<Object> get errors$ => _errorCtrl.stream;
  Stream<MicState> get state$ => _stateCtrl.stream;
  Stream<String> get status$ => _statusCtrl.stream;

  MicState _state = MicState.idle;
  MicState get state => _state;

  bool _available = false;
  bool _disposed = false;
  String? _localeId;

  String _lastPartial = '';
  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
  Duration partialEmitEvery = const Duration(milliseconds: 100);

  double _smoothedLevel = 0.0;
  double levelSmoothing = 0.25;

  bool get isAvailable => _available;
  bool get isListening => _stt.isListening;

  // ---- Keep-alive listening (prevents "must stop/start") ----
  bool _keepAlive = false;
  Timer? _restartTimer;

  // We keep the last listen config so restart uses identical settings.
  stt.ListenMode _listenMode = stt.ListenMode.dictation;
  bool _partialResults = true;
  Duration _listenFor = const Duration(minutes: 10);
  Duration _pauseFor = const Duration(seconds: 6); // <-- default longer pause
  String? _startLocaleId;
  bool _cancelOnError = false;
  bool _debugLogging = false;
  DateTime _lastStatusAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastStatus;
  int _noSpeechStreak = 0;
  DateTime _lastNoSpeechAt = DateTime.fromMillisecondsSinceEpoch(0);

  void _setState(MicState s) {
    _state = s;
    if (!_stateCtrl.isClosed) _stateCtrl.add(s);
  }

  void _log(String msg) {
    debugPrint('[mic] $msg');
  }

  bool _isNoSpeechError(Object e) {
    return e.toString().toLowerCase().contains('no speech');
  }

  AVAudioSessionCategoryOptions _iosCategoryOptions() {
    // audio_session expects AVAudioSessionCategoryOptions (bitmask object),
    // NOT int and NOT List<...>.
    return AVAudioSessionCategoryOptions.defaultToSpeaker |
        AVAudioSessionCategoryOptions.allowBluetooth |
        AVAudioSessionCategoryOptions.mixWithOthers;
  }

  Future<void> _configureIosAudioSessionIfNeeded({required bool debugLogging}) async {
    if (kIsWeb) return;
    if (!Platform.isIOS) return;

    try {
      final session = await AudioSession.instance;

      // "spokenAudio" + playAndRecord is a solid baseline for STT.
      // NOTE: Some audio_session versions do NOT support allowBluetoothA2DP.
      // Use allowBluetooth (or allowBluetoothHFP if available in your version).
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: _iosCategoryOptions(),
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,

          // Harmless on iOS; used on Android.
          androidAudioAttributes: const AndroidAudioAttributes(
            usage: AndroidAudioUsage.voiceCommunication,
            contentType: AndroidAudioContentType.speech,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
          androidWillPauseWhenDucked: false,
        ),
      );

      if (debugLogging) _log('[audio_session] configured');
    } catch (e) {
      if (debugLogging) _log('[audio_session] configure failed: $e');
    }
  }

  Future<bool> init({bool debugLogging = false, String? localeId}) async {
    if (_disposed) return false;
    if (_state == MicState.listening) return _available;

    _setState(MicState.initializing);
    if (debugLogging) _log('[init] starting…');

    await _configureIosAudioSessionIfNeeded(debugLogging: debugLogging);

    try {
      _available = await _stt.initialize(
        debugLogging: debugLogging,
        onError: (e) {
          if (debugLogging) _log('[plugin][error] $e');
          if (!_errorCtrl.isClosed) _errorCtrl.add(e);

          if (_isNoSpeechError(e)) {
            _noSpeechStreak = (_noSpeechStreak + 1).clamp(1, 6);
            _lastNoSpeechAt = DateTime.now();
            if (_keepAlive && _state == MicState.listening) {
              final backoffMs = 750 * (1 << (_noSpeechStreak - 1));
              final delay =
                  Duration(milliseconds: backoffMs.clamp(750, 8000));
              _scheduleRestart(reason: 'no-speech', force: true, delay: delay);
            }
          }
        },
        onStatus: (status) {
          if (_disposed) return;
          if (debugLogging) _log('[plugin][status] $status');
          if (!_statusCtrl.isClosed) _statusCtrl.add(status);
          _lastStatus = status;
          _lastStatusAt = DateTime.now();

          // If we are in keep-alive mode, restart on "done"/"notListening".
          final s = status.toLowerCase();
          if (s == 'done' || s == 'notlistening') {
            if (_keepAlive && _state == MicState.listening) {
              final sinceNoSpeech =
                  DateTime.now().difference(_lastNoSpeechAt);
              if (_noSpeechStreak > 0 && sinceNoSpeech.inMilliseconds < 6000) {
                final backoffMs = 750 * (1 << (_noSpeechStreak - 1));
                final delay =
                    Duration(milliseconds: backoffMs.clamp(750, 8000));
                _scheduleRestart(
                  reason: 'status=$status (no-speech backoff)',
                  force: true,
                  delay: delay,
                );
              } else {
                _scheduleRestart(reason: 'status=$status', force: true);
              }
            } else if (_state == MicState.listening && !_stt.isListening) {
              _setState(MicState.ready);
            }
          }
        },
      );

      if (_available) {
        if (localeId != null) {
          _localeId = localeId;
        } else {
          final sys = await _stt.systemLocale();
          _localeId = sys?.localeId;
        }
        _setState(MicState.ready);
      } else {
        _setState(MicState.idle);
      }

      if (debugLogging) _log('[init] ok=$_available locale=$_localeId');
      return _available;
    } catch (e) {
      if (debugLogging) _log('[init] exception: $e');
      if (!_errorCtrl.isClosed) _errorCtrl.add(e);
      _setState(MicState.idle);
      return false;
    }
  }

  void _scheduleRestart({
    required String reason,
    bool force = false,
    Duration? delay,
  }) {
    if (_disposed) return;
    if (!_keepAlive) return;

    // Avoid restart storms.
    _restartTimer?.cancel();
    _restartTimer = Timer(delay ?? const Duration(milliseconds: 250), () async {
      if (_disposed) return;
      if (!_keepAlive) return;
      if (_state != MicState.listening) return;

      // If the plugin thinks it's still listening, don’t force a restart.
      if (_stt.isListening && !force) return;

      if (force) {
        try {
          await _stt.stop();
          await _stt.cancel();
        } catch (_) {}
      }

      if (_debugLogging) _log('[keep-alive] restarting ($reason)…');
      await _startInternal(restarting: true);
    });
  }

  Future<void> start({
    stt.ListenMode listenMode = stt.ListenMode.dictation,
    bool partialResults = true,
    Duration listenFor = const Duration(minutes: 10),
    Duration pauseFor = const Duration(seconds: 6), // <-- increase from 2s
    String? localeId,
    bool cancelOnError = false,
    bool debugLogging = false,
    bool keepAlive = true,
  }) async {
    if (_disposed) return;
    if (!_available) {
      final ok = await init(debugLogging: debugLogging, localeId: localeId);
      if (!ok) {
        if (debugLogging) _log('[start] ignored: not available');
        return;
      }
    }
    if (_state == MicState.listening) {
      if (_stt.isListening) {
        if (debugLogging) _log('[start] ignored: already listening');
        return;
      }
      _setState(MicState.ready);
    }

    // Save config for restarts.
    _listenMode = listenMode;
    _partialResults = partialResults;
    _listenFor = listenFor;
    _pauseFor = pauseFor;
    _startLocaleId = localeId;
    _cancelOnError = cancelOnError;
    _debugLogging = debugLogging;

    _keepAlive = keepAlive;
    _setState(MicState.listening);

    _lastPartial = '';
    _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

    if (debugLogging) {
      _log('[start] listenMode=$listenMode partial=$partialResults locale=${localeId ?? _localeId} pauseFor=$pauseFor');
    }

    await _startInternal(restarting: false);
  }

  Future<void> _startInternal({required bool restarting}) async {
    if (_disposed) return;
    if (!_available) return;
    if (_state != MicState.listening) return;

    try {
      if (Platform.isIOS) {
        try {
          final session = await AudioSession.instance;
          await session.setActive(true);
        } catch (_) {}
      }
      await _stt.listen(
        listenMode: _listenMode,
        partialResults: _partialResults,
        cancelOnError: _cancelOnError,
        listenFor: _listenFor,
        pauseFor: _pauseFor,
        localeId: _startLocaleId ?? _localeId,
        onResult: (res) {
          if (_disposed) return;

          final txt = res.recognizedWords.trim();
          if (txt.isEmpty) return;

          _noSpeechStreak = 0;

          if (res.finalResult) {
            if (_debugLogging) _log('[final] $txt');
            if (!_finalCtrl.isClosed) _finalCtrl.add(txt);
            if (!_partialCtrl.isClosed) _partialCtrl.add(txt);
            _lastPartial = txt;

            // Many iOS sessions end shortly after final. Keep-alive will restart
            // when status flips to done/notListening. (Don’t restart here.)
            return;
          }

          final now = DateTime.now();
          final shouldEmit = now.difference(_lastEmit) >= partialEmitEvery;
          final changed = txt != _lastPartial;

          if (changed && shouldEmit) {
            if (_debugLogging) _log('[partial] $txt');
            if (!_partialCtrl.isClosed) _partialCtrl.add(txt);
            _lastPartial = txt;
            _lastEmit = now;
          }
        },
        onSoundLevelChange: (raw) {
          if (_disposed) return;
          final normalized = ((raw + 50.0) / 60.0).clamp(0.0, 1.0);
          _smoothedLevel =
              _smoothedLevel + levelSmoothing * (normalized - _smoothedLevel);
          if (!_levelCtrl.isClosed) _levelCtrl.add(_smoothedLevel);
        },
      );
    } catch (e) {
      if (_debugLogging) _log('[listen] exception: $e');
      if (!_errorCtrl.isClosed) _errorCtrl.add(e);

      // If we’re trying to keep alive, schedule a restart.
      if (_keepAlive && !_disposed && _state == MicState.listening) {
        _scheduleRestart(reason: 'listen-exception');
      } else {
        if (!_disposed) _setState(MicState.ready);
      }
    }
  }

  Future<void> stop({bool debugLogging = false}) async {
    if (_disposed) return;

    _keepAlive = false;
    _restartTimer?.cancel();
    _restartTimer = null;

    if (_state != MicState.listening) return;

    _setState(MicState.stopping);
    if (debugLogging) _log('[stop]');

    try {
      await _stt.stop();
      await _stt.cancel();
      if (Platform.isIOS) {
        try {
          final session = await AudioSession.instance;
          await session.setActive(false);
        } catch (_) {}
      }
    } catch (e) {
      if (debugLogging) _log('[stop] exception: $e');
      if (!_errorCtrl.isClosed) _errorCtrl.add(e);
    } finally {
      if (!_disposed) _setState(MicState.ready);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _keepAlive = false;
    _restartTimer?.cancel();
    _restartTimer = null;

    _setState(MicState.disposed);

    try {
      await _stt.cancel();
    } catch (_) {}

    await Future.wait([
      _partialCtrl.close(),
      _finalCtrl.close(),
      _levelCtrl.close(),
      _errorCtrl.close(),
      _stateCtrl.close(),
      _statusCtrl.close(),
    ]);
  }
}
