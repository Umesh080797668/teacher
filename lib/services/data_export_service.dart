import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class DataExportService {
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Try to request storage permission
      final status = await Permission.storage.request();
      if (status.isGranted) {
        return true;
      } else if (status.isPermanentlyDenied) {
        // Open app settings if permanently denied
        await openAppSettings();
        return false;
      } else {
        // If storage permission is denied, try to use app documents directory as fallback
        return false; // Will use documents directory as fallback
      }
    } else if (Platform.isIOS) {
      // iOS doesn't require explicit storage permission for documents directory
      return true;
    } else {
      return true;
    }
  }

  static Future<String?> exportData() async {
    try {
      // Request storage permissions
      final hasExternalPermission = await requestStoragePermission();

      // Get the directory to save the file
      Directory? directory;
      if (Platform.isAndroid) {
        if (hasExternalPermission) {
          directory = await getExternalStorageDirectory();
        } else {
          // Fallback to app documents directory
          directory = await getApplicationDocumentsDirectory();
          // Create an "Exports" subdirectory
          directory = Directory('${directory.path}/Exports');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not get storage directory');
      }

      // Get all data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final allData = <String, dynamic>{};

      for (var key in prefs.getKeys()) {
        final value = prefs.get(key);
        allData[key] = value;
      }

      // Create export data structure
      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'appVersion': '1.0.0',
        'data': allData,
      };

      // Convert to JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // Create filename with timestamp
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')[0];
      final filename = 'teacher_app_data_$timestamp.json';

      // Save the file
      final file = File('${directory.path}/$filename');
      await file.writeAsString(jsonString);

      debugPrint('Data exported to: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('Error exporting data: $e');
      rethrow;
    }
  }

  static Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('All local data cleared');
    } catch (e) {
      debugPrint('Error clearing data: $e');
      rethrow;
    }
  }
}
