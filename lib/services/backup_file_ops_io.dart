// File: lib/services/backup_file_ops_io.dart
//
// Desktop/mobile implementation of backup file operations.

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'backup_file_ops_types.dart';

class _BackupFileOpsIo implements BackupFileOps {
  @override
  Future<String?> saveBackupFile(String suggestedName, String data) async {
    final selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select backup destination',
    );

    final baseDirectory = await _resolveBaseDirectory(selectedDirectory);
    final filePath = p.join(baseDirectory.path, suggestedName);
    final file = File(filePath);
    await file.create(recursive: true);
    await file.writeAsBytes(utf8.encode(data));
    return file.path;
  }

  @override
  Future<BackupFileSelection?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;
    if (file.path != null) {
      final contents = await File(file.path!).readAsString();
      return BackupFileSelection(contents: contents, sourceName: file.path);
    }

    if (file.bytes != null) {
      final contents = utf8.decode(file.bytes!);
      return BackupFileSelection(
        contents: contents,
        sourceName: file.name,
      );
    }

    return null;
  }

  Future<Directory> _resolveBaseDirectory(String? selectedDirectory) async {
    if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
      return Directory(selectedDirectory);
    }
    return getApplicationDocumentsDirectory();
  }
}

BackupFileOps createBackupFileOps() => _BackupFileOpsIo();
