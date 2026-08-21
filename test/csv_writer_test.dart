import 'package:db_exporter/db_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CsvWriter.escape', () {
    test('leaves plain values alone', () {
      expect(CsvWriter.escape('hello'), 'hello');
    });

    test('quotes values containing the delimiter', () {
      expect(CsvWriter.escape('a,b'), '"a,b"');
    });

    test('doubles embedded quotes', () {
      expect(CsvWriter.escape('say "hi"'), '"say ""hi"""');
    });

    test('quotes values with line breaks', () {
      expect(CsvWriter.escape('line1\nline2'), '"line1\nline2"');
      expect(CsvWriter.escape('line1\r\nline2'), '"line1\r\nline2"');
    });

    test('preserves significant whitespace by quoting', () {
      expect(CsvWriter.escape(' padded '), '" padded "');
    });

    test('honours a custom delimiter', () {
      expect(CsvWriter.escape('a;b', delimiter: ';'), '"a;b"');
      expect(CsvWriter.escape('a,b', delimiter: ';'), 'a,b');
    });
  });

  group('CsvWriter.neutralizeFormula', () {
    test('prefixes every spreadsheet formula trigger', () {
      for (final trigger in ['=', '+', '-', '@']) {
        expect(
          CsvWriter.neutralizeFormula('${trigger}SUM(A1)'),
          "'${trigger}SUM(A1)",
        );
      }
    });

    test('neutralises the classic command-injection payload', () {
      const payload = r"=cmd|'/c calc'!A1";
      expect(CsvWriter.neutralizeFormula(payload), "'$payload");
    });

    test('leaves negative numbers numeric', () {
      // '-' is a formula trigger, but prefixing -5 would turn a numeric
      // column into text in the spreadsheet.
      expect(CsvWriter.neutralizeFormula('-5'), '-5');
      expect(CsvWriter.neutralizeFormula('-3.14'), '-3.14');
      expect(CsvWriter.neutralizeFormula('-5+cmd'), "'-5+cmd");
    });

    test('leaves ordinary values and empty strings untouched', () {
      expect(CsvWriter.neutralizeFormula('Ada'), 'Ada');
      expect(CsvWriter.neutralizeFormula(''), '');
      expect(CsvWriter.neutralizeFormula('a=b'), 'a=b');
    });
  });

  group('CsvWriter.encode', () {
    test('writes CRLF rows with a BOM by default', () {
      final csv = CsvWriter.encode([
        ['id', 'name'],
        ['1', 'Ada'],
      ]);
      expect(csv, '${CsvWriter.utf8Bom}id,name\r\n1,Ada\r\n');
    });

    test('omits the BOM when asked', () {
      final csv = CsvWriter.encode([
        ['a'],
      ], includeBom: false);
      expect(csv, 'a\r\n');
    });

    test('sanitises formulas by default and can be turned off', () {
      final rows = [
        ['=1+1'],
      ];
      expect(
        CsvWriter.encode(rows, includeBom: false),
        "'=1+1\r\n",
      );
      expect(
        CsvWriter.encode(rows, includeBom: false, sanitizeFormulas: false),
        '=1+1\r\n',
      );
    });
  });
}
