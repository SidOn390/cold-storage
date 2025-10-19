// lib/screens/admin/user_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cold_storage/models/app_user.dart';
import 'package:cold_storage/models/user_role.dart';
import 'package:cold_storage/services/user_management_service.dart';
import 'package:cold_storage/utils/app_notifications.dart';
import 'package:cold_storage/utils/date_fmt.dart';
import 'package:cold_storage/widgets/app_background.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserManagementService _userService = UserManagementService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _userService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showUserStatsDialog,
            tooltip: 'User Statistics',
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildSearchBar(),
              Expanded(child: _buildUserList()),
            ],
          ),
        ),
      ),
      floatingActionButton: _currentUser?.role.canManageUsers ?? false
          ? FloatingActionButton.extended(
              onPressed: _showAddUserDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Add User'),
            )
          : null,
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by name or email...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<List<AppUser>>(
      stream: _userService.getUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No users found'),
          );
        }

        var users = snapshot.data!;

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          users = users.where((user) =>
              user.displayName.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query)).toList();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            // Use RepaintBoundary and separate widget to prevent rebuilds from affecting popup menus
            return RepaintBoundary(
              child: UserCardWidget(
                key: ValueKey(user.uid),
                user: user,
                currentUser: _currentUser,
                onActionSelected: _handleUserAction,
              ),
            );
          },
        );
      },
    );
  }


  void _handleUserAction(String action, AppUser user) {
    switch (action) {
      case 'edit':
        _showEditUserDialog(user);
        break;
      case 'toggle_status':
        _toggleUserStatus(user);
        break;
      case 'delete':
        _confirmDeleteUser(user);
        break;
    }
  }

  Future<void> _showAddUserDialog() async {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailFocusNode = FocusNode();
    UserRole selectedRole = UserRole.viewer;

    // Request focus after dialog is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      emailFocusNode.requestFocus();
    });

    bool isCreating = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        title: const Text('Add New User'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                if (isCreating)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Creating user...'),
                      ],
                    ),
                  )
                else ...[
                TextFormField(
                  controller: emailController,
                  focusNode: emailFocusNode,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<UserRole>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.security),
                  ),
                  items: UserRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      selectedRole = value;
                    }
                  },
                ),
                ],
                ],
              ),
            ),
          ),
        ),
        actions: isCreating
            ? []
            : [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                setDialogState(() {
                  isCreating = true;
                });

                final scaffoldContext = this.context;

                try {
                  await _userService.createUser(
                    email: emailController.text.trim(),
                    password: passwordController.text,
                    displayName: nameController.text.trim(),
                    role: selectedRole,
                    phoneNumber: phoneController.text.trim().isEmpty
                        ? null
                        : phoneController.text.trim(),
                  );

                  if (mounted) {
                    Navigator.pop(dialogContext);
                    showAppNotification(
                      context: scaffoldContext,
                      message: 'User created successfully',
                      type: NotificationType.success,
                    );
                  }
                } catch (e) {
                  setDialogState(() {
                    isCreating = false;
                  });

                  if (mounted) {
                    showAppNotification(
                      context: scaffoldContext,
                      message: 'Error creating user: $e',
                      type: NotificationType.error,
                    );
                  }
                }
              }
            },
            child: const Text('Create User'),
          ),
        ],
      ),
      ),
    );

    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    phoneController.dispose();
    emailFocusNode.dispose();
  }

  Future<void> _showEditUserDialog(AppUser user) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user.displayName);
    final phoneController = TextEditingController(text: user.phoneNumber ?? '');
    UserRole selectedRole = user.role;
    bool isUpdating = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        title: const Text('Edit User'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isUpdating)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Updating user...'),
                      ],
                    ),
                  )
                else ...[
                TextFormField(
                  initialValue: user.email,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  enabled: false,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<UserRole>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.security),
                  ),
                  items: UserRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      selectedRole = value;
                    }
                  },
                ),
                ],
              ],
            ),
          ),
        ),
        actions: isUpdating
            ? []
            : [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                setDialogState(() {
                  isUpdating = true;
                });

                final scaffoldContext = this.context;

                try {
                  await _userService.updateUser(
                    user.copyWith(
                      displayName: nameController.text.trim(),
                      role: selectedRole,
                      phoneNumber: phoneController.text.trim().isEmpty
                          ? null
                          : phoneController.text.trim(),
                    ),
                  );

                  if (mounted) {
                    Navigator.pop(dialogContext);
                    showAppNotification(
                      context: scaffoldContext,
                      message: 'User updated successfully',
                      type: NotificationType.success,
                    );
                  }
                } catch (e) {
                  setDialogState(() {
                    isUpdating = false;
                  });

                  if (mounted) {
                    showAppNotification(
                      context: scaffoldContext,
                      message: 'Error updating user: $e',
                      type: NotificationType.error,
                    );
                  }
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
      ),
    );

    nameController.dispose();
    phoneController.dispose();
  }

  Future<void> _toggleUserStatus(AppUser user) async {
    try {
      await _userService.toggleUserStatus(user.uid, !user.isActive);

      if (mounted) {
        showAppNotification(
          context: context,
          message: user.isActive
              ? 'User deactivated'
              : 'User activated',
          type: NotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppNotification(
          context: context,
          message: 'Error updating user status: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _confirmDeleteUser(AppUser user) async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isDeleting = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
              const SizedBox(width: 12),
              const Text('Permanently Delete User?'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isDeleting)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Deleting user...'),
                        ],
                      ),
                    )
                  else ...[
                    Text(
                      'You are about to permanently delete:',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Role: ${user.role.displayName}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This action cannot be undone!',
                              style: TextStyle(
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'To confirm, type the user\'s email address:',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: emailController,
                      decoration: InputDecoration(
                        hintText: user.email,
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the email address';
                        }
                        if (value.trim() != user.email) {
                          return 'Email does not match';
                        }
                        return null;
                      },
                      autofocus: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: isDeleting
              ? []
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() {
                          isDeleting = true;
                        });

                        final scaffoldContext = this.context;

                        try {
                          final result = await _userService.deleteUser(user.uid);

                          if (mounted) {
                            Navigator.pop(dialogContext, true);

                            // Show appropriate message based on deletion type
                            if (result['fullDeletion'] == true) {
                              showAppNotification(
                                context: scaffoldContext,
                                message: result['message'] ?? 'User deleted successfully',
                                type: NotificationType.success,
                              );
                            } else {
                              // Partial deletion - show warning dialog
                              showDialog(
                                context: scaffoldContext,
                                builder: (ctx) => AlertDialog(
                                  title: Row(
                                    children: [
                                      Icon(Icons.warning_amber, color: Colors.orange.shade700),
                                      const SizedBox(width: 8),
                                      const Text('Partial Deletion'),
                                    ],
                                  ),
                                  content: Text(result['message'] ?? 'User partially deleted'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          setDialogState(() {
                            isDeleting = false;
                          });

                          if (mounted) {
                            showAppNotification(
                              context: scaffoldContext,
                              message: 'Error deleting user: $e',
                              type: NotificationType.error,
                            );
                          }
                        }
                      }
                    },
                    child: const Text('Delete Permanently'),
                  ),
                ],
        ),
      ),
    );

    emailController.dispose();
  }

  Future<void> _showUserStatsDialog() async {
    try {
      final stats = await _userService.getUserStats();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('User Statistics'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatRow('Total Users', stats['total'].toString()),
                _buildStatRow('Active', stats['active'].toString(), Colors.green),
                _buildStatRow('Inactive', stats['inactive'].toString(), Colors.red),
                const Divider(),
                const Text('By Role:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildStatRow('Super Admins', stats['byRole']['superAdmin'].toString()),
                _buildStatRow('Admins', stats['byRole']['admin'].toString()),
                _buildStatRow('Managers', stats['byRole']['manager'].toString()),
                _buildStatRow('Operators', stats['byRole']['operator'].toString()),
                _buildStatRow('Viewers', stats['byRole']['viewer'].toString()),
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
    } catch (e) {
      if (mounted) {
        showAppNotification(
          context: context,
          message: 'Error loading statistics: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  Widget _buildStatRow(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Separate widget for each user card to prevent rebuilds from affecting popup menus
class UserCardWidget extends StatelessWidget {
  final AppUser user;
  final AppUser? currentUser;
  final Function(String action, AppUser user) onActionSelected;

  const UserCardWidget({
    super.key,
    required this.user,
    required this.currentUser,
    required this.onActionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final canManage = currentUser?.role.canManageUsers ?? false;
    final isCurrentUser = currentUser?.uid == user.uid;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user.role),
          child: Text(
            user.initials,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (!user.isActive)
              Chip(
                label: const Text('Inactive', style: TextStyle(fontSize: 10)),
                backgroundColor: Colors.red.shade100,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(user.email, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 2),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(
                    user.role.displayName,
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                  backgroundColor: _getRoleColor(user.role),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  visualDensity: VisualDensity.compact,
                ),
                if (user.lastLoginAt != null)
                  Text(
                    'Last login: ${dfDdMmmYyyy.format(user.lastLoginAt!.toDate())}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: canManage && !isCurrentUser
            ? PopupMenuButton<String>(
                key: ValueKey('popup_${user.uid}'),
                onSelected: (value) => onActionSelected(value, user),
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
                  PopupMenuItem(
                    value: 'toggle_status',
                    child: Row(
                      children: [
                        Icon(
                          user.isActive ? Icons.block : Icons.check_circle,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(user.isActive ? 'Deactivate' : 'Activate'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Permanently Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Colors.purple.shade700;
      case UserRole.admin:
        return Colors.red.shade700;
      case UserRole.manager:
        return Colors.blue.shade700;
      case UserRole.operator:
        return Colors.green.shade700;
      case UserRole.viewer:
        return Colors.grey.shade600;
    }
  }
}
