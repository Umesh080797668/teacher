import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<bool> performBackup() async {
    if (!_autoBackupEnabled) return false;

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
        'data': allData,
      };

      // In a real app, you would upload this to cloud storage
      // For now, we'll just save it locally
      final backupString = jsonEncode(backupData);
      await prefs.setString('last_backup_data', backupString);

      _lastBackupTime = DateTime.now();
      await prefs.setString(
        'last_backup_time',
        _lastBackupTime!.toIso8601String(),
      );

      debugPrint('Backup completed successfully at $_lastBackupTime');
      return true;
    } catch (e) {
      debugPrint('Backup failed: $e');
      return false;
    }
  }

  Future<bool> restoreBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupString = prefs.getString('last_backup_data');

      if (backupString == null) {
        debugPrint('No backup data found');
        return false;
      }

      final backupData = jsonDecode(backupString) as Map<String, dynamic>;
      final data = backupData['data'] as Map<String, dynamic>;

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
        } else if (value is List<String>) {
          await prefs.setStringList(entry.key, value);
        }
      }

      debugPrint('Backup restored successfully');
      return true;
    } catch (e) {
      debugPrint('Restore failed: $e');
      return false;
    }
  }
}
