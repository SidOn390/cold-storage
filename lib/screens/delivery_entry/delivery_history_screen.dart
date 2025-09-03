// lib/screens/delivery/delivery_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:business_management_app/models/delivery_model.dart';
import 'package:business_management_app/models/receipt_model.dart';
import 'package:business_management_app/services/firestore_service.dart';
import 'package:business_management_app/utils/app_notifications.dart';
import 'package:business_management_app/widgets/app_background.dart';
import 'package:business_management_app/app_router.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  // Data
  List<Delivery> _allDeliveries = [];
  List<Receipt> _allReceipts = [];
  List<Delivery> _filteredDeliveries = [];

  // Keyboard-friendly date inputs
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _fromFocus = FocusNode();
  final _toFocus = FocusNode();
  // Make calendar icons non-focusable to avoid Enter triggering them
  final _fromCalFocus = FocusNode(skipTraversal: true);
  final _toCalFocus = FocusNode(skipTraversal: true);

  final DateFormat _dateFmt = DateFormat('dd-MM-yy');

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // Initialize both dates to today (user can clear any field to make it unbounded)
    final today = DateTime.now();
    _fromCtrl.text = _dateFmt.format(today);
    _toCtrl.text = _dateFmt.format(today);

    // Focus From Date on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fromFocus.requestFocus();
    });

    _fetchDataAndFilter();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    _fromCalFocus.dispose();
    _toCalFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchDataAndFilter() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      _allDeliveries = await _firestoreService.getDeliveries().first;
      _allReceipts = await _firestoreService.getReceipts().first;
      _filterDeliveries();
    } catch (e) {
      if (mounted) {
        showAppNotification(
          context: context,
          message: "Error fetching data: $e",
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  DateTime? _tryParseDate(String text) {
    final s = text.trim();
    if (s.isEmpty) return null;
    try {
      return _dateFmt.parseStrict(s);
    } catch (_) {
      return null;
    }
  }

  void _applyDateFilter() {
    final fromText = _fromCtrl.text.trim();
    final toText = _toCtrl.text.trim();
    final from = _tryParseDate(fromText);
    final to = _tryParseDate(toText);

    if (fromText.isNotEmpty && from == null) {
      showAppNotification(
        context: context,
        message: "Invalid From date. Use dd-MM-yy.",
        type: NotificationType.error,
      );
      _fromFocus.requestFocus();
      return;
    }

    if (toText.isNotEmpty && to == null) {
      showAppNotification(
        context: context,
        message: "Invalid To date. Use dd-MM-yy.",
        type: NotificationType.error,
      );
      _toFocus.requestFocus();
      return;
    }

    if (from != null && to != null && from.isAfter(to)) {
      showAppNotification(
        context: context,
        message: "From date cannot be after To date.",
        type: NotificationType.error,
      );
      _fromFocus.requestFocus();
      return;
    }

    setState(() {
      _filterDeliveries();
    });
  }

  void _filterDeliveries() {
    final fromParsed = _tryParseDate(_fromCtrl.text);
    final toParsed = _tryParseDate(_toCtrl.text);

    // Inclusive range on both ends; null = unbounded
    final DateTime? from = fromParsed == null
        ? null
        : DateTime(fromParsed.year, fromParsed.month, fromParsed.day);

    final DateTime? to = toParsed == null
        ? null
        : DateTime(toParsed.year, toParsed.month, toParsed.day, 23, 59, 59);

    _filteredDeliveries = _allDeliveries.where((delivery) {
      final d = delivery.deliveryDate.toDate();
      final lowerOk =
          from == null || d.isAfter(from.subtract(const Duration(seconds: 1)));
      final upperOk =
          to == null || d.isBefore(to.add(const Duration(seconds: 1)));
      return lowerOk && upperOk;
    }).toList();

    _filteredDeliveries.sort(
      (a, b) => b.deliveryDate.compareTo(a.deliveryDate),
    );
  }

  Future<void> _confirmDelete(Delivery delivery) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text(
          'Are you sure you want to delete this delivery entry? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final receipt = _allReceipts.firstWhere(
          (r) =>
              r.coldStorageName == delivery.coldStorageName &&
              r.receiptNumber == delivery.receiptNumber,
        );

        final newRemaining = receipt.remainingQuantity + delivery.quantity;
        await _firestoreService.updateReceipt(receipt.id!, {
          'remainingQuantity': newRemaining,
        });

        await _firestoreService.deleteDelivery(delivery.id!);

        showAppNotification(
          context: context,
          message: "Delivery deleted successfully",
          type: NotificationType.error,
        );
        _fetchDataAndFilter();
      } catch (e) {
        if (mounted) {
          showAppNotification(
            context: context,
            message: "Error deleting delivery: $e",
            type: NotificationType.error,
          );
        }
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    // Prefill initial date from the typed value when valid, else today
    DateTime initial = DateTime.now();
    final currentText = isFromDate ? _fromCtrl.text : _toCtrl.text;
    final parsed = _tryParseDate(currentText);
    if (parsed != null) initial = parsed;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      final formatted = _dateFmt.format(picked);
      if (isFromDate) {
        _fromCtrl.text = formatted;
        _toFocus.requestFocus(); // move to To date after picking From
      } else {
        _toCtrl.text = formatted;
      }
      _applyDateFilter();
    }
  }

  Future<Uint8List> _generatePdfLayout(PdfPageFormat format) async {
    final doc = pw.Document();

    // Header + range info
    final title = 'Delivery History';
    final rangeText =
        'From: '
        '${_fromCtrl.text.isEmpty ? '—' : _fromCtrl.text}   '
        'To: ${_toCtrl.text.isEmpty ? '—' : _toCtrl.text}';

    // Build table rows
    final rows = _filteredDeliveries.map((d) {
      final receipt = _allReceipts.firstWhere(
        (r) =>
            r.coldStorageName == d.coldStorageName &&
            r.receiptNumber == d.receiptNumber,
        orElse: () => Receipt(
          receiptNumber: '',
          coldStorageName: '',
          inwardDate: Timestamp.now(),
          productName: '-',
          brandName: '-',
          inwardQuantity: 0,
          remainingQuantity: 0,
          rate: 0,
          narration: '',
        ),
      );
      return [
        _dateFmt.format(d.deliveryDate.toDate()),
        '${d.coldStorageName} : #${d.receiptNumber}',
        '${receipt.productName} - ${receipt.brandName}',
        d.quantity.toString(),
        d.narration,
      ];
    }).toList();

    final totalQty = _filteredDeliveries.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(DateFormat('dd-MM-yy HH:mm').format(DateTime.now())),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(rangeText),
          pw.SizedBox(height: 10),
          if (rows.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 24),
              child: pw.Text('No deliveries in this range.'),
            )
          else
            pw.Table.fromTextArray(
              headers: const [
                'Date',
                'Cold Storage : Receipt #',
                'Product - Brand',
                'Qty',
                'Narration',
              ],
              data: rows,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerLeft,
              },
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(2.4),
                2: const pw.FlexColumnWidth(2.2),
                3: const pw.FlexColumnWidth(0.8),
                4: const pw.FlexColumnWidth(2.0),
              },
            ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                'Total Qty: ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                '$totalQty',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> _exportToPdf() async {
    if (_filteredDeliveries.isEmpty) {
      showAppNotification(
        context: context,
        message: "No data to export in the selected date range.",
        type: NotificationType.error,
      );
      return;
    }

    try {
      await Printing.layoutPdf(onLayout: _generatePdfLayout);
    } catch (e) {
      // Fallback: share the PDF if preview can't open (e.g., web popup blockers)
      try {
        final bytes = await _generatePdfLayout(PdfPageFormat.a4);
        await Printing.sharePdf(
          bytes: bytes,
          filename:
              'delivery_history_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
      } catch (e2) {
        showAppNotification(
          context: context,
          message: 'PDF export failed: $e2',
          type: NotificationType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalQty = _filteredDeliveries.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Delivery History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _buildDateFilterRow(),
                  ),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _filteredDeliveries.isEmpty
                        ? _buildEmptyState()
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth > 800;

                              return Column(
                                children: [
                                  if (isWide) _buildHeaderRow(),
                                  Expanded(
                                    child: ListView.builder(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      itemCount: _filteredDeliveries.length,
                                      itemBuilder: (context, index) {
                                        final delivery =
                                            _filteredDeliveries[index];
                                        return _buildDeliveryListItem(
                                          delivery,
                                          isWide,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                  if (!_isLoading && _filteredDeliveries.isNotEmpty)
                    _buildSummaryFooter(totalQty),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    final headerStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text('Date', style: headerStyle)),
              Expanded(
                flex: 4,
                child: Text('Cold Storage : Receipt #', style: headerStyle),
              ),
              Expanded(
                flex: 4,
                child: Text('Product - Brand', style: headerStyle),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Qty',
                  style: headerStyle,
                  textAlign: TextAlign.end,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Narration',
                  style: headerStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  'Actions',
                  style: headerStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilterRow() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        child: Row(
          children: [
            Expanded(
              child: _dateField(
                label: 'From (dd-MM-yy)',
                controller: _fromCtrl,
                focusNode: _fromFocus,
                onSubmittedEnter: () => _toFocus.requestFocus(),
                onTapCalendar: () => _selectDate(context, true),
                isFinal: false,
                suffixFocusNode: _fromCalFocus,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _dateField(
                label: 'To (dd-MM-yy)',
                controller: _toCtrl,
                focusNode: _toFocus,
                onSubmittedEnter: () {
                  // Clear focus so Enter doesn't activate any trailing widgets
                  FocusManager.instance.primaryFocus?.unfocus();
                  _applyDateFilter();
                },
                onTapCalendar: () => _selectDate(context, false),
                isFinal: true, // DONE action on To field
                suffixFocusNode: _toCalFocus,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _applyDateFilter,
              icon: const Icon(Icons.search),
              label: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required VoidCallback onSubmittedEnter,
    required VoidCallback onTapCalendar,
    required bool isFinal,
    FocusNode? suffixFocusNode,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.datetime,
      textInputAction: isFinal ? TextInputAction.done : TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'dd-MM-yy',
        suffixIcon: Focus(
          focusNode: suffixFocusNode,
          canRequestFocus: false,
          skipTraversal: true,
          child: IconButton(
            tooltip: 'Pick date',
            icon: const Icon(Icons.calendar_month),
            onPressed: onTapCalendar,
          ),
        ),
      ),
      inputFormatters: [
        // allow numbers and separators
        FilteringTextInputFormatter.allow(RegExp(r'[0-9/\-]')),
      ],
      onFieldSubmitted: (_) => onSubmittedEnter(),
      onEditingComplete: () {
        // Ensure IME "done" also applies filter for final field
        if (isFinal) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      onChanged: (_) {
        // Live apply when both fields are valid (or empty)
        final fromValid =
            _fromCtrl.text.isEmpty || _tryParseDate(_fromCtrl.text) != null;
        final toValid =
            _toCtrl.text.isEmpty || _tryParseDate(_toCtrl.text) != null;
        if (fromValid && toValid) {
          _filterDeliveries();
          setState(() {});
        }
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Deliveries Found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'No deliveries match the selected date range.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryListItem(Delivery delivery, bool isWide) {
    final receipt = _allReceipts.firstWhere(
      (r) =>
          r.coldStorageName == delivery.coldStorageName &&
          r.receiptNumber == delivery.receiptNumber,
      orElse: () => Receipt(
        receiptNumber: '',
        coldStorageName: '',
        inwardDate: Timestamp.now(),
        productName: '-',
        brandName: '-',
        inwardQuantity: 0,
        remainingQuantity: 0,
        rate: 0,
        narration: '',
      ),
    );

    return isWide
        ? _buildWideLayout(delivery, receipt)
        : _buildNarrowLayout(delivery, receipt);
  }

  Widget _buildNarrowLayout(Delivery delivery, Receipt receipt) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final result = await Navigator.pushNamed(
            context,
            AppRouter.deliveryEntry,
            arguments: delivery,
          );
          if (result == true) {
            showAppNotification(
              context: context,
              message: "Delivery updated successfully",
              type: NotificationType.info,
            );
            _fetchDataAndFilter();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "${delivery.coldStorageName.toUpperCase()} : ${delivery.receiptNumber}",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    DateFormat(
                      'dd-MM-yy',
                    ).format(delivery.deliveryDate.toDate()),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "${receipt.productName.toUpperCase()} - ${receipt.brandName.toUpperCase()}",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (delivery.narration.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    delivery.narration,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Quantity: ${delivery.quantity}",
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit Delivery',
                        onPressed: () async {
                          final result = await Navigator.pushNamed(
                            context,
                            AppRouter.deliveryEntry,
                            arguments: delivery,
                          );
                          if (result == true) {
                            showAppNotification(
                              context: context,
                              message: "Delivery updated successfully",
                              type: NotificationType.info,
                            );
                            _fetchDataAndFilter();
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        tooltip: 'Delete Delivery',
                        onPressed: () => _confirmDelete(delivery),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(Delivery delivery, Receipt receipt) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.pushNamed(
            context,
            AppRouter.deliveryEntry,
            arguments: delivery,
          );
          if (result == true) {
            showAppNotification(
              context: context,
              message: "Delivery updated successfully",
              type: NotificationType.info,
            );
            _fetchDataAndFilter();
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  DateFormat('dd-MM-yy').format(delivery.deliveryDate.toDate()),
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  "${delivery.coldStorageName.toUpperCase()} : ${delivery.receiptNumber}",
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  "${receipt.productName.toUpperCase()} - ${receipt.brandName.toUpperCase()}",
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  delivery.quantity.toString(),
                  textAlign: TextAlign.end,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  delivery.narration,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                width: 80,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Edit Delivery',
                      onPressed: () async {
                        final result = await Navigator.pushNamed(
                          context,
                          AppRouter.deliveryEntry,
                          arguments: delivery,
                        );
                        if (result == true) {
                          showAppNotification(
                            context: context,
                            message: "Delivery updated successfully",
                            type: NotificationType.info,
                          );
                          _fetchDataAndFilter();
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      tooltip: 'Delete Delivery',
                      onPressed: () => _confirmDelete(delivery),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryFooter(int totalQty) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Total Qty: $totalQty",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text("EXPORT"),
              onPressed: _exportToPdf,
            ),
          ],
        ),
      ),
    );
  }
}
