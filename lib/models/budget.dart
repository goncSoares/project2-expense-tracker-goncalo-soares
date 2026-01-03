
class Budget {
  final String id;
  final String category;
  double limit;
  double spent;
  String period; // 'Monthly' or 'Weekly'

  Budget({
    required this.id,
    required this.category,
    required this.limit,
    this.spent = 0.0,
    this.period = 'Monthly',
  });

  factory Budget.fromFirestore(Map<String, dynamic> data, String id) {
    return Budget(
      id: id,
      category: data['category'] ?? '',
      limit: (data['limit'] ?? 0).toDouble(),
      spent: (data['spent'] ?? 0).toDouble(),
      period: data['period'] ?? 'Monthly',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'category': category,
      'limit': limit,
      'spent': spent,
      'period': period,
    };
  }

  Budget copyWith({
    String? id,
    String? category,
    double? limit,
    double? spent,
    String? period,
  }) {
    return Budget(
      id: id ?? this.id,
      category: category ?? this.category,
      limit: limit ?? this.limit,
      spent: spent ?? this.spent,
      period: period ?? this.period,
    );
  }
}
