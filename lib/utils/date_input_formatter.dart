// lib/utils/date_input_formatter.dart

import 'package:flutter/services.dart';

/// Date input formatter that auto-formats numeric date input.
///
/// Converts typed digits into DD-MM-YY or DD-MM-YYYY format:
/// - "231290" → "23-12-90"
/// - "23121990" → "23-12-1990"
/// - Automatically adds hyphens after day and month
/// - Allows only digits and hyphens
/// - Max length: 10 characters (DD-MM-YYYY)
class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digits to get raw input
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // If user is deleting, allow it
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    // Limit to 8 digits (DDMMYYYY)
    if (digitsOnly.length > 8) {
      return oldValue;
    }

    // Build formatted string
    String formatted = '';
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 2 || i == 4) {
        formatted += '-';
      }
      formatted += digitsOnly[i];
    }

    // Calculate cursor position
    int selectionIndex = formatted.length;

    // Adjust cursor if it's after a hyphen was just added
    if (formatted.length > newValue.selection.end) {
      selectionIndex = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}

/// Validates date string in DD-MM-YY or DD-MM-YYYY format.
///
/// Returns null if valid, error message if invalid.
String? validateDateFormat(String? value) {
  if (value == null || value.isEmpty) {
    return 'Date is required';
  }

  // Remove hyphens for validation
  final digitsOnly = value.replaceAll('-', '');

  // Must be 6 digits (DDMMYY) or 8 digits (DDMMYYYY)
  if (digitsOnly.length != 6 && digitsOnly.length != 8) {
    return 'Invalid date format (use DD-MM-YY or DD-MM-YYYY)';
  }

  // Parse day, month, year
  final day = int.tryParse(digitsOnly.substring(0, 2));
  final month = int.tryParse(digitsOnly.substring(2, 4));
  final yearStr = digitsOnly.substring(4);

  if (day == null || month == null) {
    return 'Invalid date';
  }

  // Validate ranges
  if (day < 1 || day > 31) {
    return 'Day must be between 1-31';
  }

  if (month < 1 || month > 12) {
    return 'Month must be between 1-12';
  }

  // Convert 2-digit year to 4-digit if needed
  int year;
  if (yearStr.length == 2) {
    final yy = int.parse(yearStr);
    // Assume 00-30 = 2000-2030, 31-99 = 1931-1999
    year = yy <= 30 ? 2000 + yy : 1900 + yy;
  } else {
    year = int.parse(yearStr);
  }

  // Validate year range
  if (year < 1900 || year > 2100) {
    return 'Year must be between 1900-2100';
  }

  // Check if date is valid (basic validation)
  try {
    final date = DateTime(year, month, day);
    if (date.day != day || date.month != month || date.year != year) {
      return 'Invalid date (e.g., Feb 30 doesn\'t exist)';
    }
  } catch (e) {
    return 'Invalid date';
  }

  return null; // Valid
}

/// Parses formatted date string (DD-MM-YY or DD-MM-YYYY) to DateTime.
///
/// Returns null if parsing fails.
DateTime? parseDateString(String? value) {
  if (value == null || value.isEmpty) return null;

  final digitsOnly = value.replaceAll('-', '');

  if (digitsOnly.length != 6 && digitsOnly.length != 8) {
    return null;
  }

  try {
    final day = int.parse(digitsOnly.substring(0, 2));
    final month = int.parse(digitsOnly.substring(2, 4));
    final yearStr = digitsOnly.substring(4);

    int year;
    if (yearStr.length == 2) {
      final yy = int.parse(yearStr);
      year = yy <= 30 ? 2000 + yy : 1900 + yy;
    } else {
      year = int.parse(yearStr);
    }

    return DateTime(year, month, day);
  } catch (e) {
    return null;
  }
}

/// Formats DateTime to DD-MM-YYYY string.
String formatDateToString(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  return '$day-$month-$year';
}
