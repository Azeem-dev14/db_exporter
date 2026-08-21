/// Filename construction shared by every exporter.
abstract final class FileNaming {
  static const int _maxBaseLength = 80;

  /// Characters Windows, macOS and Android all agree are unsafe in a filename.
  static final RegExp _unsafe = RegExp(r'[^A-Za-z0-9._\-]+');

  /// Reduces an arbitrary string to something safe on every target filesystem.
  ///
  /// Returns [fallback] if nothing usable survives, so callers never have to
  /// handle an empty name.
  static String sanitize(String input, {String fallback = 'export'}) {
    final cleaned = input
        .replaceAll(_unsafe, '_')
        .replaceAll(RegExp('_+'), '_')
        .replaceAll(RegExp(r'^[._]+|[._]+$'), '');
    if (cleaned.isEmpty) return fallback;
    return cleaned.length <= _maxBaseLength
        ? cleaned
        : cleaned.substring(0, _maxBaseLength);
  }

  /// `20260822_143001` — sortable, filesystem-safe, no timezone ambiguity in
  /// the name itself (it is local time, matching what the user sees).
  static String timestamp([DateTime? at]) {
    final now = at ?? DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}'
        '_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  /// Builds `<base>_<timestamp>.<ext>`, or `<base>.<ext>` without a stamp.
  static String build({
    required String base,
    required String extension,
    bool withTimestamp = true,
    DateTime? at,
    String? suffix,
  }) {
    final parts = <String>[
      sanitize(base),
      if (suffix != null && suffix.isNotEmpty) sanitize(suffix),
      if (withTimestamp) timestamp(at),
    ];
    return '${parts.join('_')}.$extension';
  }

  /// Excel caps sheet names at 31 characters and rejects `[ ] : * ? / \`.
  static String sheetName(String table, {required Set<String> taken}) {
    var name = table.replaceAll(RegExp(r'[\[\]:*?/\\]'), '_').trim();
    if (name.isEmpty) name = 'Sheet';
    if (name.length > 31) name = name.substring(0, 31);

    if (!taken.contains(name)) return name;
    // Append _2, _3 … keeping the total within the 31-char budget.
    for (var index = 2; index < 1000; index++) {
      final suffix = '_$index';
      final trimmed = name.length + suffix.length > 31
          ? name.substring(0, 31 - suffix.length)
          : name;
      final candidate = '$trimmed$suffix';
      if (!taken.contains(candidate)) return candidate;
    }
    return name;
  }
}
