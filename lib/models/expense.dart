import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  String id;
  String category;
  String description;
  double amount;
  DateTime date;
  String? receiptUrl;
  double? latitude;
  double? longitude;
  final String? locationName;
  String currency;
  DateTime? createdAt;
  DateTime? updatedAt;
  bool isRecurring;
  String? recurringFrequency;
  List<String> tags;

  Expense({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
    this.receiptUrl,
    this.latitude,
    this.longitude,
    this.locationName,
    this.currency = 'EUR',
    this.createdAt,
    this.updatedAt,
    this.isRecurring = false,
    this.recurringFrequency,
    this.tags = const [],
  });

  factory Expense.fromFirestore(Map<String, dynamic> data, String id) {
    return Expense(
      id: id,
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      date: (data['date'] as Timestamp).toDate(),
      receiptUrl: data['receiptUrl'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      locationName: data['locationName'],
      currency: data['currency'] ?? 'EUR',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      isRecurring: data['isRecurring'] ?? false,
      recurringFrequency: data['recurringFrequency'],
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'category': category,
      'description': description,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'receiptUrl': receiptUrl,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'currency': currency,
      'isRecurring': isRecurring,
      'recurringFrequency': recurringFrequency,
      'tags': tags,
    };
  }

  Expense copyWith({
    String? id,
    String? category,
    String? description,
    double? amount,
    DateTime? date,
    String? receiptUrl,
    double? latitude,
    double? longitude,
    String? locationName,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isRecurring,
    String? recurringFrequency,
    List<String>? tags,
  }) {
    return Expense(
      id: id ?? this.id,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringFrequency: recurringFrequency ?? this.recurringFrequency,
      tags: tags ?? this.tags,
    );
  }
}
