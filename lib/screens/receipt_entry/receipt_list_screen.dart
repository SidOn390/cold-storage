// lib/screens/receipt_entry/receipt_list_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:business_management_app/models/receipt_model.dart';
import 'package:business_management_app/services/firestore_service.dart';
import 'package:business_management_app/app_router.dart';

class ReceiptListScreen extends StatefulWidget {
  const ReceiptListScreen({super.key});

  @override
  State<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedProductForBreakdown;
  bool _isStockSummaryExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return "";
    return "${text[0].toUpperCase()}${text.substring(1).toLowerCase()}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipts'), centerTitle: false),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
            child: _buildSearchBar(),
          ),
          Expanded(
            child: StreamBuilder<List<Receipt>>(
              stream: _firestoreService.getReceipts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                final allReceipts = snapshot.data!;
                final filteredReceipts = _filterReceipts(allReceipts);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                  children: [
                    _buildSummaryRow(allReceipts),
                    const SizedBox(height: 16),
                    _buildStockBreakdownCard(allReceipts),
                    const SizedBox(height: 20),
                    _buildReceiptsHeader(filteredReceipts.length),
                    const SizedBox(height: 8),
                    if (filteredReceipts.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text('No matching receipts found.'),
                        ),
                      )
                    else
                      ...filteredReceipts
                          .map((receipt) => _buildReceiptCard(receipt))
                          .toList(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, AppRouter.receiptEntry),
        child: const Icon(Icons.add),
        tooltip: 'New Receipt',
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by Receipt #, Storage, Product...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _searchController.clear(),
              )
            : null,
      ),
    );
  }

  Widget _buildSummaryRow(List<Receipt> receipts) {
    int totalReceipts = receipts.length;
    int remainingStock = receipts.fold(
      0,
      (sum, item) => sum + item.remainingQuantity,
    );
    int paidCount = receipts.where((r) => r.isPaid).length;
    int unpaidCount = totalReceipts - paidCount;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard('Total Receipts', totalReceipts.toString()),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Remaining Stock',
            remainingStock.toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildSummaryCard('Paid', paidCount.toString())),
        const SizedBox(width: 12),
        Expanded(child: _buildSummaryCard('Unpaid', unpaidCount.toString())),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockBreakdownCard(List<Receipt> receipts) {
    final productSummary = <String, int>{};
    for (var receipt in receipts) {
      productSummary.update(
        receipt.productName,
        (value) => value + receipt.remainingQuantity,
        ifAbsent: () => receipt.remainingQuantity,
      );
    }

    final brandSummary = <String, int>{};
    if (_selectedProductForBreakdown != null) {
      final productReceipts = receipts.where(
        (r) => r.productName == _selectedProductForBreakdown,
      );
      for (var receipt in productReceipts) {
        brandSummary.update(
          receipt.brandName,
          (value) => value + receipt.remainingQuantity,
          ifAbsent: () => receipt.remainingQuantity,
        );
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey('stock-summary-tile'),
        initiallyExpanded: _isStockSummaryExpanded,
        onExpansionChanged: (bool expanded) {
          setState(() {
            _isStockSummaryExpanded = expanded;
            if (!expanded) {
              _selectedProductForBreakdown = null;
            }
          });
        },
        title: Text(
          'Stock by Product Summary',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _selectedProductForBreakdown == null
                  ? _buildSummaryListView(
                      key: const ValueKey('products'),
                      summaryMap: productSummary,
                      onTap: (productName) {
                        setState(() {
                          _isStockSummaryExpanded = true;
                          _selectedProductForBreakdown = productName;
                        });
                      },
                    )
                  : _buildSummaryListView(
                      key: const ValueKey('brands'),
                      title: 'Breakdown for "$_selectedProductForBreakdown"',
                      summaryMap: brandSummary,
                      onBack: () {
                        setState(() {
                          _selectedProductForBreakdown = null;
                        });
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryListView({
    Key? key,
    String? title,
    required Map<String, int> summaryMap,
    Function(String)? onTap,
    VoidCallback? onBack,
  }) {
    final sortedEntries = summaryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Row(
            children: [
              if (onBack != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: onBack,
                  padding: const EdgeInsets.only(right: 8),
                  constraints: const BoxConstraints(),
                ),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        if (title != null) const Divider(height: 20),
        if (sortedEntries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text("No stock available."),
          )
        else
          ...sortedEntries.map((entry) {
            return ListTile(
              title: Text(entry.key),
              trailing: Text(
                entry.value.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: onTap != null ? () => onTap(entry.key) : null,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
            );
          }).toList(),
      ],
    );
  }

  Widget _buildReceiptsHeader(int count) {
    return Text(
      "All Receipts ($count)",
      style: Theme.of(context).textTheme.titleLarge,
    );
  }

  Future<void> _confirmDelete(BuildContext context, Receipt receipt) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text(
          'Are you sure you want to delete Receipt #${receipt.receiptNumber}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestoreService.deleteReceipt(receipt.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt deleted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildReceiptCard(Receipt receipt) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontWeight: FontWeight.normal,
                      ),
                      children: [
                        TextSpan(
                          text:
                              '${_capitalizeFirstLetter(receipt.coldStorageName)} : ',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const TextSpan(text: 'Receipt : '),
                        TextSpan(
                          text: receipt.receiptNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(receipt.isPaid),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "${receipt.productName} - ${receipt.brandName}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Inward on: ${DateFormat('dd MMM, yyyy').format(receipt.inwardDate.toDate())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn(
                  'Inward Qty',
                  receipt.inwardQuantity.toString(),
                ),
                _buildInfoColumn('Rate', '₹${receipt.rate.toStringAsFixed(2)}'),
                _buildInfoColumn(
                  'Remaining',
                  receipt.remainingQuantity.toString(),
                  isEnd: true,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueGrey),
                  tooltip: 'Edit Receipt',
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRouter.receiptEntry,
                      arguments: receipt,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  tooltip: 'Delete Receipt',
                  onPressed: () => _confirmDelete(context, receipt),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, {bool isEnd = false}) {
    return Column(
      crossAxisAlignment: isEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStatusChip(bool isPaid) {
    return Chip(
      label: Text(isPaid ? 'Paid' : 'Unpaid'),
      backgroundColor: isPaid ? Colors.green.shade100 : Colors.orange.shade100,
      labelStyle: TextStyle(
        color: isPaid ? Colors.green.shade800 : Colors.orange.shade800,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide.none,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No Receipts Yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to add your first receipt.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  List<Receipt> _filterReceipts(List<Receipt> receipts) {
    if (_searchQuery.isEmpty) {
      return receipts;
    }
    return receipts.where((receipt) {
      final query = _searchQuery.toLowerCase();
      return receipt.receiptNumber.toLowerCase().contains(query) ||
          receipt.coldStorageName.toLowerCase().contains(query) ||
          receipt.productName.toLowerCase().contains(query) ||
          receipt.brandName.toLowerCase().contains(query);
    }).toList();
  }
}
