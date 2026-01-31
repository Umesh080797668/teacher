import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

// Helper functions for compute
String _encodeBackupData(Map<String, dynamic> backupData) {
  return const JsonEncoder.withIndent('  ').convert(backupData);
}

Map<String, dynamic> _decodeBackupData(String backupString) {
  return jsonDecode(backupString) as Map<String, dynamic>;
}

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  bool _autoBackupEnabled = true;
  DateTime? _lastBackupTime;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _autoBackupEnabled = prefs.getBool('auto_backup') ?? true;
    final lastBackupString = prefs.getString('last_backup_time');
    if (lastBackupString != null) {
      _lastBackupTime = DateTime.parse(lastBackupString);
    }
  }

  Future<void> setAutoBackup(bool enabled) async {
    _autoBackupEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup', enabled);

    if (enabled) {
      // Trigger immediate backup when enabled
      await performBackup();
    }
  }

  bool get isEnabled => _autoBackupEnabled;
  DateTime? get lastBackupTime => _lastBackupTime;

  /// Get the backup directory
  Future<Directory> getBackupDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// Perform backup to local file
  Future<String?> performBackup({String? customName}) async {
    if (!_autoBackupEnabled && customName == null) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final allData = <String, dynamic>{};

      // Collect all data
      for (var key in prefs.getKeys()) {
        final value = prefs.get(key);
        allData[key] = value;
      }

      // Create backup structure
      final backupData = {
        'backupDate': DateTime.now().toIso8601String(),
        'version': '1.0.0',
        'deviceInfo': {
          'platform': Platform.operatingSystem,
          'version': Platform.operatingSystemVersion,
        },
        'data': allData,
      };

      // Save to file
      final backupDir = await getBackupDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final filename = customName ?? 'backup_$timestamp.json';
      final file = File('${backupDir.path}/$filename');

      final jsonString = await compute(_encodeBackupData, backupData);
      await file.writeAsString(jsonString);

      _lastBackupTime = DateTime.now();
      await prefs.setString(
        'last_backup_time',
        _lastBackupTime!.toIso8601String(),
      );
      await prefs.setString('last_backup_file', file.path);

      debugPrint('Backup completed successfully at $_lastBackupTime');
      debugPrint('Backup saved to: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('Backup failed: $e');
      return null;
    }
  }

  /// Get list of all backup files
  Future<List<File>> getBackupFiles() async {
    try {
      final backupDir = await getBackupDirectory();
      final files = await backupDir.list().where((entity) {
        return entity is File && entity.path.endsWith('.json');
      }).cast<File>().toList();

      // Sort by modification date (newest first)
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      return files;
    } catch (e) {
      debugPrint('Error listing backup files: $e');
      return [];
    }
  }

  /// Restore from a specific backup file
  Future<bool> restoreBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('Backup file not found: $filePath');
        return false;
      }

      final backupString = await file.readAsString();
      final backupData = await compute(_decodeBackupData, backupString);
      final data = backupData['data'] as Map<String, dynamic>;

      final prefs = await SharedPreferences.getInstance();

      // Clear existing data first
      await prefs.clear();

      // Restore data
      for (var entry in data.entries) {
        final value = entry.value;
        if (value is bool) {
          await prefs.setBool(entry.key, value);
        } else if (value is int) {
          await prefs.setInt(entry.key, value);
        } else if (value is double) {
          await prefs.setDouble(entry.key, value);
        } else if (value is String) {
          await prefs.setString(entry.key, value);
        } else if (value is List) {
          await prefs.setStringList(entry.key, value.cast<String>());
        }
      }

      debugPrint('Backup restored successfully from: $filePath');
      return true;
    } catch (e) {
      debugPrint('Restore failed: $e');
      return false;
    }
  }

  /// Export backup to a shareable location
  Future<String?> exportBackup(String backupFilePath) async {
    try {
      final sourceFile = File(backupFilePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      // Get external storage directory for export
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        return null;
      }

      final exportDir = Directory('${externalDir.path}/TeacherAppBackups');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final filename = sourceFile.path.split('/').last;
      final exportFile = File('${exportDir.path}/$filename');

      await sourceFile.copy(exportFile.path);

      debugPrint('Backup exported to: ${exportFile.path}');
      return exportFile.path;
    } catch (e) {
      debugPrint('Export failed: $e');
      return null;
    }
  }

  /// Import backup from external file
  Future<String?> importBackup(String externalFilePath) async {
    try {
      final sourceFile = File(externalFilePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      // Copy to internal backup directory
      final backupDir = await getBackupDirectory();
      final filename = 'imported_${DateTime.now().millisecondsSinceEpoch}.json';
      final destFile = File('${backupDir.path}/$filename');

      await sourceFile.copy(destFile.path);

      debugPrint('Backup imported to: ${destFile.path}');
      return destFile.path;
    } catch (e) {
      debugPrint('Import failed: $e');
      return null;
    }
  }

  /// Delete a backup file
  Future<bool> deleteBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Backup deleted: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Delete backup failed: $e');
      return false;
    }
  }
}
