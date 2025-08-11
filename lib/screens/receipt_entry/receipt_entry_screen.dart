// lib/screens/receipt_entry/receipt_entry_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:business_management_app/models/receipt_model.dart';
import 'package:business_management_app/services/firestore_service.dart';

enum MasterType { coldStorage, product, brand }

class ReceiptEntryScreen extends StatefulWidget {
  final Receipt? receipt;

  const ReceiptEntryScreen({super.key, this.receipt});

  @override
  State<ReceiptEntryScreen> createState() => _ReceiptEntryScreenState();
}

class _ReceiptEntryScreenState extends State<ReceiptEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();

  final _receiptNumberController = TextEditingController();
  final _coldStorageController = TextEditingController();
  final _productController = TextEditingController();
  final _brandController = TextEditingController();
  final _quantityController = TextEditingController();
  final _rateController = TextEditingController();
  final _narrationController = TextEditingController();
  final _dateController = TextEditingController();

  final _receiptNumberFocusNode = FocusNode();
  final _coldStorageFocusNode = FocusNode();
  final _dateFocusNode = FocusNode();
  final _productFocusNode = FocusNode();
  final _brandFocusNode = FocusNode();
  final _quantityFocusNode = FocusNode();
  final _rateFocusNode = FocusNode();
  final _narrationFocusNode = FocusNode();
  final _saveButtonFocusNode = FocusNode();

  DateTime _selectedDate = DateTime.now();
  String? _selectedColdStorage;
  String? _selectedProduct;
  String? _selectedBrand;

  List<String> _coldStorageOptions = [];
  List<String> _productOptions = [];
  List<String> _brandOptions = [];

  bool _isLoading = true;
  bool _isSaving = false;

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

  void _populateFieldsForEdit() {
    final r = widget.receipt!;
    _receiptNumberController.text = r.receiptNumber;
    _coldStorageController.text = r.coldStorageName;
    _productController.text = r.productName;
    _brandController.text = r.brandName;
    _quantityController.text = r.inwardQuantity.toString();
    _rateController.text = r.rate.toString();
    _narrationController.text = r.narration;
    _dateController.text = DateFormat('dd-MM-yy').format(r.inwardDate.toDate());

    _selectedDate = r.inwardDate.toDate();
    _selectedColdStorage = r.coldStorageName;
    _selectedProduct = r.productName;
    _selectedBrand = r.brandName;
  }

  @override
  void dispose() {
    _receiptNumberController.dispose();
    _coldStorageController.dispose();
    _productController.dispose();
    _brandController.dispose();
    _quantityController.dispose();
    _rateController.dispose();
    _narrationController.dispose();
    _dateController.dispose();

    _receiptNumberFocusNode.dispose();
    _coldStorageFocusNode.dispose();
    _dateFocusNode.dispose();
    _productFocusNode.dispose();
    _brandFocusNode.dispose();
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

      setState(() {
        _coldStorageOptions =
            storagesList.map((map) => map['name'] as String).toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _productOptions =
            productsList.map((map) => map['name'] as String).toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _brandOptions = brandsList.map((map) => map['name'] as String).toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showTopFlushbar('Error fetching master data: $e', isError: true);
      }
    }
  }

  void _showTopFlushbar(String message, {bool isError = false}) {
    if (!mounted) return;
    Flushbar(
      title: isError ? "An Error Occurred" : "Success",
      message: message,
      duration: const Duration(seconds: 4),
      flushbarPosition: FlushbarPosition.TOP,
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      icon: Icon(
        isError ? Icons.error_outline : Icons.check_circle_outline,
        size: 28.0,
        color: Colors.white,
      ),
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
      boxShadows: const [
        BoxShadow(
          color: Colors.black45,
          offset: Offset(0.0, 2.0),
          blurRadius: 3.0,
        ),
      ],
    ).show(context);
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
    _showTopFlushbar(message, isError: true);
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

    setState(() => _isSaving = true);

    try {
      if (_isEditMode) {
        final updatedData = {
          'productName': _selectedProduct!,
          'brandName': _selectedBrand!,
          'inwardQuantity': int.parse(_quantityController.text),
          'rate': double.parse(_rateController.text),
          'narration': _narrationController.text.trim(),
          'inwardDate': Timestamp.fromDate(_selectedDate),
        };

        await _firestoreService.updateReceipt(widget.receipt!.id!, updatedData);
        _showTopFlushbar('Receipt updated successfully.');
        Navigator.of(context).pop();
      } else {
        final receiptNumber = _receiptNumberController.text;
        final int quantity = int.parse(_quantityController.text);
        final bool isDuplicate = await _firestoreService.doesReceiptExist(
          receiptNumber,
          _selectedColdStorage!,
        );

        if (isDuplicate) {
          _showTopFlushbar(
            'Receipt #$receiptNumber already exists for this cold storage.',
            isError: true,
          );
          setState(() => _isSaving = false);
          return;
        }

        final newReceipt = Receipt(
          receiptNumber: receiptNumber,
          coldStorageName: _selectedColdStorage!,
          inwardDate: Timestamp.fromDate(_selectedDate),
          productName: _selectedProduct!,
          brandName: _selectedBrand!,
          inwardQuantity: quantity,
          remainingQuantity: quantity,
          rate: double.parse(_rateController.text),
          narration: _narrationController.text.trim(),
        );

        await _firestoreService.addReceipt(newReceipt.toJson());
        _showTopFlushbar(
          'Receipt #$receiptNumber has been saved successfully.',
        );

        _formKey.currentState!.reset();
        _receiptNumberController.clear();
        _coldStorageController.clear();
        _productController.clear();
        _brandController.clear();
        _quantityController.clear();
        _rateController.clear();
        _narrationController.clear();

        setState(() {
          _selectedDate = DateTime.now();
          _dateController.text = DateFormat('dd-MM-yy').format(_selectedDate);
          _selectedColdStorage = null;
          _selectedProduct = null;
          _selectedBrand = null;
        });
        FocusScope.of(context).requestFocus(_receiptNumberFocusNode);
      }
    } catch (e) {
      _showTopFlushbar('Error: $e', isError: true);
    } finally {
      if (mounted) {
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
          break;
        case MasterType.product:
          _selectedProduct = selection;
          _productController.text = selection;
          FocusScope.of(context).requestFocus(_brandFocusNode);
          break;
        case MasterType.brand:
          _selectedBrand = selection;
          _brandController.text = selection;
          FocusScope.of(context).requestFocus(_quantityFocusNode);
          break;
      }
    });
  }

  Future<void> _handleAddNewItem(MasterType type, String newName) async {
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
      case MasterType.product:
        collectionName = 'products';
        optionsList = _productOptions;
        label = 'Product';
        break;
      case MasterType.brand:
        collectionName = 'brands';
        optionsList = _brandOptions;
        label = 'Brand';
        break;
    }
    if (optionsList.any((o) => o.toLowerCase() == newName.toLowerCase())) {
      final existingOption = optionsList.firstWhere(
        (o) => o.toLowerCase() == newName.toLowerCase(),
      );
      _showTopFlushbar(
        '"$existingOption" already exists and has been selected.',
      );
      _handleSelection(type, existingOption);
      setState(() => _isSaving = false);
      return;
    }
    try {
      await _firestoreService.addMasterItem(collectionName, newName);
      setState(() {
        optionsList.add(newName);
        optionsList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      });
      _handleSelection(type, newName);
      _showTopFlushbar('$label "$newName" added successfully.');
    } catch (e) {
      _showTopFlushbar('Error adding new $label: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleTextChanged(MasterType type, String value) {
    switch (type) {
      case MasterType.coldStorage:
        if (_selectedColdStorage != value)
          setState(() => _selectedColdStorage = null);
        break;
      case MasterType.product:
        if (_selectedProduct != value) setState(() => _selectedProduct = null);
        break;
      case MasterType.brand:
        if (_selectedBrand != value) setState(() => _selectedBrand = null);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Receipt' : 'New Receipt Entry'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: AbsorbPointer(
                  absorbing: _isSaving,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _receiptNumberController,
                        focusNode: _receiptNumberFocusNode,
                        enabled: !_isEditMode,
                        autofocus: !_isEditMode,
                        decoration: const InputDecoration(
                          labelText: 'Receipt Number',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter a receipt number'
                            : null,
                        onFieldSubmitted: (_) => FocusScope.of(
                          context,
                        ).requestFocus(_coldStorageFocusNode),
                      ),
                      const SizedBox(height: 16),
                      _buildAutocompleteField(
                        masterType: MasterType.coldStorage,
                        focusNode: _coldStorageFocusNode,
                        controller: _coldStorageController,
                        labelText: 'Cold Storage',
                        options: _coldStorageOptions,
                        nextFocusNode: _dateFocusNode,
                        enabled: !_isEditMode,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        focusNode: _dateFocusNode,
                        controller: _dateController,
                        decoration: InputDecoration(
                          labelText: 'Inward Date',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () => _selectDate(context),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Please enter a date';
                          try {
                            DateFormat('dd-MM-yy').parseStrict(value);
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
                      _buildAutocompleteField(
                        masterType: MasterType.product,
                        focusNode: _productFocusNode,
                        controller: _productController,
                        labelText: 'Product',
                        options: _productOptions,
                        nextFocusNode: _brandFocusNode,
                      ),
                      const SizedBox(height: 16),
                      _buildAutocompleteField(
                        masterType: MasterType.brand,
                        focusNode: _brandFocusNode,
                        controller: _brandController,
                        labelText: 'Brand',
                        options: _brandOptions,
                        nextFocusNode: _quantityFocusNode,
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
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter quantity'
                            : null,
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_rateFocusNode),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _rateController,
                        focusNode: _rateFocusNode,
                        decoration: const InputDecoration(labelText: 'Rate'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter a rate'
                            : null,
                        onFieldSubmitted: (_) => FocusScope.of(
                          context,
                        ).requestFocus(_narrationFocusNode),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _narrationController,
                        focusNode: _narrationFocusNode,
                        decoration: const InputDecoration(
                          labelText: 'Narration (Optional)',
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 2,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => FocusScope.of(
                          context,
                        ).requestFocus(_saveButtonFocusNode),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        focusNode: _saveButtonFocusNode,
                        onPressed: _isSaving ? null : _saveOrUpdateReceipt,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
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
                                _isEditMode ? 'Update Receipt' : 'Save Receipt',
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildAutocompleteField({
    required MasterType masterType,
    required FocusNode focusNode,
    required TextEditingController controller,
    required String labelText,
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
                fillColor: !enabled ? Colors.grey.shade200 : null,
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
              child: Material(
                elevation: 4.0,
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
                                ? Theme.of(context).primaryColor
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
}
