// File: lib/services/backup_file_ops_web.dart
//
// Web implementation of backup file operations. Uses browser download API
// for exports and FilePicker for imports with comprehensive error handling.

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

import 'backup_file_ops_types.dart';

class _BackupFileOpsWeb implements BackupFileOps {
  @override
  Future<String?> saveBackupFile(String suggestedName, String data) async {
    try {
      final bytes = utf8.encode(data);
      final blob = html.Blob([bytes], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);

      // Create a temporary anchor element and trigger download
      final anchor = html.AnchorElement(href: url)
        ..download = suggestedName
        ..style.display = 'none';

      html.document.body?.append(anchor);
      anchor.click();

      // Clean up
      anchor.remove();
      html.Url.revokeObjectUrl(url);

      debugPrint('✅ Web backup file saved: $suggestedName');
      return 'Downloaded as $suggestedName';
    } catch (e, stackTrace) {
      debugPrint('❌ Web backup save failed: $e');
      debugPrint(stackTrace.toString());
      // Return null to indicate failure
      return null;
    }
  }

  @override
  Future<BackupFileSelection?> pickBackupFile() async {
    try {
      debugPrint('📂 Opening file picker for backup restore...');

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
        dialogTitle: 'Select Backup File',
        allowMultiple: false,
      );

      // User cancelled the picker
      if (result == null) {
        debugPrint('ℹ️ File picker cancelled by user');
        return null;
      }

      // No files selected (shouldn't happen with allowMultiple: false)
      if (result.files.isEmpty) {
        debugPrint('⚠️ No files selected from picker');
        return null;
      }

      final file = result.files.first;

      // File data not available (shouldn't happen with withData: true)
      if (file.bytes == null) {
        debugPrint('❌ File bytes not available: ${file.name}');
        throw Exception('Could not read file data. Please try again.');
      }

      // Validate file size (prevent loading huge files that could crash the browser)
      const maxSizeBytes = 50 * 1024 * 1024; // 50 MB
      if (file.bytes!.length > maxSizeBytes) {
        debugPrint('❌ File too large: ${file.bytes!.length} bytes');
        throw Exception(
          'File is too large (${(file.bytes!.length / 1024 / 1024).toStringAsFixed(1)} MB). Maximum size is 50 MB.',
        );
      }

      // Decode UTF-8 content
      String contents;
      try {
        contents = utf8.decode(file.bytes!);
      } catch (e) {
        debugPrint('❌ UTF-8 decode failed: $e');
        throw Exception('Invalid file encoding. Expected UTF-8 JSON file.');
      }

      // Basic JSON validation
      try {
        final decoded = json.decode(contents);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object at root');
        }
      } catch (e) {
        debugPrint('❌ JSON validation failed: $e');
        throw Exception('Invalid JSON file. Please select a valid backup file.');
      }

      debugPrint('✅ Backup file loaded: ${file.name} (${file.bytes!.length} bytes)');
      return BackupFileSelection(
        contents: contents,
        sourceName: file.name,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Backup file pick failed: $e');
      debugPrint(stackTrace.toString());
      // Re-throw other exceptions so they can be shown to the user
      rethrow;
    }
  }
}

BackupFileOps createBackupFileOps() => _BackupFileOpsWeb();
