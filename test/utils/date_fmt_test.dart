// test/utils/date_fmt_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:cold_storage/utils/date_fmt.dart';

void main() {
  group('Date Formatting Tests', () {
    test('dfDdMmmYyyy formats date correctly', () {
      final date = DateTime(2025, 1, 15);
      final formatted = dfDdMmmYyyy.format(date);
      expect(formatted, '15-Jan-2025');
    });

    test('dfDdMmmYyyy handles single digit days', () {
      final date = DateTime(2025, 3, 5);
      final formatted = dfDdMmmYyyy.format(date);
      expect(formatted, '05-Mar-2025');
    });

    test('dfDdMmmYyyy handles different months correctly', () {
      final dates = [
        DateTime(2025, 1, 1),
        DateTime(2025, 2, 1),
        DateTime(2025, 12, 31),
      ];
      final expected = ['01-Jan-2025', '01-Feb-2025', '31-Dec-2025'];

      for (var i = 0; i < dates.length; i++) {
        expect(dfDdMmmYyyy.format(dates[i]), expected[i]);
      }
    });

    test('dfDdMmYy formats date correctly', () {
      final date = DateTime(2025, 1, 15);
      final formatted = dfDdMmYy.format(date);
      expect(formatted, '15-01-25');
    });

    test('dfDdMmYy handles single digit months and days', () {
      final date = DateTime(2025, 3, 5);
      final formatted = dfDdMmYy.format(date);
      expect(formatted, '05-03-25');
    });

    test('dfDdMmYy handles year 2000+', () {
      final dates = [
        DateTime(2000, 6, 15),
        DateTime(2025, 12, 31),
        DateTime(2099, 1, 1),
      ];
      final expected = ['15-06-00', '31-12-25', '01-01-99'];

      for (var i = 0; i < dates.length; i++) {
        expect(dfDdMmYy.format(dates[i]), expected[i]);
      }
    });

    test('Both formatters handle leap year dates', () {
      final leapDate = DateTime(2024, 2, 29);
      expect(dfDdMmmYyyy.format(leapDate), '29-Feb-2024');
      expect(dfDdMmYy.format(leapDate), '29-02-24');
    });

    test('Both formatters handle end of year dates', () {
      final endOfYear = DateTime(2025, 12, 31);
      expect(dfDdMmmYyyy.format(endOfYear), '31-Dec-2025');
      expect(dfDdMmYy.format(endOfYear), '31-12-25');
    });

    test('Both formatters handle start of year dates', () {
      final startOfYear = DateTime(2025, 1, 1);
      expect(dfDdMmmYyyy.format(startOfYear), '01-Jan-2025');
      expect(dfDdMmYy.format(startOfYear), '01-01-25');
    });
  });
}
