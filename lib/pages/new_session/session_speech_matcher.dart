class SessionSpeechMatcher {
  List<String> tokens = const [];
  List<String> displayTokens = const [];
  int activeToken = -1;

  List<String> _heardTokens = const [];
  List<String> _lastResultTokens = const [];
  int _heardIndex = 0;

  void resetForText(String text) {
    tokens = _tokenize(text);
    displayTokens = _tokenizeDisplay(text);
    activeToken = -1;
    _heardTokens = const [];
    _lastResultTokens = const [];
    _heardIndex = 0;
  }

  bool get isComplete => tokens.isNotEmpty && activeToken >= tokens.length - 1;

  List<String> tokenizeSpeech(String text) => _tokenize(text);

  bool updateWithSpokenTokens(List<String> spokenTokens) {
    if (tokens.isEmpty || spokenTokens.isEmpty) return false;

    final newTokens = _diffTokens(spokenTokens);
    if (newTokens.isNotEmpty) {
      _heardTokens = [..._heardTokens, ...newTokens];
    }

    int newIndex = activeToken;
    int scanIndex = _heardIndex;

    for (int i = activeToken + 1; i < tokens.length; i++) {
      final target = tokens[i];
      final found = _indexOfFrom(_heardTokens, target, scanIndex);
      if (found == -1) break;
      newIndex = i;
      scanIndex = found + 1;
    }

    final changed = newIndex != activeToken || scanIndex != _heardIndex;
    if (changed) {
      activeToken = newIndex;
      _heardIndex = scanIndex;
    }
    return changed;
  }

  List<String> _tokenize(String s) {
    final cleaned = s
        .toLowerCase()
        .replaceAll(RegExp(r"[’‘`´]"), "'")
        .replaceAll("'", '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return const [];
    return cleaned.split(' ');
  }

  List<String> _tokenizeDisplay(String s) {
    final cleaned = s
        .replaceAll(RegExp(r"[’‘`´]"), "'")
        .replaceAll("'", '')
        .replaceAll(RegExp(r'[^A-Za-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return const [];
    final parts = cleaned.split(' ');
    parts[0] = _capitalizeFirst(parts[0]);
    return parts;
  }

  String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  List<String> _diffTokens(List<String> current) {
    if (_lastResultTokens.isEmpty) {
      _lastResultTokens = current;
      return current;
    }
    if (_startsWith(current, _lastResultTokens)) {
      final diff = current.sublist(_lastResultTokens.length);
      _lastResultTokens = current;
      return diff;
    }
    if (_startsWith(_lastResultTokens, current)) {
      _lastResultTokens = current;
      return const [];
    }
    _lastResultTokens = current;
    return current;
  }

  bool _startsWith(List<String> list, List<String> prefix) {
    if (prefix.length > list.length) return false;
    for (int i = 0; i < prefix.length; i++) {
      if (list[i] != prefix[i]) return false;
    }
    return true;
  }

  int _indexOfFrom(List<String> list, String token, int start) {
    for (int i = start; i < list.length; i++) {
      if (list[i] == token) return i;
    }
    return -1;
  }
}
