// lib/screens/receipt_entry/receipt_entry_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cold_storage/models/receipt_model.dart';
import 'package:cold_storage/models/rent_type.dart';
import 'package:cold_storage/models/rent_rate.dart';
import 'package:cold_storage/services/firestore_service.dart';
import 'package:cold_storage/services/rent_rate_service.dart';
import 'package:cold_storage/utils/app_notifications.dart';
import 'package:cold_storage/widgets/app_background.dart'; // 1. Import AppBackground

enum MasterType { coldStorage, product, brand, company }

class ReceiptEntryScreen extends StatefulWidget {
  final Receipt? receipt;
  const ReceiptEntryScreen({super.key, this.receipt});

  @override
  State<ReceiptEntryScreen> createState() => _ReceiptEntryScreenState();
}

class _ReceiptEntryScreenState extends State<ReceiptEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  final _rentRateService = RentRateService.instance;

  final _receiptNumberController = TextEditingController();
  final _coldStorageController = TextEditingController();
  final _productController = TextEditingController();
  final _brandController = TextEditingController();
  final _companyController = TextEditingController();
  final _quantityController = TextEditingController();
  final _rateController = TextEditingController();
  final _narrationController = TextEditingController();
  final _dateController = TextEditingController();

  final _receiptNumberFocusNode = FocusNode();
  final _coldStorageFocusNode = FocusNode();
  final _dateFocusNode = FocusNode();
  final _productFocusNode = FocusNode();
  final _brandFocusNode = FocusNode();
  final _companyFocusNode = FocusNode();
  final _quantityFocusNode = FocusNode();
  final _rateFocusNode = FocusNode();
  final _narrationFocusNode = FocusNode();
  final _saveButtonFocusNode = FocusNode();

  DateTime _selectedDate = DateTime.now();
  String? _selectedColdStorage;
  String? _selectedProduct;
  String? _selectedBrand;
  String? _selectedCompany;

  List<String> _coldStorageOptions = [];
  List<String> _productOptions = [];
  List<String> _brandOptions = [];
  List<String> _companyOptions = [];

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasDeliveries = false; // Track if receipt has existing deliveries

  // Rent-related fields
  RentType _selectedRentType = RentType.monthly;
  RentRate? _fetchedRentRate;
  bool _isFetchingRate = false;
  String? _rateError;

  bool get _isEditMode => widget.receipt != null;

  @override
  void initState() {
    super.initState();
    _fetchMasterData();

    if (_isEditMode) {
      _populateFieldsForEdit();
    } else {
      _dateController.text = DateFormat('dd-MM-yy').format(_selectedDate);
    }
  }

  void _populateFieldsForEdit() async {
    final r = widget.receipt!;
    _receiptNumberController.text = r.receiptNumber;
    _coldStorageController.text = r.coldStorageName;
    _productController.text = r.productName;
    _brandController.text = r.brandName;
    _companyController.text = r.companyName;
    _quantityController.text = r.inwardQuantity.toString();
    _rateController.text = r.rate.toString();
    _narrationController.text = r.narration;
    _dateController.text = DateFormat('dd-MM-yy').format(r.inwardDate.toDate());

    _selectedDate = r.inwardDate.toDate();
    _selectedColdStorage = r.coldStorageName;
    _selectedProduct = r.productName;
    _selectedBrand = r.brandName;
    _selectedCompany = r.companyName;

    // Load rent type and create RentRate object from stored values
    _selectedRentType = RentType.fromJson(r.rentType);
    if (r.monthlyRatePerUnit != null || r.seasonalRatePerUnit != null) {
      _fetchedRentRate = RentRate(
        coldStorageName: r.coldStorageName,
        productName: r.productName,
        rentType: _selectedRentType,
        monthlyRatePerUnit: r.monthlyRatePerUnit,
        labourRatePerUnit: r.labourRatePerUnit,
        seasonalRatePerUnit: r.seasonalRatePerUnit,
        gstPercentage: r.gstPercentage,
        createdAt: DateTime.now(),
        createdBy: 'System',
      );
    }

    // Check if deliveries exist for this receipt
    try {
      final deliveries = await _firestoreService.getDeliveriesForReceipt(
        receiptNumber: r.receiptNumber,
        coldStorageName: r.coldStorageName,
      );
      if (mounted) {
        setState(() {
          _hasDeliveries = deliveries.isNotEmpty;
        });

        // Show warning if deliveries exist
        if (_hasDeliveries) {
          Future.delayed(Duration.zero, () {
            if (mounted) {
              showAppNotification(
                context: context,
                message: 'Warning: This receipt has ${deliveries.length} delivery record(s). '
                    'Receipt Number and Cold Storage cannot be changed.',
                type: NotificationType.info,
              );
            }
          });
        }
      }
    } catch (e) {
      // If check fails, assume no deliveries
      debugPrint('Error checking deliveries: $e');
    }
  }

  @override
  void dispose() {
    _receiptNumberController.dispose();
    _coldStorageController.dispose();
    _productController.dispose();
    _brandController.dispose();
    _companyController.dispose();
    _quantityController.dispose();
    _rateController.dispose();
    _narrationController.dispose();
    _dateController.dispose();

    _receiptNumberFocusNode.dispose();
    _coldStorageFocusNode.dispose();
    _dateFocusNode.dispose();
    _productFocusNode.dispose();
    _brandFocusNode.dispose();
    _companyFocusNode.dispose();
    _quantityFocusNode.dispose();
    _rateFocusNode.dispose();
    _narrationFocusNode.dispose();
    _saveButtonFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchMasterData() async {
    try {
      final storagesList = await _firestoreService.getColdStorages().first;
      final productsList = await _firestoreService.getProducts().first;
      final brandsList = await _firestoreService.getBrands().first;
      final companiesList = await _firestoreService.getCompanies().first;

      if (mounted) {
        setState(() {
          _coldStorageOptions =
              storagesList.map((map) => map['name'] as String).toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          _productOptions =
              productsList.map((map) => map['name'] as String).toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          _brandOptions =
              brandsList.map((map) => map['name'] as String).toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          _companyOptions =
              companiesList.map((map) => map['name'] as String).toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showAppNotification(
          context: context,
          message: 'Error fetching master data: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  /// Fetch rent rate when cold storage + product + rent type are selected
  Future<void> _fetchRentRate() async {
    // Only fetch if we have cold storage, product, and rent type selected
    if (_selectedColdStorage == null || _selectedProduct == null) {
      return;
    }

    setState(() {
      _isFetchingRate = true;
      _rateError = null;
    });

    try {
      final rate = await _rentRateService.getRateFor(
        coldStorageName: _selectedColdStorage!,
        productName: _selectedProduct!,
        rentType: _selectedRentType,
      );

      if (mounted) {
        setState(() {
          _fetchedRentRate = rate;
          _isFetchingRate = false;

          if (rate == null) {
            _rateError = 'No rent rate configured for $_selectedColdStorage - $_selectedProduct (${_selectedRentType.displayName})';
          } else {
            _rateError = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingRate = false;
          _rateError = 'Error fetching rent rate: $e';
          _fetchedRentRate = null;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd-MM-yy').format(_selectedDate);
      });
      FocusScope.of(context).requestFocus(_productFocusNode);
    }
  }

  void _showValidationError(String message, FocusNode node) {
    showAppNotification(
      context: context,
      message: message,
      type: NotificationType.error,
    );
    FocusScope.of(context).requestFocus(node);
  }

  Future<void> _saveOrUpdateReceipt() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedColdStorage == null) {
      _showValidationError(
        'Please select a valid Cold Storage.',
        _coldStorageFocusNode,
      );
      return;
    }
    if (_selectedProduct == null) {
      _showValidationError('Please select a valid Product.', _productFocusNode);
      return;
    }
    if (_selectedBrand == null) {
      _showValidationError('Please select a valid Brand.', _brandFocusNode);
      return;
    }
    if (_selectedCompany == null) {
      _showValidationError(
        'Please select a valid Company.',
        _companyFocusNode,
      );
      return;
    }

    final navigator = Navigator.of(context);
    setState(() => _isSaving = true);

    try {
      if (_isEditMode) {
        final newInwardQuantity = int.parse(_quantityController.text);
        final dispatchedQuantity =
            widget.receipt!.inwardQuantity - widget.receipt!.remainingQuantity;
        final newRemainingQuantity = newInwardQuantity - dispatchedQuantity;

        if (newRemainingQuantity < 0) {
          showAppNotification(
            context: context,
            message:
                'Update failed: New quantity cannot be less than the already dispatched quantity ($dispatchedQuantity).',
            type: NotificationType.error,
          );
          if (mounted) setState(() => _isSaving = false);
          return;
        }

        final updatedData = {
          'productName': _selectedProduct!,
          'brandName': _selectedBrand!,
          'companyName': _selectedCompany!,
          'inwardQuantity': newInwardQuantity,
          'remainingQuantity': newRemainingQuantity,
          'rate': double.parse(_rateController.text),
          'narration': _narrationController.text.trim(),
          'inwardDate': Timestamp.fromDate(_selectedDate),
          // Update rent rate information (only if no deliveries)
          if (!_hasDeliveries && _fetchedRentRate != null) ...{
            'rentType': _selectedRentType.toJson(),
            'monthlyRatePerUnit': _selectedRentType == RentType.monthly
                ? _fetchedRentRate?.monthlyRatePerUnit
                : null,
            'labourRatePerUnit': _selectedRentType == RentType.monthly
                ? _fetchedRentRate?.labourRatePerUnit
                : null,
            'seasonalRatePerUnit': _selectedRentType == RentType.seasonal
                ? _fetchedRentRate?.seasonalRatePerUnit
                : null,
            'gstPercentage': _fetchedRentRate?.gstPercentage,
          },
        };

        await _firestoreService.updateReceipt(widget.receipt!.id!, updatedData);
        navigator.pop(true);
      } else {
        final receiptNumber = _receiptNumberController.text;
        final int quantity = int.parse(_quantityController.text);
        final bool isDuplicate = await _firestoreService.doesReceiptExist(
          receiptNumber,
          _selectedColdStorage!,
        );
        if (isDuplicate) {
          showAppNotification(
            context: context,
            message:
                'Receipt #$receiptNumber already exists for this cold storage.',
            type: NotificationType.error,
          );
          if (mounted) setState(() => _isSaving = false);
          return;
        }

        // Warn if rent rate is not fetched (but allow save)
        if (_fetchedRentRate == null) {
          showAppNotification(
            context: context,
            message: 'Warning: No rent rate configured for this cold storage and product. Receipt will be saved without rent information.',
            type: NotificationType.warning,
          );
        }

        final newReceipt = Receipt(
          receiptNumber: receiptNumber,
          coldStorageName: _selectedColdStorage!,
          inwardDate: Timestamp.fromDate(_selectedDate),
          productName: _selectedProduct!,
          brandName: _selectedBrand!,
          companyName: _selectedCompany!,
          inwardQuantity: quantity,
          remainingQuantity: quantity,
          rate: double.parse(_rateController.text),
          narration: _narrationController.text.trim(),
          // Store rent rate information (immutable) - null if no rate configured
          rentType: _selectedRentType.toJson(),
          monthlyRatePerUnit: _selectedRentType == RentType.monthly
              ? _fetchedRentRate?.monthlyRatePerUnit
              : null,
          labourRatePerUnit: _selectedRentType == RentType.monthly
              ? _fetchedRentRate?.labourRatePerUnit
              : null,
          seasonalRatePerUnit: _selectedRentType == RentType.seasonal
              ? _fetchedRentRate?.seasonalRatePerUnit
              : null,
          gstPercentage: _fetchedRentRate?.gstPercentage ?? 18.0,
        );

        await _firestoreService.addReceipt(newReceipt.toJson());
        showAppNotification(
          context: context,
          message: 'Receipt #$receiptNumber has been saved successfully.',
          type: NotificationType.success,
        );

        _formKey.currentState!.reset();
        _receiptNumberController.clear();
        _coldStorageController.clear();
        _productController.clear();
        _brandController.clear();
        _companyController.clear();
        _quantityController.clear();
        _rateController.clear();
        _narrationController.clear();

        setState(() {
          _selectedDate = DateTime.now();
          _dateController.text = DateFormat('dd-MM-yy').format(_selectedDate);
          _selectedColdStorage = null;
          _selectedProduct = null;
          _selectedBrand = null;
          _selectedCompany = null;
          _isSaving = false;
        });
        FocusScope.of(context).requestFocus(_receiptNumberFocusNode);
      }
    } catch (e) {
      if (mounted) {
        showAppNotification(
          context: context,
          message: 'Error: $e',
          type: NotificationType.error,
        );
        setState(() => _isSaving = false);
      }
    }
  }

  void _handleSelection(MasterType type, String selection) {
    setState(() {
      switch (type) {
        case MasterType.coldStorage:
          _selectedColdStorage = selection;
          _coldStorageController.text = selection;
          FocusScope.of(context).requestFocus(_dateFocusNode);
          // Fetch rent rate if product is also selected
          if (_selectedProduct != null) {
            _fetchRentRate();
          }
          break;
        case MasterType.product:
          _selectedProduct = selection;
          _productController.text = selection;
          FocusScope.of(context).requestFocus(_brandFocusNode);
          // Fetch rent rate if cold storage is also selected
          if (_selectedColdStorage != null) {
            _fetchRentRate();
          }
          break;
        case MasterType.brand:
          _selectedBrand = selection;
          _brandController.text = selection;
          FocusScope.of(context).requestFocus(_companyFocusNode);
          break;
        case MasterType.company:
          _selectedCompany = selection;
          _companyController.text = selection;
          FocusScope.of(context).requestFocus(_quantityFocusNode);
          break;
      }
    });
  }

  // Replace the existing _handleAddNewItem method in receipt_entry_screen.dart with this:

Future<void> _handleAddNewItem(MasterType type, String newName) async {
  // For products, show a dialog to collect weight
  if (type == MasterType.product) {
    final result = await _showProductDialog(newName);
    if (result != null) {
      final name = result['name'] as String;
      final weight = result['weight'] as double;
      
      setState(() => _isSaving = true);
      
      // Check if product already exists
      if (_productOptions.any((o) => o.toLowerCase() == name.toLowerCase())) {
        final existingOption = _productOptions.firstWhere(
          (o) => o.toLowerCase() == name.toLowerCase(),
        );
        showAppNotification(
          context: context,
          message: '"$existingOption" already exists and has been selected.',
          type: NotificationType.info,
        );
        _handleSelection(type, existingOption);
        if (mounted) setState(() => _isSaving = false);
        return;
      }
      
      try {
        await _firestoreService.addProduct(name, weight);
        if (mounted) {
          setState(() {
            _productOptions.add(name);
            _productOptions.sort(
              (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
            );
          });
        }
        _handleSelection(type, name);
        showAppNotification(
          context: context,
          message: 'Product "$name" added successfully.',
          type: NotificationType.success,
        );
      } catch (e) {
        if (mounted) {
          showAppNotification(
            context: context,
            message: 'Error adding new Product: $e',
            type: NotificationType.error,
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
    return;
  }

  // For other types (coldStorage, brand, company), use existing logic
  setState(() => _isSaving = true);
  String collectionName;
  List<String> optionsList;
  String label;
  
  switch (type) {
    case MasterType.coldStorage:
      collectionName = 'cold_storages';
      optionsList = _coldStorageOptions;
      label = 'Cold Storage';
      break;
    case MasterType.brand:
      collectionName = 'brands';
      optionsList = _brandOptions;
      label = 'Brand';
      break;
    case MasterType.company:
      collectionName = 'companies';
      optionsList = _companyOptions;
      label = 'Company';
      break;
    case MasterType.product:
      // Already handled above
      return;
  }
  
  if (optionsList.any((o) => o.toLowerCase() == newName.toLowerCase())) {
    final existingOption = optionsList.firstWhere(
      (o) => o.toLowerCase() == newName.toLowerCase(),
    );
    showAppNotification(
      context: context,
      message: '"$existingOption" already exists and has been selected.',
      type: NotificationType.info,
    );
    _handleSelection(type, existingOption);
    if (mounted) setState(() => _isSaving = false);
    return;
  }
  
  try {
    await _firestoreService.addMasterItem(collectionName, newName);
    if (mounted) {
      setState(() {
        optionsList.add(newName);
        optionsList.sort(
          (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
        );
      });
    }
    _handleSelection(type, newName);
    showAppNotification(
      context: context,
      message: '$label "$newName" added successfully.',
      type: NotificationType.success,
    );
  } catch (e) {
    if (mounted) {
      showAppNotification(
        context: context,
        message: 'Error adding new $label: $e',
        type: NotificationType.error,
      );
    }
  } finally {
    if (mounted) setState(() => _isSaving = false);
  }
}

// Add this new method to show the product dialog
Future<Map<String, dynamic>?> _showProductDialog(String initialName) async {
  final nameController = TextEditingController(text: initialName);
  final weightController = TextEditingController();
  String? nameError;
  String? weightError;
  final validName = RegExp(r"^[a-zA-Z0-9 &-]+$");

  return await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final name = nameController.text.trim();
          final weightText = weightController.text.trim();
          final weightValue = double.tryParse(weightText);
          final canSubmit = name.isNotEmpty && 
                           weightValue != null && 
                           weightValue > 0;

          return AlertDialog(
            title: const Text('Add Product'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Product Name',
                    errorText: nameError,
                    errorMaxLines: 2,
                  ),
                  onChanged: (_) => setState(() => nameError = null),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: weightController,
                  textInputAction: TextInputAction.done,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Weight',
                    hintText: 'e.g. 50',
                    suffixText: 'kg',
                    errorText: weightError,
                  ),
                  onChanged: (_) => setState(() => weightError = null),
                  onFieldSubmitted: (_) {
                    if (canSubmit) {
                      // Validate and submit
                      final name = nameController.text.trim();
                      final weight = double.tryParse(weightController.text.trim());
                      
                      if (!validName.hasMatch(name)) {
                        setState(() => nameError = 'Only letters, numbers, spaces, & and - allowed');
                        return;
                      }
                      if (weight == null || weight <= 0) {
                        setState(() => weightError = 'Enter a valid weight greater than zero');
                        return;
                      }
                      
                      Navigator.of(dialogContext).pop({
                        'name': name,
                        'weight': weight,
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: !canSubmit ? null : () {
                  final name = nameController.text.trim();
                  final weight = double.tryParse(weightController.text.trim());
                  
                  if (!validName.hasMatch(name)) {
                    setState(() => nameError = 'Only letters, numbers, spaces, & and - allowed');
                    return;
                  }
                  if (weight == null || weight <= 0) {
                    setState(() => weightError = 'Enter a valid weight greater than zero');
                    return;
                  }
                  
                  Navigator.of(dialogContext).pop({
                    'name': name,
                    'weight': weight,
                  });
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      );
    },
  );
}

  void _handleTextChanged(MasterType type, String value) {
    switch (type) {
      case MasterType.coldStorage:
        if (_selectedColdStorage != value) {
          setState(() => _selectedColdStorage = null);
        }
        break;
      case MasterType.product:
        if (_selectedProduct != value) setState(() => _selectedProduct = null);
        break;
      case MasterType.brand:
        if (_selectedBrand != value) setState(() => _selectedBrand = null);
        break;
      case MasterType.company:
        if (_selectedCompany != value) {
          setState(() => _selectedCompany = null);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- UPDATED: Make Scaffold and AppBar transparent for gradient ---
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Receipt' : 'New Receipt Entry'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      // --- UPDATED: Wrap body in AppBackground and SafeArea ---
      body: AppBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 16,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: Container(
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.5),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: AbsorbPointer(
                            absorbing: _isSaving,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth > 600;

                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextFormField(
                                      controller: _receiptNumberController,
                                      focusNode: _receiptNumberFocusNode,
                                      enabled: !_isEditMode, // Always disabled in edit mode
                                      autofocus: !_isEditMode,
                                      decoration: InputDecoration(
                                        labelText: 'Receipt Number',
                                        helperText: _isEditMode && _hasDeliveries
                                          ? 'Cannot be changed (has deliveries)'
                                          : null,
                                        helperMaxLines: 2,
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      validator: (value) =>
                                          value == null || value.isEmpty
                                          ? 'Please enter a receipt number'
                                          : null,
                                      onFieldSubmitted: (_) => FocusScope.of(
                                        context,
                                      ).requestFocus(_coldStorageFocusNode),
                                    ),
                                    const SizedBox(height: 16),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildAutocompleteField(
                                          labelText: 'Cold Storage',
                                          masterType: MasterType.coldStorage,
                                          focusNode: _coldStorageFocusNode,
                                          controller: _coldStorageController,
                                          options: _coldStorageOptions,
                                          nextFocusNode: _dateFocusNode,
                                          enabled: !_isEditMode, // Always disabled in edit mode
                                        ),
                                        if (_isEditMode && _hasDeliveries)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 12, top: 4),
                                            child: Text(
                                              'Cannot be changed (has deliveries)',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      focusNode: _dateFocusNode,
                                      controller: _dateController,
                                      autofocus: _isEditMode,
                                      decoration: InputDecoration(
                                        labelText: 'Inward Date',
                                        suffixIcon: IconButton(
                                          icon: const Icon(
                                            Icons.calendar_today_outlined,
                                          ),
                                          onPressed: () => _selectDate(context),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter a date';
                                        }
                                        try {
                                          DateFormat(
                                            'dd-MM-yy',
                                          ).parseStrict(value);
                                          return null;
                                        } catch (e) {
                                          return 'Invalid format (dd-MM-yy)';
                                        }
                                      },
                                      onChanged: (value) {
                                        try {
                                          final date = DateFormat(
                                            'dd-MM-yy',
                                          ).parseStrict(value);
                                          setState(() => _selectedDate = date);
                                        } catch (e) {
                                          /* Ignore */
                                        }
                                      },
                                      onFieldSubmitted: (_) => FocusScope.of(
                                        context,
                                      ).requestFocus(_productFocusNode),
                                    ),
                                    const SizedBox(height: 16),
                                    if (isWide)
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: _buildAutocompleteField(
                                              labelText: 'Product',
                                              masterType: MasterType.product,
                                              focusNode: _productFocusNode,
                                              controller: _productController,
                                              options: _productOptions,
                                              nextFocusNode: _brandFocusNode,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _buildAutocompleteField(
                                              labelText: 'Brand',
                                              masterType: MasterType.brand,
                                              focusNode: _brandFocusNode,
                                              controller: _brandController,
                                              options: _brandOptions,
                                              nextFocusNode: _companyFocusNode,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _buildAutocompleteField(
                                              labelText: 'Company',
                                              masterType: MasterType.company,
                                              focusNode: _companyFocusNode,
                                              controller: _companyController,
                                              options: _companyOptions,
                                              nextFocusNode: _quantityFocusNode,
                                            ),
                                          ),
                                        ],
                                      )
                                    else ...[
                                      _buildAutocompleteField(
                                        labelText: 'Product',
                                        masterType: MasterType.product,
                                        focusNode: _productFocusNode,
                                        controller: _productController,
                                        options: _productOptions,
                                        nextFocusNode: _brandFocusNode,
                                      ),
                                      const SizedBox(height: 16),
                                      _buildAutocompleteField(
                                        labelText: 'Brand',
                                        masterType: MasterType.brand,
                                        focusNode: _brandFocusNode,
                                        controller: _brandController,
                                        options: _brandOptions,
                                        nextFocusNode: _companyFocusNode,
                                      ),
                                      const SizedBox(height: 16),
                                      _buildAutocompleteField(
                                        labelText: 'Company',
                                        masterType: MasterType.company,
                                        focusNode: _companyFocusNode,
                                        controller: _companyController,
                                        options: _companyOptions,
                                        nextFocusNode: _quantityFocusNode,
                                      ),
                                    ],
                                    const SizedBox(height: 20),

                                    // Rent Type Selection
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.blue.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.account_balance_wallet,
                                                color: Colors.blue.shade700, size: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Rent Type *',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.blue.shade900,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: InkWell(
                                                  onTap: _hasDeliveries ? null : () {
                                                    setState(() {
                                                      _selectedRentType = RentType.monthly;
                                                      _fetchRentRate();
                                                    });
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: _selectedRentType == RentType.monthly
                                                          ? Colors.blue.shade100
                                                          : Colors.white,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: _selectedRentType == RentType.monthly
                                                            ? Colors.blue.shade700
                                                            : Colors.grey.shade300,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Radio<RentType>(
                                                          value: RentType.monthly,
                                                          groupValue: _selectedRentType,
                                                          onChanged: _hasDeliveries ? null : (value) {
                                                            setState(() {
                                                              _selectedRentType = value!;
                                                              _fetchRentRate();
                                                            });
                                                          },
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                'Monthly',
                                                                style: TextStyle(
                                                                  fontWeight: FontWeight.bold,
                                                                  color: _selectedRentType == RentType.monthly
                                                                      ? Colors.blue.shade900
                                                                      : Colors.black87,
                                                                ),
                                                              ),
                                                              Text(
                                                                'Calculated per 15 days',
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors.grey.shade600,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: InkWell(
                                                  onTap: _hasDeliveries ? null : () {
                                                    setState(() {
                                                      _selectedRentType = RentType.seasonal;
                                                      _fetchRentRate();
                                                    });
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: _selectedRentType == RentType.seasonal
                                                          ? Colors.orange.shade100
                                                          : Colors.white,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: _selectedRentType == RentType.seasonal
                                                            ? Colors.orange.shade700
                                                            : Colors.grey.shade300,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Radio<RentType>(
                                                          value: RentType.seasonal,
                                                          groupValue: _selectedRentType,
                                                          onChanged: _hasDeliveries ? null : (value) {
                                                            setState(() {
                                                              _selectedRentType = value!;
                                                              _fetchRentRate();
                                                            });
                                                          },
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                'Seasonal',
                                                                style: TextStyle(
                                                                  fontWeight: FontWeight.bold,
                                                                  color: _selectedRentType == RentType.seasonal
                                                                      ? Colors.orange.shade900
                                                                      : Colors.black87,
                                                                ),
                                                              ),
                                                              Text(
                                                                'Fixed for entire season',
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors.grey.shade600,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Rent Rate Display
                                    if (_isFetchingRate)
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                            const SizedBox(width: 12),
                                            const Text('Fetching rent rate...'),
                                          ],
                                        ),
                                      )
                                    else if (_rateError != null)
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          border: Border.all(color: Colors.orange.shade300),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.warning_amber, color: Colors.orange.shade700),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                _rateError!,
                                                style: TextStyle(color: Colors.orange.shade900),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else if (_fetchedRentRate != null)
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          border: Border.all(color: Colors.green.shade300),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.check_circle, color: Colors.green.shade700),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Rent Rate Found',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green.shade900,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            if (_selectedRentType == RentType.monthly) ...[
                                              _buildRateRow('Monthly Rate', '₹${_fetchedRentRate!.monthlyRatePerUnit}/unit/month'),
                                              _buildRateRow('Labour Rate', '₹${_fetchedRentRate!.labourRatePerUnit}/unit'),
                                            ] else ...[
                                              _buildRateRow('Seasonal Rate', '₹${_fetchedRentRate!.seasonalRatePerUnit}/unit (fixed)'),
                                            ],
                                            _buildRateRow('GST', '${_fetchedRentRate!.gstPercentage}%'),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    if (isWide)
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: _quantityController,
                                              focusNode: _quantityFocusNode,
                                              decoration: const InputDecoration(
                                                labelText: 'Quantity',
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                              ],
                                              validator: (value) =>
                                                  value == null || value.isEmpty
                                                  ? 'Please enter quantity'
                                                  : null,
                                              onFieldSubmitted: (_) =>
                                                  FocusScope.of(
                                                    context,
                                                  ).requestFocus(
                                                    _rateFocusNode,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: TextFormField(
                                              controller: _rateController,
                                              focusNode: _rateFocusNode,
                                              decoration: const InputDecoration(
                                                labelText: 'Rate',
                                              ),
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              inputFormatters: [
                                                FilteringTextInputFormatter.allow(
                                                  RegExp(r'^\d+\.?\d{0,2}'),
                                                ),
                                              ],
                                              validator: (value) =>
                                                  value == null || value.isEmpty
                                                  ? 'Please enter a rate'
                                                  : null,
                                              onFieldSubmitted: (_) =>
                                                  FocusScope.of(
                                                    context,
                                                  ).requestFocus(
                                                    _narrationFocusNode,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      )
                                    else ...[
                                      TextFormField(
                                        controller: _quantityController,
                                        focusNode: _quantityFocusNode,
                                        decoration: const InputDecoration(
                                          labelText: 'Quantity',
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        validator: (value) =>
                                            value == null || value.isEmpty
                                            ? 'Please enter quantity'
                                            : null,
                                        onFieldSubmitted: (_) => FocusScope.of(
                                          context,
                                        ).requestFocus(_rateFocusNode),
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: _rateController,
                                        focusNode: _rateFocusNode,
                                        decoration: const InputDecoration(
                                          labelText: 'Rate',
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d+\.?\d{0,2}'),
                                          ),
                                        ],
                                        validator: (value) =>
                                            value == null || value.isEmpty
                                            ? 'Please enter a rate'
                                            : null,
                                        onFieldSubmitted: (_) => FocusScope.of(
                                          context,
                                        ).requestFocus(_narrationFocusNode),
                                      ),
                                    ],
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
                                      textInputAction: TextInputAction.next,
                                      onFieldSubmitted: (_) => FocusScope.of(
                                        context,
                                      ).requestFocus(_saveButtonFocusNode),
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton(
                                      focusNode: _saveButtonFocusNode,
                                      onPressed: _isSaving
                                          ? null
                                          : _saveOrUpdateReceipt,
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
                                                  ? 'UPDATE RECEIPT'
                                                  : 'SAVE RECEIPT',
                                            ),
                                    ),
                                  ],
                                );
                              },
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
    required String labelText,
    required MasterType masterType,
    required FocusNode focusNode,
    required TextEditingController controller,
    required List<String> options,
    required FocusNode nextFocusNode,
    bool enabled = true,
  }) {
    return RawAutocomplete<String>(
      focusNode: focusNode,
      textEditingController: controller,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (!enabled || textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        final String lowerCaseQuery = textEditingValue.text.toLowerCase();
        final filteredOptions = options.where(
          (String option) => option.toLowerCase().contains(lowerCaseQuery),
        );
        final bool isNew = !options.any(
          (element) => element.toLowerCase() == lowerCaseQuery,
        );
        if (isNew && textEditingValue.text.isNotEmpty) {
          return [...filteredOptions, 'Add "${textEditingValue.text}"'];
        }
        return filteredOptions;
      },
      onSelected: (String selection) {
        if (selection.startsWith('Add "') && selection.endsWith('"')) {
          final newName = selection.substring(5, selection.length - 1);
          _handleAddNewItem(masterType, newName);
        } else {
          _handleSelection(masterType, selection);
        }
      },
      fieldViewBuilder:
          (
            BuildContext context,
            TextEditingController fieldTextEditingController,
            FocusNode fieldFocusNode,
            VoidCallback onFieldSubmitted,
          ) {
            return TextFormField(
              controller: fieldTextEditingController,
              focusNode: fieldFocusNode,
              enabled: enabled,
              decoration: InputDecoration(
                labelText: labelText,
                filled: !enabled,
                fillColor: !enabled ? Colors.grey.withOpacity(0.1) : null,
              ),
              onChanged: (value) => _handleTextChanged(masterType, value),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter or select a $labelText';
                }
                return null;
              },
              onFieldSubmitted: (_) {
                onFieldSubmitted();
              },
            );
          },
      optionsViewBuilder:
          (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            return Align(
              alignment: Alignment.topLeft,
              child: Card(
                margin: const EdgeInsets.only(top: 8.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      final bool isAddNewOption = option.startsWith('Add "');
                      return ListTile(
                        title: Text(
                          option,
                          style: TextStyle(
                            fontStyle: isAddNewOption
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: isAddNewOption
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                        onTap: () => onSelected(option),
                        tileColor:
                            AutocompleteHighlightedOption.of(context) == index
                            ? Theme.of(context).focusColor.withOpacity(0.1)
                            : null,
                      );
                    },
                  ),
                ),
              ),
            );
          },
    );
  }

  Widget _buildRateRow(String label, String value) {
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
}