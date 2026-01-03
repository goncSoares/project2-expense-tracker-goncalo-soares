import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Image picking and compression service
class ImageService {
  final ImagePicker _picker = ImagePicker();

  /// Compression quality presets
  static const int qualityHigh = 85;
  static const int qualityMedium = 70;
  static const int qualityLow = 50;

  /// Maximum file size (10MB)
  static const int maxFileSizeBytes = 10 * 1024 * 1024;

  /// Pick image from gallery with validation
  Future<File?> pickImageFromGallery({int quality = qualityMedium}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: quality,
      );

      if (image == null) {
        print('No image selected');
        return null;
      }

      final File file = File(image.path);

      // Validate file
      if (!await _validateImage(file)) {
        return null;
      }

      return file;
    } catch (e) {
      print('❌ Error picking image from gallery: $e');
      return null;
    }
  }

  /// Pick image from camera with validation
  Future<File?> pickImageFromCamera({int quality = qualityMedium}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: quality,
      );

      if (image == null) {
        print('No photo taken');
        return null;
      }

      final File file = File(image.path);

      // Validate file
      if (!await _validateImage(file)) {
        return null;
      }

      return file;
    } catch (e) {
      print('❌ Error taking photo: $e');
      return null;
    }
  }

  /// Compress an existing image file
  /// Returns compressed file or null if compression fails
  Future<File?> compressImage(
    File file, {
    int quality = qualityMedium,
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) async {
    try {
      final String targetPath = '${file.parent.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg,
      );

      if (compressedFile == null) {
        print('⚠️ Compression failed');
        return null;
      }

      final File compressed = File(compressedFile.path);
      final int originalSize = await file.length();
      final int compressedSize = await compressed.length();
      final double reduction = ((originalSize - compressedSize) / originalSize * 100);

      print('✅ Compressed: ${_formatFileSize(originalSize)} → ${_formatFileSize(compressedSize)} (${reduction.toStringAsFixed(1)}% reduction)');

      return compressed;
    } catch (e) {
      print('❌ Error compressing image: $e');
      return null;
    }
  }

  /// Get image dimensions
  Future<Map<String, int>?> getImageDimensions(File file) async {
    try {
      final image = await decodeImageFromFile(file);
      return {
        'width': image.width,
        'height': image.height,
      };
    } catch (e) {
      print('❌ Error getting image dimensions: $e');
      return null;
    }
  }

  /// Validate image file
  Future<bool> _validateImage(File file) async {
    try {
      // Check if file exists
      if (!await file.exists()) {
        print('❌ File does not exist');
        return false;
      }

      // Check file size
      final int fileSize = await file.length();
      if (fileSize > maxFileSizeBytes) {
        print('❌ File too large: ${_formatFileSize(fileSize)} (max: ${_formatFileSize(maxFileSizeBytes)})');
        return false;
      }

      // Check file format
      if (!_isValidImageFormat(file.path)) {
        print('❌ Invalid image format. Only JPEG, PNG, and WebP are supported');
        return false;
      }

      print('✅ Image validated: ${_formatFileSize(fileSize)}');
      return true;
    } catch (e) {
      print('❌ Error validating image: $e');
      return false;
    }
  }

  /// Check if file has valid image format
  bool _isValidImageFormat(String path) {
    final String ext = path.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.webp');
  }

  /// Format file size for display
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
    }
  }

  /// Decode image from file (helper for getting dimensions)
  Future<dynamic> decodeImageFromFile(File file) async {
    try {
      // This is a placeholder - in real implementation, you'd use dart:ui
      // or image package to decode the image
      // For now, we'll just return a mock object
      throw UnimplementedError('Image decoding requires dart:ui or image package');
    } catch (e) {
      rethrow;
    }
  }
}