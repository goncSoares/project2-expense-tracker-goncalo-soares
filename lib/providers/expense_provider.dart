import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/expense.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class ExpenseProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Expense> _expenses = [];
  List<Expense> get expenses => _expenses;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  ExpenseProvider() {
    _initializeListener();
  }

  /// Inicializar listener de despesas quando user faz login
  void _initializeListener() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _listenToExpenses(user.uid);
      } else {
        _expenses = [];
        notifyListeners();
      }
    });
  }

  /// Listen to real-time changes nas despesas do user
  void _listenToExpenses(String userId) {
    _firestoreService.getUserExpenses(userId).listen(
          (expenses) {
        _expenses = expenses;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Adicionar despesa
  Future<void> addExpense(Expense expense) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.addExpense(user.uid, expense);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Atualizar despesa
  Future<void> updateExpense(Expense expense) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.updateExpense(
        user.uid,
        expense.id,
        expense.toFirestore(),
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Eliminar despesa (COM CLEANUP DE STORAGE)
  Future<void> deleteExpense(String expenseId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Delete receipts from Storage FIRST
      await _storageService.deleteExpenseReceipts(expenseId);

      // 2. Then delete from Firestore
      await _firestoreService.deleteExpense(user.uid, expenseId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Batch delete com cleanup de storage
  Future<void> batchDeleteExpenses(List<String> expenseIds) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Delete receipts for each expense
      for (String expenseId in expenseIds) {
        await _storageService.deleteExpenseReceipts(expenseId);
      }

      // Then batch delete from Firestore
      await _firestoreService.batchDeleteExpenses(user.uid, expenseIds);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Cleanup orphaned files periodically
  Future<void> cleanupOrphanedFiles() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Get all active expense IDs
      final activeIds = _expenses.map((e) => e.id).toList();

      // Cleanup orphaned files
      await _storageService.cleanupOrphanedFiles(activeIds);
    } catch (e) {
      print('Cleanup error: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}