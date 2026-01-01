class UserSettings {
  final String baseCurrency;
  final bool budgetAlerts;
  final String theme;

  UserSettings({
    this.baseCurrency = 'EUR',
    this.budgetAlerts = true,
    this.theme = 'light',
  });

  factory UserSettings.fromFirestore(Map<String, dynamic> data) {
    return UserSettings(
      baseCurrency: data['baseCurrency'] ?? 'EUR',
      budgetAlerts: data['budgetAlerts'] ?? true,
      theme: data['theme'] ?? 'light',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'baseCurrency': baseCurrency,
      'budgetAlerts': budgetAlerts,
      'theme': theme,
    };
  }

  UserSettings copyWith({
    String? baseCurrency,
    bool? budgetAlerts,
    String? theme,
  }) {
    return UserSettings(
      baseCurrency: baseCurrency ?? this.baseCurrency,
      budgetAlerts: budgetAlerts ?? this.budgetAlerts,
      theme: theme ?? this.theme,
    );
  }
}