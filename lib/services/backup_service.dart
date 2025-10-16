// File: lib/services/backup_service.dart
//
// Provides manual backup and restore functionality between Firestore and
// local storage.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:cold_storage/services/encryption_service.dart';

import 'backup_file_ops_types.dart';
import 'backup_file_ops_stub.dart'
    if (dart.library.io) 'backup_file_ops_io.dart'
    if (dart.library.html) 'backup_file_ops_web.dart';

class BackupResult {
  BackupResult.success({this.locationMessage})
      : success = true,
        error = null;

  BackupResult.failure(this.error)
      : success = false,
        locationMessage = null;

  final bool success;
  final String? locationMessage;
  final String? error;
}

class RestoreResult {
  RestoreResult.success({this.source})
      : success = true,
        error = null;

  RestoreResult.failure(this.error)
      : success = false,
        source = null;

  final bool success;
  final String? source;
  final String? error;
}

class BackupService {
  BackupService() : _fileOps = createBackupFileOps();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BackupFileOps _fileOps;
  final EncryptionService _encryptionService = EncryptionService();

  static const _schemaVersion = 1;
  static const List<String> _collections = <String>[
    'cold_storages',
    'products',
    'brands',
    'companies',
    'receipts',
    'deliveries',
  ];

  /// Export backup to local storage
  /// Set [encrypt] to true for encrypted backup (default: true)
  /// Optionally provide [password] for password-based encryption
  Future<BackupResult> exportToLocal({
    bool encrypt = true,
    String? password,
  }) async {
    try {
      final payload = await _buildExportPayload();
      final fileName = _buildFileName(encrypted: encrypt);

      String fileContent;

      if (encrypt) {
        // Encrypt the backup
        final jsonString = const JsonEncoder.withIndent('  ').convert(payload);

        if (password != null && password.isNotEmpty) {
          // Use password-based encryption
          final encryptedData = await _encryptionService.encryptWithPassword(
            jsonString,
            password,
          );
          fileContent = jsonEncode({
            'format': 'cold_storage_encrypted_backup',
            'format_version': '2.0',
            'password_protected': true,
            'encrypted_data': encryptedData,
          });
        } else {
          // Use device-based encryption
          fileContent = await _encryptionService.encryptBackup(
            jsonData: jsonString,
            backupVersion: _schemaVersion.toString(),
          );
        }
      } else {
        // Plain JSON backup (not recommended)
        fileContent = const JsonEncoder.withIndent('  ').convert(payload);
      }

      final location = await _fileOps.saveBackupFile(fileName, fileContent);
      if (location == null) {
        return BackupResult.failure('Backup cancelled by user.');
      }
      return BackupResult.success(locationMessage: location);
    } catch (e, st) {
      debugPrint('Backup export failed: $e\n$st');
      return BackupResult.failure('Failed to export backup: $e');
    }
  }

  /// Import backup from local storage
  /// Optionally provide [password] if backup is password-protected
  Future<RestoreResult> importFromLocal({String? password}) async {
    try {
      final selection = await _fileOps.pickBackupFile();
      if (selection == null) {
        return RestoreResult.failure('No backup file selected.');
      }

      // Check if backup is encrypted
      final isEncrypted = _encryptionService.isEncrypted(selection.contents);

      Map<String, dynamic> decoded;

      if (isEncrypted) {
        // Decrypt backup
        try {
          final backupStructure = jsonDecode(selection.contents);
          final isPasswordProtected =
              backupStructure['password_protected'] == true;

          if (isPasswordProtected) {
            // Password-protected backup
            if (password == null || password.isEmpty) {
              return RestoreResult.failure(
                'Backup is password-protected. Please provide password.',
              );
            }

            final encryptedData = backupStructure['encrypted_data'] as String;
            final decryptedJson = await _encryptionService.decryptWithPassword(
              encryptedData,
              password,
            );
            decoded = jsonDecode(decryptedJson);
          } else {
            // Device-based encryption
            final decryptedBackup = await _encryptionService.decryptBackup(
              selection.contents,
            );
            final dataJson = decryptedBackup['data'] as String;
            decoded = jsonDecode(dataJson);
          }
        } on Exception catch (e) {
          return RestoreResult.failure(
            'Failed to decrypt backup. Wrong password or corrupted file: $e',
          );
        }
      } else {
        // Plain JSON backup
        decoded = json.decode(selection.contents);
        if (decoded is! Map<String, dynamic>) {
          return RestoreResult.failure('Backup file has invalid format.');
        }
      }

      _validateSchema(decoded);
      final collections = decoded['collections'] as Map<String, dynamic>;
      for (final entry in collections.entries) {
        if (!_collections.contains(entry.key)) {
          // Skip unknown collections to remain forward compatible.
          continue;
        }
        await _restoreCollection(entry.key, entry.value);
      }

      return RestoreResult.success(source: selection.sourceName);
    } catch (e, st) {
      debugPrint('Backup import failed: $e\n$st');
      return RestoreResult.failure('Failed to import backup: $e');
    }
  }

  Future<Map<String, dynamic>> _buildExportPayload() async {
    final collections = <String, dynamic>{};
    for (final name in _collections) {
      final snapshot = await _firestore.collection(name).get();
      final docs = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                'data': _serializeValue(doc.data()),
              })
          .toList();
      collections[name] = docs;
    }

    return <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'collections': collections,
    };
  }

  String _buildFileName({bool encrypted = true}) {
    final timestamp =
        DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final suffix = encrypted ? 'encrypted' : 'plain';
    return 'cold_storage_backup_${suffix}_$timestamp.json';
  }

  void _validateSchema(Map<String, dynamic> decoded) {
    final version = decoded['schemaVersion'];
    if (version != _schemaVersion) {
      throw FormatException(
        'Unsupported backup version: $version (expected $_schemaVersion)',
      );
    }

    if (decoded['collections'] is! Map<String, dynamic>) {
      throw const FormatException('Backup collections missing or invalid.');
    }
  }

  Future<void> _restoreCollection(String name, Object? value) async {
    if (value is! List) {
      throw FormatException('Collection $name must contain a list of docs.');
    }

    final chunks = <List<Map<String, dynamic>>>[];
    var current = <Map<String, dynamic>>[];

    for (final entry in value) {
      if (entry is! Map<String, dynamic>) {
        throw FormatException('Invalid document entry in $name.');
      }
      current.add(entry);
      if (current.length == 400) {
        chunks.add(current);
        current = <Map<String, dynamic>>[];
      }
    }
    if (current.isNotEmpty) {
      chunks.add(current);
    }

    for (final chunk in chunks) {
      final batch = _firestore.batch();
      for (final docEntry in chunk) {
        final id = docEntry['id'] as String?;
        final data = docEntry['data'];
        if (id == null || data == null) {
          continue;
        }
        final deserialized = _deserializeValue(data);
        final ref = _firestore.collection(name).doc(id);
        batch.set(ref, deserialized as Map<String, dynamic>);
      }
      await batch.commit();
    }
  }

  dynamic _serializeValue(dynamic value) {
    if (value is Timestamp) {
      return {
        '__type__': 'timestamp',
        'value': value.toDate().toUtc().toIso8601String(),
      };
    }
    if (value is GeoPoint) {
      return {
        '__type__': 'geopoint',
        'lat': value.latitude,
        'lng': value.longitude,
      };
    }
    if (value is DocumentReference) {
      return {
        '__type__': 'docRef',
        'path': value.path,
      };
    }
    if (value is Map<String, dynamic>) {
      return value.map(
        (key, nestedValue) => MapEntry(key, _serializeValue(nestedValue)),
      );
    }
    if (value is Iterable) {
      return value.map(_serializeValue).toList();
    }
    return value;
  }

  dynamic _deserializeValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      final marker = value['__type__'];
      if (marker == 'timestamp') {
        final iso = value['value'] as String;
        return Timestamp.fromDate(DateTime.parse(iso).toUtc());
      }
      if (marker == 'geopoint') {
        return GeoPoint(
          (value['lat'] as num).toDouble(),
          (value['lng'] as num).toDouble(),
        );
      }
      if (marker == 'docRef') {
        final path = value['path'] as String;
        return _firestore.doc(path);
      }
      return value.map(
        (key, nested) => MapEntry(key, _deserializeValue(nested)),
      );
    }
    if (value is List) {
      return value.map(_deserializeValue).toList();
    }
    return value;
  }
}
