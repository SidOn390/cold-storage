// lib/screens/setup/initial_setup_screen.dart
//
// One-time setup screen to create initial super admin user

import 'package:flutter/material.dart';
import 'package:cold_storage/utils/create_super_admin_helper.dart';

class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({super.key});

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  bool _isCreating = false;
  Map<String, dynamic>? _result;

  Future<void> _createSuperAdmin() async {
    setState(() {
      _isCreating = true;
      _result = null;
    });

    final result = await CreateSuperAdminHelper.createInitialSuperAdmin();

    setState(() {
      _isCreating = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Initial Setup'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App Icon/Logo
              const Icon(
                Icons.admin_panel_settings,
                size: 100,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Create Super Admin',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              const Text(
                'This will create the initial super admin user for your Cold Storage application.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Info Card
              Card(
                color: Colors.blue[50],
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Super Admin Credentials',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.email, size: 20, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Email: admin@coldstorage.com',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.lock, size: 20, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Password: Admin123',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person, size: 20, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Display Name: Siddharth Shah',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.star, size: 20, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Role: Super Admin',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Create Button
              if (!_isCreating && _result == null)
                ElevatedButton.icon(
                  onPressed: _createSuperAdmin,
                  icon: const Icon(Icons.add_moderator),
                  label: const Text('Create Super Admin User'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),

              // Loading Indicator
              if (_isCreating)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Creating super admin user...'),
                  ],
                ),

              // Success Result
              if (_result != null && _result!['success'] == true) ...[
                Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Success!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Super Admin user created successfully',
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Login Credentials:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Email: ${_result!['email']}'),
                              Text('Password: ${_result!['password']}'),
                              Text('Name: ${_result!['displayName']}'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'IMPORTANT: Write down these credentials!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Go to Login'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],

              // Error Result
              if (_result != null && _result!['success'] == false) ...[
                Card(
                  color: Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Error',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _result!['error'] ?? 'Unknown error occurred',
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _result = null);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Instructions
              Card(
                color: Colors.amber[50],
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.amber),
                          SizedBox(width: 8),
                          Text(
                            'Next Steps',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text('1. Click "Create Super Admin User" above'),
                      Text('2. Write down the login credentials'),
                      Text('3. Use credentials to log into the app'),
                      Text('4. Go to Masters → User Management'),
                      Text('5. Create additional users as needed'),
                      SizedBox(height: 8),
                      Text(
                        'Note: This screen can only create the super admin once.',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
