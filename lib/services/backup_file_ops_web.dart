// File: lib/services/backup_file_ops_web.dart
//
// Web implementation of backup file operations. Uses a temporary anchor
// element to trigger file downloads and leverages FilePicker for imports.

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;

import 'backup_file_ops_types.dart';

class _BackupFileOpsWeb implements BackupFileOps {
  @override
  Future<String?> saveBackupFile(String suggestedName, String data) async {
    final bytes = utf8.encode(data);
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..download = suggestedName
      ..click();
    html.Url.revokeObjectUrl(url);
    return 'Downloaded as $suggestedName';
  }

  @override
  Future<BackupFileSelection?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;
    if (file.bytes == null) {
      return null;
    }

    final contents = utf8.decode(file.bytes!);
    return BackupFileSelection(contents: contents, sourceName: file.name);
  }
}

BackupFileOps createBackupFileOps() => _BackupFileOpsWeb();
