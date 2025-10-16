// File: lib/screens/masters/brand_master_screen.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cold_storage/services/firestore_service.dart';
import 'package:cold_storage/utils/app_notifications.dart';
import 'package:cold_storage/widgets/app_background.dart'; // 1. Import AppBackground

class BrandMasterScreen extends StatefulWidget {
  const BrandMasterScreen({super.key});

  @override
  _BrandMasterScreenState createState() => _BrandMasterScreenState();
}

class _BrandMasterScreenState extends State<BrandMasterScreen> {
  final FirestoreService _firestore = FirestoreService();
  final TextEditingController _textCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
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
      itemCount: 8,
      itemBuilder: (_, __) => Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: const SizedBox(height: 56, width: double.infinity),
        ),
      ),
    );
  }

  Future<bool?> _showDialog({String? id, String? initialName}) async {
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

            // --- NEW: Extracted save logic ---
            Future<void> submitForm() async {
              setState(() => _isProcessing = true);
              final name = _textCtrl.text.trim();
              if (!_validName.hasMatch(name)) {
                setState(() {
                  errorText = 'Only letters, numbers, spaces, & and - allowed';
                  _isProcessing = false;
                });
                return;
              }
              try {
                final existing = await _firestore.getBrands().first;
                final lowerNames = existing
                    .map((e) => (e['name'] as String).toLowerCase())
                    .toList();
                if (id == null) {
                  if (lowerNames.contains(name.toLowerCase())) {
                    setState(() {
                      errorText = 'This brand already exists';
                      _isProcessing = false;
                    });
                    return;
                  }
                  await _firestore.addBrand(name);
                } else {
                  final original =
                      existing.firstWhere((e) => e['id'] == id)['name']
                          as String;
                  if (original.toLowerCase() != name.toLowerCase() &&
                      lowerNames.contains(name.toLowerCase())) {
                    setState(() {
                      errorText = 'This brand already exists';
                      _isProcessing = false;
                    });
                    return;
                  }
                  // CASCADE UPDATE: Pass oldName to update all references
                  await _firestore.updateBrand(id, name, oldName: original);
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
            }

            return AlertDialog(
              title: Text(id == null ? 'Add Brand' : 'Edit Brand'),
              content: TextFormField(
                controller: _textCtrl,
                autofocus: true,
                // --- NEW: Added properties for "Enter" key submission ---
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (canSubmit) {
                    submitForm();
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Brand Name',
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
                  onPressed: !canSubmit ? null : submitForm,
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
    final bool isInUse = await _firestore.isBrandInUse(name);
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
        title: const Text('Delete Brand'),
        content: const Text('Are you sure you want to delete this brand?'),
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
        await _firestore.deleteBrand(id);
        if (mounted) {
          showAppNotification(
            context: context,
            message: 'Brand deleted successfully',
            type: NotificationType.error,
          );
        }
      } catch (e) {
        if (mounted) {
          showAppNotification(
            context: context,
            message: 'Error deleting brand: $e',
            type: NotificationType.error,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 2. Make Scaffold and AppBar transparent
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Brands'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      // 3. Wrap the body content with AppBackground
      body: AppBackground(
        // 4. Use SafeArea to avoid system UI (like status bar)
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 0),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search brands…',
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
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _firestore.getBrands(),
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
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.branding_watermark_outlined,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Brands Found',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap the + button to add your first brand.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final item = items[i];
                          return Card(
                            child: ListTile(
                              title: Text(item['name'] as String),
                              onTap: () async {
                                final success = await _showDialog(
                                  id: item['id'] as String,
                                  initialName: item['name'] as String,
                                );
                                if (success == true && mounted) {
                                  showAppNotification(
                                    context: context,
                                    message: 'Brand updated successfully',
                                    type: NotificationType.info,
                                  );
                                }
                              },
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Edit ${item['name']}',
                                    onPressed: () async {
                                      final success = await _showDialog(
                                        id: item['id'] as String,
                                        initialName: item['name'] as String,
                                      );
                                      if (success == true && mounted) {
                                        showAppNotification(
                                          context: context,
                                          message: 'Brand updated successfully',
                                          type: NotificationType.info,
                                        );
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Delete ${item['name']}',
                                    onPressed: () => _confirmDelete(
                                      item['id'] as String,
                                      item['name'] as String,
                                    ),
                                  ),
                                ],
                              ),
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
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final success = await _showDialog();
          if (success == true && mounted) {
            showAppNotification(
              context: context,
              message: 'Brand added successfully',
              type: NotificationType.success,
            );
          }
        },
        tooltip: 'Add Brand',
        child: const Icon(Icons.add),
      ),
    );
  }
}
