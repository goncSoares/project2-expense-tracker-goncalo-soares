import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import 'auth_provider.dart';

class ExpenseProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  
  String? _userId;

  List<Expense> _expenses = [];
  List<Expense> get expenses => _expenses;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // Called by ProxyProvider when AuthProvider updates
  void update(AuthProvider auth) {
    if (auth.user?.uid != _userId) {
      _userId = auth.user?.uid;
      
      if (_userId != null) {
        _listenToExpenses(_userId!);
      } else {
        _expenses = [];
        notifyListeners();
      }
    }
  }

  /// Listen to real-time changes nas despesas do user
  void _listenToExpenses(String userId) {
    _isLoading = true; // Set loading initially
    notifyListeners();
    
    _firestoreService.getUserExpenses(userId).listen(
          (expenses) {
        _expenses = expenses;
        _isLoading = false;
        _error = null;
        notifyListeners();
        _checkRecurringExpenses(); // Check for auto-generation
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
    if (_userId == null) {
      throw Exception('No user logged in');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.addExpense(_userId!, expense);
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
    if (_userId == null) {
      throw Exception('No user logged in');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.updateExpense(
        _userId!,
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
    if (_userId == null) {
      throw Exception('No user logged in');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Delete receipts from Storage FIRST
      await _storageService.deleteItemImages(expenseId);

      // 2. Then delete from Firestore
      await _firestoreService.deleteExpense(_userId!, expenseId);

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
    if (_userId == null) {
      throw Exception('No user logged in');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Delete receipts for each expense
      for (String expenseId in expenseIds) {
        await _storageService.deleteItemImages(expenseId);
      }

      // Then batch delete from Firestore
      await _firestoreService.batchDeleteExpenses(_userId!, expenseIds);

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
    if (_userId == null) return;

    try {
      // Get all active expense IDs
      final activeIds = _expenses.map((e) => e.id).toList();

      // Cleanup orphaned files
      await _storageService.cleanupOrphanedFiles(_userId!, activeIds);
    } catch (e) {
      print('Cleanup error: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Check and generate recurring expenses
  Future<void> _checkRecurringExpenses() async {
    if (_userId == null) return;
    
    final now = DateTime.now();
    final recurringSources = _expenses.where((e) => e.isRecurring).toList();

    for (var source in recurringSources) {
      if (source.recurringFrequency == null) continue;

      DateTime nextDate = _calculateNextDate(source.date, source.recurringFrequency!);
      
      // Prevent infinite loop if bad data (e.g. daily for 10 years ago)
      // Limit catch-up to 365 days or 50 instances?
      int safetyCount = 0;
      
      while (nextDate.isBefore(now) && safetyCount < 50) {
        safetyCount++;
        
        // Tag to identify this specific instance
        final String periodTag = 'rec_${source.id}_${nextDate.year}_${nextDate.month}_${nextDate.day}';
        
        final alreadyExists = _expenses.any((e) => e.tags.contains(periodTag));
        
        if (!alreadyExists) {
             // Create child expense
             final newExpense = source.copyWith(
               id: 'pending', // ID will be generated by Firestore
               date: nextDate,
               isRecurring: false, // Child is not a source
               tags: [...source.tags, periodTag, 'auto_generated'],
               createdAt: DateTime.now(),
               updatedAt: DateTime.now(),
             );
             
             // Add directly to Firestore (will trigger listener update)
             await _firestoreService.addExpense(_userId!, newExpense);
             
             // Also update budget! (Best effort)
             await _firestoreService.updateBudgetSpent(_userId!, newExpense.category, newExpense.amount);
        }
        
        nextDate = _calculateNextDate(nextDate, source.recurringFrequency!);
      }
    }
  }

  DateTime _calculateNextDate(DateTime date, String frequency) {
    if (frequency == 'Daily') {
      return date.add(const Duration(days: 1));
    } else if (frequency == 'Weekly') {
      return date.add(const Duration(days: 7));
    } else if (frequency == 'Monthly') {
      var newDate = DateTime(date.year, date.month + 1, date.day);
       if (newDate.month != (date.month % 12) + 1) {
         // Overflow (e.g. Oct 31 -> Dec 1), return last day of Nov
         newDate = DateTime(date.year, date.month + 2, 0); 
       }
       return newDate;
    } else if (frequency == 'Yearly') {
      return DateTime(date.year + 1, date.month, date.day);
    }
    return date;
  }
}