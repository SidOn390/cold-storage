// test/utils/date_input_formatter_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:cold_storage/utils/date_input_formatter.dart';
import 'package:flutter/services.dart';

void main() {
  group('DateInputFormatter', () {
    late DateInputFormatter formatter;

    setUp(() {
      formatter = DateInputFormatter();
    });

    test('formats 6 digits to DD-MM-YY', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(text: '231290');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '23-12-90');
    });

    test('formats 8 digits to DD-MM-YYYY', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(text: '23121990');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '23-12-1990');
    });

    test('auto-adds hyphen when typing third digit', () {
      const oldValue = TextEditingValue(text: '23');
      const newValue = TextEditingValue(text: '231');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '23-1');
    });

    test('auto-adds hyphen when typing fifth digit', () {
      const oldValue = TextEditingValue(text: '23-12');
      const newValue = TextEditingValue(text: '23121');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '23-12-1');
    });

    test('allows deletion', () {
      const oldValue = TextEditingValue(text: '23-12-90');
      const newValue = TextEditingValue(text: '23-12-9');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '23-12-9');
    });

    test('limits to 8 digits', () {
      const oldValue = TextEditingValue(text: '23-12-1990');
      const newValue = TextEditingValue(text: '23-12-19905');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      // Should return old value when exceeding 8 digits
      expect(result.text, '23-12-1990');
    });

    test('ignores non-digit characters', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(text: '23abc12');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      // Should extract only digits and format
      expect(result.text, '23-12');
    });
  });

  group('validateDateFormat', () {
    test('accepts valid DD-MM-YY format', () {
      final result = validateDateFormat('23-12-90');
      expect(result, isNull);
    });

    test('accepts valid DD-MM-YYYY format', () {
      final result = validateDateFormat('23-12-1990');
      expect(result, isNull);
    });

    test('rejects empty string', () {
      final result = validateDateFormat('');
      expect(result, 'Date is required');
    });

    test('rejects null', () {
      final result = validateDateFormat(null);
      expect(result, 'Date is required');
    });

    test('rejects invalid day (0)', () {
      final result = validateDateFormat('00-12-90');
      expect(result, contains('Day must be between'));
    });

    test('rejects invalid day (32)', () {
      final result = validateDateFormat('32-12-90');
      expect(result, contains('Day must be between'));
    });

    test('rejects invalid month (0)', () {
      final result = validateDateFormat('23-00-90');
      expect(result, contains('Month must be between'));
    });

    test('rejects invalid month (13)', () {
      final result = validateDateFormat('23-13-90');
      expect(result, contains('Month must be between'));
    });

    test('rejects invalid date (Feb 30)', () {
      final result = validateDateFormat('30-02-2020');
      expect(result, contains('Invalid date'));
    });

    test('accepts leap year Feb 29', () {
      final result = validateDateFormat('29-02-2020');
      expect(result, isNull);
    });

    test('rejects non-leap year Feb 29', () {
      final result = validateDateFormat('29-02-2021');
      expect(result, contains('Invalid date'));
    });
  });

  group('parseDateString', () {
    test('parses DD-MM-YY format', () {
      final result = parseDateString('23-12-90');
      expect(result, isNotNull);
      expect(result!.day, 23);
      expect(result.month, 12);
      expect(result.year, 1990);
    });

    test('parses DD-MM-YYYY format', () {
      final result = parseDateString('23-12-2025');
      expect(result, isNotNull);
      expect(result!.day, 23);
      expect(result.month, 12);
      expect(result.year, 2025);
    });

    test('interprets 00-30 as 2000s', () {
      final result = parseDateString('23-12-25');
      expect(result!.year, 2025);
    });

    test('interprets 31-99 as 1900s', () {
      final result = parseDateString('23-12-90');
      expect(result!.year, 1990);
    });

    test('returns null for invalid format', () {
      final result = parseDateString('invalid');
      expect(result, isNull);
    });

    test('returns null for empty string', () {
      final result = parseDateString('');
      expect(result, isNull);
    });

    test('returns null for null', () {
      final result = parseDateString(null);
      expect(result, isNull);
    });
  });

  group('formatDateToString', () {
    test('formats DateTime to DD-MM-YYYY', () {
      final date = DateTime(2025, 10, 30);
      final result = formatDateToString(date);
      expect(result, '30-10-2025');
    });

    test('pads single digit day with zero', () {
      final date = DateTime(2025, 10, 5);
      final result = formatDateToString(date);
      expect(result, '05-10-2025');
    });

    test('pads single digit month with zero', () {
      final date = DateTime(2025, 5, 30);
      final result = formatDateToString(date);
      expect(result, '30-05-2025');
    });
  });
}
