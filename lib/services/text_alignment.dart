class TextAlignment {
  static String normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Returns number of leading chars in `targetNorm` matched by `spokenNorm`.
  /// (Greedy prefix match; simple & stable.)
  static int prefixMatchLen(String targetNorm, String spokenNorm) {
    final n = targetNorm.length;
    final m = spokenNorm.length;
    final L = (m < n) ? m : n;
    int i = 0;
    while (i < L && targetNorm.codeUnitAt(i) == spokenNorm.codeUnitAt(i)) {
      i++;
    }
    return i;
  }
}