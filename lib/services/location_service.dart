import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Get current location (simplified - works or returns null)
  Future<Position?> getCurrentLocation() async {
    try {
      // Check if service enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location service disabled');
        return null; // GPS está desligado
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permission denied forever');
        return null;
      }

      // Get position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Location timeout'),
      );

      print('Location OK: ${position.latitude}, ${position.longitude}');
      return position;

    } on TimeoutException {
      print('Location request timed out');
      return null;
    } catch (e) {
      print('Location error: $e');
      return null;
    }
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      return false;
    }
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      return false;
    }
  }

  /// Format location
  String formatLocation(double? lat, double? lng) {
    if (lat == null || lng == null) return 'No location';
    return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
  }
}