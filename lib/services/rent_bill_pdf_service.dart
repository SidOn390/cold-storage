// lib/services/rent_bill_pdf_service.dart

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:cold_storage/models/rent_bill.dart';
import 'package:cold_storage/models/rent_type.dart';

/// Service for generating PDF documents for rent bills.
/// Supports both monthly (with labour) and seasonal (fixed) formats.
class RentBillPdfService {
  static final RentBillPdfService _instance = RentBillPdfService._internal();
  static RentBillPdfService get instance => _instance;

  RentBillPdfService._internal();

  /// Generate PDF for a rent bill
  Future<Uint8List> generatePdf(RentBill bill) async {
    final pdf = pw.Document();

    // Load fonts
    final boldFont = await PdfGoogleFonts.montserratBold();
    final regularFont = await PdfGoogleFonts.latoRegular();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(bill, boldFont, regularFont),
              pw.SizedBox(height: 20),

              // Bill Info
              _buildBillInfo(bill, boldFont, regularFont),
              pw.SizedBox(height: 20),

              // Receipt Details
              _buildReceiptDetails(bill, regularFont),
              pw.SizedBox(height: 20),

              // Deliveries Table
              bill.rentType == RentType.monthly
                  ? _buildMonthlyTable(bill, boldFont, regularFont)
                  : _buildSeasonalTable(bill, boldFont, regularFont),
              pw.SizedBox(height: 20),

              // Summary
              _buildSummary(bill, boldFont, regularFont),
              pw.Spacer(),

              // Footer
              _buildFooter(regularFont),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Print the PDF directly
  Future<void> printPdf(RentBill bill) async {
    final pdfData = await generatePdf(bill);
    await Printing.layoutPdf(
      onLayout: (format) async => pdfData,
    );
  }

  /// Save PDF to file (platform-specific handling needed)
  Future<void> savePdf(RentBill bill, String filename) async {
    final pdfData = await generatePdf(bill);
    await Printing.sharePdf(
      bytes: pdfData,
      filename: filename,
    );
  }

  // ========== Header Section ==========

  pw.Widget _buildHeader(RentBill bill, pw.Font boldFont, pw.Font regularFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'MULCHAND-BADRIDAS',
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 24,
            color: PdfColors.teal800,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Cold Storage Services',
          style: pw.TextStyle(
            font: regularFont,
            fontSize: 12,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 2, color: PdfColors.teal800),
      ],
    );
  }

  // ========== Bill Info Section ==========

  pw.Widget _buildBillInfo(RentBill bill, pw.Font boldFont, pw.Font regularFont) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'RENT BILL',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 18,
                color: PdfColors.teal800,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Bill No: ${bill.billNumber}',
              style: pw.TextStyle(font: regularFont, fontSize: 11),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Date: ${DateFormat('dd-MM-yyyy').format(bill.billDate)}',
              style: pw.TextStyle(font: regularFont, fontSize: 11),
            ),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: bill.rentType == RentType.monthly
                    ? PdfColors.blue100
                    : PdfColors.orange100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                bill.rentType.displayName,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 10,
                  color: bill.rentType == RentType.monthly
                      ? PdfColors.blue900
                      : PdfColors.orange900,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ========== Receipt Details Section ==========

  pw.Widget _buildReceiptDetails(RentBill bill, pw.Font regularFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Receipt No:', bill.receiptNumber, regularFont),
          pw.SizedBox(height: 4),
          _buildDetailRow('Cold Storage:', bill.coldStorageName, regularFont),
          pw.SizedBox(height: 4),
          _buildDetailRow('Product:', bill.productName, regularFont),
          pw.SizedBox(height: 4),
          _buildDetailRow('Company:', bill.companyName, regularFont),
        ],
      ),
    );
  }

  pw.Widget _buildDetailRow(String label, String value, pw.Font regularFont) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(
            label,
            style: pw.TextStyle(font: regularFont, fontSize: 10, color: PdfColors.grey700),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(font: regularFont, fontSize: 10),
        ),
      ],
    );
  }

  // ========== Monthly Table (with labour) ==========

  pw.Widget _buildMonthlyTable(RentBill bill, pw.Font boldFont, pw.Font regularFont) {
    final headers = [
      'DC No',
      'Inward Date',
      'Outward Date',
      'Qty',
      'Days',
      'Months',
      'Rate',
      'Amount',
    ];

    final rows = bill.items.map((item) {
      return [
        item.dcNumber,
        DateFormat('dd-MM-yy').format(item.inwardDate),
        DateFormat('dd-MM-yy').format(item.outwardDate),
        item.quantity.toStringAsFixed(0),
        item.daysStored.toString(),
        item.months.toStringAsFixed(1),
        item.ratePerUnit.toStringAsFixed(2),
        item.amount.toStringAsFixed(2),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        font: boldFont,
        fontSize: 9,
        color: PdfColors.white,
      ),
      cellStyle: pw.TextStyle(font: regularFont, fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        0: pw.Alignment.centerLeft,  // DC No
        1: pw.Alignment.centerLeft,  // Inward
        2: pw.Alignment.centerLeft,  // Outward
        3: pw.Alignment.centerRight, // Qty
        4: pw.Alignment.centerRight, // Days
        5: pw.Alignment.centerRight, // Months
        6: pw.Alignment.centerRight, // Rate
        7: pw.Alignment.centerRight, // Amount
      },
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5), // DC No
        1: const pw.FlexColumnWidth(1.5), // Inward
        2: const pw.FlexColumnWidth(1.5), // Outward
        3: const pw.FlexColumnWidth(1),   // Qty
        4: const pw.FlexColumnWidth(0.8), // Days
        5: const pw.FlexColumnWidth(1),   // Months
        6: const pw.FlexColumnWidth(1),   // Rate
        7: const pw.FlexColumnWidth(1.2), // Amount
      },
    );
  }

  // ========== Seasonal Table (no months, no labour) ==========

  pw.Widget _buildSeasonalTable(RentBill bill, pw.Font boldFont, pw.Font regularFont) {
    final headers = [
      'DC No',
      'Inward Date',
      'Outward Date',
      'Qty',
      'Days',
      'Rate',
      'Amount',
    ];

    final rows = bill.items.map((item) {
      return [
        item.dcNumber,
        DateFormat('dd-MM-yy').format(item.inwardDate),
        DateFormat('dd-MM-yy').format(item.outwardDate),
        item.quantity.toStringAsFixed(0),
        item.daysStored.toString(),
        item.ratePerUnit.toStringAsFixed(2),
        item.amount.toStringAsFixed(2),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        font: boldFont,
        fontSize: 9,
        color: PdfColors.white,
      ),
      cellStyle: pw.TextStyle(font: regularFont, fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        0: pw.Alignment.centerLeft,  // DC No
        1: pw.Alignment.centerLeft,  // Inward
        2: pw.Alignment.centerLeft,  // Outward
        3: pw.Alignment.centerRight, // Qty
        4: pw.Alignment.centerRight, // Days
        5: pw.Alignment.centerRight, // Rate
        6: pw.Alignment.centerRight, // Amount
      },
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5), // DC No
        1: const pw.FlexColumnWidth(1.5), // Inward
        2: const pw.FlexColumnWidth(1.5), // Outward
        3: const pw.FlexColumnWidth(1),   // Qty
        4: const pw.FlexColumnWidth(1),   // Days
        5: const pw.FlexColumnWidth(1.2), // Rate
        6: const pw.FlexColumnWidth(1.5), // Amount
      },
    );
  }

  // ========== Summary Section ==========

  pw.Widget _buildSummary(RentBill bill, pw.Font boldFont, pw.Font regularFont) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 250,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              // Monthly-specific rows
              if (bill.rentType == RentType.monthly) ...[
                _buildSummaryRow(
                  'Total Rent:',
                  '₹${bill.totalRentAmount.toStringAsFixed(2)}',
                  regularFont,
                ),
                pw.SizedBox(height: 4),
                _buildSummaryRow(
                  'Labour Charges:',
                  '₹${bill.labourCharges.toStringAsFixed(2)}',
                  regularFont,
                ),
                pw.SizedBox(height: 4),
                _buildSummaryRow(
                  'Subtotal:',
                  '₹${bill.subtotalBeforeGst.toStringAsFixed(2)}',
                  boldFont,
                  bold: true,
                ),
              ] else ...[
                _buildSummaryRow(
                  'Total Amount:',
                  '₹${bill.subtotalBeforeGst.toStringAsFixed(2)}',
                  boldFont,
                  bold: true,
                ),
              ],
              pw.Divider(thickness: 1),
              _buildSummaryRow(
                'SGST (9%):',
                '₹${bill.sgst.toStringAsFixed(2)}',
                regularFont,
              ),
              pw.SizedBox(height: 4),
              _buildSummaryRow(
                'CGST (9%):',
                '₹${bill.cgst.toStringAsFixed(2)}',
                regularFont,
              ),
              pw.Divider(thickness: 2),
              _buildSummaryRow(
                'FINAL AMOUNT:',
                '₹${bill.finalAmount.toStringAsFixed(2)}',
                boldFont,
                bold: true,
                fontSize: 12,
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSummaryRow(
    String label,
    String value,
    pw.Font font, {
    bool bold = false,
    double fontSize = 10,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: font,
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : null,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: font,
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : null,
          ),
        ),
      ],
    );
  }

  // ========== Footer Section ==========

  pw.Widget _buildFooter(pw.Font regularFont) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 1, color: PdfColors.grey400),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated on: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(font: regularFont, fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Thank you for your business',
              style: pw.TextStyle(font: regularFont, fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ],
    );
  }
}
