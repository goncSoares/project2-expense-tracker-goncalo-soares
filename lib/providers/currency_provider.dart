import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/currency_service.dart';

class CurrencyProvider with ChangeNotifier {
  String _selectedCurrency = 'EUR'; // Default
  Map<String, double> _rates = {};
  bool _isLoading = false;
  String? _error;

  // Popular currencies
  static const List<Map<String, String>> availableCurrencies = [
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
    {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$'},
    {'code': 'GBP', 'name': 'British Pound', 'symbol': '£'},
    {'code': 'JPY', 'name': 'Japanese Yen', 'symbol': '¥'},
    {'code': 'BRL', 'name': 'Brazilian Real', 'symbol': 'R\$'},
    {'code': 'CAD', 'name': 'Canadian Dollar', 'symbol': 'C\$'},
    {'code': 'CHF', 'name': 'Swiss Franc', 'symbol': 'CHF'},
    {'code': 'CNY', 'name': 'Chinese Yuan', 'symbol': '¥'},
    {'code': 'INR', 'name': 'Indian Rupee', 'symbol': '₹'},
    {'code': 'AUD', 'name': 'Australian Dollar', 'symbol': 'A\$'},
  ];

  String get selectedCurrency => _selectedCurrency;
  Map<String, double> get rates => _rates;
  bool get isLoading => _isLoading;
  String? get error => _error;

  CurrencyProvider() {
    _loadSelectedCurrency();
    _loadRates();
  }

  /// Load saved currency from SharedPreferences
  Future<void> _loadSelectedCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('selected_currency');
      if (saved != null) {
        _selectedCurrency = saved;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading currency: $e');
    }
  }

  /// Load exchange rates
  Future<void> _loadRates() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _rates = await CurrencyService.getExchangeRates();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load rates';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Change selected currency
  Future<void> changeCurrency(String currencyCode) async {
    _selectedCurrency = currencyCode;

    // Save to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_currency', currencyCode);
    } catch (e) {
      print('Error saving currency: $e');
    }

    notifyListeners();
  }

  /// Convert amount from EUR to selected currency
  double convertFromEUR(double amountEUR) {
    if (_selectedCurrency == 'EUR') return amountEUR;

    final rate = _rates[_selectedCurrency];
    if (rate == null) return amountEUR; // Fallback

    return amountEUR * rate;
  }

  /// Get currency symbol
  String getCurrencySymbol() {
    final currency = availableCurrencies.firstWhere(
          (c) => c['code'] == _selectedCurrency,
      orElse: () => {'symbol': '€'},
    );
    return currency['symbol']!;
  }

  /// Get currency name
  String getCurrencyName() {
    final currency = availableCurrencies.firstWhere(
          (c) => c['code'] == _selectedCurrency,
      orElse: () => {'name': 'Euro'},
    );
    return currency['name']!;
  }

  /// Refresh rates manually
  Future<void> refreshRates() async {
    await _loadRates();
  }

  /// Format amount with currency symbol
  String formatAmount(double amount) {
    final converted = convertFromEUR(amount);
    return '${getCurrencySymbol()}${converted.toStringAsFixed(2)}';
  }
}