import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/currency.dart';

/// Enhanced currency service with multiple API endpoints and caching
class CurrencyService {
  // Using frankfurter.app (free, no API key needed)
  static const String _baseUrl = 'https://api.frankfurter.app';

  // Memory cache
  static Map<String, double>? _cachedRates;
  static DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(hours: 1);

  // SharedPreferences keys
  static const String _prefKeyRates = 'currency_rates';
  static const String _prefKeyRatesTime = 'currency_rates_time';
  static const String _prefKeyPreferredCurrency = 'preferred_currency';

  /// ENDPOINT 1: Get latest exchange rates
  static Future<Map<String, double>> getExchangeRates({String base = 'EUR'}) async {
    // Check memory cache
    if (_cachedRates != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      print('✅ Using memory cached exchange rates');
      return _cachedRates!;
    }

    // Check persistent cache
    final persistentRates = await _loadPersistentCache();
    if (persistentRates != null) {
      _cachedRates = persistentRates;
      print('✅ Using persistent cached exchange rates');
      return persistentRates;
    }

    try {
      // Fetch from API
      final response = await http.get(
        Uri.parse('$_baseUrl/latest?from=$base'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = Map<String, double>.from(
          data['rates'].map(
            (key, value) => MapEntry(key, value.toDouble()),
          ),
        );

        // Add base currency
        rates[base] = 1.0;

        // Cache in memory
        _cachedRates = rates;
        _cacheTime = DateTime.now();

        // Cache persistently
        await _savePersistentCache(rates);

        print('✅ Exchange rates loaded from API');
        return rates;
      } else if (response.statusCode == 429) {
        print('⚠️ Rate limit reached, using cached data');
        return _getHardcodedRates();
      }

      print('⚠️ API error: ${response.statusCode}');
      return _getHardcodedRates();
    } catch (e) {
      print('❌ Error fetching exchange rates: $e');
      return _getHardcodedRates();
    }
  }

  /// ENDPOINT 2: Get historical exchange rates for specific date
  static Future<Map<String, double>> getHistoricalRates(
    DateTime date, {
    String base = 'EUR',
  }) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final response = await http.get(
        Uri.parse('$_baseUrl/$dateStr?from=$base'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = Map<String, double>.from(
          data['rates'].map(
            (key, value) => MapEntry(key, value.toDouble()),
          ),
        );

        // Add base currency
        rates[base] = 1.0;

        print('✅ Historical rates loaded for $dateStr');
        return rates;
      }

      print('⚠️ Historical rates unavailable, using current rates');
      return await getExchangeRates(base: base);
    } catch (e) {
      print('❌ Error fetching historical rates: $e');
      return await getExchangeRates(base: base);
    }
  }

  /// ENDPOINT 3: Get list of supported currencies
  static Future<Map<String, String>> getSupportedCurrencies() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/currencies'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final currencies = Map<String, String>.from(data);
        print('✅ Supported currencies loaded: ${currencies.length}');
        return currencies;
      }

      print('⚠️ Could not load currencies list');
      return _getHardcodedCurrencyNames();
    } catch (e) {
      print('❌ Error fetching currencies: $e');
      return _getHardcodedCurrencyNames();
    }
  }

  /// ENDPOINT 4: Convert amount between currencies
  static Future<double> convert({
    required double amount,
    required String from,
    required String to,
  }) async {
    if (from == to) return amount;

    try {
      final rates = await getExchangeRates(base: from);

      if (to == from) {
        return amount;
      }

      final toRate = rates[to];
      if (toRate != null) {
        return amount * toRate;
      }

      print('⚠️ Rate not found for $to');
      return amount;
    } catch (e) {
      print('❌ Conversion error: $e');
      return amount;
    }
  }

  /// Batch convert multiple amounts
  static Future<List<double>> convertBatch(
    List<double> amounts,
    String from,
    String to,
  ) async {
    if (from == to) return amounts;

    try {
      final rates = await getExchangeRates(base: from);
      final toRate = rates[to];

      if (toRate == null) {
        print('⚠️ Rate not found for $to');
        return amounts;
      }

      return amounts.map((amount) => amount * toRate).toList();
    } catch (e) {
      print('❌ Batch conversion error: $e');
      return amounts;
    }
  }

  /// Get currency symbol
  static String getCurrencySymbol(String code) {
    return Currency.getSymbol(code);
  }

  /// Get currency name
  static String getCurrencyName(String code) {
    return Currency.getName(code);
  }

  /// Format amount with currency
  static String formatAmount(double amount, String currencyCode) {
    final symbol = getCurrencySymbol(currencyCode);
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Save preferred currency
  static Future<void> savePreferredCurrency(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyPreferredCurrency, code);
      print('✅ Preferred currency saved: $code');
    } catch (e) {
      print('❌ Error saving preferred currency: $e');
    }
  }

  /// Get preferred currency
  static Future<String> getPreferredCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefKeyPreferredCurrency) ?? 'EUR';
    } catch (e) {
      print('❌ Error loading preferred currency: $e');
      return 'EUR';
    }
  }

  /// Save rates to persistent cache
  static Future<void> _savePersistentCache(Map<String, double> rates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ratesJson = json.encode(rates);
      await prefs.setString(_prefKeyRates, ratesJson);
      await prefs.setInt(_prefKeyRatesTime, DateTime.now().millisecondsSinceEpoch);
      print('💾 Rates saved to persistent cache');
    } catch (e) {
      print('❌ Error saving persistent cache: $e');
    }
  }

  /// Load rates from persistent cache
  static Future<Map<String, double>?> _loadPersistentCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ratesJson = prefs.getString(_prefKeyRates);
      final ratesTime = prefs.getInt(_prefKeyRatesTime);

      if (ratesJson == null || ratesTime == null) {
        return null;
      }

      final cacheAge = DateTime.now().millisecondsSinceEpoch - ratesTime;
      const maxAge = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

      if (cacheAge > maxAge) {
        print('⚠️ Persistent cache expired');
        return null;
      }

      final rates = Map<String, double>.from(json.decode(ratesJson));
      _cacheTime = DateTime.fromMillisecondsSinceEpoch(ratesTime);
      return rates;
    } catch (e) {
      print('❌ Error loading persistent cache: $e');
      return null;
    }
  }

  /// Get hardcoded fallback rates
  static Map<String, double> _getHardcodedRates() {
    return {
      'EUR': 1.0,
      'USD': 1.10,
      'GBP': 0.85,
      'JPY': 165.0,
      'BRL': 6.20,
      'CAD': 1.50,
      'CHF': 0.95,
      'CNY': 7.90,
      'INR': 92.0,
      'AUD': 1.70,
    };
  }

  /// Get hardcoded currency names
  static Map<String, String> _getHardcodedCurrencyNames() {
    return {
      'EUR': 'Euro',
      'USD': 'US Dollar',
      'GBP': 'British Pound',
      'JPY': 'Japanese Yen',
      'BRL': 'Brazilian Real',
      'CAD': 'Canadian Dollar',
      'CHF': 'Swiss Franc',
      'CNY': 'Chinese Yuan',
      'INR': 'Indian Rupee',
      'AUD': 'Australian Dollar',
    };
  }

  /// Clear all caches
  static Future<void> clearCache() async {
    _cachedRates = null;
    _cacheTime = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyRates);
      await prefs.remove(_prefKeyRatesTime);
      print('🧹 All currency caches cleared');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }

  /// Get cache age in minutes
  static int? getCacheAgeMinutes() {
    if (_cacheTime == null) return null;
    return DateTime.now().difference(_cacheTime!).inMinutes;
  }
}