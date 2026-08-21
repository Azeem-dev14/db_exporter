import 'package:db_exporter/src/util/file_naming.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileNaming.sanitize', () {
    test('replaces unsafe characters', () {
      expect(FileNaming.sanitize('my db/name'), 'my_db_name');
      expect(FileNaming.sanitize(r'a:b*c?d"e'), 'a_b_c_d_e');
    });

    test('collapses runs of underscores', () {
      expect(FileNaming.sanitize('a///b'), 'a_b');
    });

    test('trims leading and trailing separators', () {
      expect(FileNaming.sanitize('__name__'), 'name');
      expect(FileNaming.sanitize('...name...'), 'name');
    });

    test('falls back when nothing usable survives', () {
      expect(FileNaming.sanitize('///'), 'export');
      expect(FileNaming.sanitize('', fallback: 'db'), 'db');
    });

    test('caps the length', () {
      expect(FileNaming.sanitize('a' * 200).length, 80);
    });
  });

  group('FileNaming.timestamp', () {
    test('is zero-padded and sortable', () {
      expect(
        FileNaming.timestamp(DateTime(2026, 8, 5, 9, 3, 7)),
        '20260805_090307',
      );
    });
  });

  group('FileNaming.build', () {
    final at = DateTime(2026, 8, 22, 14, 30, 1);

    test('joins base, suffix and timestamp in order', () {
      expect(
        FileNaming.build(
          base: 'app',
          suffix: 'users',
          extension: 'csv',
          at: at,
        ),
        'app_users_20260822_143001.csv',
      );
    });

    test('omits the timestamp on request', () {
      expect(
        FileNaming.build(
          base: 'app',
          extension: 'json',
          withTimestamp: false,
        ),
        'app.json',
      );
    });
  });

  group('FileNaming.sheetName', () {
    test('strips characters Excel rejects', () {
      expect(
        FileNaming.sheetName(r'a[b]c:d*e?f/g\h', taken: {}),
        'a_b_c_d_e_f_g_h',
      );
    });

    test('caps at 31 characters', () {
      expect(FileNaming.sheetName('t' * 40, taken: {}).length, 31);
    });

    test('deduplicates against names already used', () {
      final taken = <String>{'users'};
      expect(FileNaming.sheetName('users', taken: taken), 'users_2');
      taken.add('users_2');
      expect(FileNaming.sheetName('users', taken: taken), 'users_3');
    });

    test('keeps deduplicated long names within the 31-char budget', () {
      final long = 'x' * 31;
      final name = FileNaming.sheetName(long, taken: {long});
      expect(name.length, lessThanOrEqualTo(31));
      expect(name, endsWith('_2'));
    });

    test('falls back for an empty name', () {
      expect(FileNaming.sheetName('   ', taken: {}), 'Sheet');
    });
  });
}
