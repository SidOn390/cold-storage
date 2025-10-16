// lib/screens/delivery/delivery_entry_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cold_storage/models/delivery_model.dart';
import 'package:cold_storage/models/receipt_model.dart';
import 'package:cold_storage/services/firestore_service.dart';
import 'package:cold_storage/utils/app_notifications.dart';
import 'package:cold_storage/widgets/app_background.dart';

class DeliveryEntryScreen extends StatefulWidget {
  final Delivery? delivery;
  const DeliveryEntryScreen({super.key, this.delivery});

  @override
  State<DeliveryEntryScreen> createState() => _DeliveryEntryScreenState();
}

class _DeliveryEntryScreenState extends State<DeliveryEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();

  final _coldStorageController = TextEditingController();
  final _receiptController = TextEditingController();
  final _quantityController = TextEditingController();
  final _narrationController = TextEditingController();
  final _dateController = TextEditingController();
  final _productController = TextEditingController();
  final _brandController = TextEditingController();

  final _coldStorageFocusNode = FocusNode();
  final _receiptFocusNode = FocusNode();
  final _dateFocusNode = FocusNode();
  final _quantityFocusNode = FocusNode();
  final _narrationFocusNode = FocusNode();
  final _saveButtonFocusNode = FocusNode();

  DateTime _selectedDate = DateTime.now();
  String? _selectedColdStorage;

  List<Receipt> _allReceipts = [];
  List<String> _coldStorageOptions = [];
  List<String> _receiptOptions = [];

  bool _isLoading = true;
  bool _isSaving = false;

  bool get _isEditMode => widget.delivery != null;

  Receipt? get _selectedReceipt {
    final cold = (_selectedColdStorage ?? '').trim().toLowerCase();
    final rec = _receiptController.text.trim().toLowerCase();
    if (cold.isEmpty || rec.isEmpty) return null;
    try {
      return _allReceipts.firstWhere(
        (r) =>
            r.coldStorageName.trim().toLowerCase() == cold &&
            r.receiptNumber.trim().toLowerCase() == rec,
      );
    } catch (_) {
      return null;
    }
  }

  int? get _remainingStock {
    if (_selectedReceipt == null) return null;
    final int currentlyRemaining = _selectedReceipt!.remainingQuantity;
    if (_isEditMode &&
        _selectedReceipt!.receiptNumber == widget.delivery!.receiptNumber &&
        _selectedReceipt!.coldStorageName == widget.delivery!.coldStorageName) {
      return currentlyRemaining + widget.delivery!.quantity;
    }
    return currentlyRemaining;
  }

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _coldStorageController.addListener(_syncReceiptOptionsWithCold);
  }

  @override
  void dispose() {
    _coldStorageController.removeListener(_syncReceiptOptionsWithCold);
    _coldStorageController.dispose();
    _receiptController.dispose();
    _quantityController.dispose();
    _narrationController.dispose();
    _dateController.dispose();
    _productController.dispose();
    _brandController.dispose();
    _coldStorageFocusNode.dispose();
    _receiptFocusNode.dispose();
    _dateFocusNode.dispose();
    _quantityFocusNode.dispose();
    _narrationFocusNode.dispose();
    _saveButtonFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    try {
      _allReceipts = await _firestoreService.getReceipts().first;

      final storageNames =
          _allReceipts.map((r) => r.coldStorageName.trim()).toSet().toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (mounted) {
        setState(() {
          _coldStorageOptions = storageNames;
          _isLoading = false;
        });

        if (_isEditMode) {
          _populateFieldsForEdit();
        } else {
          _dateController.text = DateFormat('dd-MM-yy').format(_selectedDate);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showAppNotification(
          context: context,
          message: 'Error fetching data: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  void _populateFieldsForEdit() {
    final delivery = widget.delivery!;
    _coldStorageController.text = delivery.coldStorageName;
    _receiptController.text = delivery.receiptNumber;
    _quantityController.text = delivery.quantity.toString();
    _narrationController.text = delivery.narration;
    _selectedDate = delivery.deliveryDate.toDate();
    _dateController.text = DateFormat('dd-MM-yy').format(_selectedDate);

    _syncReceiptOptionsWithCold();
    if (_selectedReceipt != null) {
      _productController.text = _selectedReceipt!.productName;
      _brandController.text = _selectedReceipt!.brandName;
    }
  }

  void _syncReceiptOptionsWithCold() {
    if (!mounted) return;
    final coldText = _coldStorageController.text.trim().toLowerCase();

    final exact = _coldStorageOptions.firstWhere(
      (c) => c.trim().toLowerCase() == coldText,
      orElse: () => '',
    );

    setState(() {
      _selectedColdStorage = exact.isEmpty ? null : exact;

      _receiptOptions =
          _allReceipts
              .where(
                (r) =>
                    r.coldStorageName.trim().toLowerCase() == coldText &&
                    (_isEditMode
                        ? (r.receiptNumber == widget.delivery?.receiptNumber ||
                              r.remainingQuantity > 0)
                        : r.remainingQuantity > 0),
              )
              .map((r) => r.receiptNumber.trim())
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (_selectedColdStorage == null ||
          (_receiptController.text.isNotEmpty &&
              !_receiptOptions.contains(_receiptController.text))) {
        _receiptController.clear();
        _productController.clear();
        _brandController.clear();
      }
    });
  }

  void _onColdStorageSelected(String selection) {
    _coldStorageController.text = selection;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _receiptFocusNode.requestFocus();
    });
  }

  void _onReceiptSelected(String selection) {
    setState(() {
      _receiptController.text = selection;
      if (_selectedReceipt != null) {
        _productController.text = _selectedReceipt!.productName;
        _brandController.text = _selectedReceipt!.brandName;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _dateFocusNode.requestFocus();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: _selectedReceipt?.inwardDate.toDate() ?? DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd-MM-yy').format(_selectedDate);
      });
      _quantityFocusNode.requestFocus();
    }
  }

  Future<void> _saveDelivery() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedReceipt == null) {
      showAppNotification(
        context: context,
        message: 'Selected receipt is not valid.',
        type: NotificationType.error,
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      showAppNotification(
        context: context,
        message: 'Please enter a valid quantity.',
        type: NotificationType.error,
      );
      return;
    }

    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);

    try {
      // COMPREHENSIVE VALIDATION using DeliveryValidationService
      final validation = await _firestoreService.validateDelivery(
        receipt: _selectedReceipt!,
        attemptedQuantity: quantity,
        excludeDeliveryId: _isEditMode ? widget.delivery?.id : null,
      );

      if (!validation.isValid) {
        if (mounted) {
          setState(() => _isSaving = false);
          showAppNotification(
            context: context,
            message: validation.errorMessage!,
            type: NotificationType.error,
          );
        }
        return;
      }

      // Validation passed, proceed with save
      if (_isEditMode) {
        final deliveryToUpdate = widget.delivery!;
        final updatedData = {
          'quantity': quantity,
          'narration': _narrationController.text.trim(),
          'deliveryDate': Timestamp.fromDate(_selectedDate),
        };
        await _firestoreService.updateDelivery(
          deliveryToUpdate.id!,
          updatedData,
        );

        // Sync receipt remaining quantity from actual deliveries
        await _firestoreService.syncReceiptRemainingQuantity(
          receiptId: _selectedReceipt!.id!,
          receiptNumber: _selectedReceipt!.receiptNumber,
          coldStorageName: _selectedReceipt!.coldStorageName,
          inwardQuantity: _selectedReceipt!.inwardQuantity,
        );

        navigator.pop(true);
      } else {
        final newDelivery = Delivery(
          coldStorageName: _selectedColdStorage!,
          receiptNumber: _receiptController.text.trim(),
          quantity: quantity,
          narration: _narrationController.text.trim(),
          deliveryDate: Timestamp.fromDate(_selectedDate),
        );
        await _firestoreService.addDelivery(newDelivery);

        // Sync receipt remaining quantity from actual deliveries
        await _firestoreService.syncReceiptRemainingQuantity(
          receiptId: _selectedReceipt!.id!,
          receiptNumber: _selectedReceipt!.receiptNumber,
          coldStorageName: _selectedReceipt!.coldStorageName,
          inwardQuantity: _selectedReceipt!.inwardQuantity,
        );

        showAppNotification(
          context: context,
          message: 'Delivery saved successfully!',
          type: NotificationType.success,
        );

        await _fetchInitialData();
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        showAppNotification(
          context: context,
          message: 'Error saving delivery: $e',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _coldStorageController.clear();
    _receiptController.clear();
    _quantityController.clear();
    _narrationController.clear();
    _productController.clear();
    _brandController.clear();
    setState(() {
      _selectedColdStorage = null;
      _receiptOptions = [];
      _selectedDate = DateTime.now();
      _dateController.text = DateFormat('dd-MM-yy').format(_selectedDate);
    });
    _coldStorageFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Delivery' : 'New Delivery Entry'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AppBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: Container(
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: Form(
                          key: _formKey,
                          child: AbsorbPointer(
                            absorbing: _isSaving,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildAutocompleteField(
                                  focusNode: _coldStorageFocusNode,
                                  controller: _coldStorageController,
                                  labelText: 'Cold Storage',
                                  options: _coldStorageOptions,
                                  onSelected: _onColdStorageSelected,
                                  autofocus: !_isEditMode,
                                  enabled:
                                      !_isEditMode, // Disabled in edit mode
                                ),
                                const SizedBox(height: 16),
                                _buildAutocompleteField(
                                  key: ValueKey(
                                    'receipt@${_selectedColdStorage ?? ''}',
                                  ),
                                  focusNode: _receiptFocusNode,
                                  controller: _receiptController,
                                  labelText: 'Receipt Number',
                                  options: _receiptOptions,
                                  onSelected: _onReceiptSelected,
                                  enabled:
                                      _selectedColdStorage != null &&
                                      !_isEditMode, // Disabled in edit mode
                                ),
                                if (_selectedReceipt != null) ...[
                                  const SizedBox(height: 16),
                                  // --- FIX 2: Added disabled styling for Product and Brand ---
                                  TextFormField(
                                    controller: _productController,
                                    readOnly: true,
                                    decoration: InputDecoration(
                                      labelText: 'Product',
                                      filled: true,
                                      fillColor: Theme.of(
                                        context,
                                      ).disabledColor.withOpacity(0.05),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _brandController,
                                    readOnly: true,
                                    decoration: InputDecoration(
                                      labelText: 'Brand',
                                      filled: true,
                                      fillColor: Theme.of(
                                        context,
                                      ).disabledColor.withOpacity(0.05),
                                    ),
                                  ),
                                ],
                                if (_remainingStock != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      'Available Stock for Delivery: $_remainingStock',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  focusNode: _dateFocusNode,
                                  controller: _dateController,
                                  readOnly: true,
                                  autofocus:
                                      _isEditMode, // --- FIX 3: ADDED AUTOFOCUS ---
                                  onTap: () => _selectDate(context),
                                  decoration: const InputDecoration(
                                    labelText: 'Delivery Date',
                                    suffixIcon: Icon(
                                      Icons.calendar_today_outlined,
                                    ),
                                  ),
                                  textInputAction: TextInputAction.next,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _quantityController,
                                  focusNode: _quantityFocusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'Quantity',
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) =>
                                      _narrationFocusNode.requestFocus(),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter quantity';
                                    }
                                    final v = int.tryParse(value) ?? 0;
                                    if (v <= 0) return 'Enter a valid quantity';
                                    if (_remainingStock != null &&
                                        v > _remainingStock!) {
                                      return 'Exceeds available stock';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _narrationController,
                                  focusNode: _narrationFocusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'Narration (Optional)',
                                  ),
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  maxLines: 2,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _saveDelivery(),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  focusNode: _saveButtonFocusNode,
                                  onPressed: _isSaving ? null : _saveDelivery,
                                  child: _isSaving
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _isEditMode
                                              ? 'UPDATE DELIVERY'
                                              : 'SAVE DELIVERY',
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildAutocompleteField({
    Key? key,
    required FocusNode focusNode,
    required TextEditingController controller,
    required String labelText,
    required List<String> options,
    required Function(String) onSelected,
    bool enabled = true,
    bool autofocus = false,
  }) {
    return RawAutocomplete<String>(
      key: key,
      focusNode: focusNode,
      textEditingController: controller,
      optionsBuilder: (TextEditingValue textEditingValue) {
        final q = textEditingValue.text.trim().toLowerCase();
        if (q.isEmpty) return options;
        return options.where((String option) {
          return option.toLowerCase().contains(q);
        });
      },
      onSelected: onSelected,
      fieldViewBuilder:
          (
            context,
            fieldTextEditingController,
            fieldFocusNode,
            onAutocompleteSubmitted,
          ) {
            return TextFormField(
              controller: fieldTextEditingController,
              focusNode: fieldFocusNode,
              enabled: enabled,
              autofocus: autofocus,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) {
                final entered = fieldTextEditingController.text.trim();
                final exact = options.firstWhere(
                  (o) => o.trim().toLowerCase() == entered.toLowerCase(),
                  orElse: () => '',
                );

                if (exact.isNotEmpty) {
                  onSelected(exact);
                } else {
                  onAutocompleteSubmitted();
                }
              },
              decoration: InputDecoration(
                labelText: labelText,
                filled: !enabled,
                fillColor: !enabled
                    ? Theme.of(context).disabledColor.withOpacity(0.05)
                    : null,
              ),
              validator: (value) {
                if (!enabled) return null;
                if (value == null || value.isEmpty) {
                  return 'Please select a $labelText';
                }
                if (!options
                    .map((o) => o.trim().toLowerCase())
                    .contains(value.trim().toLowerCase())) {
                  return 'Please select a valid $labelText from the list';
                }
                return null;
              },
            );
          },
      optionsViewBuilder: (context, onSelected, optionsIterable) {
        final optionsList = optionsIterable.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Card(
            margin: const EdgeInsets.only(top: 8.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: optionsList.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = optionsList[index];
                  final bool isHighlighted =
                      AutocompleteHighlightedOption.of(context) == index;
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Container(
                      color: isHighlighted
                          ? Theme.of(context).focusColor
                          : null,
                      padding: const EdgeInsets.all(16.0),
                      child: Text(option),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
