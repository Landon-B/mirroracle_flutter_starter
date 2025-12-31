// lib/services/mic_service.dart
import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum MicState { idle, initializing, ready, listening, stopping, disposed }

class MicService {
  MicService({this.tag = 'mic'});

  final String tag;

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
  bool get isAvailable => _available;
  bool get isListening => _stt.isListening;

  // Locale used for listen()
  String? _localeId;

  // Partial throttling
  String _lastPartial = '';
  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
  Duration partialEmitEvery = const Duration(milliseconds: 120);

  // Sound level smoothing
  double _smoothedLevel = 0.0;
  double levelSmoothing = 0.25;

  // Instrumentation
  bool _debug = false;

  void _log(String msg) {
    if (!_debug) return;
    debugPrint('[$tag] $msg');
  }

  void _setState(MicState s) {
    _state = s;
    if (!_stateCtrl.isClosed) _stateCtrl.add(s);
    _log('[state] $s');
  }

  void _emitError(Object e) {
    if (!_errorCtrl.isClosed) _errorCtrl.add(e);
    _log('[error] $e');
  }

  Future<void> _configureIosAudioSession() async {
    if (!Platform.isIOS) return;

    // This is a known-good baseline for speech recognition:
    // - playAndRecord so iOS routes mic audio correctly
    // - defaultToSpeaker so it doesn’t route strangely during capture
    // - allowBluetooth / allowBluetoothA2DP so headphones don’t break recognition
    // - spokenAudio mode to hint “voice” use-case
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.combine([
          AVAudioSessionCategoryOptions.defaultToSpeaker,
          AVAudioSessionCategoryOptions.allowBluetooth,
          AVAudioSessionCategoryOptions.allowBluetoothA2dp,
          // You can add duckOthers if you want music to duck during mic:
          // AVAudioSessionCategoryOptions.duckOthers,
        ]),
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ),
    );

    try {
      await session.setActive(true);
    } catch (e) {
      // Don’t hard-fail init if setActive fails; still try to initialize STT.
      _emitError(e);
    }

    _log('[audio_session] configured + active');
  }

  /// Initialize the speech recognizer.
  ///
  /// - `debugLogging` enables plugin debug logs + our own logs.
  /// - `localeId` optionally forces a locale (e.g., "en_US").
  Future<bool> init({bool debugLogging = false, String? localeId}) async {
    if (_disposed) return false;

    _debug = debugLogging;

    // If already initialized and available, don’t redo heavy work.
    if (_available && _state != MicState.idle && _state != MicState.disposed) {
      _log('[init] already available=true, locale=$_localeId');
      return true;
    }

    _setState(MicState.initializing);

    try {
      // iOS audio session: do this BEFORE initialize/listen.
      await _configureIosAudioSession();

      _available = await _stt.initialize(
        debugLogging: debugLogging,
        onError: (e) {
          if (_disposed) return;
          _emitError(e);
          // When STT errors, it often stops emitting results but claims “listening”.
          // Force state back to ready so callers can restart.
          if (!_disposed) _setState(MicState.ready);
        },
        onStatus: (status) {
          if (_disposed) return;
          if (!_statusCtrl.isClosed) _statusCtrl.add(status);
          _log('[status] $status');
        },
      );

      if (!_available) {
        _setState(MicState.idle);
        _log('[init] available=false (permissions/recognizer unavailable)');
        return false;
      }

      if (localeId != null) {
        _localeId = localeId;
      } else {
        try {
          final sys = await _stt.systemLocale();
          _localeId = sys?.localeId;
        } catch (_) {
          // If systemLocale fails, we’ll let listen() pick default.
          _localeId = null;
        }
      }

      _setState(MicState.ready);
      _log('[init] ok=true locale=$_localeId');
      return true;
    } catch (e) {
      _emitError(e);
      _setState(MicState.idle);
      return false;
    }
  }

  /// Start listening.
  ///
  /// If it was already listening, this will stop/cancel first to avoid the
  /// “listening but no results” stuck state.
  Future<void> start({
    stt.ListenMode listenMode = stt.ListenMode.dictation,
    bool partialResults = true,
    Duration listenFor = const Duration(minutes: 10),
    Duration pauseFor = const Duration(seconds: 2),
    String? localeId,
    bool cancelOnError = false,
  }) async {
    if (_disposed) return;
    if (!_available) {
      _log('[start] skipped (available=false)');
      return;
    }

    // If already listening, do a clean restart (helps iOS stuck cases).
    if (_stt.isListening || _state == MicState.listening) {
      _log('[start] already listening -> restarting');
      await stop();
      await cancel(); // ensure internal recognizer resets
    }

    _setState(MicState.listening);

    _lastPartial = '';
    _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

    try {
      // iOS audio session can get deactivated by other audio events.
      // Reactivate right before listen.
      if (Platform.isIOS) {
        try {
          final session = await AudioSession.instance;
          await session.setActive(true);
          _log('[audio_session] setActive(true) before listen');
        } catch (e) {
          _emitError(e);
        }
      }

      _log('[listen] mode=$listenMode partial=$partialResults locale=${localeId ?? _localeId}');
      await _stt.listen(
        listenMode: listenMode,
        partialResults: partialResults,
        cancelOnError: cancelOnError,
        listenFor: listenFor,
        pauseFor: pauseFor,
        localeId: localeId ?? _localeId,
        onResult: (res) {
          if (_disposed) return;

          final txt = res.recognizedWords.trim();
          if (txt.isEmpty) return;

          if (res.finalResult) {
            if (!_finalCtrl.isClosed) _finalCtrl.add(txt);
            if (!_partialCtrl.isClosed) _partialCtrl.add(txt);
            _lastPartial = txt;
            _log('[final] $txt');
            return;
          }

          final now = DateTime.now();
          final shouldEmit = now.difference(_lastEmit) >= partialEmitEvery;
          final changed = txt != _lastPartial;

          if (changed && shouldEmit) {
            if (!_partialCtrl.isClosed) _partialCtrl.add(txt);
            _lastPartial = txt;
            _lastEmit = now;
            _log('[partial] $txt');
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
      _emitError(e);
      if (!_disposed) _setState(MicState.ready);
    }
  }

  Future<void> stop() async {
    if (_disposed) return;
    if (_state != MicState.listening && !_stt.isListening) return;

    _setState(MicState.stopping);
    try {
      await _stt.stop();
      _log('[stop] ok');
    } catch (e) {
      _emitError(e);
    } finally {
      if (!_disposed) _setState(MicState.ready);
    }
  }

  /// Cancels recognition immediately (hard reset).
  /// This is safe to call even if not currently listening.
  Future<void> cancel() async {
    if (_disposed) return;

    // Don’t flip to stopping if we’re already idle/ready; just cancel underlying.
    try {
      await _stt.cancel();
      _log('[cancel] ok');
    } catch (e) {
      _emitError(e);
    } finally {
      if (!_disposed && _state != MicState.disposed) _setState(MicState.ready);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

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