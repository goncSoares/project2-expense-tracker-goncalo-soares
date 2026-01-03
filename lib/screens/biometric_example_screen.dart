import 'package:flutter/material.dart';
import '../services/biometric_service.dart';
import '../screens/biometric_lock_screen.dart';
import 'package:local_auth/local_auth.dart';

/// Example screen demonstrating biometric authentication
/// This shows how to protect sensitive sections of your app
class BiometricExampleScreen extends StatefulWidget {
  const BiometricExampleScreen({super.key});

  @override
  State<BiometricExampleScreen> createState() => _BiometricExampleScreenState();
}

class _BiometricExampleScreenState extends State<BiometricExampleScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _isSupported = false;
  List<BiometricType> _availableTypes = [];
  String _biometricTypeName = 'Biometric';

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    final supported = await _biometricService.isDeviceSupported();
    final types = await _biometricService.getAvailableBiometrics();
    final typeName = _biometricService.getBiometricTypeName(types);

    setState(() {
      _isSupported = supported;
      _availableTypes = types;
      _biometricTypeName = typeName;
    });
  }

  Future<void> _authenticateSimple() async {
    final authenticated = await _biometricService.authenticate(
      localizedReason: 'Please authenticate to access sensitive data',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authenticated ? 'Authentication successful!' : 'Authentication failed',
          ),
          backgroundColor: authenticated ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _openProtectedScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BiometricLockScreen(
          title: 'Secure Expenses',
          message: 'Authenticate to view your expenses',
          child: const _ProtectedContentScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Authentication'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Device Support Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Device Support',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Biometric Supported',
                      _isSupported ? 'Yes' : 'No',
                      _isSupported ? Colors.green : Colors.red,
                    ),
                    _buildInfoRow(
                      'Available Type',
                      _biometricTypeName,
                      Colors.blue,
                    ),
                    if (_availableTypes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Available: ${_availableTypes.map((t) => t.name).join(', ')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Examples Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.security, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Authentication Examples',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Simple Authentication
                    const Text(
                      '1. Simple Authentication',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Authenticate once for a specific action',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isSupported ? _authenticateSimple : null,
                      icon: const Icon(Icons.fingerprint),
                      label: Text('Authenticate with $_biometricTypeName'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Protected Screen
                    const Text(
                      '2. Protected Screen',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Lock an entire screen behind biometric authentication',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _isSupported ? _openProtectedScreen : null,
                      icon: const Icon(Icons.lock),
                      label: const Text('Open Protected Screen'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Usage Guide Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.code, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'How to Use',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildCodeExample(
                      'Simple Authentication',
                      '''
final biometric = BiometricService();
final success = await biometric.authenticate(
  localizedReason: 'Authenticate to continue',
);
if (success) {
  // Proceed with action
}''',
                    ),
                    const SizedBox(height: 12),
                    _buildCodeExample(
                      'Protected Screen',
                      '''
Navigator.push(context,
  MaterialPageRoute(
    builder: (_) => BiometricLockScreen(
      title: 'Secure Area',
      message: 'Authenticate to continue',
      child: YourProtectedScreen(),
    ),
  ),
);''',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeExample(String title, String code) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

/// Example of protected content
class _ProtectedContentScreen extends StatelessWidget {
  const _ProtectedContentScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Protected Content'),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.verified_user,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              const Text(
                'Authentication Successful!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'This is a protected screen that requires biometric authentication to access.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.lock_open, color: Colors.green),
                      const SizedBox(height: 8),
                      const Text(
                        'Sensitive Information',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Account Balance: €1,234.56',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        'Total Expenses: €567.89',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
