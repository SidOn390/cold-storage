// lib/screens/billing/billing_checker_screen.dart

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:business_management_app/models/receipt_model.dart';
import 'package:business_management_app/models/delivery_model.dart';
import 'package:business_management_app/services/firestore_service.dart';
import 'package:business_management_app/utils/app_notifications.dart';
import 'package:business_management_app/widgets/app_background.dart';

class BillingCheckerScreen extends StatefulWidget {
  const BillingCheckerScreen({super.key, this.initialDetailReceipt});
  final Receipt? initialDetailReceipt;

  @override
  State<BillingCheckerScreen> createState() => _BillingCheckerScreenState();
}

class _BillingCheckerScreenState extends State<BillingCheckerScreen> {
  final FirestoreService _firestore = FirestoreService();

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

  // Autocomplete controller
  final TextEditingController _storageCtrl = TextEditingController(text: 'All');
  final FocusNode _storageFocus = FocusNode();

  final _dateFmt = DateFormat('dd-MM-yy');
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchAll();
    if (widget.initialDetailReceipt != null) {
      _detailReceipt = widget.initialDetailReceipt; // ⬅️ NEW
      _selectedColdStorage =
          widget.initialDetailReceipt!.coldStorageName; // optional polish
      _tab = widget.initialDetailReceipt!.isPaid
          ? 'Paid'
          : 'Unpaid'; // optional polish
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

  Future<void> _togglePaid(Receipt r) async {
    // For safety: only allow marking as paid if remaining == 0
    if (!r.isPaid && _remainingFor(r) != 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(r.isPaid ? 'Unmark as Paid?' : 'Mark as Paid?'),
        content: Text(
          'Are you sure you want to ${r.isPaid ? 'unmark' : 'mark'} this receipt as paid?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OK'),
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

    final rows = _filteredReceipts.take(_visibleCount).map((r) {
      return [
        r.coldStorageName,
        '#${r.receiptNumber}',
        r.productName,
        r.brandName,
        _dateFmt.format(_inwardTs(r).toDate()),
        _inwardQty(r).toString(),
        _remainingFor(r).toString(),
        _isPaid(r) ? 'Yes' : 'No',
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(20),
        build: (_) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Billing Checker - $_tab Summary',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(DateFormat('dd-MM-yy HH:mm').format(DateTime.now())),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text('Cold Storage: $_selectedColdStorage'),
          pw.SizedBox(height: 8),
          if (rows.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 24),
              child: pw.Text('No entries.'),
            )
          else
            pw.Table.fromTextArray(
              headers: const [
                'Cold Storage',
                'Receipt #',
                'Product',
                'Brand',
                'Inward Date',
                'Inward Qty',
                'Remaining',
                'Paid',
              ],
              data: rows,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerLeft,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
                7: pw.Alignment.center,
              },
              columnWidths: const {
                0: pw.FlexColumnWidth(2.0),
                1: pw.FlexColumnWidth(1.2),
                2: pw.FlexColumnWidth(1.6),
                3: pw.FlexColumnWidth(1.2),
                4: pw.FlexColumnWidth(1.2),
                5: pw.FlexColumnWidth(1.0),
                6: pw.FlexColumnWidth(1.0),
                7: pw.FlexColumnWidth(0.8),
              },
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

    final rows = deliveries.map((d) {
      return [
        _dateFmt.format(d.deliveryDate.toDate()),
        d.quantity.toString(),
        d.narration,
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(20),
        build: (_) => [
          pw.Text(
            '${r.coldStorageName}  -  #${r.receiptNumber}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Product: ${r.productName}   •   Brand: ${r.brandName}'),
          pw.Text(
            'Inward: ${_dateFmt.format(_inwardTs(r).toDate())}   •   Inward Qty: ${_inwardQty(r)}   •   Remaining: ${_remainingFor(r)}',
          ),
          pw.SizedBox(height: 10),
          if (rows.isEmpty)
            pw.Text('No deliveries recorded yet.')
          else
            pw.Table.fromTextArray(
              headers: const ['Date', 'Qty', 'Narration'],
              data: rows,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerLeft,
              },
              columnWidths: const {
                0: pw.FlexColumnWidth(1.0),
                1: pw.FlexColumnWidth(0.6),
                2: pw.FlexColumnWidth(2.0),
              },
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
  // In lib/screens/billing/billing_checker_screen.dart
  // Add this new method anywhere inside the _BillingCheckerScreenState class

  Widget _buildColdStorageSelector() {
    return TextField(
      controller: _storageCtrl, // Displays the selected value
      readOnly: true, // Prevents the keyboard from showing up
      onTap: _showColdStorageSheet, // Triggers the bottom sheet on tap
      decoration: InputDecoration(
        labelText: 'Cold Storage',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        // The prefix icon inside the field
        prefixIcon: const Icon(Icons.store_outlined),
        // --- Key styling for the look you want ---
        filled: true,
        fillColor: Colors.white,
        // Create a rounded border but make the border line invisible
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none, // This removes the border outline
        ),
        // ------------------------------------------
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
              // Make the list scrollable and not take up the whole screen
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
                        Navigator.pop(context); // Close the bottom sheet
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

  // In lib/screens/billing/billing_checker_screen.dart

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // --- FIX 1: Allow the body to extend behind the AppBar ---
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _detailReceipt == null
              ? 'Billing Checker' // summary view
              : (_launchedForDetail
                    ? 'Receipt Detail' // opened from Receipt List
                    : 'Billing Checker – Detail'), // opened inside Billing screen
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _detailReceipt != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (_launchedForDetail) {
                    Navigator.pop(context); // ⬅️ NEW (return to Receipt List)
                  } else {
                    setState(
                      () => _detailReceipt = null,
                    ); // old behavior (return to summary)
                  }
                },
              )
            : null,
      ),
      body: AppBackground(
        child: SafeArea(
          // --- FIX 2: Ensure SafeArea respects the top of the screen ---
          top: true,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _fetchAll,
                  child: _detailReceipt == null
                      ? _buildSummaryView()
                      : _buildDetailView(_detailReceipt!),
                ),
        ),
      ),
    );
  }

  Widget _buildSummaryView() {
    final data = _filteredReceipts;
    final visible = data.take(_visibleCount).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Autocomplete Cold Storage
                  Expanded(child: _buildColdStorageSelector()),

                  // Expanded(
                  //   child: OutlinedButton.icon(
                  //     icon: const Icon(Icons.store_outlined),
                  //     label: Text(_selectedColdStorage),
                  //     onPressed: _showColdStorageSheet,
                  //     style: OutlinedButton.styleFrom(
                  //       padding: const EdgeInsets.symmetric(vertical: 16),
                  //       alignment: Alignment.centerLeft,
                  //       textStyle: const TextStyle(fontSize: 16),
                  //     ),
                  //   ),
                  // ),
                  const SizedBox(width: 12),
                  // Paid/Unpaid chips
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _exportSummaryPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text('Export $_tab PDF'),
                ),
              ),
            ),
            const Divider(height: 0),
            Expanded(
              child: visible.isEmpty
                  ? _buildEmptyState('No $_tab receipts found.')
                  : ListView.separated(
                      controller: _scroll,
                      itemCount:
                          visible.length +
                          (visible.length < data.length ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemBuilder: (context, index) {
                        if (index >= visible.length) {
                          // Load more footer indicator
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16.0,
                              ),
                              child: Text(
                                'Loading more… (${visible.length}/${data.length})',
                              ),
                            ),
                          );
                        }
                        final r = visible[index];
                        final remaining = _remainingFor(r);
                        final paid = _isPaid(r);
                        return _receiptCard(
                          r,
                          remaining: remaining,
                          paid: paid,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptCard(Receipt r, {required int remaining, required bool paid}) {
    final inwardDate = _dateFmt.format(_inwardTs(r).toDate());
    final canMarkPaid = !paid && remaining == 0;

    return Card(
      child: InkWell(
        onTap: () => setState(() => _detailReceipt = r),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: paid
                          ? Colors.green.withOpacity(0.15)
                          : (remaining == 0
                                ? Colors.orange.withOpacity(0.15)
                                : Colors.blue.withOpacity(0.15)),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      paid
                          ? 'Paid'
                          : (remaining == 0 ? 'Unpaid' : 'In Progress'),
                      style: TextStyle(
                        color: paid
                            ? Colors.green
                            : (remaining == 0 ? Colors.orange : Colors.blue),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
          // Added missing ConstrainedBox
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
                    _detailRow('Cold Storage', r.coldStorageName),
                    _detailRow('Receipt #', r.receiptNumber),
                    _detailRow('Product', r.productName),
                    _detailRow('Brand', r.brandName),
                    _detailRow(
                      'Inward Date',
                      _dateFmt.format(_inwardTs(r).toDate()),
                    ),
                    _detailRow('Inward Qty', _inwardQty(r).toString()),
                    _detailRow(
                      'Remaining',
                      remaining.toString(),
                      valueColor: remaining == 0
                          ? Colors.green
                          : Theme.of(context).colorScheme.error,
                    ),
                  ],
                ),
              ),
            ),
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
                                      _dateFmt.format(d.deliveryDate.toDate()),
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

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(
              value.toUpperCase(),
              style: TextStyle(color: valueColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.blueGrey),
            SizedBox(height: 12),
            Text('No data to show', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
