import 'package:flutter/material.dart';
import 'dart:async';
import '../models/budget.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

class BudgetProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<Budget> _budgets = [];
  String? _userId;

  StreamSubscription<List<Budget>>? _budgetSubscription;

  List<Budget> get budgets => _budgets;

  void update(AuthProvider auth) {
    if (auth.user != null) {
      // Only re-init if user changed or not initialized
      if (_userId != auth.user!.uid) {
        _userId = auth.user!.uid;
        _initListener();
      }
    } else {
      _userId = null;
      _budgets = [];
      _budgetSubscription?.cancel();
      notifyListeners();
    }
  }

  void _initListener() {
    _budgetSubscription?.cancel();
    if (_userId == null) return;
    
    _budgetSubscription = _firestoreService.getUserBudgets(_userId!).listen((budgets) {
      _budgets = budgets;
      notifyListeners();
    }, onError: (e) {
      print('Error in Budget Stream: $e');
    });
  }

  @override
  void dispose() {
    _budgetSubscription?.cancel();
    super.dispose();
  }

  Future<void> setBudget(Budget budget) async {
    if (_userId == null) throw Exception('User not authenticated (BudgetProvider)');
    await _firestoreService.setBudget(_userId!, budget);
  }

  Future<void> deleteBudget(String budgetId) async {
    if (_userId == null) return;
    await _firestoreService.deleteBudget(_userId!, budgetId);
  }

  Budget? getBudgetForCategory(String category) {
    try {
      return _budgets.firstWhere((b) => b.category == category);
    } catch (_) {
      return null;
    }
  }
}
