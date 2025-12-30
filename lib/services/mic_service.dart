class _MicService {
  final _stt = stt.SpeechToText();
  final _partialCtrl = StreamController<String>.broadcast();
  final _levelCtrl = StreamController<double>.broadcast();

  Stream<String> get partialText$ => _partialCtrl.stream;
  Stream<double> get soundLevel$ => _levelCtrl.stream;

  bool _available = false;
  String? _localeId;

  Future<bool> init() async {
    try {
      _available = await _stt.initialize(
        debugLogging: false,
        onStatus: (s) {
          // debugPrint('[stt] status=$s'); // uncomment if needed
        },
        onError: (e) {
          // debugPrint('[stt] error=$e'); // uncomment if needed
        },
      );
      if (_available) {
        final sys = await _stt.systemLocale();
        _localeId = sys?.localeId;
      }
      return _available;
    } catch (_) {
      return false;
    }
  }

  Future<void> start() async {
    if (!_available) return;
    try {
      await _stt.listen(
        // ⚠️ Dictation mode streams partials continuously
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(minutes: 10),
        pauseFor: const Duration(seconds: 2),
        localeId: _localeId, // fall back to system locale
        onResult: (res) {
          final txt = res.recognizedWords;
          if (txt.isNotEmpty) {
            _partialCtrl.add(txt); // push EVERY partial
          }
        },
        onSoundLevelChange: (level) {
          _levelCtrl.add(level);
        },
      );
    } catch (_) {}
  }

  Future<void> stop() async {
    try { await _stt.stop(); } catch (_) {}
  }

  Future<void> dispose() async {
    try { await _stt.cancel(); } catch (_) {}
    await _partialCtrl.close();
    await _levelCtrl.close();
  }
}