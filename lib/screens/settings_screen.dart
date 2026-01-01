import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/biometric_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final BiometricService _biometricService = BiometricService();
  final user = FirebaseAuth.instance.currentUser;

  bool _biometricLockEnabled = false;
  bool _isBiometricAvailable = false;
  String _biometricType = 'Biometric';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Check biometric availability
    final available = await _biometricService.canCheckBiometrics();
    final types = await _biometricService.getAvailableBiometrics();
    final typeName = _biometricService.getBiometricTypeName(types);

    // Load saved preference
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('biometric_lock_enabled') ?? false;

    setState(() {
      _isBiometricAvailable = available;
      _biometricType = typeName;
      _biometricLockEnabled = enabled && available;
    });
  }

  Future<void> _toggleBiometricLock(bool value) async {
    if (value) {
      // Authenticate before enabling
      final authenticated = await _biometricService.authenticate(
        localizedReason: 'Authenticate to enable biometric lock',
      );

      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // Save preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_lock_enabled', value);

    setState(() {
      _biometricLockEnabled = value;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Biometric lock enabled'
                : 'Biometric lock disabled',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Security Section
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Security',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('Biometric Lock ($_biometricType)'),
                  subtitle: Text(
                    _isBiometricAvailable
                        ? 'Secure app with $_biometricType'
                        : 'Not available on this device',
                  ),
                  secondary: Icon(
                    _biometricType.contains('Face')
                        ? Icons.face
                        : Icons.fingerprint,
                  ),
                  value: _biometricLockEnabled,
                  onChanged: _isBiometricAvailable ? _toggleBiometricLock : null,
                ),
                if (_isBiometricAvailable)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      'When enabled, you will be asked to authenticate when opening the app',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Account Section
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Account',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email),
                  title: const Text('Email'),
                  subtitle: Text(user?.email ?? 'Not available'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.verified_user),
                  title: const Text('Email Verified'),
                  subtitle: Text(
                    user?.emailVerified == true ? 'Yes' : 'No',
                  ),
                  trailing: user?.emailVerified == false
                      ? TextButton(
                    onPressed: () async {
                      await user?.sendEmailVerification();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Verification email sent!'),
                          ),
                        );
                      }
                    },
                    child: const Text('Verify'),
                  )
                      : null,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // About Section
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'About',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info),
                  title: Text('Version'),
                  subtitle: Text('1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Open privacy policy
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}