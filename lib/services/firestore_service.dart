import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense.dart';
import '../models/user_profile.dart';
import '../models/user_settings.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== USER PROFILE ====================

  /// Criar perfil do utilizador após registo
  Future<void> createUserProfile({
    required String userId,
    required String email,
    String? displayName,
    String? photoURL,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'profile': {
          'email': email,
          'displayName': displayName ?? '',
          'photoURL': photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        }
      });

      // Criar settings padrão
      await createDefaultSettings(userId);
    } on FirebaseException catch (e) {
      throw Exception('Failed to create user profile: ${e.message}');
    }
  }

  /// Obter perfil do utilizador
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['profile'] != null) {
          return UserProfile.fromFirestore(data['profile'] as Map<String, dynamic>);
        }
      }
      return null;
    } on FirebaseException catch (e) {
      throw Exception('Failed to get user profile: ${e.message}');
    }
  }

  /// Atualizar perfil do utilizador
  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    try {
      Map<String, dynamic> profileUpdates = {};
      updates.forEach((key, value) {
        profileUpdates['profile.$key'] = value;
      });

      await _firestore.collection('users').doc(userId).update(profileUpdates);
    } on FirebaseException catch (e) {
      throw Exception('Failed to update user profile: ${e.message}');
    }
  }

  // ==================== EXPENSES (User-Specific) ====================

  /// Stream de despesas do utilizador (real-time)
  Stream<List<Expense>> getUserExpenses(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Expense.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Adicionar despesa
  Future<void> addExpense(String userId, Expense expense) async {
    try {
      final expenseData = expense.toFirestore();
      expenseData['createdAt'] = FieldValue.serverTimestamp();
      expenseData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .add(expenseData);
    } on FirebaseException catch (e) {
      throw Exception('Failed to add expense: ${e.message}');
    }
  }

  /// Atualizar despesa
  Future<void> updateExpense(
      String userId,
      String expenseId,
      Map<String, dynamic> updates,
      ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc(expenseId)
          .update(updates);
    } on FirebaseException catch (e) {
      throw Exception('Failed to update expense: ${e.message}');
    }
  }

  /// Eliminar despesa
  Future<void> deleteExpense(String userId, String expenseId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc(expenseId)
          .delete();
    } on FirebaseException catch (e) {
      throw Exception('Failed to delete expense: ${e.message}');
    }
  }

  /// Pesquisar despesas por descrição ou categoria
  Future<List<Expense>> searchExpenses(String userId, String query) async {
    try {
      // Pesquisar por categoria (exact match)
      final categoryQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .where('category', isEqualTo: query)
          .get();

      // Converter para lista de Expense
      List<Expense> expenses = categoryQuery.docs.map((doc) {
        return Expense.fromFirestore(doc.data(), doc.id);
      }).toList();

      // TODO: Para pesquisa de texto completo, usar Algolia ou similar
      // Firestore não suporta LIKE ou text search nativamente

      return expenses;
    } on FirebaseException catch (e) {
      throw Exception('Failed to search expenses: ${e.message}');
    }
  }

  /// Obter despesas por intervalo de datas
  Future<List<Expense>> getExpensesByDateRange(
      String userId,
      DateTime startDate,
      DateTime endDate,
      ) async {
    try {
      final query = await _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: true)
          .get();

      return query.docs.map((doc) {
        return Expense.fromFirestore(doc.data(), doc.id);
      }).toList();
    } on FirebaseException catch (e) {
      throw Exception('Failed to get expenses by date: ${e.message}');
    }
  }

  /// Obter despesas por categoria
  Future<List<Expense>> getExpensesByCategory(
      String userId,
      String category,
      ) async {
    try {
      final query = await _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .where('category', isEqualTo: category)
          .orderBy('date', descending: true)
          .get();

      return query.docs.map((doc) {
        return Expense.fromFirestore(doc.data(), doc.id);
      }).toList();
    } on FirebaseException catch (e) {
      throw Exception('Failed to get expenses by category: ${e.message}');
    }
  }

  /// Obter total de despesas por categoria (compound query)
  Future<Map<String, double>> getTotalByCategory(String userId) async {
    try {
      final query = await _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .get();

      Map<String, double> totals = {};

      for (var doc in query.docs) {
        final expense = Expense.fromFirestore(doc.data(), doc.id);
        totals[expense.category] =
            (totals[expense.category] ?? 0) + expense.amount;
      }

      return totals;
    } on FirebaseException catch (e) {
      throw Exception('Failed to get totals by category: ${e.message}');
    }
  }

  /// Batch delete - eliminar múltiplas despesas
  Future<void> batchDeleteExpenses(
      String userId,
      List<String> expenseIds,
      ) async {
    try {
      final batch = _firestore.batch();

      for (String expenseId in expenseIds) {
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('expenses')
            .doc(expenseId);
        batch.delete(docRef);
      }

      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception('Failed to batch delete expenses: ${e.message}');
    }
  }

  // ==================== SETTINGS ====================

  /// Criar settings padrão
  Future<void> createDefaultSettings(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'settings': {
          'baseCurrency': 'EUR',
          'budgetAlerts': true,
          'theme': 'light',
        }
      });
    } on FirebaseException catch (e) {
      throw Exception('Failed to create default settings: ${e.message}');
    }
  }

  /// Obter settings do utilizador
  Future<UserSettings?> getUserSettings(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['settings'] != null) {
          return UserSettings.fromFirestore(data['settings'] as Map<String, dynamic>);
        }
      }
      return null;
    } on FirebaseException catch (e) {
      throw Exception('Failed to get user settings: ${e.message}');
    }
  }

  /// Atualizar settings
  Future<void> updateUserSettings(
      String userId,
      Map<String, dynamic> updates,
      ) async {
    try {
      Map<String, dynamic> settingsUpdates = {};
      updates.forEach((key, value) {
        settingsUpdates['settings.$key'] = value;
      });

      await _firestore.collection('users').doc(userId).update(settingsUpdates);
    } on FirebaseException catch (e) {
      throw Exception('Failed to update user settings: ${e.message}');
    }
  }

  // ==================== PAGINATION (Optional but recommended) ====================

  /// Obter despesas com paginação
  Future<List<Expense>> getExpensesPaginated(
      String userId, {
        int limit = 20,
        DocumentSnapshot? lastDocument,
      }) async {
    try {
      Query query = _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .orderBy('date', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        return Expense.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } on FirebaseException catch (e) {
      throw Exception('Failed to get paginated expenses: ${e.message}');
    }
  }
}