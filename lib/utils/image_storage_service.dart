import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageStorageService {
  static const String profilePicturesFolder = 'profile_pictures';

  /// Get the directory for storing profile pictures
  static Future<Directory> _getProfilePicturesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final profileDir = Directory(path.join(appDir.path, profilePicturesFolder));

    if (!await profileDir.exists()) {
      await profileDir.create(recursive: true);
    }

    return profileDir;
  }

  /// Save a profile picture to device storage
  /// Returns the local file path of the saved image
  static Future<String> saveProfilePicture(File imageFile, String teacherId) async {
    final profileDir = await _getProfilePicturesDirectory();

    // Generate filename with teacher ID and timestamp
    final fileName = '${teacherId}_profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final filePath = path.join(profileDir.path, fileName);

    // Copy the image file to the profile pictures directory
    await imageFile.copy(filePath);

    return filePath;
  }

  /// Delete an old profile picture if it exists
  static Future<void> deleteOldProfilePicture(String? oldImagePath) async {
    if (oldImagePath == null || oldImagePath.isEmpty) return;

    try {
      final file = File(oldImagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Log error but don't throw - this shouldn't break the profile update
      print('Error deleting old profile picture: $e');
    }
  }

  /// Get the profile picture file for a teacher
  static Future<File?> getProfilePicture(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return null;

    try {
      final file = File(imagePath);
      if (await file.exists()) {
        return file;
      }
    } catch (e) {
      print('Error getting profile picture: $e');
    }

    return null;
  }

  /// Check if a profile picture exists
  static Future<bool> profilePictureExists(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return false;

    try {
      final file = File(imagePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
}