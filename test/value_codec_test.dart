import 'dart:convert';
import 'dart:typed_data';

import 'package:db_exporter/db_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ValueCodec.asText', () {
    test('renders null as an empty cell', () {
      expect(ValueCodec.asText(null), '');
    });

    test('passes strings and numbers through', () {
      expect(ValueCodec.asText('Ada'), 'Ada');
      expect(ValueCodec.asText(42), '42');
      expect(ValueCodec.asText(3.5), '3.5');
    });

    test('base64-encodes BLOBs', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      expect(ValueCodec.asText(bytes), base64Encode(bytes));
    });

    test('renders DateTime as ISO-8601', () {
      final date = DateTime.utc(2026, 8, 22);
      expect(ValueCodec.asText(date), date.toIso8601String());
    });
  });

  group('ValueCodec.asJson', () {
    test('keeps numbers as numbers, not strings', () {
      expect(ValueCodec.asJson(42), 42);
      expect(ValueCodec.asJson(3.5), 3.5);
    });

    test('keeps null as null', () {
      expect(ValueCodec.asJson(null), isNull);
    });

    test('base64-encodes BLOBs so the document stays valid JSON', () {
      final bytes = Uint8List.fromList([255, 0, 128]);
      final encoded = ValueCodec.asJson(bytes);
      expect(encoded, base64Encode(bytes));
      expect(() => jsonEncode({'blob': encoded}), returnsNormally);
    });
  });
}
