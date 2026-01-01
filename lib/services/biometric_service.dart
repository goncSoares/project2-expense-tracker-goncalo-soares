import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Check if device supports biometric authentication
  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException catch (e) {
      print('Error checking biometrics: $e');
      return false;
    }
  }

  /// Check if device is capable of biometric authentication
  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException catch (e) {
      print('Error checking device support: $e');
      return false;
    }
  }

  /// Get list of available biometric types
  /// Returns: [BiometricType.face, BiometricType.fingerprint, etc.]
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      print('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Authenticate with biometrics
  /// Returns true if authentication successful
  Future<bool> authenticate({
    String localizedReason = 'Please authenticate to access this feature',
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      // Check if biometrics is available
      final bool canAuthenticate = await canCheckBiometrics() ||
          await isDeviceSupported();

      if (!canAuthenticate) {
        print('Biometric authentication not available');
        return false;
      }

      // Authenticate
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: false, // Allow PIN/password fallback
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      print('Authentication error: $e');
      return false;
    }
  }

  /// Authenticate with only biometrics (no PIN/password fallback)
  Future<bool> authenticateBiometricOnly({
    String localizedReason = 'Please authenticate with biometrics',
  }) async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          biometricOnly: true, // NO fallback
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      print('Biometric authentication error: $e');
      return false;
    }
  }

  /// Stop authentication
  Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (e) {
      print('Error stopping authentication: $e');
    }
  }

  /// Get biometric type name for display
  String getBiometricTypeName(List<BiometricType> types) {
    if (types.isEmpty) return 'Biometric';

    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (types.contains(BiometricType.iris)) {
      return 'Iris';
    } else if (types.contains(BiometricType.strong)) {
      return 'Strong Biometric';
    } else if (types.contains(BiometricType.weak)) {
      return 'Weak Biometric';
    }

    return 'Biometric';
  }
}