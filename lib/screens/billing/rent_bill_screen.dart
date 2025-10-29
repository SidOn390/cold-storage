// lib/screens/billing/rent_bill_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cold_storage/models/receipt_model.dart';
import 'package:cold_storage/models/rent_type.dart';
import 'package:cold_storage/models/rent_bill.dart';
import 'package:cold_storage/models/rent_bill_item.dart';
import 'package:cold_storage/services/firestore_service.dart';
import 'package:cold_storage/services/rent_bill_service.dart';
import 'package:cold_storage/services/rent_bill_pdf_service.dart';
import 'package:cold_storage/services/user_management_service.dart';
import 'package:cold_storage/utils/app_notifications.dart';
import 'package:cold_storage/widgets/app_background.dart';
import 'package:intl/intl.dart';

class RentBillScreen extends StatefulWidget {
  const RentBillScreen({super.key});

  @override
  State<RentBillScreen> createState() => _RentBillScreenState();
}

class _RentBillScreenState extends State<RentBillScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final RentBillService _billService = RentBillService.instance;
  final RentBillPdfService _pdfService = RentBillPdfService.instance;
  final UserManagementService _userService = UserManagementService();

  List<Receipt> _receipts = [];
  Receipt? _selectedReceipt;
  List<Map<String, dynamic>> _deliveries = [];
  RentBill? _previewBill;

  bool _isLoadingReceipts = true;
  bool _isLoadingDeliveries = false;
  bool _isGeneratingBill = false;
  bool _isSavingBill = false;

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    setState(() => _isLoadingReceipts = true);

    try {
      final receiptsStream = _firestoreService.getReceipts();
      final receiptsSnapshot = await receiptsStream.first;

      if (mounted) {
        setState(() {
          _receipts = receiptsSnapshot;
          _isLoadingReceipts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReceipts = false);
        showAppNotification(
          context: context,
          message: 'Error loading receipts: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _onReceiptSelected(Receipt receipt) async {
    setState(() {
      _selectedReceipt = receipt;
      _deliveries = [];
      _previewBill = null;
      _isLoadingDeliveries = true;
    });

    try {
      final deliveries = await _firestoreService.getDeliveriesForReceipt(
        receiptNumber: receipt.receiptNumber,
        coldStorageName: receipt.coldStorageName,
      );

      if (mounted) {
        setState(() {
          _deliveries = deliveries;
          _isLoadingDeliveries = false;
        });

        if (deliveries.isEmpty) {
          showAppNotification(
            context: context,
            message: 'No deliveries found for this receipt',
            type: NotificationType.info,
          );
        } else {
          // Auto-generate bill preview
          _generateBillPreview();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDeliveries = false);
        showAppNotification(
          context: context,
          message: 'Error loading deliveries: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _generateBillPreview() async {
    if (_selectedReceipt == null || _deliveries.isEmpty) return;

    setState(() => _isGeneratingBill = true);

    try {
      final currentUser = await _userService.getCurrentUser();

      final bill = await _billService.generateBillFromReceipt(
        receipt: _selectedReceipt!,
        deliveries: _deliveries,
        createdBy: currentUser?.displayName ?? 'System',
      );

      if (mounted) {
        setState(() {
          _previewBill = bill;
          _isGeneratingBill = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingBill = false);
        showAppNotification(
          context: context,
          message: 'Error generating bill: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _saveBill() async {
    if (_previewBill == null) return;

    setState(() => _isSavingBill = true);

    try {
      await _billService.saveBill(_previewBill!);

      if (mounted) {
        showAppNotification(
          context: context,
          message: 'Bill saved successfully!',
          type: NotificationType.success,
        );

        // Reset state
        setState(() {
          _selectedReceipt = null;
          _deliveries = [];
          _previewBill = null;
          _isSavingBill = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingBill = false);
        showAppNotification(
          context: context,
          message: 'Error saving bill: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  /// Export bill as PDF
  Future<void> _exportPdf() async {
    if (_previewBill == null) return;

    try {
      // Generate filename
      final filename = 'Rent_Bill_${_previewBill!.billNumber}_${DateFormat('ddMMyyyy').format(_previewBill!.billDate)}.pdf';

      // Generate and save PDF
      await _pdfService.savePdf(_previewBill!, filename);

      if (mounted) {
        showAppNotification(
          context: context,
          message: 'PDF exported successfully!',
          type: NotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppNotification(
          context: context,
          message: 'Error exporting PDF: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Rent Bill Generation'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AppBackground(
        child: SafeArea(
          child: _isLoadingReceipts
              ? const Center(child: CircularProgressIndicator())
              : _receipts.isEmpty
                  ? _buildEmptyState()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildReceiptSelector(),
                                  const SizedBox(height: 16),
                                  if (_selectedReceipt != null) ...[
                                    _buildReceiptInfo(),
                                    const SizedBox(height: 16),
                                  ],
                                  if (_isLoadingDeliveries)
                                    const Center(child: CircularProgressIndicator())
                                  else if (_deliveries.isNotEmpty) ...[
                                    SizedBox(
                                      height: constraints.maxHeight * 0.6,
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: _buildDeliveriesList(),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            flex: 3,
                                            child: _buildBillPreview(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Receipts Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create receipts to generate rent bills',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Text(
                'Select Receipt',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Receipt>(
            value: _selectedReceipt,
            decoration: InputDecoration(
              hintText: 'Choose a receipt to generate bill',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            items: _receipts.map((receipt) {
              return DropdownMenuItem(
                value: receipt,
                child: Text(
                  '${receipt.receiptNumber} - ${receipt.companyName} (${receipt.productName})',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (receipt) {
              if (receipt != null) {
                _onReceiptSelected(receipt);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptInfo() {
    final receipt = _selectedReceipt!;
    final rentType = RentType.fromJson(receipt.rentType);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: rentType == RentType.monthly
              ? [Colors.blue.shade50, Colors.blue.shade100]
              : [Colors.orange.shade50, Colors.orange.shade100],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rentType == RentType.monthly
              ? Colors.blue.shade300
              : Colors.orange.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                rentType == RentType.monthly
                    ? Icons.calendar_month
                    : Icons.wb_sunny,
                color: rentType == RentType.monthly
                    ? Colors.blue.shade700
                    : Colors.orange.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                'Receipt Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: rentType == RentType.monthly
                      ? Colors.blue.shade900
                      : Colors.orange.shade900,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow('Receipt No', receipt.receiptNumber),
          _buildInfoRow('Company', receipt.companyName),
          _buildInfoRow('Product', receipt.productName),
          _buildInfoRow('Cold Storage', receipt.coldStorageName),
          _buildInfoRow('Inward Qty', receipt.inwardQuantity.toString()),
          _buildInfoRow(
            'Inward Date',
            DateFormat('dd-MM-yyyy').format(receipt.inwardDate.toDate()),
          ),
          if (rentType == RentType.monthly) ...[
            const Divider(height: 24),
            _buildInfoRow(
              'Monthly Rate',
              '₹${receipt.monthlyRatePerUnit}/unit/month',
            ),
            _buildInfoRow(
              'Labour Rate',
              '₹${receipt.labourRatePerUnit}/unit',
            ),
          ] else ...[
            const Divider(height: 24),
            _buildInfoRow(
              'Seasonal Rate',
              '₹${receipt.seasonalRatePerUnit}/unit (fixed)',
            ),
          ],
          _buildInfoRow('GST', '${receipt.gstPercentage}%'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveriesList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.local_shipping, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(
                  'Deliveries (${_deliveries.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _deliveries.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final delivery = _deliveries[index];
                final deliveryDate = (delivery['deliveryDate'] as Timestamp).toDate();
                final quantity = delivery['quantity'];
                final deliveryId = delivery['id'] ?? '${index + 1}';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    'Delivery #$deliveryId',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Date: ${DateFormat('dd-MM-yyyy').format(deliveryDate)}\n'
                    'Qty: $quantity',
                  ),
                  isThreeLine: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillPreview() {
    if (_isGeneratingBill) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_previewBill == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.visibility_off, size: 60, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No Preview Available',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bill = _previewBill!;
    final rentType = bill.rentType;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: rentType == RentType.monthly
                    ? [Colors.blue.shade700, Colors.blue.shade900]
                    : [Colors.orange.shade700, Colors.orange.shade900],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Bill Preview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    rentType.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bill Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bill Details
                  _buildBillRow('Bill Number', bill.billNumber, bold: true),
                  _buildBillRow('Company', bill.companyName),
                  _buildBillRow(
                    'Bill Date',
                    DateFormat('dd-MM-yyyy').format(bill.billDate),
                  ),
                  const Divider(height: 24),

                  // Line Items
                  const Text(
                    'Deliveries',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...bill.items.map((item) => _buildLineItem(item)),
                  const Divider(height: 24),

                  // Calculations
                  if (rentType == RentType.monthly) ...[
                    _buildBillRow(
                      'Total Rent',
                      '₹${bill.totalRentAmount.toStringAsFixed(2)}',
                    ),
                    _buildBillRow(
                      'Labour Charges',
                      '₹${bill.labourCharges.toStringAsFixed(2)}',
                    ),
                    _buildBillRow(
                      'Subtotal',
                      '₹${bill.subtotalBeforeGst.toStringAsFixed(2)}',
                      bold: true,
                    ),
                  ] else ...[
                    _buildBillRow(
                      'Total Amount',
                      '₹${bill.subtotalBeforeGst.toStringAsFixed(2)}',
                      bold: true,
                    ),
                  ],
                  const Divider(height: 24),

                  // Tax
                  _buildBillRow(
                    'SGST (9%)',
                    '₹${bill.sgst.toStringAsFixed(2)}',
                  ),
                  _buildBillRow(
                    'CGST (9%)',
                    '₹${bill.cgst.toStringAsFixed(2)}',
                  ),
                  if (bill.roundOff != 0.0)
                    _buildBillRow(
                      'Round-off',
                      '${bill.roundOff >= 0 ? '+' : ''}₹${bill.roundOff.toStringAsFixed(2)}',
                    ),
                  const Divider(height: 24),

                  // Final Amount
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: rentType == RentType.monthly
                          ? Colors.blue.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Final Amount',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: rentType == RentType.monthly
                                ? Colors.blue.shade900
                                : Colors.orange.shade900,
                          ),
                        ),
                        Text(
                          '₹${bill.finalAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: rentType == RentType.monthly
                                ? Colors.blue.shade900
                                : Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _previewBill == null ? null : _exportPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export PDF'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSavingBill ? null : _saveBill,
                    icon: _isSavingBill
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSavingBill ? 'Saving...' : 'Save Bill'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItem(RentBillItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DC: ${item.dcNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Qty: ${item.quantity}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Outward: ${DateFormat('dd-MM-yyyy').format(item.outwardDate)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          if (item.months > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Days: ${item.daysStored} → ${item.months} months',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amount:',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
              Text(
                '₹${item.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
