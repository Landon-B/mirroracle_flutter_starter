import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum MicState { idle, initializing, ready, listening, stopping, disposed }

/// Production-ready wrapper around `speech_to_text`
///
/// Emits:
/// - partialText$: throttled + deduped partial hypotheses
/// - finalText$: final recognized phrase(s)
/// - soundLevel$: normalized 0..1, smoothed, with optional peak-hold decay
/// - errors$: raw plugin errors / exceptions
/// - state$: MicState transitions
class MicService {
  final stt.SpeechToText _stt;

  MicService({stt.SpeechToText? sttInstance}) : _stt = sttInstance ?? stt.SpeechToText();

  // Streams
  final _partialCtrl = StreamController<String>.broadcast();
  final _finalCtrl = StreamController<String>.broadcast();
  final _levelCtrl = StreamController<double>.broadcast();
  final _errorCtrl = StreamController<Object>.broadcast();
  final _stateCtrl = StreamController<MicState>.broadcast();

  Stream<String> get partialText$ => _partialCtrl.stream;
  Stream<String> get finalText$ => _finalCtrl.stream;
  Stream<double> get soundLevel$ => _levelCtrl.stream; // 0..1
  Stream<Object> get errors$ => _errorCtrl.stream;
  Stream<MicState> get state$ => _stateCtrl.stream;

  MicState _state = MicState.idle;
  MicState get state => _state;

  bool _available = false;
  bool get available => _available;

  bool _disposed = false;
  bool get disposed => _disposed;

  String? _localeId;

  // ----- Partial emission controls -----
  /// Minimum time between emitted partials.
  Duration partialEmitEvery = const Duration(milliseconds: 100);

  String _lastPartial = '';
  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

  // ----- Sound level smoothing (EMA + peak-hold) -----
  /// EMA alpha in [0..1]. Higher = more reactive, lower = smoother.
  double levelSmoothing = 0.25;

  /// If true, holds a short peak and decays it (looks nicer for a mic ring).
  bool usePeakHold = true;

  /// How fast the peak decays per tick (0..1). Smaller = slower decay.
  double peakDecayPerTick = 0.92;

  double _smoothedLevel = 0.0;
  double _peakLevel = 0.0;

  Timer? _peakDecayTimer;

  void _setState(MicState s) {
    _state = s;
    if (!_stateCtrl.isClosed) _stateCtrl.add(s);
  }

  void _emitError(Object e) {
    if (!_errorCtrl.isClosed) _errorCtrl.add(e);
  }

  /// Initialize speech engine and choose locale (default: system locale).
  Future<bool> init({bool debugLogging = false, String? localeId}) async {
    if (_disposed) return false;

    // If already initialized, no-op.
    if (_available && (_state == MicState.ready || _state == MicState.listening)) {
      return true;
    }

    _setState(MicState.initializing);

    try {
      _available = await _stt.initialize(
        debugLogging: debugLogging,
        onStatus: _handleStatus,
        onError: (e) => _emitError(e),
      );

      if (!_available) {
        _setState(MicState.idle);
        return false;
      }

      if (localeId != null) {
        _localeId = localeId;
      } else {
        final sys = await _stt.systemLocale();
        _localeId = sys?.localeId;
      }

      _setState(MicState.ready);
      return true;
    } catch (e) {
      _emitError(e);
      _available = false;
      _setState(MicState.idle);
      return false;
    }
  }

  void _handleStatus(String status) {
    if (_disposed) return;

    // Typical statuses: listening, notListening, done
    switch (status) {
      case 'listening':
        _setState(MicState.listening);
        break;
      case 'notListening':
      case 'done':
        // Only move to ready if we aren't intentionally stopping
        if (_state != MicState.stopping) _setState(MicState.ready);
        break;
      default:
        // keep current
        break;
    }
  }

  /// Start listening. Safe to call multiple times.
  Future<void> start({
    stt.ListenMode listenMode = stt.ListenMode.dictation,
    bool partialResults = true,
    Duration listenFor = const Duration(minutes: 10),
    Duration pauseFor = const Duration(seconds: 2),
    String? localeId,
    bool cancelOnError = true,
  }) async {
    if (_disposed) return;
    if (!_available) return;

    // If already listening, no-op
    if (_state == MicState.listening || _stt.isListening) return;

    _setState(MicState.listening);
    _resetPartialTracking();
    _resetLevelTracking();

    _startPeakDecayTimerIfNeeded();

    try {
      await _stt.listen(
        listenMode: listenMode,
        partialResults: partialResults,
        cancelOnError: cancelOnError,
        listenFor: listenFor,
        pauseFor: pauseFor,
        localeId: localeId ?? _localeId,
        onResult: _handleResult,
        onSoundLevelChange: _handleSoundLevel,
      );
    } catch (e) {
      _emitError(e);
      if (!_disposed) _setState(MicState.ready);
    }
  }

  void _handleResult(stt.SpeechRecognitionResult res) {
    if (_disposed) return;

    final txt = res.recognizedWords.trim();
    if (txt.isEmpty) return;

    if (res.finalResult) {
      if (!_finalCtrl.isClosed) _finalCtrl.add(txt);
      // push final to partial too so UI always matches the final phrase
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
  }

  void _handleSoundLevel(double raw) {
    if (_disposed) return;

    // Raw varies a lot by device. Normalize to 0..1.
    // Typical raw range often ~ -50..+10 (but not guaranteed).
    final normalized = ((raw + 50.0) / 60.0).clamp(0.0, 1.0);

    // EMA smoothing
    _smoothedLevel = _smoothedLevel + levelSmoothing * (normalized - _smoothedLevel);

    if (usePeakHold) {
      // Track peak; decay handled by timer
      if (_smoothedLevel > _peakLevel) _peakLevel = _smoothedLevel;
      if (!_levelCtrl.isClosed) _levelCtrl.add(_peakLevel);
    } else {
      if (!_levelCtrl.isClosed) _levelCtrl.add(_smoothedLevel);
    }
  }

  Future<void> stop() async {
    if (_disposed) return;
    if (!_stt.isListening && _state != MicState.listening) return;

    _setState(MicState.stopping);
    try {
      await _stt.stop();
    } catch (e) {
      _emitError(e);
    } finally {
      _stopPeakDecayTimer();
      if (!_disposed) _setState(MicState.ready);
    }
  }

  Future<void> cancel() async {
    if (_disposed) return;
    try {
      await _stt.cancel();
    } catch (e) {
      _emitError(e);
    } finally {
      _stopPeakDecayTimer();
      if (!_disposed) _setState(MicState.ready);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _setState(MicState.disposed);

    _stopPeakDecayTimer();

    try {
      await _stt.cancel();
    } catch (_) {}

    await Future.wait([
      _partialCtrl.close(),
      _finalCtrl.close(),
      _levelCtrl.close(),
      _errorCtrl.close(),
      _stateCtrl.close(),
    ]);
  }

  // ----- helpers -----

  void _resetPartialTracking() {
    _lastPartial = '';
    _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _resetLevelTracking() {
    _smoothedLevel = 0.0;
    _peakLevel = 0.0;
  }

  void _startPeakDecayTimerIfNeeded() {
    if (!usePeakHold) return;
    _peakDecayTimer?.cancel();
    // ~30fps decay is plenty for UI
    _peakDecayTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (_disposed) return;
      _peakLevel *= peakDecayPerTick;
      if (_peakLevel < _smoothedLevel) _peakLevel = _smoothedLevel;
      if (!_levelCtrl.isClosed) _levelCtrl.add(_peakLevel);
    });
  }

  void _stopPeakDecayTimer() {
    _peakDecayTimer?.cancel();
    _peakDecayTimer = null;
  }
}