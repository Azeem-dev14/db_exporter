import 'dart:convert';
import 'dart:typed_data';

/// Converts raw SQLite values into the representation each format expects.
///
/// SQLite only ever hands back `null`, `int`, `double`, `String` or a byte
/// list, but ORMs sitting on top may widen that (drift can return `DateTime`
/// for typed converters), so every branch is defensive.
abstract final class ValueCodec {
  /// Flat text, for CSV and Excel text cells.
  static String asText(Object? value) => switch (value) {
        null => '',
        final String text => text,
        final Uint8List bytes => base64Encode(bytes),
        final List<int> bytes => base64Encode(bytes),
        final DateTime date => date.toIso8601String(),
        _ => value.toString(),
      };

  /// A JSON-encodable value.
  ///
  /// BLOBs become base64 strings — JSON has no byte type — so a JSON export is
  /// lossless but not human-readable for binary columns.
  static Object? asJson(Object? value) => switch (value) {
        null => null,
        final num number => number,
        final bool flag => flag,
        final String text => text,
        final Uint8List bytes => base64Encode(bytes),
        final List<int> bytes => base64Encode(bytes),
        final DateTime date => date.toIso8601String(),
        _ => value.toString(),
      };

  /// True when the value is a byte payload rather than something displayable.
  static bool isBlob(Object? value) =>
      value is Uint8List || (value is List<int> && value is! String);
}
