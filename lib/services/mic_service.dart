import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum MicState { idle, initializing, ready, listening, stopping, disposed }

class MicService {
  final stt.SpeechToText _stt = stt.SpeechToText();

  final _partialCtrl = StreamController<String>.broadcast();
  final _finalCtrl = StreamController<String>.broadcast();
  final _levelCtrl = StreamController<double>.broadcast();
  final _errorCtrl = StreamController<Object>.broadcast();
  final _stateCtrl = StreamController<MicState>.broadcast();

  // ✅ NEW: status stream from the plugin (e.g., "listening", "notListening", "done")
  final _statusCtrl = StreamController<String>.broadcast();
  Stream<String> get status$ => _statusCtrl.stream;

  Stream<String> get partialText$ => _partialCtrl.stream;
  Stream<String> get finalText$ => _finalCtrl.stream;
  Stream<double> get soundLevel$ => _levelCtrl.stream;
  Stream<Object> get errors$ => _errorCtrl.stream;
  Stream<MicState> get state$ => _stateCtrl.stream;

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

  void _setState(MicState s) {
    _state = s;
    if (!_stateCtrl.isClosed) _stateCtrl.add(s);
  }

  Future<bool> init({bool debugLogging = false, String? localeId}) async {
    if (_disposed) return false;
    if (_state == MicState.listening) return _available;

    _setState(MicState.initializing);
    try {
      _available = await _stt.initialize(
        debugLogging: debugLogging,
        onError: (e) {
          if (!_errorCtrl.isClosed) _errorCtrl.add(e);
        },
        // ✅ NEW
        onStatus: (status) {
          if (_disposed) return;
          if (!_statusCtrl.isClosed) _statusCtrl.add(status);
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
      return _available;
    } catch (e) {
      if (!_errorCtrl.isClosed) _errorCtrl.add(e);
      _setState(MicState.idle);
      return false;
    }
  }

  Future<void> start({
    stt.ListenMode listenMode = stt.ListenMode.dictation,
    bool partialResults = true,
    Duration listenFor = const Duration(minutes: 10),
    Duration pauseFor = const Duration(seconds: 2),
    String? localeId,
    bool cancelOnError = false,
  }) async {
    if (_disposed) return;
    if (!_available) return;
    if (_state == MicState.listening) return;

    _setState(MicState.listening);

    _lastPartial = '';
    _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

    try {
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
            return;
          }

          final now = DateTime.now();
          final shouldEmit = now.difference(_lastEmit) >= partialEmitEvery;
          final changed = txt != _lastPartial;

          if (changed && shouldEmit) {
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
      if (!_errorCtrl.isClosed) _errorCtrl.add(e);
      if (!_disposed) _setState(MicState.ready);
    }
  }

  Future<void> stop() async {
    if (_disposed) return;
    if (_state != MicState.listening) return;

    _setState(MicState.stopping);
    try {
      await _stt.stop();
    } catch (e) {
      if (!_errorCtrl.isClosed) _errorCtrl.add(e);
    } finally {
      if (!_disposed) _setState(MicState.ready);
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
      // ✅ NEW
      _statusCtrl.close(),
    ]);
  }
}