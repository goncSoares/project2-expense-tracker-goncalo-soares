import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();

  /// Pick image from gallery
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,      // Compression - limit size
        maxHeight: 1024,
        imageQuality: 70,    // Compression - 70% quality
      );

      if (image == null) {
        print('No image selected');
        return null;
      }

      return File(image.path);
    } catch (e) {
      print('Error picking image from gallery: $e');
      return null;
    }
  }

  /// Pick image from camera
  Future<File?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );

      if (image == null) {
        print('No photo taken');
        return null;
      }

      return File(image.path);
    } catch (e) {
      print('Error taking photo: $e');
      return null;
    }
  }
}