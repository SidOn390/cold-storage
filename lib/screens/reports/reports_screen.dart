import 'dart:async';
import 'dart:math' as math;

import 'package:cold_storage/models/receipt_model.dart';
import 'package:cold_storage/services/firestore_service.dart';
import 'package:cold_storage/utils/app_notifications.dart';
import 'package:cold_storage/widgets/app_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  // NEW: Use a ValueNotifier to share rate overrides without rebuilding parent
  final ValueNotifier<Map<String, double>> _rateOverrides = ValueNotifier({});

  static const int _productFlex = 4;
  static const int _quantityFlex = 2;
  static const int _weightFlex = 3;
  static const int _rateFlex = 3;
  static const int _amountFlex = 3;

  StreamSubscription<List<Map<String, dynamic>>>? _productsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _companiesSub;

  Map<String, double> _productWeights = {};
  List<String> _companies = [];
  String? _selectedCompany;

  @override
  void initState() {
    super.initState();
    _productsSub = _firestoreService.getProducts().listen((products) {
      if (!mounted) return;
      setState(() {
        _productWeights = {
          for (final product in products)
            (product['name'] as String):
                (product['weight'] as num?)?.toDouble() ?? 0.0,
        };
      });
    });
    _companiesSub = _firestoreService.getCompanies().listen((companySnapshots) {
      if (!mounted) return;
      setState(() {
        _companies = companySnapshots
            .map((company) => company['name'] as String? ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
      });
    });
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    _companiesSub?.cancel();
    _rateOverrides.dispose();
    super.dispose();
  }

  String _formatNumber(num value, {int decimalDigits = 2}) {
    final formatter = NumberFormat.decimalPattern()
      ..minimumFractionDigits = decimalDigits
      ..maximumFractionDigits = decimalDigits;
    return formatter.format(value);
  }

  String _formatRate(double value) => value.toStringAsFixed(2);

  Future<void> _exportReport({
    required List<_ProductValuationRow> rows,
    required int totalQuantity,
    required double totalWeight,
    required double totalAmount,
  }) async {
    if (rows.isEmpty) {
      showAppNotification(
        context: context,
        message: 'No data available to export.',
        type: NotificationType.error,
      );
      return;
    }

    final doc = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(now);
    final companyLabel = _selectedCompany == null
        ? 'All Companies'
        : _selectedCompany!;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return [
            pw.Text(
              'Stock Valuation Report',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Company: $companyLabel'),
            pw.Text('Generated: $dateStr'),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: const [
                'Product',
                'Total Qty',
                'Total Weight (kg)',
                'Rate (₹)',
                'Amount (₹)',
              ],
              data: rows
                  .map(
                    (row) => [
                      row.productName,
                      row.totalQuantity.toString(),
                      _formatNumber(row.totalWeight),
                      _formatRate(row.effectiveRate),
                      _formatNumber(row.totalAmount),
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerRight,
              cellAlignments: {0: pw.Alignment.centerLeft},
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Grand Total Quantity: $totalQuantity',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Grand Total Weight: ${_formatNumber(totalWeight)} kg',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Grand Total Amount: ₹${_formatNumber(totalAmount)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    try {
      await Printing.layoutPdf(onLayout: (format) => doc.save());
    } catch (e) {
      try {
        final bytes = await doc.save();
        await Printing.sharePdf(
          bytes: bytes,
          filename:
              'stock_valuation_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
      } catch (err) {
        if (!mounted) return;
        showAppNotification(
          context: context,
          message: 'PDF export failed: $err',
          type: NotificationType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final companies = [..._companies]
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFilters(companies),
                    const SizedBox(height: 16),
                    Expanded(
                      child: StreamBuilder<List<Receipt>>(
                        stream: _firestoreService.getReceipts(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          }

                          final receipts = snapshot.data ?? [];
                          final rows = _buildValuationRows(receipts);

                          if (rows.isEmpty) {
                            return _buildEmptyState();
                          }

                          return ValueListenableBuilder<Map<String, double>>(
                            valueListenable: _rateOverrides,
                            builder: (context, overrides, _) {
                              final rowsWithOverrides = rows.map((row) {
                                final effectiveRate =
                                    overrides[row.productName] ??
                                    row.averageRate;
                                return _ProductValuationRow(
                                  productName: row.productName,
                                  totalQuantity: row.totalQuantity,
                                  averageRate: row.averageRate,
                                  unitWeight: row.unitWeight,
                                  effectiveRate: effectiveRate,
                                  totalWeight: row.totalWeight,
                                  totalAmount: row.totalWeight * effectiveRate,
                                );
                              }).toList();

                              final totals = _calculateTotals(
                                rowsWithOverrides,
                              );

                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  final isCompact = constraints.maxWidth < 720;
                                  final reportView = isCompact
                                      ? _buildCompactList(
                                          context,
                                          rowsWithOverrides,
                                          totals,
                                        )
                                      : _buildDataTableView(
                                          context,
                                          rowsWithOverrides,
                                          totals,
                                          constraints.maxWidth,
                                        );
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _exportReport(
                                            rows: rowsWithOverrides,
                                            totalQuantity: totals.totalQuantity,
                                            totalWeight: totals.totalWeight,
                                            totalAmount: totals.totalAmount,
                                          ),
                                          icon: const Icon(
                                            Icons.picture_as_pdf,
                                          ),
                                          label: const Text('Export'),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Expanded(child: reportView),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(List<String> companies) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stock Valuation Report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _selectedCompany,
              decoration: const InputDecoration(
                labelText: 'Company',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Companies'),
                ),
                ...companies.map(
                  (company) => DropdownMenuItem<String?>(
                    value: company,
                    child: Text(company),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCompany = value;
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Adjust the rate in the table to preview different valuations. '
              'Changes made here are for reporting only and are not saved.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTableView(
    BuildContext context,
    List<_ProductValuationRow> rows,
    _ValuationTotals totals,
    double availableWidth,
  ) {
    final minTableWidth = math.max(availableWidth, 900.0);
    final columnWidths = <int, TableColumnWidth>{
      0: FlexColumnWidth(_productFlex.toDouble()),
      1: FlexColumnWidth(_quantityFlex.toDouble()),
      2: FlexColumnWidth(_weightFlex.toDouble()),
      3: FlexColumnWidth(_rateFlex.toDouble()),
      4: FlexColumnWidth(_amountFlex.toDouble()),
    };
    final headerStyle =
        Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600) ??
        const TextStyle(fontWeight: FontWeight.w600);
    final rowStyle = Theme.of(context).textTheme.bodyMedium;
    final totalStyle =
        Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold) ??
        const TextStyle(fontWeight: FontWeight.bold);
    final cellPadding = const EdgeInsets.symmetric(
      vertical: 12.0,
      horizontal: 12.0,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minTableWidth),
                child: Table(
                  columnWidths: columnWidths,
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                      children: [
                        _buildTableHeaderCell(
                          text: 'Product',
                          alignment: Alignment.centerLeft,
                          style: headerStyle,
                          padding: cellPadding,
                        ),
                        _buildTableHeaderCell(
                          text: 'Total Qty',
                          style: headerStyle,
                          padding: cellPadding,
                        ),
                        _buildTableHeaderCell(
                          text: 'Total Weight (kg)',
                          style: headerStyle,
                          padding: cellPadding,
                        ),
                        _buildTableHeaderCell(
                          text: 'Rate (₹)',
                          style: headerStyle,
                          padding: cellPadding,
                        ),
                        _buildTableHeaderCell(
                          text: 'Amount (₹)',
                          style: headerStyle,
                          padding: cellPadding,
                        ),
                      ],
                    ),
                    ...rows.map(
                      (row) => TableRow(
                        key: ValueKey('row-${row.productName}'),
                        children: [
                          _buildTableBodyCell(
                            child: Text(row.productName, style: rowStyle),
                            alignment: Alignment.centerLeft,
                            padding: cellPadding,
                          ),
                          _buildTableBodyCell(
                            child: Text(
                              row.totalQuantity.toString(),
                              style: rowStyle,
                            ),
                            padding: cellPadding,
                          ),
                          _buildTableBodyCell(
                            child: Text(
                              _formatNumber(row.totalWeight),
                              style: rowStyle,
                            ),
                            padding: cellPadding,
                          ),
                          _buildTableBodyCell(
                            child: SizedBox(
                              width: 140,
                              child: _RateEditor(
                                key: ValueKey('rate-${row.productName}'),
                                productName: row.productName,
                                averageRate: row.averageRate,
                                rateOverrides: _rateOverrides,
                              ),
                            ),
                            padding: cellPadding,
                          ),
                          _buildTableBodyCell(
                            child: Text(
                              '₹${_formatNumber(row.totalAmount)}',
                              style: rowStyle,
                            ),
                            padding: cellPadding,
                          ),
                        ],
                      ),
                    ),
                    TableRow(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                      ),
                      children: [
                        _buildTableBodyCell(
                          child: Text('Grand Total', style: totalStyle),
                          alignment: Alignment.centerLeft,
                          padding: cellPadding,
                        ),
                        _buildTableBodyCell(
                          child: Text(
                            totals.totalQuantity.toString(),
                            style: totalStyle,
                          ),
                          padding: cellPadding,
                        ),
                        _buildTableBodyCell(
                          child: Text(
                            _formatNumber(totals.totalWeight),
                            style: totalStyle,
                          ),
                          padding: cellPadding,
                        ),
                        _buildTableBodyCell(
                          child: const SizedBox.shrink(),
                          padding: cellPadding,
                        ),
                        _buildTableBodyCell(
                          child: Text(
                            '₹${_formatNumber(totals.totalAmount)}',
                            style: totalStyle,
                          ),
                          padding: cellPadding,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TableCell _buildTableHeaderCell({
    required String text,
    Alignment alignment = Alignment.centerRight,
    required TextStyle style,
    required EdgeInsets padding,
  }) {
    return TableCell(
      child: Padding(
        padding: padding,
        child: Align(
          alignment: alignment,
          child: Text(text, style: style),
        ),
      ),
    );
  }

  TableCell _buildTableBodyCell({
    required Widget child,
    Alignment alignment = Alignment.centerRight,
    required EdgeInsets padding,
  }) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: padding,
        child: Align(alignment: alignment, child: child),
      ),
    );
  }

  Widget _buildCompactList(
    BuildContext context,
    List<_ProductValuationRow> rows,
    _ValuationTotals totals,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: rows.length + 1,
      separatorBuilder: (context, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == rows.length) {
          return _buildTotalsSummaryCard(context, totals);
        }
        final row = rows[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.productName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _buildMetricTile(
                      context,
                      'Total Qty',
                      row.totalQuantity.toString(),
                    ),
                    _buildMetricTile(
                      context,
                      'Total Weight (kg)',
                      _formatNumber(row.totalWeight),
                    ),
                    _buildMetricTile(
                      context,
                      'Amount (₹)',
                      _formatNumber(row.totalAmount),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate (₹)',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 200,
                      child: _RateEditor(
                        key: ValueKey('rate-compact-${row.productName}'),
                        productName: row.productName,
                        averageRate: row.averageRate,
                        rateOverrides: _rateOverrides,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Amount: ₹${_formatNumber(row.totalAmount)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricTile(BuildContext context, String label, String value) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).hintColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSummaryCard(
    BuildContext context,
    _ValuationTotals totals,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grand Totals',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _buildMetricTile(
                  context,
                  'Total Qty',
                  totals.totalQuantity.toString(),
                ),
                _buildMetricTile(
                  context,
                  'Total Weight (kg)',
                  _formatNumber(totals.totalWeight),
                ),
                _buildMetricTile(
                  context,
                  'Amount (₹)',
                  _formatNumber(totals.totalAmount),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('No stock valuation data available.'),
        ],
      ),
    );
  }

  List<_ProductValuationRow> _buildValuationRows(List<Receipt> receipts) {
    final filtered = receipts.where((receipt) {
      if (receipt.remainingQuantity <= 0) return false;
      if (receipt.status.toLowerCase() == 'cancelled') return false;
      if (_selectedCompany == null) return true;
      return receipt.companyName == _selectedCompany;
    });

    final Map<String, _ValuationAccumulator> grouped = {};
    for (final receipt in filtered) {
      final acc = grouped.putIfAbsent(
        receipt.productName,
        () => _ValuationAccumulator(),
      );
      acc.totalQuantity += receipt.remainingQuantity;
      acc.weightedRate += receipt.rate * receipt.remainingQuantity;
    }

    final rows = grouped.entries
        .map((entry) {
          final product = entry.key;
          final data = entry.value;
          final totalQty = data.totalQuantity;
          if (totalQty <= 0) return null;

          final averageRate = data.weightedRate / totalQty;
          final unitWeight = _productWeights[product] ?? 0.0;
          final totalWeight = unitWeight * totalQty;

          return _ProductValuationRow(
            productName: product,
            totalQuantity: totalQty,
            averageRate: averageRate,
            unitWeight: unitWeight,
            effectiveRate: averageRate,
            totalWeight: totalWeight,
            totalAmount: totalWeight * averageRate,
          );
        })
        .whereType<_ProductValuationRow>()
        .toList();

    rows.sort((a, b) => a.productName.compareTo(b.productName));
    return rows;
  }

  _ValuationTotals _calculateTotals(List<_ProductValuationRow> rows) {
    int totalQuantity = 0;
    double totalWeight = 0;
    double totalAmount = 0;

    for (final row in rows) {
      totalQuantity += row.totalQuantity;
      totalWeight += row.totalWeight;
      totalAmount += row.totalAmount;
    }

    return _ValuationTotals(
      totalQuantity: totalQuantity,
      totalWeight: totalWeight,
      totalAmount: totalAmount,
    );
  }
}

// NEW: Isolated stateful widget for each rate editor
class _RateEditor extends StatefulWidget {
  final String productName;
  final double averageRate;
  final ValueNotifier<Map<String, double>> rateOverrides;

  const _RateEditor({
    super.key,
    required this.productName,
    required this.averageRate,
    required this.rateOverrides,
  });

  @override
  State<_RateEditor> createState() => _RateEditorState();
}

class _RateEditorState extends State<_RateEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    final override = widget.rateOverrides.value[widget.productName];
    _controller = TextEditingController(
      text: (override ?? widget.averageRate).toStringAsFixed(2),
    );
  }

  @override
  void didUpdateWidget(_RateEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update if not focused and average rate changed
    if (!_focusNode.hasFocus &&
        oldWidget.averageRate != widget.averageRate &&
        !widget.rateOverrides.value.containsKey(widget.productName)) {
      _controller.text = widget.averageRate.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final trimmed = value.trim();

    // Allow partial input during typing
    if (trimmed.isEmpty) {
      final overrides = Map<String, double>.from(widget.rateOverrides.value);
      overrides.remove(widget.productName);
      widget.rateOverrides.value = overrides;
      return;
    }

    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      // Invalid number - don't update overrides yet (user might be typing)
      return;
    }

    // Check if different from average
    final isDifferent = (parsed - widget.averageRate).abs() > 0.0001;
    final overrides = Map<String, double>.from(widget.rateOverrides.value);

    if (isDifferent) {
      overrides[widget.productName] = parsed;
    } else {
      overrides.remove(widget.productName);
    }

    widget.rateOverrides.value = overrides;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      focusNode: _focusNode,
      controller: _controller,
      textAlign: TextAlign.right,
      textInputAction: TextInputAction.next,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      onChanged: _onChanged,
      onTap: () {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      },
    );
  }
}

class _ValuationAccumulator {
  int totalQuantity = 0;
  double weightedRate = 0;
}

class _ProductValuationRow {
  final String productName;
  final int totalQuantity;
  final double averageRate;
  final double unitWeight;
  final double effectiveRate;
  final double totalWeight;
  final double totalAmount;

  _ProductValuationRow({
    required this.productName,
    required this.totalQuantity,
    required this.averageRate,
    required this.unitWeight,
    required this.effectiveRate,
    required this.totalWeight,
    required this.totalAmount,
  });
}

class _ValuationTotals {
  final int totalQuantity;
  final double totalWeight;
  final double totalAmount;

  _ValuationTotals({
    required this.totalQuantity,
    required this.totalWeight,
    required this.totalAmount,
  });
}
