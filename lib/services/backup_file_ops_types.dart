// File: lib/services/backup_file_ops_types.dart
//
// Shared types for platform-specific backup file operations.

class BackupFileSelection {
  BackupFileSelection({required this.contents, this.sourceName});

  final String contents;
  final String? sourceName;
}

abstract class BackupFileOps {
  Future<String?> saveBackupFile(String suggestedName, String data);
  Future<BackupFileSelection?> pickBackupFile();
}
