/// Minimal RFC 4180 CSV encoder.
///
/// Deliberately not a dependency: the `csv` package ships a parser we never
/// use, and the encoding rules are a dozen lines.
abstract final class CsvWriter {
  /// Byte-order mark.
  ///
  /// Excel on Windows reads a BOM-less UTF-8 CSV as ANSI and mangles every
  /// non-ASCII character, so this is written by default.
  static const String utf8Bom = '﻿';

  static const String _crlf = '\r\n';

  /// Characters that make Excel, LibreOffice and Google Sheets treat a cell as
  /// a formula rather than text.
  static const List<String> _formulaTriggers = ['=', '+', '-', '@', '\t', '\r'];

  /// Encodes [rows] as a CSV document.
  ///
  /// [sanitizeFormulas] guards against CSV injection — see [neutralizeFormula].
  static String encode(
    Iterable<List<String>> rows, {
    String delimiter = ',',
    bool includeBom = true,
    bool sanitizeFormulas = true,
  }) {
    final buffer = StringBuffer();
    if (includeBom) buffer.write(utf8Bom);
    for (final row in rows) {
      final cells = row.map((cell) {
        final value = sanitizeFormulas ? neutralizeFormula(cell) : cell;
        return escape(value, delimiter: delimiter);
      });
      buffer
        ..writeAll(cells, delimiter)
        ..write(_crlf);
    }
    return buffer.toString();
  }

  /// Quotes a single field if RFC 4180 requires it.
  ///
  /// Quoting is needed when the field contains the delimiter, a double quote,
  /// a line break, or has significant leading/trailing whitespace.
  static String escape(String value, {String delimiter = ','}) {
    final needsQuotes = value.contains(delimiter) ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r') ||
        (value.isNotEmpty && (value.startsWith(' ') || value.endsWith(' ')));
    if (!needsQuotes) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  /// Prefixes a leading formula character with `'` so spreadsheets show the
  /// text instead of evaluating it.
  ///
  /// A row containing `=cmd|'/c calc'!A1` is a remote code execution vector
  /// when the CSV is opened in Excel — the classic CSV-injection attack. Since
  /// a database export is exactly the path by which untrusted user input
  /// reaches a spreadsheet, this is on by default.
  ///
  /// It does change the data: turn it off with `CsvExporter(sanitizeFormulas:
  /// false)` when the CSV is consumed by a machine rather than opened by a
  /// person.
  static String neutralizeFormula(String value) {
    if (value.isEmpty) return value;
    if (!_formulaTriggers.contains(value[0])) return value;
    // A negative number starts with '-' but is not a formula; prefixing it
    // would turn a numeric column into text in the spreadsheet.
    if (num.tryParse(value) != null) return value;
    return "'$value";
  }
}
