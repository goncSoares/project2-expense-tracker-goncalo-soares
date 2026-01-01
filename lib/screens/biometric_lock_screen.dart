import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../services/biometric_service.dart';

class BiometricLockScreen extends StatefulWidget {
  final Widget child;
  final String title;
  final String message;

  const BiometricLockScreen({
    super.key,
    required this.child,
    this.title = 'Secure Area',
    this.message = 'Please authenticate to continue',
  });

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _biometricType;

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    final types = await _biometricService.getAvailableBiometrics();
    setState(() {
      _biometricType = _biometricService.getBiometricTypeName(types);
      _isLoading = false;
    });

    // Auto-trigger authentication
    _authenticate();
  }

  Future<void> _authenticate() async {
    final authenticated = await _biometricService.authenticate(
      localizedReason: widget.message,
    );

    if (authenticated) {
      setState(() {
        _isAuthenticated = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isAuthenticated) {
      return widget.child;
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                widget.message,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: Icon(_getBiometricIcon()),
                label: Text('Authenticate with $_biometricType'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getBiometricIcon() {
    if (_biometricType?.contains('Face') == true) {
      return Icons.face;
    } else if (_biometricType?.contains('Fingerprint') == true) {
      return Icons.fingerprint;
    }
    return Icons.security;
  }
}