// lib/services/encryption_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for encrypting and decrypting backup data
/// Uses AES-256 encryption with secure key storage
class EncryptionService {
  static const String _keyStorageKey = 'backup_encryption_key';
  static const String _ivStorageKey = 'backup_encryption_iv';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // ─── Key Management ────────────────────────────────────────────────

  /// Generate a new encryption key and IV
  Future<void> generateNewKey() async {
    final key = encrypt.Key.fromSecureRandom(32); // 256-bit key
    final iv = encrypt.IV.fromSecureRandom(16);   // 128-bit IV

    await _secureStorage.write(
      key: _keyStorageKey,
      value: base64Encode(key.bytes),
    );
    await _secureStorage.write(
      key: _ivStorageKey,
      value: base64Encode(iv.bytes),
    );
  }

  /// Get or create encryption key
  Future<encrypt.Key> _getKey() async {
    String? keyString = await _secureStorage.read(key: _keyStorageKey);

    if (keyString == null) {
      // Generate new key if doesn't exist
      await generateNewKey();
      keyString = await _secureStorage.read(key: _keyStorageKey);
    }

    return encrypt.Key(base64Decode(keyString!));
  }

  /// Get or create IV
  Future<encrypt.IV> _getIV() async {
    String? ivString = await _secureStorage.read(key: _ivStorageKey);

    if (ivString == null) {
      // Generate new IV if doesn't exist
      await generateNewKey();
      ivString = await _secureStorage.read(key: _ivStorageKey);
    }

    return encrypt.IV(base64Decode(ivString!));
  }

  /// Set encryption key from password
  /// This allows users to use a memorable password for encryption
  Future<void> setKeyFromPassword(String password) async {
    // Use PBKDF2 to derive a key from password
    final salt = utf8.encode('cold_storage_backup_salt_v1');
    final bytes = utf8.encode(password);

    // Derive 256-bit key from password
    final key = _deriveKey(bytes, salt, 32);
    final iv = _deriveKey(bytes, salt, 16);

    await _secureStorage.write(
      key: _keyStorageKey,
      value: base64Encode(key),
    );
    await _secureStorage.write(
      key: _ivStorageKey,
      value: base64Encode(iv),
    );
  }

  /// Derive key from password using PBKDF2-like approach
  Uint8List _deriveKey(List<int> password, List<int> salt, int length) {
    var hmac = Hmac(sha256, password);
    var digest = hmac.convert(salt);

    // Multiple rounds for better security
    for (int i = 0; i < 10000; i++) {
      digest = hmac.convert(digest.bytes);
    }

    return Uint8List.fromList(digest.bytes.sublist(0, length));
  }

  /// Check if encryption key exists
  Future<bool> hasKey() async {
    final keyString = await _secureStorage.read(key: _keyStorageKey);
    return keyString != null;
  }

  /// Delete encryption keys (use with caution!)
  Future<void> deleteKeys() async {
    await _secureStorage.delete(key: _keyStorageKey);
    await _secureStorage.delete(key: _ivStorageKey);
  }

  // ─── Encryption/Decryption ─────────────────────────────────────────

  /// Encrypt JSON string data
  Future<String> encryptData(String jsonData) async {
    try {
      // Handle empty string - AES-CBC requires minimum data length
      if (jsonData.isEmpty) {
        jsonData = ' '; // Use single space for empty strings
      }

      final key = await _getKey();
      final iv = await _getIV();

      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );

      final encrypted = encrypter.encrypt(jsonData, iv: iv);

      // Return base64 encoded encrypted data
      return encrypted.base64;
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  /// Decrypt data to JSON string
  Future<String> decryptData(String encryptedData) async {
    try {
      final key = await _getKey();
      final iv = await _getIV();

      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );

      final decrypted = encrypter.decrypt64(encryptedData, iv: iv);

      // Handle empty string case (was replaced with space during encryption)
      if (decrypted == ' ') {
        return '';
      }

      return decrypted;
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  /// Encrypt backup file with metadata
  /// Returns encrypted content with header information
  Future<String> encryptBackup({
    required String jsonData,
    required String backupVersion,
  }) async {
    try {
      // Create backup metadata
      final metadata = {
        'version': backupVersion,
        'timestamp': DateTime.now().toIso8601String(),
        'encrypted': true,
        'encryption_algorithm': 'AES-256-CBC',
        'app_version': '1.1.0',
      };

      // Combine metadata and data
      final backupData = {
        'metadata': metadata,
        'data': jsonData,
      };

      final backupJson = jsonEncode(backupData);

      // Encrypt the entire backup
      final encryptedData = await encryptData(backupJson);

      // Create final backup structure with header
      final encryptedBackup = {
        'format': 'cold_storage_encrypted_backup',
        'format_version': '2.0',
        'encrypted_data': encryptedData,
      };

      return jsonEncode(encryptedBackup);
    } catch (e) {
      throw Exception('Backup encryption failed: $e');
    }
  }

  /// Decrypt backup file and extract data
  Future<Map<String, dynamic>> decryptBackup(String encryptedBackupJson) async {
    try {
      final backupStructure = jsonDecode(encryptedBackupJson);

      // Validate format
      if (backupStructure['format'] != 'cold_storage_encrypted_backup') {
        throw Exception('Invalid backup format');
      }

      // Extract encrypted data
      final encryptedData = backupStructure['encrypted_data'] as String;

      // Decrypt
      final decryptedJson = await decryptData(encryptedData);
      final backupData = jsonDecode(decryptedJson);

      // Validate structure
      if (!backupData.containsKey('metadata') ||
          !backupData.containsKey('data')) {
        throw Exception('Invalid backup structure');
      }

      return {
        'metadata': backupData['metadata'],
        'data': backupData['data'],
      };
    } catch (e) {
      throw Exception('Backup decryption failed: $e');
    }
  }

  // ─── Password-Based Operations ─────────────────────────────────────

  /// Encrypt data with a specific password (one-time use)
  Future<String> encryptWithPassword(String data, String password) async {
    // Temporarily store current keys
    final currentKey = await _secureStorage.read(key: _keyStorageKey);
    final currentIV = await _secureStorage.read(key: _ivStorageKey);

    try {
      // Set password-based key
      await setKeyFromPassword(password);

      // Encrypt
      final encrypted = await encryptData(data);

      return encrypted;
    } finally {
      // Restore original keys
      if (currentKey != null) {
        await _secureStorage.write(key: _keyStorageKey, value: currentKey);
      }
      if (currentIV != null) {
        await _secureStorage.write(key: _ivStorageKey, value: currentIV);
      }
    }
  }

  /// Decrypt data with a specific password (one-time use)
  Future<String> decryptWithPassword(
    String encryptedData,
    String password,
  ) async {
    // Temporarily store current keys
    final currentKey = await _secureStorage.read(key: _keyStorageKey);
    final currentIV = await _secureStorage.read(key: _ivStorageKey);

    try {
      // Set password-based key
      await setKeyFromPassword(password);

      // Decrypt
      final decrypted = await decryptData(encryptedData);

      return decrypted;
    } finally {
      // Restore original keys
      if (currentKey != null) {
        await _secureStorage.write(key: _keyStorageKey, value: currentKey);
      }
      if (currentIV != null) {
        await _secureStorage.write(key: _ivStorageKey, value: currentIV);
      }
    }
  }

  // ─── Utility Methods ───────────────────────────────────────────────

  /// Check if data is encrypted
  bool isEncrypted(String data) {
    try {
      final json = jsonDecode(data);
      return json['format'] == 'cold_storage_encrypted_backup' &&
             json.containsKey('encrypted_data');
    } catch (e) {
      return false;
    }
  }

  /// Get backup metadata without decrypting
  Map<String, dynamic>? getBackupInfo(String backupJson) {
    try {
      final backup = jsonDecode(backupJson);

      if (backup['format'] == 'cold_storage_encrypted_backup') {
        return {
          'encrypted': true,
          'format_version': backup['format_version'],
        };
      } else {
        return {
          'encrypted': false,
        };
      }
    } catch (e) {
      return null;
    }
  }

  /// Validate password by attempting decryption
  Future<bool> validatePassword(String encryptedBackupJson, String password) async {
    try {
      final backupStructure = jsonDecode(encryptedBackupJson);
      final encryptedData = backupStructure['encrypted_data'] as String;

      await decryptWithPassword(encryptedData, password);
      return true;
    } catch (e) {
      return false;
    }
  }
}
