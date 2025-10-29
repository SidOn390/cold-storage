// lib/screens/masters/rent_rate_master_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cold_storage/models/rent_rate.dart';
import 'package:cold_storage/models/rent_type.dart';
import 'package:cold_storage/services/rent_rate_service.dart';
import 'package:cold_storage/services/master_service.dart';
import 'package:cold_storage/services/user_management_service.dart';
import 'package:cold_storage/widgets/app_background.dart';
import 'package:cold_storage/utils/app_notifications.dart';

class RentRateMasterScreen extends StatefulWidget {
  const RentRateMasterScreen({super.key});

  @override
  State<RentRateMasterScreen> createState() => _RentRateMasterScreenState();
}

class _RentRateMasterScreenState extends State<RentRateMasterScreen> {
  final RentRateService _rentRateService = RentRateService.instance;
  final UserManagementService _userService = UserManagementService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _filterColdStorageController = TextEditingController();
  final FocusNode _filterColdStorageFocusNode = FocusNode();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _searchQuery = '';
  String? _filterColdStorage;
  RentType? _filterRentType;
  List<String> _coldStorageOptions = [];

  // Fetch cold storages directly from Firestore
  Future<List<String>> _fetchColdStorages() async {
    try {
      final snapshot = await _firestore
          .collection('cold_storages')
          .orderBy('name')
          .get();
      final result = snapshot.docs.map((doc) => doc['name'] as String).toList();
      debugPrint('✅ Fetched ${result.length} cold storages from Firestore');
      return result;
    } catch (e) {
      debugPrint('❌ Error fetching cold storages: $e');
      return [];
    }
  }

  // Fetch products directly from Firestore
  Future<List<String>> _fetchProducts() async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .orderBy('name')
          .get();
      final result = snapshot.docs.map((doc) => doc['name'] as String).toList();
      debugPrint('✅ Fetched ${result.length} products from Firestore');
      return result;
    } catch (e) {
      debugPrint('❌ Error fetching products: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filterColdStorageController.dispose();
    _filterColdStorageFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Debug: Check what data is available
    debugPrint('🔍 Rent Rate Master initialized');
    debugPrint('🔍 Cold Storages count: ${MasterService.coldStorages.length}');
    debugPrint('🔍 Products count: ${MasterService.products.length}');

    // Load cold storage options for filter
    _loadColdStorages();
  }

  void _loadColdStorages() async {
    final storages = await _fetchColdStorages();
    if (mounted) {
      setState(() {
        _coldStorageOptions = storages;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Rent Rate Master'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showStatsDialog,
            tooltip: 'Statistics',
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildSearchAndFilters(),
              Expanded(child: _buildRatesList()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Rate'),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by product or cold storage...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 12),

          // Filters
          Row(
            children: [
              // Cold Storage filter - Autocomplete
              Expanded(
                child: RawAutocomplete<String>(
                  focusNode: _filterColdStorageFocusNode,
                  textEditingController: _filterColdStorageController,
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return ['All', ..._coldStorageOptions];
                    }
                    final String lowerCaseQuery = textEditingValue.text.toLowerCase();
                    final filtered = _coldStorageOptions.where(
                      (String option) => option.toLowerCase().contains(lowerCaseQuery),
                    );
                    return ['All', ...filtered];
                  },
                  onSelected: (String selection) {
                    setState(() {
                      if (selection == 'All') {
                        _filterColdStorage = null;
                        _filterColdStorageController.clear();
                      } else {
                        _filterColdStorage = selection;
                      }
                    });
                  },
                  fieldViewBuilder: (
                    BuildContext context,
                    TextEditingController fieldTextEditingController,
                    FocusNode fieldFocusNode,
                    VoidCallback onFieldSubmitted,
                  ) {
                    return TextFormField(
                      controller: fieldTextEditingController,
                      focusNode: fieldFocusNode,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: 'Filter by Cold Storage',
                        hintText: 'All',
                        prefixIcon: const Icon(Icons.warehouse),
                        suffixIcon: _filterColdStorage != null
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _filterColdStorage = null;
                                    _filterColdStorageController.clear();
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onFieldSubmitted: (_) {
                        // Let autocomplete handle Enter key to select highlighted option
                        onFieldSubmitted();
                      },
                    );
                  },
                  optionsViewBuilder: (
                    BuildContext context,
                    AutocompleteOnSelected<String> onSelected,
                    Iterable<String> options,
                  ) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final String option = options.elementAt(index);
                              return ListTile(
                                title: Text(
                                  option,
                                  style: TextStyle(
                                    fontWeight: option == 'All' ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                onTap: () => onSelected(option),
                                tileColor: AutocompleteHighlightedOption.of(context) == index
                                    ? Theme.of(context).focusColor.withOpacity(0.1)
                                    : null,
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Rent Type filter
              Expanded(
                child: DropdownButtonFormField<RentType>(
                  value: _filterRentType,
                  decoration: InputDecoration(
                    labelText: 'Filter by Rent Type',
                    prefixIcon: const Icon(Icons.category),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All'),
                    ),
                    ...RentType.values.map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _filterRentType = value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatesList() {
    return StreamBuilder<List<RentRate>>(
      stream: _rentRateService.getRentRatesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        var rates = snapshot.data ?? [];

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          rates = rates.where((rate) =>
            rate.productName.toLowerCase().contains(query) ||
            rate.coldStorageName.toLowerCase().contains(query)
          ).toList();
        }

        // Apply cold storage filter
        if (_filterColdStorage != null) {
          rates = rates.where((r) => r.coldStorageName == _filterColdStorage).toList();
        }

        // Apply rent type filter
        if (_filterRentType != null) {
          rates = rates.where((r) => r.rentType == _filterRentType).toList();
        }

        if (rates.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty || _filterColdStorage != null || _filterRentType != null
                      ? 'No rates found matching filters'
                      : 'No rent rates configured yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap + button to add a rate',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rates.length,
          itemBuilder: (context, index) {
            final rate = rates[index];
            return _buildRateCard(rate);
          },
        );
      },
    );
  }

  Widget _buildRateCard(RentRate rate) {
    final isMonthly = rate.rentType == RentType.monthly;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMonthly
                ? Colors.blue.shade50
                : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isMonthly ? Icons.calendar_month : Icons.wb_sunny,
            color: isMonthly ? Colors.blue : Colors.orange,
            size: 28,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                rate.productName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isMonthly
                    ? Colors.blue.shade100
                    : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                rate.rentType.displayName,
                style: TextStyle(
                  fontSize: 12,
                  color: isMonthly ? Colors.blue.shade900 : Colors.orange.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warehouse, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  rate.coldStorageName,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isMonthly) ...[
              Row(
                children: [
                  const Icon(Icons.currency_rupee, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    '₹${rate.monthlyRatePerUnit}/unit/month',
                    style: const TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 20),
                  const Icon(Icons.engineering, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    '₹${rate.labourRatePerUnit}/unit (labour)',
                    style: const TextStyle(fontSize: 14, color: Colors.blue),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.currency_rupee, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    '₹${rate.seasonalRatePerUnit}/unit (fixed)',
                    style: const TextStyle(fontSize: 14, color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.receipt, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'GST: ${rate.gstPercentage}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showAddEditDialog(rate: rate);
            } else if (value == 'delete') {
              _confirmDelete(rate);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddEditDialog({RentRate? rate}) async {
    final isEdit = rate != null;

    // Debug: Check what data is available when dialog opens
    debugPrint('📋 Opening Add/Edit dialog');
    debugPrint('📋 Cold Storages available: ${MasterService.coldStorages.length}');
    debugPrint('📋 Products available: ${MasterService.products.length}');

    // Form controllers with autocomplete support
    RentType selectedRentType = rate?.rentType ?? RentType.monthly;

    final coldStorageController = TextEditingController(
      text: rate?.coldStorageName ?? '',
    );
    final productController = TextEditingController(
      text: rate?.productName ?? '',
    );
    final monthlyRateController = TextEditingController(
      text: rate?.monthlyRatePerUnit?.toString() ?? '',
    );
    final labourRateController = TextEditingController(
      text: rate?.labourRatePerUnit?.toString() ?? '',
    );
    final seasonalRateController = TextEditingController(
      text: rate?.seasonalRatePerUnit?.toString() ?? '',
    );
    final gstController = TextEditingController(
      text: rate?.gstPercentage.toString() ?? '18',
    );

    // Focus nodes for autocomplete and navigation
    final coldStorageFocusNode = FocusNode();
    final productFocusNode = FocusNode();
    final monthlyRateFocusNode = FocusNode();
    final labourRateFocusNode = FocusNode();
    final seasonalRateFocusNode = FocusNode();
    final gstFocusNode = FocusNode();

    // Fetch master data for autocomplete
    final coldStorages = await _fetchColdStorages();
    final products = await _fetchProducts();

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // Auto-focus on first field after dialog is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (coldStorageFocusNode.canRequestFocus) {
            coldStorageFocusNode.requestFocus();
          }
        });

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Rent Rate' : 'Add Rent Rate'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cold Storage autocomplete field
                    if (coldStorages.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No cold storages found. Please add cold storages in Master Data first.',
                                style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _buildAutocompleteField(
                        labelText: 'Cold Storage *',
                        focusNode: coldStorageFocusNode,
                        controller: coldStorageController,
                        options: coldStorages,
                        prefixIcon: Icons.warehouse,
                        nextFocusNode: productFocusNode,
                        onSelected: (value) {
                          // Controller is already updated by autocomplete
                          setDialogState(() {});
                        },
                        validator: (value) =>
                            value == null || value.isEmpty
                                ? 'Please select cold storage'
                                : null,
                      ),
                    const SizedBox(height: 16),

                    // Product autocomplete field
                    if (products.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No products found. Please add products in Master Data first.',
                                style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _buildAutocompleteField(
                        labelText: 'Product *',
                        focusNode: productFocusNode,
                        controller: productController,
                        options: products,
                        prefixIcon: Icons.inventory,
                        onSelected: (value) {
                          // Controller is already updated by autocomplete
                          setDialogState(() {});
                        },
                        validator: (value) =>
                            value == null || value.isEmpty
                                ? 'Please select product'
                                : null,
                      ),
                    const SizedBox(height: 16),

                    // Rent Type
                    DropdownButtonFormField<RentType>(
                      value: selectedRentType,
                      decoration: const InputDecoration(
                        labelText: 'Rent Type *',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: RentType.values.map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.displayName),
                        ),
                      ).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedRentType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Conditional fields based on rent type
                    if (selectedRentType == RentType.monthly) ...[
                      Text(
                        'Monthly Rent Configuration',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: monthlyRateController,
                        focusNode: monthlyRateFocusNode,
                        decoration: const InputDecoration(
                          labelText: 'Monthly Rate per Unit *',
                          prefixIcon: Icon(Icons.currency_rupee),
                          hintText: '10.00',
                        ),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => labourRateFocusNode.requestFocus(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Invalid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: labourRateController,
                        focusNode: labourRateFocusNode,
                        decoration: const InputDecoration(
                          labelText: 'Labour Rate per Unit *',
                          prefixIcon: Icon(Icons.engineering),
                          hintText: '5.00',
                        ),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => gstFocusNode.requestFocus(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Invalid number';
                          }
                          return null;
                        },
                      ),
                    ] else ...[
                      Text(
                        'Seasonal Rent Configuration',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: seasonalRateController,
                        focusNode: seasonalRateFocusNode,
                        decoration: const InputDecoration(
                          labelText: 'Seasonal Fixed Rate per Unit *',
                          prefixIcon: Icon(Icons.currency_rupee),
                          hintText: '60.00',
                          helperText: 'Fixed rate for entire season',
                        ),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => gstFocusNode.requestFocus(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Invalid number';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 16),

                    // GST Percentage
                    TextFormField(
                      controller: gstController,
                      focusNode: gstFocusNode,
                      decoration: const InputDecoration(
                        labelText: 'GST Percentage *',
                        prefixIcon: Icon(Icons.percent),
                        hintText: '18',
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        // Trigger validation and save when Enter is pressed on last field
                        if (formKey.currentState!.validate()) {
                          // Find and click the save button
                          Navigator.pop(dialogContext);
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final val = double.tryParse(value);
                        if (val == null) {
                          return 'Invalid number';
                        }
                        if (val < 0 || val > 100) {
                          return 'Must be between 0-100';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                try {
                  final currentUser = await _userService.getCurrentUser();

                  final newRate = RentRate(
                    id: rate?.id,
                    coldStorageName: coldStorageController.text.trim(),
                    productName: productController.text.trim(),
                    rentType: selectedRentType,
                    monthlyRatePerUnit: selectedRentType == RentType.monthly
                        ? double.parse(monthlyRateController.text)
                        : null,
                    labourRatePerUnit: selectedRentType == RentType.monthly
                        ? double.parse(labourRateController.text)
                        : null,
                    seasonalRatePerUnit: selectedRentType == RentType.seasonal
                        ? double.parse(seasonalRateController.text)
                        : null,
                    gstPercentage: double.parse(gstController.text),
                    createdAt: rate?.createdAt ?? DateTime.now(),
                    createdBy: rate?.createdBy ?? currentUser?.displayName ?? 'System',
                    updatedAt: isEdit ? DateTime.now() : null,
                    updatedBy: isEdit ? currentUser?.displayName : null,
                  );

                  if (isEdit) {
                    await _rentRateService.updateRentRate(newRate);
                  } else {
                    await _rentRateService.addRentRate(newRate);
                  }

                  if (mounted) {
                    Navigator.pop(dialogContext);
                    showAppNotification(
                      context: context,
                      message: isEdit
                          ? 'Rent rate updated successfully'
                          : 'Rent rate added successfully',
                      type: NotificationType.success,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    showAppNotification(
                      context: context,
                      message: 'Error: $e',
                      type: NotificationType.error,
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Update' : 'Add'),
            ),
          ],
        ),
      );
      },
    );

    // Dispose controllers and focus nodes safely after dialog is fully closed
    // Use addPostFrameCallback to ensure dialog widgets are fully disposed first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      coldStorageController.dispose();
      productController.dispose();
      monthlyRateController.dispose();
      labourRateController.dispose();
      seasonalRateController.dispose();
      gstController.dispose();
      coldStorageFocusNode.dispose();
      productFocusNode.dispose();
      monthlyRateFocusNode.dispose();
      labourRateFocusNode.dispose();
      seasonalRateFocusNode.dispose();
      gstFocusNode.dispose();
    });
  }

  Future<void> _confirmDelete(RentRate rate) async {
    // Check if rate is in use
    final inUse = await _rentRateService.isRateInUse(rate.id!);

    if (inUse && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete'),
          content: const Text(
            'This rate is being used in existing receipts and cannot be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rent Rate'),
        content: Text(
          'Are you sure you want to delete the rent rate for:\n\n'
          '${rate.productName} - ${rate.coldStorageName}\n'
          '(${rate.rentType.displayName})',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final currentUser = await _userService.getCurrentUser();
        await _rentRateService.deleteRentRate(
          rate.id!,
          currentUser?.displayName ?? 'System',
        );

        if (mounted) {
          showAppNotification(
            context: context,
            message: 'Rent rate deleted successfully',
            type: NotificationType.success,
          );
        }
      } catch (e) {
        if (mounted) {
          showAppNotification(
            context: context,
            message: 'Error deleting rate: $e',
            type: NotificationType.error,
          );
        }
      }
    }
  }

  Future<void> _showStatsDialog() async {
    final stats = await _rentRateService.getStatistics();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rent Rate Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow('Total Rates', stats['total'].toString(), Icons.receipt_long),
            const Divider(),
            _buildStatRow('Monthly Rates', stats['monthly'].toString(), Icons.calendar_month, Colors.blue),
            _buildStatRow('Seasonal Rates', stats['seasonal'].toString(), Icons.wb_sunny, Colors.orange),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color ?? Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutocompleteField({
    required String labelText,
    required FocusNode focusNode,
    required TextEditingController controller,
    required List<String> options,
    required IconData prefixIcon,
    required Function(String?) onSelected,
    String? Function(String?)? validator,
    FocusNode? nextFocusNode,
  }) {
    return RawAutocomplete<String>(
      focusNode: focusNode,
      textEditingController: controller,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        final String lowerCaseQuery = textEditingValue.text.toLowerCase();
        return options.where(
          (String option) => option.toLowerCase().contains(lowerCaseQuery),
        );
      },
      onSelected: (String selection) {
        onSelected(selection);
        // Move to next field after selection
        if (nextFocusNode != null) {
          // Small delay to ensure the value is set before moving focus
          Future.delayed(const Duration(milliseconds: 50), () {
            nextFocusNode.requestFocus();
          });
        }
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController fieldTextEditingController,
        FocusNode fieldFocusNode,
        VoidCallback onFieldSubmitted,
      ) {
        return TextFormField(
          controller: fieldTextEditingController,
          focusNode: fieldFocusNode,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: labelText,
            prefixIcon: Icon(prefixIcon),
          ),
          validator: validator,
          onFieldSubmitted: (_) {
            // Let autocomplete handle Enter key to select option
            // onFieldSubmitted will be called by autocomplete after selection
            onFieldSubmitted();
          },
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<String> onSelected,
        Iterable<String> options,
      ) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return ListTile(
                    title: Text(option),
                    onTap: () => onSelected(option),
                    tileColor: AutocompleteHighlightedOption.of(context) == index
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
