// scripts/backup_editor_cli.dart
//
// Command-line tool for editing encrypted backups
//
// Usage:
//   dart run scripts/backup_editor_cli.dart <command> [options]
//
// Commands:
//   check     - Check if a backup is encrypted
//   decrypt   - Decrypt backup to plain JSON
//   encrypt   - Encrypt plain JSON to backup
//   validate  - Validate backup JSON format
//
// Examples:
//   dart run scripts/backup_editor_cli.dart check backup.json
//   dart run scripts/backup_editor_cli.dart decrypt backup_encrypted.json backup_plain.json --password "MyPass"
//   dart run scripts/backup_editor_cli.dart encrypt backup_plain.json backup_encrypted.json --password "MyPass"
//   dart run scripts/backup_editor_cli.dart validate backup_plain.json

import 'dart:io';
import 'package:cold_storage/utils/backup_editor.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    printUsage();
    exit(1);
  }

  final command = args[0].toLowerCase();
  final editor = BackupEditor();

  try {
    switch (command) {
      case 'check':
        await handleCheck(editor, args);
        break;

      case 'decrypt':
        await handleDecrypt(editor, args);
        break;

      case 'encrypt':
        await handleEncrypt(editor, args);
        break;

      case 'validate':
        await handleValidate(editor, args);
        break;

      case 'help':
      case '--help':
      case '-h':
        printUsage();
        break;

      default:
        print('❌ Unknown command: $command\n');
        printUsage();
        exit(1);
    }
  } catch (e) {
    print('\n❌ Error: $e');
    exit(1);
  }
}

Future<void> handleCheck(BackupEditor editor, List<String> args) async {
  if (args.length < 2) {
    print('❌ Missing file path');
    print('Usage: dart run scripts/backup_editor_cli.dart check <file>');
    exit(1);
  }

  final filePath = args[1];
  print('Checking backup file...\n');
  await editor.checkBackupType(filePath);
}

Future<void> handleDecrypt(BackupEditor editor, List<String> args) async {
  if (args.length < 3) {
    print('❌ Missing required arguments');
    print('Usage: dart run scripts/backup_editor_cli.dart decrypt <input> <output> [--password "pass"]');
    exit(1);
  }

  final inputPath = args[1];
  final outputPath = args[2];
  final password = getPasswordFromArgs(args);

  print('Decrypting backup...\n');
  await editor.decryptBackupFile(
    inputPath: inputPath,
    outputPath: outputPath,
    password: password,
  );

  print('\n📝 You can now edit: $outputPath');
  print('💡 After editing, run:');
  print('   dart run scripts/backup_editor_cli.dart encrypt $outputPath backup_new.json${password != null ? ' --password "$password"' : ''}');
}

Future<void> handleEncrypt(BackupEditor editor, List<String> args) async {
  if (args.length < 3) {
    print('❌ Missing required arguments');
    print('Usage: dart run scripts/backup_editor_cli.dart encrypt <input> <output> [--password "pass"]');
    exit(1);
  }

  final inputPath = args[1];
  final outputPath = args[2];
  final password = getPasswordFromArgs(args);

  // Validate before encrypting
  print('Validating JSON...\n');
  final isValid = await editor.validateBackupJson(inputPath);

  if (!isValid) {
    print('\n❌ Validation failed. Please fix the JSON and try again.');
    exit(1);
  }

  print('\n✅ Validation passed. Encrypting...\n');
  await editor.encryptBackupFile(
    inputPath: inputPath,
    outputPath: outputPath,
    password: password,
  );

  print('\n✅ Done! You can now import: $outputPath');
}

Future<void> handleValidate(BackupEditor editor, List<String> args) async {
  if (args.length < 2) {
    print('❌ Missing file path');
    print('Usage: dart run scripts/backup_editor_cli.dart validate <file>');
    exit(1);
  }

  final filePath = args[1];
  print('Validating backup JSON...\n');
  final isValid = await editor.validateBackupJson(filePath);

  if (isValid) {
    print('\n✅ Validation passed. File is ready to encrypt.');
    exit(0);
  } else {
    print('\n❌ Validation failed. Please fix the errors and try again.');
    exit(1);
  }
}

String? getPasswordFromArgs(List<String> args) {
  for (int i = 0; i < args.length - 1; i++) {
    if (args[i] == '--password' || args[i] == '-p') {
      return args[i + 1];
    }
  }
  return null;
}

void printUsage() {
  print('''
╔═══════════════════════════════════════════════════════════════╗
║           Cold Storage Backup Editor CLI Tool                ║
╚═══════════════════════════════════════════════════════════════╝

DESCRIPTION:
  Command-line tool for editing encrypted backup files.
  Allows you to decrypt, edit, and re-encrypt backup JSON files.

USAGE:
  dart run scripts/backup_editor_cli.dart <command> [options]

COMMANDS:
  check <file>
      Check if a backup file is encrypted and display info

  decrypt <input> <output> [--password "pass"]
      Decrypt an encrypted backup to plain JSON
      - input:  Path to encrypted backup file
      - output: Path for decrypted JSON file
      - password: Required if backup is password-protected

  encrypt <input> <output> [--password "pass"]
      Encrypt a plain JSON file to backup format
      - input:  Path to plain JSON file
      - output: Path for encrypted backup file
      - password: Optional, for password-based encryption

  validate <file>
      Validate that a JSON file has correct backup structure

  help, --help, -h
      Show this help message

EXAMPLES:

  1. Check if backup is encrypted:
     dart run scripts/backup_editor_cli.dart check backup.json

  2. Decrypt backup (device-based):
     dart run scripts/backup_editor_cli.dart decrypt backup_encrypted.json backup_plain.json

  3. Decrypt backup (password-protected):
     dart run scripts/backup_editor_cli.dart decrypt backup_encrypted.json backup_plain.json --password "MyPass123"

  4. Edit the plain JSON file:
     (Use any text editor to modify backup_plain.json)

  5. Validate your changes:
     dart run scripts/backup_editor_cli.dart validate backup_plain.json

  6. Re-encrypt after editing:
     dart run scripts/backup_editor_cli.dart encrypt backup_plain.json backup_new.json --password "MyPass123"

  7. Import the new backup into the app

WORKFLOW FOR EDITING:

  ┌─────────────────────────────────────────────────────────────┐
  │ 1. Decrypt:  encrypted → plain JSON                        │
  │ 2. Edit:     Modify JSON with text editor                  │
  │ 3. Validate: Check JSON structure is valid                 │
  │ 4. Encrypt:  plain JSON → encrypted                        │
  │ 5. Import:   Use app to restore edited backup              │
  └─────────────────────────────────────────────────────────────┘

NOTES:
  - Device-based encryption uses keys from Flutter Secure Storage
  - Must run on the same device that created the backup (for device-based)
  - Password-based encryption works on any device with the password
  - Always validate JSON after editing before encrypting
  - Keep a backup of original file before editing

SECURITY:
  - Never commit passwords to version control
  - Use strong passwords for password-based encryption
  - Delete plain JSON files after re-encrypting
  - Store encrypted backups securely

For more information, see DATA_ENCRYPTION_MODULE.md
''');
}
