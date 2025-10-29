// lib/services/rent_calculation_service.dart

import 'package:flutter/foundation.dart';
import 'package:cold_storage/models/rent_type.dart';

/// Service for calculating rent based on business rules.
///
/// Business Logic:
/// - **Monthly Rent**: Calculated in 15-day increments (0.5, 1.0, 1.5, 2.0...)
///   - Formula: Quantity × Months × Rate
///   - Labour: Total Receipt Quantity × Labour Rate
///   - GST: 18% on (Rent + Labour)
///
/// - **Seasonal Rent**: Fixed rate for entire season
///   - Formula: Quantity × Seasonal Rate
///   - No labour charges
///   - GST: 18% on total
class RentCalculationService {
  RentCalculationService._();
  static final RentCalculationService instance = RentCalculationService._();

  /// Calculate number of months for monthly rent based on business logic.
  ///
  /// Business Logic:
  /// - First 0-32 days: 1.0 month (minimum charge)
  /// - Beyond 32 days: Every additional 15 days adds 0.5 months
  ///
  /// Formula:
  /// - If days ≤ 32: return 1.0 month
  /// - If days > 32: 1.0 + CEILING((days - 32) / 15) × 0.5
  ///
  /// Day Ranges:
  /// - 0-32 days   = 1.0 month   (minimum charge)
  /// - 33-47 days  = 1.5 months  (32 + 1-15 days)
  /// - 48-62 days  = 2.0 months  (32 + 16-30 days)
  /// - 63-77 days  = 2.5 months  (32 + 31-45 days) ← 77 days example
  /// - 78-92 days  = 3.0 months  (32 + 46-60 days)
  /// - 93-107 days = 3.5 months  (32 + 61-75 days) ← 107 days example
  /// - 108-122 days = 4.0 months (32 + 76-90 days)
  /// - And so on...
  ///
  /// Note: Days are calculated from inward date to delivery/outward date (inclusive)
  double calculateMonths(DateTime inwardDate, DateTime outwardDate) {
    final days = outwardDate.difference(inwardDate).inDays + 1; // +1 to include both dates

    if (days <= 0) {
      debugPrint('⚠️ Invalid date range: outward date must be after inward date');
      return 0.0;
    }

    double months;

    if (days <= 32) {
      // Minimum charge: 1.0 month for first 32 days
      months = 1.0;
    } else {
      // Calculate additional periods beyond 32 days
      final additionalDays = days - 32;
      final additionalPeriods = (additionalDays / 15.0).ceil();
      months = 1.0 + (additionalPeriods * 0.5);
    }

    debugPrint('📅 Rent calculation: $days days → $months months');
    if (days > 32) {
      final additionalDays = days - 32;
      final additionalPeriods = (additionalDays / 15.0).ceil();
      debugPrint('   Breakdown: 32 days (1.0) + $additionalDays days ($additionalPeriods periods × 0.5 = ${additionalPeriods * 0.5})');
    }

    return months;
  }

  /// Calculate rent amount for monthly rent type.
  ///
  /// Formula: Quantity × Months × Rate Per Unit
  double calculateMonthlyRentAmount({
    required double quantity,
    required double months,
    required double ratePerUnit,
  }) {
    if (quantity <= 0 || months <= 0 || ratePerUnit <= 0) {
      return 0.0;
    }

    final amount = quantity * months * ratePerUnit;
    debugPrint('💰 Monthly rent: $quantity × $months × ₹$ratePerUnit = ₹$amount');
    return double.parse(amount.toStringAsFixed(2));
  }

  /// Calculate rent amount for seasonal rent type.
  ///
  /// Formula: Quantity × Seasonal Rate Per Unit
  double calculateSeasonalRentAmount({
    required double quantity,
    required double ratePerUnit,
  }) {
    if (quantity <= 0 || ratePerUnit <= 0) {
      return 0.0;
    }

    final amount = quantity * ratePerUnit;
    debugPrint('💰 Seasonal rent: $quantity × ₹$ratePerUnit = ₹$amount');
    return double.parse(amount.toStringAsFixed(2));
  }

  /// Calculate labour charges for monthly rent.
  ///
  /// Formula: Total Receipt Quantity × Labour Rate Per Unit
  double calculateLabourCharges({
    required double totalReceiptQuantity,
    required double labourRatePerUnit,
  }) {
    if (totalReceiptQuantity <= 0 || labourRatePerUnit <= 0) {
      return 0.0;
    }

    final labour = totalReceiptQuantity * labourRatePerUnit;
    debugPrint('👷 Labour charges: $totalReceiptQuantity × ₹$labourRatePerUnit = ₹$labour');
    return double.parse(labour.toStringAsFixed(2));
  }

  /// Calculate GST (SGST + CGST).
  ///
  /// Default: 9% SGST + 9% CGST = 18% total
  Map<String, double> calculateGST({
    required double amount,
    double gstPercentage = 18.0,
  }) {
    if (amount <= 0) {
      return {'sgst': 0.0, 'cgst': 0.0, 'igst': 0.0, 'total': 0.0};
    }

    // Split GST equally between SGST and CGST (for intra-state)
    final sgstPercent = gstPercentage / 2;
    final cgstPercent = gstPercentage / 2;

    final sgst = double.parse((amount * sgstPercent / 100).toStringAsFixed(2));
    final cgst = double.parse((amount * cgstPercent / 100).toStringAsFixed(2));
    final total = sgst + cgst;

    debugPrint('🧾 GST calculation: ₹$amount × $gstPercentage% = SGST ₹$sgst + CGST ₹$cgst = ₹$total');

    return {
      'sgst': sgst,
      'cgst': cgst,
      'igst': 0.0, // For same state, IGST is 0
      'total': total,
    };
  }

  /// Calculate complete bill totals.
  ///
  /// Returns a map with all calculated amounts:
  /// - totalRentAmount: Sum of all line item amounts
  /// - labourCharges: Labour charges (0 for seasonal)
  /// - subtotalBeforeGst: Total rent + labour
  /// - sgst: State GST (9%)
  /// - cgst: Central GST (9%)
  /// - igst: Integrated GST (0 for same state)
  /// - roundOff: Adjustment to make final amount a whole number
  /// - finalAmount: Grand total including GST (rounded to nearest rupee)
  Map<String, double> calculateBillTotals({
    required double totalRentAmount,
    required double labourCharges,
    double gstPercentage = 18.0,
  }) {
    final subtotalBeforeGst = totalRentAmount + labourCharges;
    final gst = calculateGST(amount: subtotalBeforeGst, gstPercentage: gstPercentage);
    final amountBeforeRounding = subtotalBeforeGst + gst['total']!;

    // Round to nearest rupee
    final finalAmount = amountBeforeRounding.roundToDouble();
    final roundOff = finalAmount - amountBeforeRounding;

    debugPrint('📊 Bill totals:');
    debugPrint('   Rent: ₹$totalRentAmount');
    debugPrint('   Labour: ₹$labourCharges');
    debugPrint('   Subtotal: ₹$subtotalBeforeGst');
    debugPrint('   SGST: ₹${gst['sgst']}');
    debugPrint('   CGST: ₹${gst['cgst']}');
    debugPrint('   Before Round-off: ₹${amountBeforeRounding.toStringAsFixed(2)}');
    debugPrint('   Round-off: ₹${roundOff.toStringAsFixed(2)}');
    debugPrint('   Final: ₹${finalAmount.toStringAsFixed(0)}');

    return {
      'totalRentAmount': totalRentAmount,
      'labourCharges': labourCharges,
      'subtotalBeforeGst': subtotalBeforeGst,
      'sgst': gst['sgst']!,
      'cgst': gst['cgst']!,
      'igst': gst['igst']!,
      'roundOff': roundOff,
      'finalAmount': finalAmount,
    };
  }

  /// Validate rent calculation inputs.
  String? validateRentCalculation({
    required RentType rentType,
    required DateTime inwardDate,
    required DateTime outwardDate,
    required double quantity,
    required double? monthlyRate,
    required double? labourRate,
    required double? seasonalRate,
  }) {
    // Validate dates
    if (outwardDate.isBefore(inwardDate)) {
      return 'Outward date must be after inward date';
    }

    // Validate quantity
    if (quantity <= 0) {
      return 'Quantity must be greater than 0';
    }

    // Validate rates based on rent type
    if (rentType == RentType.monthly) {
      if (monthlyRate == null || monthlyRate <= 0) {
        return 'Monthly rate is required and must be greater than 0';
      }
      if (labourRate == null || labourRate < 0) {
        return 'Labour rate is required (can be 0)';
      }
    } else if (rentType == RentType.seasonal) {
      if (seasonalRate == null || seasonalRate <= 0) {
        return 'Seasonal rate is required and must be greater than 0';
      }
    }

    return null; // Valid
  }

  /// Convert amount to words (for bill display).
  ///
  /// Example: 38586.00 → "Thirty Eight Thousand Five Hundred Eighty Six Only"
  String amountToWords(double amount) {
    if (amount == 0) return 'Zero Only';

    final intAmount = amount.floor();
    final ones = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
      'Seventeen', 'Eighteen', 'Nineteen'
    ];
    final tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    ];

    String convertGroup(int num) {
      if (num == 0) return '';
      if (num < 20) return ones[num];
      if (num < 100) {
        return '${tens[num ~/ 10]} ${ones[num % 10]}'.trim();
      }
      if (num < 1000) {
        final hundreds = '${ones[num ~/ 100]} Hundred';
        final remainder = convertGroup(num % 100);
        return remainder.isEmpty ? hundreds : '$hundreds $remainder';
      }
      return '';
    }

    final crore = intAmount ~/ 10000000;
    final lakh = (intAmount % 10000000) ~/ 100000;
    final thousand = (intAmount % 100000) ~/ 1000;
    final remainder = intAmount % 1000;

    final parts = <String>[];
    if (crore > 0) parts.add('${convertGroup(crore)} Crore');
    if (lakh > 0) parts.add('${convertGroup(lakh)} Lakh');
    if (thousand > 0) parts.add('${convertGroup(thousand)} Thousand');
    if (remainder > 0) parts.add(convertGroup(remainder));

    return '${parts.join(' ')} Only';
  }
}
