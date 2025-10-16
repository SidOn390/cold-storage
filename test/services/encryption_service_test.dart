// test/services/encryption_service_test.dart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:cold_storage/services/encryption_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the secure storage methods
  FlutterSecureStorage.setMockInitialValues({});

  group('EncryptionService Tests', () {
    late EncryptionService encryptionService;

    setUp(() {
      encryptionService = EncryptionService();
      // Reset mock storage between tests
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('Can encrypt and decrypt simple text', () async {
      const testData = 'Hello, World!';

      final encrypted = await encryptionService.encryptData(testData);
      expect(encrypted, isNotEmpty);
      expect(encrypted, isNot(equals(testData)));

      final decrypted = await encryptionService.decryptData(encrypted);
      expect(decrypted, equals(testData));
    });

    test('Encrypted data is different from original', () async {
      const testData = 'Sensitive information';

      final encrypted = await encryptionService.encryptData(testData);

      expect(encrypted, isNot(contains('Sensitive')));
      expect(encrypted, isNot(contains('information')));
    });

    test('Can encrypt and decrypt JSON data', () async {
      const jsonData = '{"name":"Test","value":123,"active":true}';

      final encrypted = await encryptionService.encryptData(jsonData);
      final decrypted = await encryptionService.decryptData(encrypted);

      expect(decrypted, equals(jsonData));
    });

    test('Can encrypt and decrypt long text', () async {
      final longText = 'A' * 10000; // 10,000 characters

      final encrypted = await encryptionService.encryptData(longText);
      final decrypted = await encryptionService.decryptData(encrypted);

      expect(decrypted, equals(longText));
      expect(decrypted.length, equals(10000));
    });

    test('Can encrypt and decrypt special characters', () async {
      const specialText = '!@#\$%^&*()_+-=[]{}|;:",.<>?/~`àéîôù中文日本語';

      final encrypted = await encryptionService.encryptData(specialText);
      final decrypted = await encryptionService.decryptData(encrypted);

      expect(decrypted, equals(specialText));
    });

    test('Can encrypt and decrypt empty string', () async {
      const emptyString = '';

      final encrypted = await encryptionService.encryptData(emptyString);
      final decrypted = await encryptionService.decryptData(encrypted);

      expect(decrypted, equals(emptyString));
    });

    test('Encrypted data is base64 encoded', () async {
      const testData = 'Test data';

      final encrypted = await encryptionService.encryptData(testData);

      // Base64 should only contain these characters
      final base64Pattern = RegExp(r'^[A-Za-z0-9+/=]+$');
      expect(base64Pattern.hasMatch(encrypted), true);
    });

    test('Same data produces different encrypted output (with different IV)',
        () async {
      const testData = 'Consistent data';

      // Generate new keys to get different IV
      await encryptionService.generateNewKey();
      final encrypted1 = await encryptionService.encryptData(testData);

      await encryptionService.generateNewKey();
      final encrypted2 = await encryptionService.encryptData(testData);

      // With different keys/IVs, encryption should produce different results
      expect(encrypted1, isNot(equals(encrypted2)));
    });

    test('isEncrypted identifies encrypted backup correctly', () {
      const encryptedBackup = '{"format":"cold_storage_encrypted_backup",'
          '"encrypted_data":"test"}';
      const plainBackup = '{"schemaVersion":1,"collections":{}}';

      expect(encryptionService.isEncrypted(encryptedBackup), true);
      expect(encryptionService.isEncrypted(plainBackup), false);
    });

    test('isEncrypted handles invalid JSON', () {
      const invalidJson = 'Not valid JSON';

      expect(encryptionService.isEncrypted(invalidJson), false);
    });

    test('getBackupInfo extracts info from encrypted backup', () {
      const encryptedBackup = '{"format":"cold_storage_encrypted_backup",'
          '"format_version":"2.0","encrypted_data":"test"}';

      final info = encryptionService.getBackupInfo(encryptedBackup);

      expect(info, isNotNull);
      expect(info!['encrypted'], true);
      expect(info['format_version'], '2.0');
    });

    test('getBackupInfo extracts info from plain backup', () {
      const plainBackup = '{"schemaVersion":1}';

      final info = encryptionService.getBackupInfo(plainBackup);

      expect(info, isNotNull);
      expect(info!['encrypted'], false);
    });

    test('getBackupInfo returns null for invalid JSON', () {
      const invalidJson = 'Invalid';

      final info = encryptionService.getBackupInfo(invalidJson);

      expect(info, isNull);
    });

    group('Password-Based Encryption Tests', () {
      test('Can encrypt and decrypt with password', () async {
        const testData = 'Password protected data';
        const password = 'MySecurePassword123!';

        final encrypted = await encryptionService.encryptWithPassword(
          testData,
          password,
        );
        final decrypted = await encryptionService.decryptWithPassword(
          encrypted,
          password,
        );

        expect(decrypted, equals(testData));
      });

      test('Cannot decrypt with wrong password', () async {
        const testData = 'Secret data';
        const correctPassword = 'CorrectPass123';
        const wrongPassword = 'WrongPass456';

        final encrypted = await encryptionService.encryptWithPassword(
          testData,
          correctPassword,
        );

        expect(
          () => encryptionService.decryptWithPassword(encrypted, wrongPassword),
          throwsException,
        );
      });

      test('Same password produces consistent results', () async {
        const testData = 'Consistent data';
        const password = 'SamePassword123';

        final encrypted1 = await encryptionService.encryptWithPassword(
          testData,
          password,
        );
        final encrypted2 = await encryptionService.encryptWithPassword(
          testData,
          password,
        );

        // Same password should derive same key, producing same encryption
        expect(encrypted1, equals(encrypted2));
      });

      test('Different passwords produce different encrypted data', () async {
        const testData = 'Same data';
        const password1 = 'Password1';
        const password2 = 'Password2';

        final encrypted1 = await encryptionService.encryptWithPassword(
          testData,
          password1,
        );
        final encrypted2 = await encryptionService.encryptWithPassword(
          testData,
          password2,
        );

        expect(encrypted1, isNot(equals(encrypted2)));
      });

      test('Empty password works but is not secure', () async {
        const testData = 'Data';
        const emptyPassword = '';

        final encrypted = await encryptionService.encryptWithPassword(
          testData,
          emptyPassword,
        );
        final decrypted = await encryptionService.decryptWithPassword(
          encrypted,
          emptyPassword,
        );

        expect(decrypted, equals(testData));
      });

      test('Special characters in password work correctly', () async {
        const testData = 'Data';
        const complexPassword = '!@#\$%^&*()_+-=[]{}|;:",.<>?/~`';

        final encrypted = await encryptionService.encryptWithPassword(
          testData,
          complexPassword,
        );
        final decrypted = await encryptionService.decryptWithPassword(
          encrypted,
          complexPassword,
        );

        expect(decrypted, equals(testData));
      });

      test('Unicode characters in password work correctly', () async {
        const testData = 'Data';
        const unicodePassword = 'Password密码パスワード🔒';

        final encrypted = await encryptionService.encryptWithPassword(
          testData,
          unicodePassword,
        );
        final decrypted = await encryptionService.decryptWithPassword(
          encrypted,
          unicodePassword,
        );

        expect(decrypted, equals(testData));
      });
    });

    group('Backup Encryption Tests', () {
      test('Can encrypt and decrypt backup with metadata', () async {
        const jsonData = '{"test":"data","value":123}';
        const backupVersion = '1';

        final encrypted = await encryptionService.encryptBackup(
          jsonData: jsonData,
          backupVersion: backupVersion,
        );

        expect(encrypted, contains('cold_storage_encrypted_backup'));

        final decrypted = await encryptionService.decryptBackup(encrypted);

        expect(decrypted['data'], equals(jsonData));
        expect(decrypted['metadata'], isNotNull);
        expect(decrypted['metadata']['version'], equals(backupVersion));
        expect(decrypted['metadata']['encrypted'], true);
      });

      test('Encrypted backup contains metadata', () async {
        const jsonData = '{"test":"data"}';
        const backupVersion = '1';

        final encrypted = await encryptionService.encryptBackup(
          jsonData: jsonData,
          backupVersion: backupVersion,
        );

        final decrypted = await encryptionService.decryptBackup(encrypted);
        final metadata = decrypted['metadata'] as Map<String, dynamic>;

        expect(metadata['version'], equals(backupVersion));
        expect(metadata['encrypted'], true);
        expect(metadata['encryption_algorithm'], equals('AES-256-CBC'));
        expect(metadata['timestamp'], isNotNull);
      });

      test('Cannot decrypt backup with invalid format', () async {
        const invalidBackup = '{"format":"wrong_format","data":"test"}';

        expect(
          () => encryptionService.decryptBackup(invalidBackup),
          throwsException,
        );
      });

      test('Cannot decrypt backup with missing encrypted_data', () async {
        const invalidBackup =
            '{"format":"cold_storage_encrypted_backup","format_version":"2.0"}';

        expect(
          () => encryptionService.decryptBackup(invalidBackup),
          throwsException,
        );
      });
    });

    group('Error Handling Tests', () {
      test('Decrypting invalid base64 throws exception', () async {
        const invalidEncrypted = 'Not valid base64!!!###';

        expect(
          () => encryptionService.decryptData(invalidEncrypted),
          throwsException,
        );
      });

      test('Decrypting corrupted data throws exception', () async {
        const corruptedData = 'VGhpcyBpcyBjb3JydXB0ZWQgZGF0YQ==';

        expect(
          () => encryptionService.decryptData(corruptedData),
          throwsException,
        );
      });
    });
  });
}
