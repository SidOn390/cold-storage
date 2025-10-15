// File: lib/services/backup_file_ops_stub.dart
//
// Fallback implementation for platforms without specialized file handling.

import 'backup_file_ops_types.dart';

BackupFileOps createBackupFileOps() {
  throw UnsupportedError(
    'Backup file operations are not supported on this platform.',
  );
}
