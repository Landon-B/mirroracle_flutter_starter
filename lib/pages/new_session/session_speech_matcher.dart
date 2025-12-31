// lib/pages/new_session/session_speech_matcher.dart
//
// Production speech matcher for affirmation progress highlighting.
//
// Goals:
// - Stable tokenization (punctuation/apostrophes normalized)
// - Works well with partial STT "rewrites" (diffing strategy)
// - Forward-only matching: once a token is marked "done", it stays done
// - Light fuzzy matching for small variations/typos
//
// Semantics:
// - tokens: normalized target tokens
// - displayTokens: tokens for rendering (nice casing)
// - activeToken: index of the NEXT token the user should say
//   - 0 => none spoken yet
//   - tokens.length => complete

import 'dart:math' as math;

class SessionSpeechMatcher {
  /// Normalized target tokens.
  List<String> tokens = const [];

  /// Tokens used for display in the UI.
  List<String> displayTokens = const [];

  /// Index of the next token to speak (0..tokens.length).
  int activeToken = 0;

  // Incremental buffer of "heard" tokens (normalized).
  List<String> _heardTokens = const [];

  // Last normalized STT token list we processed (used for diffing partial rewrites).
  List<String> _lastResultTokens = const [];

  // Pointer into _heardTokens so we don't rescan old tokens repeatedly.
  int _heardIndex = 0;

  // Tunables
  final int _maxFuzzyDistance = 1; // 0..1 is a good default
  final int _minLenForFuzzy = 4; // only fuzzy-match longer words

  /// Reset matcher for a new target phrase (affirmation).
  void resetForText(String text) {
    tokens = _tokenizeNormalized(text);
    displayTokens = _tokenizeDisplay(text);

    activeToken = 0;
    _heardTokens = const [];
    _lastResultTokens = const [];
    _heardIndex = 0;
  }

  bool get isComplete => tokens.isNotEmpty && activeToken >= tokens.length;

  /// Normalize and tokenize a speech string for matching.
  List<String> tokenizeSpeech(String text) => _tokenizeNormalized(text);

  /// Update internal progress from the current STT token list.
  /// Returns true if progress changed.
  bool updateWithSpokenTokens(List<String> spokenTokens) {
    if (tokens.isEmpty || spokenTokens.isEmpty) return false;

    // Convert the current STT tokens into incremental additions.
    final newTokens = _diffTokens(spokenTokens);
    if (newTokens.isNotEmpty) {
      _heardTokens = [..._heardTokens, ...newTokens];
    }

    final prevActive = activeToken;
    final prevHeardIndex = _heardIndex;

    // Forward-only: advance activeToken as long as we can find the next target token.
    while (activeToken < tokens.length) {
      final target = tokens[activeToken];
      final found = _indexOfFromFuzzy(_heardTokens, target, _heardIndex);
      if (found == -1) break;

      _heardIndex = found + 1;
      activeToken += 1;
    }

    return prevActive != activeToken || prevHeardIndex != _heardIndex;
  }

  // ---------------- Tokenization ----------------

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

  String _capitalizeFirst(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ---------------- Diffing partial results ----------------

  /// Diff strategy for partial results:
  /// - If current starts with last => return suffix (new tokens)
  /// - If current is prefix of last => return [] (rollback)
  /// - Else => treat as rewrite and return full current
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

  // ---------------- Matching ----------------

  int _indexOfFromFuzzy(List<String> list, String target, int start) {
    for (int i = start; i < list.length; i++) {
      if (_tokenEquals(list[i], target)) return i;
    }
    return -1;
  }

  bool _tokenEquals(String a, String b) {
    if (a == b) return true;

    // Cheap stemming-ish normalization for common English suffix noise.
    final sa = _stripSuffix(a);
    final sb = _stripSuffix(b);
    if (sa == sb) return true;

    // Light fuzzy match for longer words.
    if (sa.length >= _minLenForFuzzy && sb.length >= _minLenForFuzzy) {
      final dist = _levenshtein(sa, sb, maxDist: _maxFuzzyDistance);
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

  /// Bounded Levenshtein (early exit when > maxDist).
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