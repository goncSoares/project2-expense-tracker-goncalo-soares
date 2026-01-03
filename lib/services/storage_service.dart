import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';

/// Local storage service with image compression and file management
class StorageService {
  final Uuid _uuid = const Uuid();

  /// Get base storage directory for user
  Future<Directory> _getUserStorageDir(String userId) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String userPath = '${appDir.path}/users/$userId';
    final Directory userDir = Directory(userPath);

    if (!await userDir.exists()) {
      await userDir.create(recursive: true);
    }

    return userDir;
  }

  /// Compress image file before saving
  Future<File?> _compressImage(File file, {int quality = 70}) async {
    try {
      final String targetPath = '${file.parent.path}/compressed_${_uuid.v4()}.jpg';
      
      final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: 1024,
        minHeight: 1024,
        format: CompressFormat.jpeg,
      );

      if (compressedFile == null) {
        print('⚠️ Compression failed, using original file');
        return file;
      }

      final File compressed = File(compressedFile.path);
      final int originalSize = await file.length();
      final int compressedSize = await compressed.length();
      final double reduction = ((originalSize - compressedSize) / originalSize * 100);

      print('✅ Image compressed: ${(originalSize / 1024).toStringAsFixed(1)}KB → ${(compressedSize / 1024).toStringAsFixed(1)}KB (${reduction.toStringAsFixed(1)}% reduction)');

      return compressed;
    } catch (e) {
      print('❌ Error compressing image: $e');
      return file; // Return original if compression fails
    }
  }

  /// Generic upload image method
  /// [path] - Storage path relative to user directory (e.g., 'profile/avatar.jpg' or 'items/123/image.jpg')
  /// [file] - Image file to upload
  /// [onProgress] - Progress callback (0.0 to 1.0)
  Future<String?> uploadImage(
    String path,
    File file, {
    void Function(double)? onProgress,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      onProgress?.call(0.1);

      // Compress image
      final File? compressedFile = await _compressImage(file);
      if (compressedFile == null) throw Exception('Image compression failed');

      onProgress?.call(0.5);

      // Get user storage directory
      final Directory userDir = await _getUserStorageDir(user.uid);
      final String filePath = '${userDir.path}/$path';

      // Create parent directories if needed
      final File targetFile = File(filePath);
      if (!await targetFile.parent.exists()) {
        await targetFile.parent.create(recursive: true);
      }

      onProgress?.call(0.7);

      // Copy compressed image to target location
      final File savedFile = await compressedFile.copy(filePath);

      // Clean up temporary compressed file if different from original
      if (compressedFile.path != file.path) {
        try {
          await compressedFile.delete();
        } catch (e) {
          print('⚠️ Could not delete temp file: $e');
        }
      }

      onProgress?.call(1.0);

      print('✅ Image saved: $filePath');
      return savedFile.path;
    } catch (e) {
      print('❌ Error uploading image: $e');
      return null;
    }
  }

  /// Upload profile picture with compression
  Future<String?> uploadProfilePicture(
    File file, {
    void Function(double)? onProgress,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Delete old profile picture first
      await deleteProfilePicture(user.uid);

      // Upload new one
      return await uploadImage(
        'profile/avatar.jpg',
        file,
        onProgress: onProgress,
      );
    } catch (e) {
      print('❌ Error uploading profile picture: $e');
      return null;
    }
  }

  /// Upload item/expense image with compression
  Future<String?> uploadItemImage(
    String itemId,
    File file, {
    void Function(double)? onProgress,
  }) async {
    try {
      final uniqueId = _uuid.v4().substring(0, 8);
      final String path = 'items/$itemId/${uniqueId}_image.jpg';

      return await uploadImage(
        path,
        file,
        onProgress: onProgress,
      );
    } catch (e) {
      print('❌ Error uploading item image: $e');
      return null;
    }
  }

  /// Delete image by path
  Future<bool> deleteImage(String filePath) async {
    try {
      final File file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('✅ Image deleted: $filePath');

        // Clean up empty parent directories
        await _cleanupEmptyDirectories(file.parent);
        return true;
      }
      print('⚠️ File not found: $filePath');
      return false;
    } catch (e) {
      print('❌ Error deleting image: $e');
      return false;
    }
  }

  /// Delete user's profile picture
  Future<bool> deleteProfilePicture(String userId) async {
    try {
      final Directory userDir = await _getUserStorageDir(userId);
      final String profilePath = '${userDir.path}/profile/avatar.jpg';
      return await deleteImage(profilePath);
    } catch (e) {
      print('❌ Error deleting profile picture: $e');
      return false;
    }
  }

  /// Delete all images for a specific item
  Future<int> deleteItemImages(String itemId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final Directory userDir = await _getUserStorageDir(user.uid);
      final Directory itemDir = Directory('${userDir.path}/items/$itemId');

      if (!await itemDir.exists()) {
        print('⚠️ Item directory not found: ${itemDir.path}');
        return 0;
      }

      int deletedCount = 0;
      await for (final entity in itemDir.list()) {
        if (entity is File) {
          await entity.delete();
          deletedCount++;
        }
      }

      // Delete the item directory itself
      await itemDir.delete();
      print('✅ Deleted $deletedCount images for item $itemId');

      return deletedCount;
    } catch (e) {
      print('❌ Error deleting item images: $e');
      return 0;
    }
  }

  /// Get all images for a user
  Future<List<String>> getUserImages(String userId) async {
    try {
      final Directory userDir = await _getUserStorageDir(userId);
      final List<String> imagePaths = [];

      if (!await userDir.exists()) {
        return imagePaths;
      }

      await for (final entity in userDir.list(recursive: true)) {
        if (entity is File && _isImageFile(entity.path)) {
          imagePaths.add(entity.path);
        }
      }

      print('📁 Found ${imagePaths.length} images for user $userId');
      return imagePaths;
    } catch (e) {
      print('❌ Error getting user images: $e');
      return [];
    }
  }

  /// Get all images for a specific item
  Future<List<String>> getItemImages(String itemId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final Directory userDir = await _getUserStorageDir(user.uid);
      final Directory itemDir = Directory('${userDir.path}/items/$itemId');
      final List<String> imagePaths = [];

      if (!await itemDir.exists()) {
        return imagePaths;
      }

      await for (final entity in itemDir.list()) {
        if (entity is File && _isImageFile(entity.path)) {
          imagePaths.add(entity.path);
        }
      }

      print('📁 Found ${imagePaths.length} images for item $itemId');
      return imagePaths;
    } catch (e) {
      print('❌ Error getting item images: $e');
      return [];
    }
  }

  /// Cleanup orphaned files (images for items that no longer exist)
  /// [validItemIds] - List of item IDs that should have images
  Future<int> cleanupOrphanedFiles(String userId, List<String> validItemIds) async {
    try {
      final Directory userDir = await _getUserStorageDir(userId);
      final Directory itemsDir = Directory('${userDir.path}/items');

      if (!await itemsDir.exists()) {
        print('⚠️ Items directory not found');
        return 0;
      }

      int deletedCount = 0;

      await for (final entity in itemsDir.list()) {
        if (entity is Directory) {
          final String itemId = entity.path.split(Platform.pathSeparator).last;

          // If this item ID is not in the valid list, delete it
          if (!validItemIds.contains(itemId)) {
            print('🗑️ Deleting orphaned files for item: $itemId');
            await entity.delete(recursive: true);
            deletedCount++;
          }
        }
      }

      print('✅ Cleaned up $deletedCount orphaned item directories');
      return deletedCount;
    } catch (e) {
      print('❌ Error cleaning up orphaned files: $e');
      return 0;
    }
  }

  /// Get file size in bytes
  Future<int> getFileSize(String filePath) async {
    try {
      final File file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      print('❌ Error getting file size: $e');
      return 0;
    }
  }

  /// Get total storage used by user (in bytes)
  Future<int> getTotalStorageUsed(String userId) async {
    try {
      final List<String> images = await getUserImages(userId);
      int totalBytes = 0;

      for (final imagePath in images) {
        totalBytes += await getFileSize(imagePath);
      }

      print('📊 Total storage used: ${(totalBytes / 1024 / 1024).toStringAsFixed(2)} MB');
      return totalBytes;
    } catch (e) {
      print('❌ Error calculating total storage: $e');
      return 0;
    }
  }

  /// Check if file exists
  Future<bool> fileExists(String filePath) async {
    try {
      return await File(filePath).exists();
    } catch (e) {
      return false;
    }
  }

  /// Helper: Check if file is an image based on extension
  bool _isImageFile(String path) {
    final String ext = path.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.webp');
  }

  /// Helper: Clean up empty directories recursively
  Future<void> _cleanupEmptyDirectories(Directory dir) async {
    try {
      if (!await dir.exists()) return;

      final List<FileSystemEntity> contents = await dir.list().toList();

      // If directory is empty, delete it
      if (contents.isEmpty) {
        await dir.delete();
        print('🗑️ Removed empty directory: ${dir.path}');

        // Recursively check parent directory
        final Directory parent = dir.parent;
        if (parent.path != (await getApplicationDocumentsDirectory()).path) {
          await _cleanupEmptyDirectories(parent);
        }
      }
    } catch (e) {
      print('⚠️ Error cleaning up directory: $e');
    }
  }
}