import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== PROFILE PICTURES ====================

  /// Upload profile picture with progress tracking
  /// Path: users/{userId}/profile/avatar.jpg
  Future<String?> uploadProfilePicture(
      File imageFile, {
        Function(double)? onProgress,
      }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('No user logged in');
      }

      // User-specific directory
      final String storagePath = 'users/$userId/profile/avatar.jpg';
      final storageRef = _storage.ref().child(storagePath);

      // Upload with progress tracking
      final uploadTask = storageRef.putFile(imageFile);

      // Listen to progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      // Wait for upload to complete
      await uploadTask;

      // Get download URL
      final downloadUrl = await storageRef.getDownloadURL();

      print('Profile picture uploaded: $downloadUrl');
      return downloadUrl;
    } on FirebaseException catch (e) {
      print('Firebase upload error: ${e.message}');
      throw Exception('Failed to upload profile picture: ${e.message}');
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  /// Delete profile picture
  Future<void> deleteProfilePicture() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final String storagePath = 'users/$userId/profile/avatar.jpg';
      await _storage.ref().child(storagePath).delete();

      print('Profile picture deleted');
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        print('Profile picture does not exist');
        return;
      }
      print('Delete error: ${e.message}');
    }
  }

  // ==================== EXPENSE RECEIPTS (items) ====================

  /// Upload receipt image for expense
  /// Path: users/{userId}/items/{expenseId}/receipt_{timestamp}.jpg
  Future<String?> uploadReceiptImage({
    required String expenseId,
    required File imageFile,
    Function(double)? onProgress,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('No user logged in');
      }

      // Generate unique filename with timestamp
      final String fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // User-specific directory structure: users/{userId}/items/{expenseId}/
      final String storagePath = 'users/$userId/items/$expenseId/$fileName';
      final storageRef = _storage.ref().child(storagePath);

      // Upload with progress
      final uploadTask = storageRef.putFile(imageFile);

      // Track progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      // Wait for completion
      await uploadTask;

      // Get download URL
      final downloadUrl = await storageRef.getDownloadURL();

      print('Receipt uploaded: $downloadUrl');
      return downloadUrl;
    } on FirebaseException catch (e) {
      print('Firebase upload error: ${e.message}');
      throw Exception('Failed to upload receipt: ${e.message}');
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  /// Delete specific receipt image by URL
  Future<void> deleteReceiptImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      print('Receipt deleted: $imageUrl');
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        print('Receipt does not exist');
        return;
      }
      print('Delete error: ${e.message}');
    }
  }

  /// Delete all receipts for a specific expense (cleanup orphaned files)
  /// Called when expense is deleted
  Future<void> deleteExpenseReceipts(String expenseId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final String storagePath = 'users/$userId/items/$expenseId/';
      final listResult = await _storage.ref().child(storagePath).listAll();

      // Delete all files in the expense folder
      for (var item in listResult.items) {
        await item.delete();
        print('Deleted: ${item.fullPath}');
      }

      print('All receipts deleted for expense: $expenseId');
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        print('No receipts found for expense: $expenseId');
        return;
      }
      print('Delete error: ${e.message}');
    }
  }

  /// Get all receipt URLs for a specific expense
  Future<List<String>> getExpenseReceipts(String expenseId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final String storagePath = 'users/$userId/items/$expenseId/';
      final listResult = await _storage.ref().child(storagePath).listAll();

      List<String> urls = [];
      for (var item in listResult.items) {
        final url = await item.getDownloadURL();
        urls.add(url);
      }

      print('Found ${urls.length} receipts for expense: $expenseId');
      return urls;
    } on FirebaseException catch (e) {
      print('Get receipts error: ${e.message}');
      return [];
    }
  }

  // ==================== GENERIC METHODS (Required in spec) ====================

  /// Generic upload image method with progress
  Future<String?> uploadImage(
      String path,
      File file, {
        Function(double)? onProgress,
      }) async {
    try {
      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(file);

      // Progress tracking
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      // Wait for upload
      await uploadTask;

      // Get URL
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } on FirebaseException catch (e) {
      print('Upload failed: ${e.message}');
      throw Exception('Upload failed: ${e.message}');
    }
  }

  /// Generic delete image method
  Future<void> deleteImage(String path) async {
    try {
      await _storage.ref().child(path).delete();
      print('Image deleted: $path');
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        print('Image not found: $path');
        return;
      }
      print('Delete failed: ${e.message}');
    }
  }

  /// Get all images for a user (all directories)
  Future<List<String>> getUserImages(String userId) async {
    try {
      final String storagePath = 'users/$userId/';
      final listResult = await _storage.ref().child(storagePath).listAll();

      List<String> urls = [];

      // Get all files in root user directory
      for (var item in listResult.items) {
        final url = await item.getDownloadURL();
        urls.add(url);
      }

      // Get files from subdirectories (profile, items)
      for (var prefix in listResult.prefixes) {
        final subResult = await _getAllFilesInDirectory(prefix);
        urls.addAll(subResult);
      }

      print('Found ${urls.length} total images for user: $userId');
      return urls;
    } on FirebaseException catch (e) {
      print('Get user images error: ${e.message}');
      return [];
    }
  }

  /// Helper: Get all files in directory recursively
  Future<List<String>> _getAllFilesInDirectory(Reference dirRef) async {
    List<String> urls = [];

    final listResult = await dirRef.listAll();

    // Get all files
    for (var item in listResult.items) {
      final url = await item.getDownloadURL();
      urls.add(url);
    }

    // Recursively get files from subdirectories
    for (var prefix in listResult.prefixes) {
      final subUrls = await _getAllFilesInDirectory(prefix);
      urls.addAll(subUrls);
    }

    return urls;
  }

  // ==================== CLEANUP & VALIDATION ====================

  /// Delete all user data (GDPR compliance / account deletion)
  Future<void> deleteAllUserData(String userId) async {
    try {
      final String storagePath = 'users/$userId/';
      await _deleteDirectoryRecursive(storagePath);
      print('All data deleted for user: $userId');
    } catch (e) {
      print('Delete user data error: $e');
      throw Exception('Failed to delete user data: $e');
    }
  }

  /// Helper: Delete directory recursively
  Future<void> _deleteDirectoryRecursive(String path) async {
    final dirRef = _storage.ref().child(path);
    final listResult = await dirRef.listAll();

    // Delete all files
    for (var item in listResult.items) {
      await item.delete();
    }

    // Delete subdirectories recursively
    for (var prefix in listResult.prefixes) {
      await _deleteDirectoryRecursive(prefix.fullPath);
    }
  }

  /// Validate file is an image
  bool isValidImageFile(File file) {
    final validExtensions = ['.jpg', '.jpeg', '.png', '.heic', '.webp'];
    final extension = file.path.toLowerCase().split('.').last;
    return validExtensions.contains('.$extension');
  }

  /// Get file size in MB
  Future<double> getFileSizeInMB(File file) async {
    final bytes = await file.length();
    return bytes / (1024 * 1024);
  }

  /// Cleanup orphaned files (files without corresponding Firestore documents)
  /// Call this periodically or on app maintenance
  Future<void> cleanupOrphanedFiles(List<String> activeExpenseIds) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final String itemsPath = 'users/$userId/items/';
      final listResult = await _storage.ref().child(itemsPath).listAll();

      // Check each expense folder
      for (var expenseFolder in listResult.prefixes) {
        final expenseId = expenseFolder.name;

        // If expense doesn't exist in Firestore, delete its files
        if (!activeExpenseIds.contains(expenseId)) {
          print('Cleaning up orphaned files for expense: $expenseId');
          await deleteExpenseReceipts(expenseId);
        }
      }

      print('Cleanup completed');
    } catch (e) {
      print('Cleanup error: $e');
    }
  }
}