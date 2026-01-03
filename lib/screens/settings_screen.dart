import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/biometric_service.dart';
import 'package:local_auth/local_auth.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../models/currency.dart';
import 'budget_screen.dart';
import 'reports_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final BiometricService _biometricService = BiometricService();

  bool _biometricLockEnabled = false;
  bool _isBiometricAvailable = false;
  bool _isDeviceSupported = false;
  String _biometricType = 'Biometric';
  bool _isCheckingBiometric = true;
  List<BiometricType> _availableTypes = [];

  @override
  void initState() {
    super.initState();
    _loadBiometricSettings();
  }

  Future<void> _loadBiometricSettings() async {
    setState(() => _isCheckingBiometric = true);

    try {
      // 1. Check device support
      final deviceSupported = await _biometricService.isDeviceSupported();

      // 2. Check biometric availability
      final canCheck = await _biometricService.canCheckBiometrics();

      // 3. Get available types
      final types = await _biometricService.getAvailableBiometrics();
      final typeName = _biometricService.getBiometricTypeName(types);

      // 4. Load preference
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('biometric_lock_enabled') ?? false;

      if (mounted) {
        setState(() {
          _isDeviceSupported = deviceSupported;
          _isBiometricAvailable = canCheck && types.isNotEmpty;
          _availableTypes = types;
          _biometricType = typeName;
          _biometricLockEnabled = enabled && _isBiometricAvailable;
          _isCheckingBiometric = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBiometricAvailable = false;
          _isDeviceSupported = false;
          _isCheckingBiometric = false;
        });
      }
    }
  }

  Future<void> _toggleBiometricLock(bool value) async {
    if (value) {
      // Test authentication first
      try {
        final authenticated = await _biometricService.authenticate(
          localizedReason: 'Authenticate to enable biometric lock',
        );

        if (!authenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication failed or cancelled'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // Save preference
    try {
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
                  ? 'Biometric lock enabled successfully!'
                  : 'Biometric lock disabled',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testBiometric() async {
    try {
      final result = await _biometricService.authenticate(
        localizedReason: 'Testing biometric authentication',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result ? '✅ Authentication successful!' : '❌ Authentication failed'),
            backgroundColor: result ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SettingsProvider, AuthProvider>(
      builder: (context, settings, auth, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: ListView(
            children: [
               // Appearance Section
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Appearance',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Dark Mode'),
                      secondary: const Icon(Icons.dark_mode),
                      value: settings.themeMode == ThemeMode.dark,
                      onChanged: (bool value) {
                settings.toggleTheme(value);
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Manage Budgets'),
              subtitle: const Text('Set monthly spending limits'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BudgetScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.summarize_outlined),
              title: const Text('Export Reports'),
              subtitle: const Text('PDF & CSV exports'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
                );
              },
            ),
            const Divider(),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.currency_exchange),
                      title: const Text('Currency'),
                      subtitle: Text(settings.currency),
                      trailing: DropdownButton<String>(
                        value: settings.currency,
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            settings.setCurrency(newValue);
                          }
                        },
                        items: Currency.popular.map<DropdownMenuItem<String>>((Currency currency) {
                          return DropdownMenuItem<String>(
                            value: currency.code,
                            child: Text(currency.code),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              
              // Security Section
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Security',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),

              // Biometric Status Card
              if (!_isCheckingBiometric)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: _isBiometricAvailable ? Colors.green.shade50 : Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isBiometricAvailable ? Icons.check_circle : Icons.warning,
                              color: _isBiometricAvailable ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isBiometricAvailable ? 'Biometric Available' : 'Biometric Not Available',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isBiometricAvailable
                              ? 'Type: $_biometricType'
                              : _isDeviceSupported
                              ? 'No biometric enrolled on device'
                              : 'Device does not support biometric (normal on emulator)',
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                        if (!_isBiometricAvailable && _isDeviceSupported) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'To enable: Go to device Settings → Security → Add fingerprint/face',
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black87),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // Biometric Toggle
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: _isCheckingBiometric
                    ? const ListTile(
                  title: Text('Checking biometric...'),
                  trailing: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
                    : SwitchListTile(
                  title: Text('Biometric Lock ($_biometricType)'),
                  subtitle: Text(
                    _isBiometricAvailable
                        ? 'Require $_biometricType to open app'
                        : 'Set up biometric on your device first',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isBiometricAvailable ? Colors.grey : Colors.orange,
                    ),
                  ),
                  secondary: Icon(
                    _biometricType.contains('Face')
                        ? Icons.face
                        : Icons.fingerprint,
                    color: _isBiometricAvailable ? null : Colors.grey,
                  ),
                  value: _biometricLockEnabled,
                  onChanged: _isBiometricAvailable ? _toggleBiometricLock : null,
                ),
              ),

              // Test Biometric Button
              if (_isBiometricAvailable)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: OutlinedButton.icon(
                    onPressed: _testBiometric,
                    icon: const Icon(Icons.science),
                    label: const Text('Test Biometric'),
                  ),
                ),

              const SizedBox(height: 24),

              // Account Section
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Account',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),

              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.email),
                      title: const Text('Email'),
                      subtitle: Text(auth.user?.email ?? 'Not available'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.verified_user),
                      title: const Text('Email Verified'),
                      subtitle: Text(auth.user?.emailVerified == true ? 'Yes' : 'No'),
                      trailing: auth.user?.emailVerified == false
                          ? TextButton(
                        onPressed: () async {
                          await auth.user?.sendEmailVerification();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Verification email sent!')),
                            );
                          }
                        },
                        child: const Text('Verify'),
                      )
                          : null,
                    ),
                     const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                      onTap: () async {
                        await auth.signOut();
                        if (mounted) Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // About
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'About',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                      leading: const Icon(Icons.description),
                      title: const Text('Features'),
                      subtitle: const Text('GPS + Maps, Biometric, Local Storage, Multi-Currency'),
                      onTap: () {
                         showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Implemented Features'),
                            content: const SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('✅ Authentication (Email + Google)'),
                                  Text('✅ Firestore (user-specific data)'),
                                  Text('✅ Local Storage (receipts + photos)'),
                                  Text('✅ GPS Location + Google Maps'),
                                  Text('✅ Biometric Lock (Face ID / Fingerprint)'),
                                  Text('✅ Multi-Currency Conversion'),
                                  Text('✅ Statistics & Charts'),
                                  Text('✅ Provider State Management'),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}