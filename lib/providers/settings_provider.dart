import 'package:flutter/material.dart';
import '../services/currency_service.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _currency = 'EUR';
  bool _isLoading = true;

  ThemeMode get themeMode => _themeMode;
  String get currency => _currency;
  bool get isLoading => _isLoading;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _isLoading = true;
    notifyListeners();

    // Load Currency (using existing service)
    _currency = await CurrencyService.getPreferredCurrency();

    // TODO: Load Theme preference from SharedPreferences if we want persistence
    // For now defaults to system

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setCurrency(String newCurrency) async {
    if (_currency == newCurrency) return;
    
    _currency = newCurrency;
    notifyListeners();
    
    await CurrencyService.savePreferredCurrency(newCurrency);
  }

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
