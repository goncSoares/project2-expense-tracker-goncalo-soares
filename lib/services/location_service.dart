import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check location permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Get current location with proper error handling
  Future<Position?> getCurrentLocation() async {
    try {
      print('Getting location...');

      // Step 1: Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('Location service enabled: $serviceEnabled');

      if (!serviceEnabled) {
        print('Location services are disabled');
        throw Exception('Location services are disabled. Please enable location in your device settings.');
      }

      // Step 2: Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      print('Current permission: $permission');

      if (permission == LocationPermission.denied) {
        print('Requesting permission...');
        permission = await Geolocator.requestPermission();
        print('Permission after request: $permission');

        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied. Please enable them in app settings.');
      }

      print('Permission OK, getting position...');

      // Step 3: Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      print('Location obtained: ${position.latitude}, ${position.longitude}');
      return position;

    } on TimeoutException catch (e) {
      print('Timeout getting location: $e');
      throw Exception('Location request timed out. Please try again.');
    } catch (e) {
      print('Error getting location: $e');
      rethrow;
    }
  }

  /// Get current location with custom timeout
  Future<Position?> getCurrentLocationWithTimeout({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      // Check service
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services disabled');
      }

      // Check/request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }

      // Get position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(timeout);

      return position;
    } catch (e) {
      print('Error getting location with timeout: $e');
      return null;
    }
  }

  /// Calculate distance between two points in meters
  double calculateDistance(
      double startLatitude,
      double startLongitude,
      double endLatitude,
      double endLongitude,
      ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Format location for display
  String formatLocation(Position position) {
    return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
  }

  /// Open device location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings (for permissions)
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Get location address string
  String getLocationString(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return 'No location';
    }
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }
}