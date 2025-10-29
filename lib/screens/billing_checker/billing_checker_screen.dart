// lib/screens/billing/billing_checker_screen.dart

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:cold_storage/models/receipt_model.dart';
import 'package:cold_storage/models/delivery_model.dart';
import 'package:cold_storage/models/rent_bill.dart';
import 'package:cold_storage/models/rent_bill_item.dart';
import 'package:cold_storage/models/rent_type.dart';
import 'package:cold_storage/services/firestore_service.dart';
import 'package:cold_storage/services/rent_bill_service.dart';
import 'package:cold_storage/services/user_management_service.dart';
import 'package:cold_storage/utils/app_notifications.dart';
import 'package:cold_storage/widgets/app_background.dart';

// Shared building blocks
import 'package:cold_storage/widgets/status_chip.dart';
import 'package:cold_storage/widgets/info_kv_row.dart';
import 'package:cold_storage/utils/date_fmt.dart';
import 'package:cold_storage/utils/pdf_utils.dart' as pdfu;

class BillingCheckerScreen extends StatefulWidget {
  const BillingCheckerScreen({super.key, this.initialDetailReceipt});
  final Receipt? initialDetailReceipt;

  @override
  State<BillingCheckerScreen> createState() => _BillingCheckerScreenState();
}

class _BillingCheckerScreenState extends State<BillingCheckerScreen> {
  final FirestoreService _firestore = FirestoreService();
  final RentBillService _billService = RentBillService.instance;
  final UserManagementService _userService = UserManagementService();

  // Data
  List<Receipt> _allReceipts = [];
  List<Delivery> _allDeliveries = [];

  // UI state
  String _tab = 'Paid'; // 'Paid' | 'Unpaid'
  String _selectedColdStorage = 'All';
  int _visibleCount = 20;
  bool _isLoading = true;
  bool get _launchedForDetail => widget.initialDetailReceipt != null;

  // Detail view
  Receipt? _detailReceipt;
  RentBill? _calculatedBill; // For rent calculation display
  bool _isCalculatingBill = false;
  bool _showDetailedBreakdown = false; // Toggle for line item details

  // Storage selector
  final TextEditingController _storageCtrl = TextEditingController(text: 'All');
  final FocusNode _storageFocus = FocusNode();

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchAll();
    if (widget.initialDetailReceipt != null) {
      _detailReceipt = widget.initialDetailReceipt;
      _selectedColdStorage = widget.initialDetailReceipt!.coldStorageName;
      _tab = widget.initialDetailReceipt!.isPaid ? 'Paid' : 'Unpaid';
      // Calculate rent for initial receipt
      _calculateRentBill(widget.initialDetailReceipt!);
    }
    _scroll.addListener(_onScrollLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _storageCtrl.dispose();
    _storageFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      _allReceipts = await _firestore.getReceipts().first;
      _allDeliveries = await _firestore.getDeliveries().first;
    } catch (e) {
      if (!mounted) return;
      showAppNotification(
        context: context,
        message: 'Error loading data: $e',
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ====== Derived helpers ======

  List<String> get _coldStorageNames {
    final names = _allReceipts.map((r) => r.coldStorageName).toSet().toList();
    names.sort();
    return names;
  }

  bool _isPaid(Receipt r) => r.isPaid;
  int _remainingFor(Receipt r) => r.remainingQuantity;
  Timestamp _inwardTs(Receipt r) => r.inwardDate;
  int _inwardQty(Receipt r) => r.inwardQuantity;

  List<Receipt> get _filteredReceipts {
    final query = _selectedColdStorage.trim().toLowerCase();
    final list = _allReceipts.where((r) {
      final storageOk = query == 'all'
          ? true
          : r.coldStorageName.toLowerCase().contains(query); // substring match
      final remaining = _remainingFor(r);
      final paid = _isPaid(r);
      // Unpaid tab = fully cleared but not yet marked paid
      final tabOk = _tab == 'Paid' ? paid : (!paid && remaining == 0);
      return storageOk && tabOk;
    }).toList();

    // Recent first by inward date
    list.sort((a, b) => _inwardTs(b).compareTo(_inwardTs(a)));
    return list;
  }

  List<Delivery> _deliveriesFor(Receipt r) {
    final list = _allDeliveries
        .where(
          (d) =>
              d.coldStorageName == r.coldStorageName &&
              d.receiptNumber == r.receiptNumber,
        )
        .toList();
    list.sort((a, b) => a.deliveryDate.compareTo(b.deliveryDate));
    return list;
  }

  void _onScrollLoadMore() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      final total = _filteredReceipts.length;
      if (_visibleCount < total) {
        setState(() => _visibleCount = (_visibleCount + 20).clamp(0, total));
      }
    }
  }

  void _applyColdStorage(String raw) {
    final v = raw.trim().isEmpty ? 'All' : raw.trim();
    setState(() {
      _selectedColdStorage = v;
      _storageCtrl.text = v;
      _visibleCount = 20;
    });
  }

  // ====== Actions ======

  Future<void> _calculateRentBill(Receipt receipt) async {
    if (!mounted) return;

    setState(() {
      _isCalculatingBill = true;
      _calculatedBill = null;
      _showDetailedBreakdown = false; // Reset when loading new receipt
    });

    try {
      // Get deliveries for this receipt
      final deliveries = await _firestore.getDeliveriesForReceipt(
        receiptNumber: receipt.receiptNumber,
        coldStorageName: receipt.coldStorageName,
      );

      if (deliveries.isEmpty) {
        if (mounted) {
          setState(() => _isCalculatingBill = false);
        }
        return;
      }

      // Generate rent bill calculation
      final currentUser = await _userService.getCurrentUser();
      final bill = await _billService.generateBillFromReceipt(
        receipt: receipt,
        deliveries: deliveries,
        createdBy: currentUser?.displayName ?? 'System',
      );

      if (mounted) {
        setState(() {
          _calculatedBill = bill;
          _isCalculatingBill = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCalculatingBill = false);
        showAppNotification(
          context: context,
          message: 'Error calculating rent: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _togglePaid(Receipt r) async {
    final remaining = _remainingFor(r);

    // Enhanced validation: Only allow marking as paid if all deliveries completed
    if (!r.isPaid && remaining != 0) {
      showAppNotification(
        context: context,
        message: 'Cannot mark as paid. Receipt has $remaining units remaining. Complete all deliveries first.',
        type: NotificationType.error,
      );
      return;
    }

    // Show amount in confirmation if available
    String amountText = '';
    if (_calculatedBill != null) {
      amountText = '\n\nCalculated Amount: ₹${_calculatedBill!.finalAmount.toStringAsFixed(0)}';
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(r.isPaid ? 'Unmark as Paid?' : 'Mark as Paid?'),
        content: Text(
          r.isPaid
              ? 'Are you sure you want to unmark receipt #${r.receiptNumber} as paid?'
              : 'Confirm marking receipt #${r.receiptNumber} as paid?$amountText',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: r.isPaid ? Colors.orange : Colors.green,
            ),
            child: Text(r.isPaid ? 'Unmark' : 'Mark Paid'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _firestore.toggleReceiptPaidStatus(r.id!, r.isPaid);
      if (!mounted) return;
      showAppNotification(
        context: context,
        message: r.isPaid
            ? 'Receipt unmarked as paid'
            : 'Receipt marked as paid',
        type: NotificationType.info,
      );
      await _fetchAll();
      if (_detailReceipt != null) {
        setState(() {
          _detailReceipt = _allReceipts.firstWhere(
            (x) => x.id == r.id,
            orElse: () => r,
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      showAppNotification(
        context: context,
        message: 'Failed to update: $e',
        type: NotificationType.error,
      );
    }
  }

  // ====== PDF: summary ======

  Future<Uint8List> _buildSummaryPdf(PdfPageFormat format) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(20),
        build: (_) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pdfu.h1('Billing Checker - $_tab Summary'),
              pw.Text(DateFormat('dd-MM-yy HH:mm').format(DateTime.now())),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text('Cold Storage: $_selectedColdStorage'),
          pw.SizedBox(height: 8),
          if (_filteredReceipts.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 24),
              child: pw.Text('No entries.'),
            )
          else
            pdfu.table(
              const [
                'Cold Storage',
                'Receipt #',
                'Product',
                'Brand',
                'Inward Date',
                'Inward Qty',
                'Remaining',
                'Paid',
              ],
              _filteredReceipts
                  .take(_visibleCount)
                  .map(
                    (r) => [
                      r.coldStorageName,
                      '#${r.receiptNumber}',
                      r.productName,
                      r.brandName,
                      dfDdMmYy.format(_inwardTs(r).toDate()),
                      '${_inwardQty(r)}',
                      '${_remainingFor(r)}',
                      _isPaid(r) ? 'Yes' : 'No',
                    ],
                  )
                  .toList(),
            ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> _exportSummaryPdf() async {
    if (_filteredReceipts.isEmpty) {
      showAppNotification(
        context: context,
        message: 'No $_tab receipts to export.',
        type: NotificationType.error,
      );
      return;
    }
    try {
      await Printing.layoutPdf(onLayout: _buildSummaryPdf);
    } catch (_) {
      // Fallback for web / popup blockers
      final bytes = await _buildSummaryPdf(PdfPageFormat.a4);
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'billing_${_tab.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    }
  }

  // ====== PDF: detail ======

  Future<Uint8List> _buildDetailPdf(Receipt r, PdfPageFormat format) async {
    final doc = pw.Document();
    final deliveries = _deliveriesFor(r);

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(20),
        build: (_) => [
          pdfu.h1('${r.coldStorageName}  -  #${r.receiptNumber}'),
          pw.SizedBox(height: 6),
          pw.Text('Product: ${r.productName}   •   Brand: ${r.brandName}'),
          pw.Text(
            'Inward: ${dfDdMmYy.format(_inwardTs(r).toDate())}   •   Inward Qty: ${_inwardQty(r)}   •   Remaining: ${_remainingFor(r)}',
          ),
          pw.SizedBox(height: 10),
          if (deliveries.isEmpty)
            pw.Text('No deliveries recorded yet.')
          else
            pdfu.table(
              const ['Date', 'Qty', 'Narration'],
              deliveries
                  .map(
                    (d) => [
                      dfDdMmYy.format(d.deliveryDate.toDate()),
                      '${d.quantity}',
                      d.narration,
                    ],
                  )
                  .toList(),
            ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> _exportDetailPdf(Receipt r) async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) => _buildDetailPdf(r, format),
      );
    } catch (_) {
      final bytes = await _buildDetailPdf(r, PdfPageFormat.a4);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'receipt_${r.receiptNumber}.pdf',
      );
    }
    if (!mounted) return;
  }

  Future<void> _exportDetailedRentBillPdf(Receipt r) async {
    if (_calculatedBill == null) {
      showAppNotification(
        context: context,
        message: 'No rent calculation available to export',
        type: NotificationType.error,
      );
      return;
    }

    try {
      await Printing.layoutPdf(
        onLayout: (format) => _buildDetailedRentBillPdf(r, _calculatedBill!, format),
      );
    } catch (_) {
      final bytes = await _buildDetailedRentBillPdf(r, _calculatedBill!, PdfPageFormat.a4);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'detailed_bill_${r.receiptNumber}.pdf',
      );
    }
  }

  Future<Uint8List> _buildDetailedRentBillPdf(
    Receipt receipt,
    RentBill bill,
    PdfPageFormat format,
  ) async {
    final doc = pw.Document();
    final rentType = bill.rentType;

    // Sort line items by date
    final sortedItems = bill.items.toList()
      ..sort((a, b) => a.outwardDate.compareTo(b.outwardDate));

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(20),
        build: (_) => [
          // Header
          pdfu.h1('DETAILED RENT BILL'),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Receipt #${receipt.receiptNumber}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text('Company: ${receipt.companyName}'),
                  pw.Text('Product: ${receipt.productName}'),
                  pw.Text('Cold Storage: ${receipt.coldStorageName}'),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Bill #${bill.billNumber}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Date: ${DateFormat('dd-MM-yyyy').format(bill.billDate)}'),
                  pw.Text('Type: ${rentType.displayName}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.SizedBox(height: 16),

          // Line items header
          pw.Text('DELIVERY BREAKDOWN',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 12),

          // Line items
          ...sortedItems.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final item = entry.value;

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('$index. ${DateFormat('dd-MM-yyyy').format(item.outwardDate)}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Quantity: ${item.quantity} units',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  if (rentType == RentType.monthly)
                    pw.Text('Days Stored: ${item.daysStored} days → ${item.months.toStringAsFixed(2)} months',
                        style: const pw.TextStyle(fontSize: 10))
                  else
                    pw.Text('Days Stored: ${item.daysStored} days',
                        style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Rate: ₹${item.ratePerUnit}${rentType == RentType.monthly ? '/unit/month' : '/unit'}',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    color: PdfColors.grey100,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Calculation:',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          rentType == RentType.monthly
                              ? '${item.quantity} × ${item.months.toStringAsFixed(2)} × ₹${item.ratePerUnit} = ₹${item.amount.toStringAsFixed(2)}'
                              : '${item.quantity} × ₹${item.ratePerUnit} = ₹${item.amount.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  pw.Divider(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Line Total:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('₹${item.amount.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            );
          }),

          pw.SizedBox(height: 16),
          pw.Divider(thickness: 2),
          pw.SizedBox(height: 12),

          // Summary section
          pw.Text('BILL SUMMARY',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 8),

          if (rentType == RentType.monthly) ...[
            _pdfRow('Total Rent', '₹${bill.totalRentAmount.toStringAsFixed(2)}'),
            _pdfRow('Labour Charges (${receipt.inwardQuantity} units × ₹${bill.labourCharges / receipt.inwardQuantity})',
                '₹${bill.labourCharges.toStringAsFixed(2)}'),
            _pdfRow('Subtotal', '₹${bill.subtotalBeforeGst.toStringAsFixed(2)}', bold: true),
          ] else
            _pdfRow('Total Amount', '₹${bill.subtotalBeforeGst.toStringAsFixed(2)}', bold: true),

          pw.Divider(height: 16),
          _pdfRow('SGST (9%)', '₹${bill.sgst.toStringAsFixed(2)}'),
          _pdfRow('CGST (9%)', '₹${bill.cgst.toStringAsFixed(2)}'),
          if (bill.roundOff != 0.0)
            _pdfRow('Round-off', '${bill.roundOff >= 0 ? '+' : ''}₹${bill.roundOff.toStringAsFixed(2)}'),
          pw.Divider(height: 16, thickness: 2),

          // Final amount
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            color: PdfColors.green50,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('FINAL AMOUNT',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.Text('₹${bill.finalAmount.toStringAsFixed(0)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),

          pw.SizedBox(height: 20),
          pw.Text('Generated on: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  // ====== Cold Storage selector (bottom sheet trigger) ======

  Widget _buildColdStorageSelector() {
    return TextField(
      controller: _storageCtrl,
      readOnly: true,
      onTap: _showColdStorageSheet,
      decoration: InputDecoration(
        labelText: 'Cold Storage',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        prefixIcon: const Icon(Icons.store_outlined),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void _showColdStorageSheet() {
    final allOptions = <String>['All', ..._coldStorageNames];

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Select Cold Storage',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allOptions.length,
                  itemBuilder: (context, index) {
                    final opt = allOptions[index];
                    return ListTile(
                      title: Text(opt),
                      onTap: () {
                        _applyColdStorage(opt);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ====== UI ======

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _detailReceipt == null
              ? 'Billing Checker'
              : (_launchedForDetail
                    ? 'Receipt Detail'
                    : 'Billing Checker – Detail'),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _detailReceipt != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (_launchedForDetail) {
                    Navigator.pop(context);
                  } else {
                    setState(() => _detailReceipt = null);
                  }
                },
              )
            : null,
      ),
      body: AppBackground(
        child: SafeArea(
          top: true,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _fetchAll,
                  child: _detailReceipt == null
                      ? _buildSummaryView() // now sliver-based
                      : _buildDetailView(_detailReceipt!),
                ),
        ),
      ),
    );
  }

  /// SUMMARY VIEW — Sliver-based, lazy list with separators + load-more footer
  Widget _buildSummaryView() {
    final data = _filteredReceipts;
    final visible = data.take(_visibleCount).toList();

    // Helper line stats
    final scope = _selectedColdStorage == 'All'
        ? _allReceipts
        : _allReceipts
              .where((r) => r.coldStorageName == _selectedColdStorage)
              .toList();
    final scopeUnpaid = scope.where((r) => !r.isPaid).length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            // Header row: storage selector + tabs
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildColdStorageSelector()),
                    const SizedBox(width: 12),
                    Wrap(
                      spacing: 8,
                      children: ['Paid', 'Unpaid'].map((f) {
                        final active = _tab == f;
                        return ChoiceChip(
                          label: Text(f),
                          selected: active,
                          onSelected: (_) => setState(() {
                            _tab = f;
                            _visibleCount = 20;
                          }),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Helper line + Export button
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Showing $_selectedColdStorage · ${scope.length} receipts ($scopeUnpaid unpaid)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _exportSummaryPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text('Export $_tab PDF'),
                    ),
                  ],
                ),
              ),
            ),

            // Divider
            const SliverToBoxAdapter(child: Divider(height: 0)),

            if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState('No $_tab receipts found.'),
              )
            else
              // Lazy list with on-the-fly separators
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index.isOdd) {
                      return const SizedBox(height: 8);
                    }
                    final i = index ~/ 2;
                    final r = visible[i];
                    final remaining = _remainingFor(r);
                    final paid = _isPaid(r);
                    return _receiptCard(r, remaining: remaining, paid: paid);
                  }, childCount: visible.length * 2 - 1),
                ),
              ),

            // Load-more footer (only when more are available)
            if (visible.length < data.length)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0, top: 4),
                    child: Text(
                      'Loading more… (${visible.length}/${data.length})',
                    ),
                  ),
                ),
              ),

            // Extra bottom padding to clear FAB
            const SliverToBoxAdapter(child: SizedBox(height: 72)),
          ],
        ),
      ),
    );
  }

  Widget _receiptCard(Receipt r, {required int remaining, required bool paid}) {
    final inwardDate = dfDdMmYy.format(_inwardTs(r).toDate());
    final canMarkPaid = !paid && remaining == 0;

    return Card(
      child: InkWell(
        onTap: () {
          setState(() => _detailReceipt = r);
          _calculateRentBill(r);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${r.coldStorageName.toUpperCase()}  –  ${r.receiptNumber}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusChip(isPaid: paid),
                      if (!paid && remaining > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'In Progress',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Product: ${r.productName.toUpperCase()}'),
              Text('Brand: ${r.brandName.toUpperCase()}'),
              Text(
                'Inward: $inwardDate   •   Inward Qty: ${_inwardQty(r)}   •   Remaining: $remaining',
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (canMarkPaid)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Mark as Paid'),
                      onPressed: () => _togglePaid(r),
                    )
                  else if (paid)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.undo_outlined),
                      label: const Text('Unmark Paid'),
                      onPressed: () => _togglePaid(r),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailView(Receipt r) {
    final deliveries = _deliveriesFor(r);
    final remaining = _remainingFor(r);
    final paid = _isPaid(r);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receipt Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InfoKvRow(label: 'Company', value: r.companyName),
                    InfoKvRow(label: 'Cold Storage', value: r.coldStorageName),
                    InfoKvRow(
                      label: 'Receipt #',
                      value: r.receiptNumber.toString(),
                    ),
                    InfoKvRow(label: 'Product', value: r.productName),
                    InfoKvRow(label: 'Brand', value: r.brandName),
                    InfoKvRow(
                      label: 'Inward Date',
                      value: dfDdMmYy.format(_inwardTs(r).toDate()),
                    ),
                    InfoKvRow(
                      label: 'Inward Qty',
                      value: _inwardQty(r).toString(),
                    ),
                    InfoKvRow(label: 'Remaining', value: remaining.toString()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Rent Calculation Card
            _buildRentCalculationCard(r),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outward Entries',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (deliveries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'No deliveries recorded yet.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    else
                      Column(
                        children: [
                          const Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Date',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Qty',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Narration',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          ...deliveries.map(
                            (d) => Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6.0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      dfDdMmYy.format(d.deliveryDate.toDate()),
                                    ),
                                  ),
                                  Expanded(child: Text(d.quantity.toString())),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      d.narration.isEmpty ? '-' : d.narration,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () => _exportDetailPdf(r),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Export Detail PDF'),
                ),
                const SizedBox(width: 12),
                // Show detailed rent bill PDF export only when calculation is available
                if (_calculatedBill != null) ...[
                  FilledButton.icon(
                    onPressed: () => _exportDetailedRentBillPdf(r),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Export Rent Bill PDF'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                FilledButton.icon(
                  onPressed: (!paid && remaining != 0)
                      ? null
                      : () => _togglePaid(r),
                  icon: Icon(
                    paid ? Icons.undo_outlined : Icons.verified_outlined,
                  ),
                  label: Text(paid ? 'Unmark Paid' : 'Mark as Paid'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRentCalculationCard(Receipt receipt) {
    final rentType = RentType.fromJson(receipt.rentType);
    final hasRateInfo = rentType == RentType.monthly
        ? (receipt.monthlyRatePerUnit != null || receipt.isRateLocked == false)
        : (receipt.seasonalRatePerUnit != null || receipt.isRateLocked == false);

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calculate_outlined, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Rent Calculation',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade900,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: rentType == RentType.monthly
                        ? Colors.blue.shade700
                        : Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    rentType.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            if (_isCalculatingBill)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (!hasRateInfo)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No rent rate configured in Rent Master for this combination.',
                        style: TextStyle(color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              )
            else if (_calculatedBill == null)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No deliveries to calculate rent.'),
              )
            else
              Column(
                children: [
                  // Show rate lock status
                  if (receipt.isRateLocked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.lock, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Rate locked by Bill #${receipt.lockedByBillNumber}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.sync, size: 14, color: Colors.green.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Using live rates from Rent Master',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Calculation breakdown
                  if (rentType == RentType.monthly) ...[
                    _buildCalcRow('Total Rent', '₹${_calculatedBill!.totalRentAmount.toStringAsFixed(2)}'),
                    _buildCalcRow('Labour Charges', '₹${_calculatedBill!.labourCharges.toStringAsFixed(2)}'),
                    _buildCalcRow('Subtotal', '₹${_calculatedBill!.subtotalBeforeGst.toStringAsFixed(2)}', bold: true),
                  ] else
                    _buildCalcRow('Total Amount', '₹${_calculatedBill!.subtotalBeforeGst.toStringAsFixed(2)}', bold: true),

                  const Divider(height: 20),
                  _buildCalcRow('SGST (9%)', '₹${_calculatedBill!.sgst.toStringAsFixed(2)}'),
                  _buildCalcRow('CGST (9%)', '₹${_calculatedBill!.cgst.toStringAsFixed(2)}'),
                  if (_calculatedBill!.roundOff != 0.0)
                    _buildCalcRow(
                      'Round-off',
                      '${_calculatedBill!.roundOff >= 0 ? '+' : ''}₹${_calculatedBill!.roundOff.toStringAsFixed(2)}',
                    ),
                  const Divider(height: 20),

                  // Toggle button for detailed breakdown
                  Center(
                    child: TextButton.icon(
                      icon: Icon(_showDetailedBreakdown
                          ? Icons.expand_less
                          : Icons.expand_more),
                      label: Text(_showDetailedBreakdown
                          ? 'Hide Detail View'
                          : 'View Detail View'),
                      onPressed: () {
                        setState(() {
                          _showDetailedBreakdown = !_showDetailedBreakdown;
                        });
                      },
                    ),
                  ),

                  // Expandable detailed breakdown
                  if (_showDetailedBreakdown) ...[
                    const Divider(height: 20),
                    Text(
                      'Detailed View',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...(_calculatedBill!.items.toList()
                          ..sort((a, b) => a.outwardDate.compareTo(b.outwardDate)))
                        .asMap()
                        .entries
                        .map((entry) => _buildLineItemDetail(entry.key + 1, entry.value)),
                    const Divider(height: 20),
                  ],

                  // Final amount - prominent display
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300, width: 2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'FINAL AMOUNT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                        Text(
                          '₹${_calculatedBill!.finalAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalcRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItemDetail(int index, RentBillItem item) {
    final rentType = _calculatedBill?.rentType ?? RentType.monthly;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$index',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd-MM-yyyy').format(item.outwardDate),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Qty: ${item.quantity}',
                  style: TextStyle(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                rentType == RentType.monthly
                    ? '${item.daysStored} days → ${item.months.toStringAsFixed(2)} months'
                    : '${item.daysStored} days',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.currency_rupee, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                rentType == RentType.monthly
                    ? 'Rate: ₹${item.ratePerUnit}/unit/month'
                    : 'Rate: ₹${item.ratePerUnit}/unit',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Line Total:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Text(
                '₹${item.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
