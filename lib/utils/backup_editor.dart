// lib/utils/backup_editor.dart
//
// Utility for decrypting, editing, and re-encrypting backup files
// Use this when you need to manually edit backup JSON files

import 'dart:convert';
import 'dart:io';
import 'package:cold_storage/services/encryption_service.dart';

class BackupEditor {
  final EncryptionService _encryptionService = EncryptionService();

  /// Decrypt an encrypted backup file to plain JSON
  ///
  /// Usage:
  /// ```dart
  /// final editor = BackupEditor();
  /// await editor.decryptBackupFile(
  ///   inputPath: 'backup_encrypted.json',
  ///   outputPath: 'backup_plain.json',
  ///   password: 'YourPassword', // Only if password-protected
  /// );
  /// ```
  Future<void> decryptBackupFile({
    required String inputPath,
    required String outputPath,
    String? password,
  }) async {
    try {
      print('Reading encrypted backup from: $inputPath');

      // Read encrypted file
      final file = File(inputPath);
      if (!await file.exists()) {
        throw Exception('Input file not found: $inputPath');
      }

      final encryptedContent = await file.readAsString();

      // Check if it's encrypted
      if (!_encryptionService.isEncrypted(encryptedContent)) {
        throw Exception('File is not encrypted or is already plain JSON');
      }

      // Get backup info
      final info = _encryptionService.getBackupInfo(encryptedContent);
      final isPasswordProtected = info?['password_protected'] == true;

      print('Backup info:');
      print('  - Encrypted: ${info?['encrypted']}');
      print('  - Password protected: $isPasswordProtected');
      print('  - Format version: ${info?['format_version']}');

      // Decrypt
      Map<String, dynamic> decrypted;

      if (isPasswordProtected) {
        if (password == null || password.isEmpty) {
          throw Exception(
            'This backup is password-protected. Please provide the password.',
          );
        }

        print('Decrypting with password...');
        final backupStructure = jsonDecode(encryptedContent);
        final encryptedData = backupStructure['encrypted_data'] as String;
        final decryptedJson = await _encryptionService.decryptWithPassword(
          encryptedData,
          password,
        );
        decrypted = jsonDecode(decryptedJson);
      } else {
        print('Decrypting with device keys...');
        final decryptedBackup = await _encryptionService.decryptBackup(
          encryptedContent,
        );
        final dataJson = decryptedBackup['data'] as String;
        decrypted = jsonDecode(dataJson);
      }

      // Write plain JSON
      final outputFile = File(outputPath);
      final prettyJson = const JsonEncoder.withIndent('  ').convert(decrypted);
      await outputFile.writeAsString(prettyJson);

      print('✅ Successfully decrypted to: $outputPath');
      print('You can now edit the JSON file manually.');
    } catch (e) {
      print('❌ Decryption failed: $e');
      rethrow;
    }
  }

  /// Encrypt a plain JSON backup file
  ///
  /// Usage:
  /// ```dart
  /// final editor = BackupEditor();
  /// await editor.encryptBackupFile(
  ///   inputPath: 'backup_plain.json',
  ///   outputPath: 'backup_encrypted.json',
  ///   password: 'YourPassword', // Optional for password-based encryption
  /// );
  /// ```
  Future<void> encryptBackupFile({
    required String inputPath,
    required String outputPath,
    String? password,
  }) async {
    try {
      print('Reading plain backup from: $inputPath');

      // Read plain JSON file
      final file = File(inputPath);
      if (!await file.exists()) {
        throw Exception('Input file not found: $inputPath');
      }

      final plainContent = await file.readAsString();

      // Validate JSON
      try {
        jsonDecode(plainContent);
      } catch (e) {
        throw Exception('Invalid JSON format: $e');
      }

      // Encrypt
      String encryptedContent;

      if (password != null && password.isNotEmpty) {
        print('Encrypting with password...');
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
        print('Encrypting with device keys...');
        encryptedContent = await _encryptionService.encryptBackup(
          jsonData: plainContent,
          backupVersion: '1', // Schema version
        );
      }

      // Write encrypted file
      final outputFile = File(outputPath);
      await outputFile.writeAsString(encryptedContent);

      print('✅ Successfully encrypted to: $outputPath');
      print('Backup is now encrypted and ready to restore.');
    } catch (e) {
      print('❌ Encryption failed: $e');
      rethrow;
    }
  }

  /// Convert encrypted backup to plain JSON, edit, and re-encrypt
  /// This is a convenience method that combines decrypt + manual edit + encrypt
  ///
  /// Usage:
  /// ```dart
  /// final editor = BackupEditor();
  ///
  /// // Step 1: Decrypt
  /// await editor.decryptForEditing(
  ///   encryptedPath: 'backup_encrypted.json',
  ///   plainPath: 'backup_editable.json',
  ///   password: 'YourPassword',
  /// );
  ///
  /// // Step 2: Edit backup_editable.json manually
  ///
  /// // Step 3: Re-encrypt
  /// await editor.reencryptAfterEditing(
  ///   plainPath: 'backup_editable.json',
  ///   encryptedPath: 'backup_encrypted_new.json',
  ///   password: 'YourPassword',
  /// );
  /// ```
  Future<void> decryptForEditing({
    required String encryptedPath,
    required String plainPath,
    String? password,
  }) async {
    await decryptBackupFile(
      inputPath: encryptedPath,
      outputPath: plainPath,
      password: password,
    );

    print('\n📝 Next steps:');
    print('1. Edit the file: $plainPath');
    print('2. Save your changes');
    print('3. Run reencryptAfterEditing() to create new encrypted backup');
  }

  /// Re-encrypt a plain JSON file after editing
  Future<void> reencryptAfterEditing({
    required String plainPath,
    required String encryptedPath,
    String? password,
  }) async {
    await encryptBackupFile(
      inputPath: plainPath,
      outputPath: encryptedPath,
      password: password,
    );

    print('\n✅ Process complete!');
    print('Original encrypted file: (unchanged)');
    print('Edited plain file: $plainPath');
    print('New encrypted file: $encryptedPath');
    print('\nYou can now import the new encrypted backup into the app.');
  }

  /// Check if a backup file is encrypted
  Future<void> checkBackupType(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found: $filePath');
      }

      final content = await file.readAsString();
      final isEncrypted = _encryptionService.isEncrypted(content);

      print('File: $filePath');

      if (isEncrypted) {
        final info = _encryptionService.getBackupInfo(content);
        print('Status: ✅ ENCRYPTED');
        print('Format version: ${info?['format_version']}');
        print('Password protected: ${info?['password_protected'] == true ? 'Yes' : 'No'}');
      } else {
        print('Status: ⚠️  PLAIN JSON (not encrypted)');

        // Try to parse as JSON
        try {
          final json = jsonDecode(content);
          if (json is Map<String, dynamic>) {
            print('Schema version: ${json['schemaVersion']}');
            print('Created at: ${json['createdAt']}');
            if (json['collections'] != null) {
              final collections = json['collections'] as Map;
              print('Collections: ${collections.keys.join(', ')}');
            }
          }
        } catch (e) {
          print('⚠️  Invalid JSON format');
        }
      }
    } catch (e) {
      print('❌ Error checking file: $e');
      rethrow;
    }
  }

  /// Validate that edited JSON is valid for import
  Future<bool> validateBackupJson(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ File not found: $filePath');
        return false;
      }

      final content = await file.readAsString();
      final json = jsonDecode(content);

      if (json is! Map<String, dynamic>) {
        print('❌ Invalid format: Root must be a JSON object');
        return false;
      }

      // Check required fields
      if (!json.containsKey('schemaVersion')) {
        print('❌ Missing required field: schemaVersion');
        return false;
      }

      if (!json.containsKey('collections')) {
        print('❌ Missing required field: collections');
        return false;
      }

      if (json['collections'] is! Map<String, dynamic>) {
        print('❌ Invalid format: collections must be an object');
        return false;
      }

      final collections = json['collections'] as Map<String, dynamic>;
      final validCollections = [
        'cold_storages',
        'products',
        'brands',
        'companies',
        'receipts',
        'deliveries',
      ];

      // Validate each collection
      for (final entry in collections.entries) {
        if (!validCollections.contains(entry.key)) {
          print('⚠️  Unknown collection: ${entry.key} (will be skipped on import)');
        }

        if (entry.value is! List) {
          print('❌ Invalid format: ${entry.key} must be an array');
          return false;
        }
      }

      print('✅ Backup JSON is valid');
      print('Schema version: ${json['schemaVersion']}');
      print('Collections: ${collections.keys.join(', ')}');

      return true;
    } catch (e) {
      print('❌ Validation failed: $e');
      return false;
    }
  }
}
