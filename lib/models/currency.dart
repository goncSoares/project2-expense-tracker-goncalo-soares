/// Currency model with metadata
class Currency {
  final String code;
  final String name;
  final String symbol;
  final String flag;

  const Currency({
    required this.code,
    required this.name,
    required this.symbol,
    this.flag = '',
  });

  /// Popular currencies with metadata
  static const List<Currency> popular = [
    Currency(code: 'EUR', name: 'Euro', symbol: '€', flag: '🇪🇺'),
    Currency(code: 'USD', name: 'US Dollar', symbol: '\$', flag: '🇺🇸'),
    Currency(code: 'GBP', name: 'British Pound', symbol: '£', flag: '🇬🇧'),
    Currency(code: 'JPY', name: 'Japanese Yen', symbol: '¥', flag: '🇯🇵'),
    Currency(code: 'BRL', name: 'Brazilian Real', symbol: 'R\$', flag: '🇧🇷'),
    Currency(code: 'CAD', name: 'Canadian Dollar', symbol: 'C\$', flag: '🇨🇦'),
    Currency(code: 'CHF', name: 'Swiss Franc', symbol: 'CHF', flag: '🇨🇭'),
    Currency(code: 'CNY', name: 'Chinese Yuan', symbol: '¥', flag: '🇨🇳'),
    Currency(code: 'INR', name: 'Indian Rupee', symbol: '₹', flag: '🇮🇳'),
    Currency(code: 'AUD', name: 'Australian Dollar', symbol: 'A\$', flag: '🇦🇺'),
  ];

  /// Get currency by code
  static Currency? getByCode(String code) {
    try {
      return popular.firstWhere((c) => c.code == code);
    } catch (e) {
      return null;
    }
  }

  /// Get symbol for currency code
  static String getSymbol(String code) {
    return getByCode(code)?.symbol ?? code;
  }

  /// Get name for currency code
  static String getName(String code) {
    return getByCode(code)?.name ?? code;
  }

  @override
  String toString() => '$flag $code - $name';
}
