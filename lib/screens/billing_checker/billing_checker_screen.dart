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

// Shared building blocks
import 'package:business_management_app/widgets/status_chip.dart';
import 'package:business_management_app/widgets/info_kv_row.dart';
import 'package:business_management_app/utils/date_fmt.dart';
import 'package:business_management_app/utils/pdf_utils.dart' as pdfu;

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
                        'Showing $_selectedColdStorage · ${scope.length} receipts (${scopeUnpaid} unpaid)',
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
                            color: Colors.blue.withOpacity(0.15),
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
