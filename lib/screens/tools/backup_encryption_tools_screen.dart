// lib/screens/tools/backup_encryption_tools_screen.dart
//
// UI for encrypting and decrypting backup files
// Allows users to convert between encrypted and plain JSON backups

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cold_storage/services/encryption_service.dart';
import 'package:cold_storage/utils/app_notifications.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

class BackupEncryptionToolsScreen extends StatefulWidget {
  const BackupEncryptionToolsScreen({super.key});

  @override
  State<BackupEncryptionToolsScreen> createState() =>
      _BackupEncryptionToolsScreenState();
}

class _BackupEncryptionToolsScreenState
    extends State<BackupEncryptionToolsScreen> {
  final EncryptionService _encryptionService = EncryptionService();
  final TextEditingController _passwordController = TextEditingController();

  bool _isProcessing = false;
  String? _selectedFileName;
  String? _selectedFileContent; // Cached content
  bool? _isSelectedFileEncrypted;
  Map<String, dynamic>? _fileInfo;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select Backup File',
        withData: true, // Load bytes
      );

      if (result != null) {
        final bytes = result.files.single.bytes;
        if (bytes == null) {
          if (mounted) {
            showAppNotification(
              context: context,
              message: 'Unable to read file',
              type: NotificationType.error,
            );
          }
          return;
        }

        final content = utf8.decode(bytes);

        setState(() {
          _selectedFileName = result.files.single.name;
          _selectedFileContent = content;
          _isSelectedFileEncrypted = _encryptionService.isEncrypted(content);
          _fileInfo = _encryptionService.getBackupInfo(content);
        });

        if (mounted) {
          showAppNotification(
            context: context,
            message: 'File loaded: $_selectedFileName',
            type: NotificationType.success,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showAppNotification(
          context: context,
          message: 'Error loading file: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _decryptFile() async {
    if (_selectedFileContent == null) {
      showAppNotification(
        context: context,
        message: 'Please select a file first',
        type: NotificationType.warning,
      );
      return;
    }

    if (_isSelectedFileEncrypted != true) {
      showAppNotification(
        context: context,
        message: 'Selected file is not encrypted',
        type: NotificationType.warning,
      );
      return;
    }

    // Check if password-protected
    final isPasswordProtected = _fileInfo?['password_protected'] == true;
    final password = _passwordController.text.trim();

    if (isPasswordProtected && password.isEmpty) {
      showAppNotification(
        context: context,
        message: 'This backup is password-protected. Please enter password.',
        type: NotificationType.warning,
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Use cached content
      final encryptedContent = _selectedFileContent!;

      // Decrypt
      Map<String, dynamic> decrypted;

      if (isPasswordProtected) {
        final backupStructure = jsonDecode(encryptedContent);
        final encryptedData = backupStructure['encrypted_data'] as String;
        final decryptedJson = await _encryptionService.decryptWithPassword(
          encryptedData,
          password,
        );
        decrypted = jsonDecode(decryptedJson);
      } else {
        final decryptedBackup = await _encryptionService.decryptBackup(
          encryptedContent,
        );
        final dataJson = decryptedBackup['data'] as String;
        decrypted = jsonDecode(dataJson);
      }

      // Save decrypted file
      await _saveDecryptedFile(decrypted);
    } catch (e) {
      if (mounted) {
        showAppNotification(
          context: context,
          message: 'Decryption failed: $e',
          type: NotificationType.error,
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveDecryptedFile(Map<String, dynamic> data) async {
    try {
      final prettyJson = const JsonEncoder.withIndent('  ').convert(data);
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'backup_decrypted_$timestamp.json';

      // Web platform - trigger download
      final bytes = utf8.encode(prettyJson);
      final blob = web.Blob(<JSAny>[bytes.toJS].toJS);
      final url = web.URL.createObjectURL(blob);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement
        ..href = url
        ..download = fileName;
      anchor.click();
      web.URL.revokeObjectURL(url);

      if (mounted) {
        showAppNotification(
          context: context,
          message: 'Decrypted backup downloaded: $fileName',
          type: NotificationType.success,
        );

        _showSuccessDialog(
          title: 'Decryption Successful',
          message: 'Plain JSON file downloaded as:\n$fileName\n\n'
              'Check your browser downloads folder.',
          filePath: fileName,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppNotification(
          context: context,
          message: 'Error saving file: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _encryptFile() async {
    if (_selectedFileContent == null) {
      showAppNotification(
        context: context,
        message: 'Please select a file first',
        type: NotificationType.warning,
      );
      return;
    }

    if (_isSelectedFileEncrypted == true) {
      showAppNotification(
        context: context,
        message: 'Selected file is already encrypted',
        type: NotificationType.warning,
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Use cached content
      final plainContent = _selectedFileContent!;

      // Validate JSON
      try {
        jsonDecode(plainContent);
      } catch (e) {
        throw Exception('Invalid JSON format: $e');
      }

      // Encrypt
      final password = _passwordController.text.trim();
      String encryptedContent;

      if (password.isNotEmpty) {
        // Password-based encryption
        final encryptedData = await _encryptionService.encryptWithPassword(
          plainContent,
          password,
        );
        encryptedContent = jsonEncode({
          'format': 'cold_storage_encrypted_backup',
          'format_version': '2.0',
          'password_protected': true,
          'encrypted_data': encryptedData,
        });
      } else {
        // Device-based encryption
        encryptedContent = await _encryptionService.encryptBackup(
          jsonData: plainContent,
          backupVersion: '1',
        );
      }

      // Save encrypted file
      await _saveEncryptedFile(encryptedContent);
    } catch (e) {
      if (mounted) {
        showAppNotification(
          context: context,
          message: 'Encryption failed: $e',
          type: NotificationType.error,
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveEncryptedFile(String encryptedContent) async {
    try {
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'backup_encrypted_$timestamp.json';

      // Web platform - trigger download
      final bytes = utf8.encode(encryptedContent);
      final blob = web.Blob(<JSAny>[bytes.toJS].toJS);
      final url = web.URL.createObjectURL(blob);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement
        ..href = url
        ..download = fileName;
      anchor.click();
      web.URL.revokeObjectURL(url);

      if (mounted) {
        showAppNotification(
          context: context,
          message: 'Encrypted backup downloaded: $fileName',
          type: NotificationType.success,
        );

        _showSuccessDialog(
          title: 'Encryption Successful',
          message: 'Encrypted backup downloaded as:\n$fileName\n\n'
              'Check your browser downloads folder.',
          filePath: fileName,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppNotification(
          context: context,
          message: 'Error saving file: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  void _showSuccessDialog({
    required String title,
    required String message,
    required String filePath,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                filePath,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Encryption Tools'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Purpose',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'These tools allow you to decrypt encrypted backups for editing, '
                'and re-encrypt plain JSON backups.',
              ),
              SizedBox(height: 16),
              Text(
                'Decrypt Backup',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                '1. Select an encrypted backup file\n'
                '2. Enter password (if password-protected)\n'
                '3. Click "Decrypt"\n'
                '4. Plain JSON will be downloaded\n'
                '5. Edit the JSON with any text editor',
              ),
              SizedBox(height: 16),
              Text(
                'Encrypt Backup',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                '1. Select a plain JSON backup file\n'
                '2. Optionally enter password for password-based encryption\n'
                '3. Click "Encrypt"\n'
                '4. Encrypted backup will be downloaded\n'
                '5. Import the encrypted file back into the app',
              ),
              SizedBox(height: 16),
              Text(
                'Security Notes',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                '• Always delete plain JSON files after re-encrypting\n'
                '• Use strong passwords for password-based encryption\n'
                '• Keep backup copies before editing\n'
                '• Validate JSON structure before encrypting',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Encryption Tools'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
            tooltip: 'Help',
          ),
        ],
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info Card
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Decrypt backups to edit JSON, then re-encrypt before importing',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // File Selection Section
                  _buildSectionTitle('1. Select Backup File'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Choose File'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),

                  if (_selectedFileName != null) ...[
                    const SizedBox(height: 12),
                    _buildFileInfoCard(),
                  ],

                  const SizedBox(height: 24),

                  // Password Section
                  _buildSectionTitle('2. Password (Optional)'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Required for password-protected backups',
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      helperText: _isSelectedFileEncrypted == true &&
                              _fileInfo?['password_protected'] == true
                          ? 'This backup is password-protected'
                          : 'Leave empty for device-based encryption',
                      helperMaxLines: 2,
                    ),
                    obscureText: true,
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons Section
                  _buildSectionTitle('3. Choose Action'),
                  const SizedBox(height: 12),

                  // Decrypt Button
                  if (_isSelectedFileEncrypted == true) ...[
                    ElevatedButton.icon(
                      onPressed: _selectedFileContent != null ? _decryptFile : null,
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Decrypt Backup'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Converts encrypted backup to plain JSON for editing',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  // Encrypt Button
                  if (_isSelectedFileEncrypted == false) ...[
                    ElevatedButton.icon(
                      onPressed: _selectedFileContent != null ? _encryptFile : null,
                      icon: const Icon(Icons.lock),
                      label: const Text('Encrypt Backup'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Converts plain JSON to encrypted backup',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Warning Card
                  Card(
                    color: Colors.amber[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning, color: Colors.amber[700]),
                              const SizedBox(width: 8),
                              const Text(
                                'Important',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '• Always keep a backup of the original file\n'
                            '• Delete plain JSON files after re-encrypting\n'
                            '• Validate JSON structure before encrypting\n'
                            '• Test restore on non-production data first',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildFileInfoCard() {
    final isEncrypted = _isSelectedFileEncrypted ?? false;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isEncrypted ? Icons.lock : Icons.lock_open,
                  color: isEncrypted ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedFileName!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              'Status',
              isEncrypted ? 'ENCRYPTED' : 'PLAIN JSON',
              isEncrypted ? Colors.green : Colors.orange,
            ),
            if (_fileInfo != null) ...[
              const SizedBox(height: 8),
              if (_fileInfo!['encrypted'] == true) ...[
                _buildInfoRow(
                  'Format Version',
                  _fileInfo!['format_version']?.toString() ?? 'N/A',
                  Colors.blue,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Password Protected',
                  _fileInfo!['password_protected'] == true ? 'Yes' : 'No',
                  _fileInfo!['password_protected'] == true
                      ? Colors.red
                      : Colors.grey,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
