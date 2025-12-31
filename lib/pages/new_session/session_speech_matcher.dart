import 'dart:math' as math;

/// Production speech matcher for incremental STT partials.
///
/// Semantics:
/// - [activeToken] = index of the NEXT token to say (0..tokens.length)
///   - done tokens are indices < activeToken
///   - current token is == activeToken (if activeToken < tokens.length)
class SessionSpeechMatcher {
  List<String> tokens = const [];
  List<String> displayTokens = const [];

  int activeToken = 0;

  List<String> _heardTokens = const [];
  List<String> _lastResultTokens = const [];
  int _heardIndex = 0;

  final int _maxFuzzyDistance = 1;
  final int _minLenForFuzzy = 4;

  void resetForText(String text) {
    tokens = _tokenizeNormalized(text);
    displayTokens = _tokenizeDisplay(text);
    activeToken = 0;

    _heardTokens = const [];
    _lastResultTokens = const [];
    _heardIndex = 0;
  }

  bool get isComplete => tokens.isNotEmpty && activeToken >= tokens.length;

  List<String> tokenizeSpeech(String text) => _tokenizeNormalized(text);

  bool updateWithSpokenTokens(List<String> spokenTokens) {
    if (tokens.isEmpty || spokenTokens.isEmpty) return false;

    final newTokens = _diffTokens(spokenTokens);
    if (newTokens.isNotEmpty) {
      _heardTokens = [..._heardTokens, ...newTokens];
    }

    final prevActive = activeToken;
    final prevHeardIndex = _heardIndex;

    while (activeToken < tokens.length) {
      final target = tokens[activeToken];
      final found = _indexOfFromFuzzy(_heardTokens, target, _heardIndex);
      if (found == -1) break;

      _heardIndex = found + 1;
      activeToken += 1;
    }

    return prevActive != activeToken || prevHeardIndex != _heardIndex;
  }

  // ---------------- internals ----------------

  List<String> _tokenizeNormalized(String s) {
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
    if (parts.isNotEmpty) parts[0] = _capitalizeFirst(parts[0]);
    return parts;
  }

  String _capitalizeFirst(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

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

  int _indexOfFromFuzzy(List<String> list, String target, int start) {
    for (int i = start; i < list.length; i++) {
      if (_tokenEquals(list[i], target)) return i;
    }
    return -1;
  }

  bool _tokenEquals(String a, String b) {
    if (a == b) return true;

    final as = _stripSuffix(a);
    final bs = _stripSuffix(b);
    if (as == bs) return true;

    if (a.length >= _minLenForFuzzy && b.length >= _minLenForFuzzy) {
      final dist = _levenshtein(a, b, maxDist: _maxFuzzyDistance);
      return dist <= _maxFuzzyDistance;
    }

    return false;
  }

  String _stripSuffix(String s) {
    if (s.endsWith('ing') && s.length > 5) return s.substring(0, s.length - 3);
    if (s.endsWith('ed') && s.length > 4) return s.substring(0, s.length - 2);
    if (s.endsWith('s') && s.length > 3) return s.substring(0, s.length - 1);
    return s;
  }

  int _levenshtein(String s, String t, {required int maxDist}) {
    final n = s.length;
    final m = t.length;

    if ((n - m).abs() > maxDist) return maxDist + 1;
    if (n == 0) return m;
    if (m == 0) return n;

    List<int> prev = List<int>.generate(m + 1, (j) => j);
    List<int> curr = List<int>.filled(m + 1, 0);

    for (int i = 1; i <= n; i++) {
      curr[0] = i;
      int rowMin = curr[0];
      final si = s.codeUnitAt(i - 1);

      for (int j = 1; j <= m; j++) {
        final cost = (si == t.codeUnitAt(j - 1)) ? 0 : 1;
        curr[j] = math.min(
          math.min(curr[j - 1] + 1, prev[j] + 1),
          prev[j - 1] + cost,
        );
        rowMin = math.min(rowMin, curr[j]);
      }

      if (rowMin > maxDist) return maxDist + 1;

      final tmp = prev;
      prev = curr;
      curr = tmp;
    }

    return prev[m];
  }
}