import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  String id;
  String category;
  String description;
  double amount;
  DateTime date;
  String? receiptUrl;
  double? latitude;   // ← NOVO!
  double? longitude;  // ← NOVO!
  DateTime? createdAt;
  DateTime? updatedAt;

  Expense({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
    this.receiptUrl,
    this.latitude,   // ← NOVO!
    this.longitude,  // ← NOVO!
    this.createdAt,
    this.updatedAt,
  });

  factory Expense.fromFirestore(Map<String, dynamic> data, String id) {
    return Expense(
      id: id,
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      date: (data['date'] as Timestamp).toDate(),
      receiptUrl: data['receiptUrl'],
      latitude: data['latitude']?.toDouble(),   // ← NOVO!
      longitude: data['longitude']?.toDouble(), // ← NOVO!
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'category': category,
      'description': description,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'receiptUrl': receiptUrl,
      'latitude': latitude,   // ← NOVO!
      'longitude': longitude, // ← NOVO!
      // createdAt e updatedAt são adicionados pelo FirestoreService
    };
  }

  // CopyWith para facilitar updates
  Expense copyWith({
    String? id,
    String? category,
    String? description,
    double? amount,
    DateTime? date,
    String? receiptUrl,
    double? latitude,   // ← NOVO!
    double? longitude,  // ← NOVO!
    DateTime? createdAt,
    DateTime? updatedAt,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}