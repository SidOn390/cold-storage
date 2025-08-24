// File: lib/screens/masters/product_type_master_screen.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:business_management_app/services/firestore_service.dart';
import 'package:business_management_app/utils/app_notifications.dart';

class ProductMasterScreen extends StatefulWidget {
  const ProductMasterScreen({Key? key}) : super(key: key);

  @override
  _ProductMasterScreenState createState() => _ProductMasterScreenState();
}

class _ProductMasterScreenState extends State<ProductMasterScreen> {
  final FirestoreService _firestore = FirestoreService();
  final TextEditingController _textCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  String? _editingId;
  String _searchQuery = '';
  bool _isProcessing = false;
  final RegExp _validName = RegExp(r"^[a-zA-Z0-9 &-]+$");

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
      () => setState(() => _searchQuery = _searchCtrl.text.trim()),
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _buildShimmer() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            height: 56,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDialog({String? id, String? initialName}) async {
    _editingId = id;
    _textCtrl.text = initialName ?? '';
    _isProcessing = false;

    return await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            final name = _textCtrl.text.trim();
            final canSubmit = name.isNotEmpty && !_isProcessing;
            return AlertDialog(
              title: Text(id == null ? 'Add Product' : 'Edit Product'),
              content: TextField(
                controller: _textCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Name',
                  errorText: errorText,
                  errorMaxLines: 2,
                ),
                onChanged: (_) => setState(() => errorText = null),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: !canSubmit
                      ? null
                      : () async {
                          setState(() => _isProcessing = true);
                          final name = _textCtrl.text.trim();
                          if (!_validName.hasMatch(name)) {
                            setState(() {
                              errorText =
                                  'Only letters, numbers, spaces, & and - allowed';
                              _isProcessing = false;
                            });
                            return;
                          }
                          try {
                            final existing = await _firestore
                                .getProducts()
                                .first;
                            final lowerNames = existing
                                .map((e) => (e['name'] as String).toLowerCase())
                                .toList();
                            if (id == null) {
                              if (lowerNames.contains(name.toLowerCase())) {
                                setState(() {
                                  errorText = 'This Product already exists';
                                  _isProcessing = false;
                                });
                                return;
                              }
                              await _firestore.addProduct(name);
                            } else {
                              final original =
                                  existing.firstWhere(
                                        (e) => e['id'] == id,
                                      )['name']
                                      as String;
                              if (original.toLowerCase() !=
                                      name.toLowerCase() &&
                                  lowerNames.contains(name.toLowerCase())) {
                                setState(() {
                                  errorText = 'This Product already exists';
                                  _isProcessing = false;
                                });
                                return;
                              }
                              await _firestore.updateProduct(id, name);
                            }
                            Navigator.of(dialogContext).pop(true);
                          } catch (e) {
                            if (mounted) {
                              showAppNotification(
                                context: context,
                                message: 'Error: $e',
                                type: NotificationType.error,
                              );
                            }
                            Navigator.of(dialogContext).pop(false);
                          } finally {
                            if (mounted) {
                              setState(() => _isProcessing = false);
                            }
                          }
                        },
                  child: Text(id == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(String id, String name) async {
    final bool isInUse = await _firestore.isProductInUse(name);

    if (!mounted) return;

    if (isInUse) {
      showAppNotification(
        context: context,
        message: '"$name" cannot be deleted as it is in use.',
        type: NotificationType.error,
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _firestore.deleteProduct(id);
        if (mounted) {
          showAppNotification(
            context: context,
            message: 'Product deleted successfully',
            type: NotificationType.error,
          );
        }
      } catch (e) {
        if (mounted) {
          showAppNotification(
            context: context,
            message: 'Error deleting product: $e',
            type: NotificationType.error,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Products')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search Product…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _firestore.getProducts(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return _buildShimmer();
                  }
                  final items = (snap.data ?? [])
                      .where(
                        (e) => (e['name'] as String).toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ),
                      )
                      .toList();
                  items.sort(
                    (a, b) => (a['name'] as String).toLowerCase().compareTo(
                      (b['name'] as String).toLowerCase(),
                    ),
                  );
                  if (items.isEmpty) {
                    return const Center(child: Text('No Product yet'));
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return ListTile(
                        title: Text(item['name'] as String),
                        onTap: () async {
                          final success = await _showDialog(
                            id: item['id'] as String,
                            initialName: item['name'] as String,
                          );
                          if (success == true && mounted) {
                            showAppNotification(
                              context: context,
                              message: 'Product updated successfully',
                              type: NotificationType.info,
                            );
                          }
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Edit ${item['name']}',
                              onPressed: () async {
                                final success = await _showDialog(
                                  id: item['id'] as String,
                                  initialName: item['name'] as String,
                                );
                                if (success == true && mounted) {
                                  showAppNotification(
                                    context: context,
                                    message: 'Product updated successfully',
                                    type: NotificationType.info,
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: 'Delete ${item['name']}',
                              onPressed: () => _confirmDelete(
                                item['id'] as String,
                                item['name'] as String,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final success = await _showDialog();
          if (success == true && mounted) {
            showAppNotification(
              context: context,
              message: 'Product added successfully',
              type: NotificationType.success,
            );
          }
        },
        tooltip: 'Add Product',
        child: const Icon(Icons.add),
      ),
    );
  }
}
