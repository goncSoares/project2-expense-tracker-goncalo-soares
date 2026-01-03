import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/budget_provider.dart';
import '../providers/expense_provider.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../services/currency_service.dart';
import '../providers/settings_provider.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final List<String> _categories = [
    'Food', 'Transport', 'Entertainment', 'Shopping', 
    'Health', 'Education', 'Bills', 'Other'
  ];

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Budgets'),
        elevation: 0,
      ),
      body: Consumer2<BudgetProvider, ExpenseProvider>(
        builder: (context, budgetProvider, expenseProvider, _) {
          // 1. Calculate spending per category for CURRENT MONTH
          final expenses = expenseProvider.expenses;
          final now = DateTime.now();
          final startOfMonth = DateTime(now.year, now.month, 1);
          
          final Map<String, double> currentSpending = {};
          
          for (var expense in expenses) {
            if (expense.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1)))) {
               currentSpending[expense.category] = 
                   (currentSpending[expense.category] ?? 0) + expense.amount;
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final budget = budgetProvider.getBudgetForCategory(category);
              final spent = currentSpending[category] ?? 0.0;
              final limit = budget?.limit ?? 0.0;
              final hasBudget = limit > 0;
              final progress = hasBudget ? (spent / limit).clamp(0.0, 1.0) : 0.0;
              final isOverBudget = spent > limit;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(category).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getCategoryIcon(category),
                              color: _getCategoryColor(category),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (hasBudget)
                                  Text(
                                    isOverBudget 
                                        ? 'Over Budget!'
                                        : '${(progress * 100).toStringAsFixed(0)}% used',
                                    style: TextStyle(
                                      color: isOverBudget ? Colors.red : Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                else
                                  const Text(
                                    'No limit set',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              hasBudget ? Icons.edit : Icons.add_circle_outline,
                              color: Theme.of(context).primaryColor,
                            ),
                            onPressed: () => _showSetBudgetDialog(context, category, budget),
                          ),
                        ],
                      ),
                      if (hasBudget || spent > 0) ...[
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: hasBudget ? progress : 0,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation(
                            isOverBudget ? Colors.red : _getCategoryColor(category),
                          ),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<Map<String, double>>(
                          future: _convertValues(spent, limit, settings.currency),
                          builder: (context, snapshot) {
                            final data = snapshot.data;
                            final displaySpent = data?['spent'] ?? spent;
                            final displayLimit = data?['limit'] ?? limit;
                            final symbol = CurrencyService.getCurrencySymbol(settings.currency);

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$symbol${displaySpent.toStringAsFixed(0)} spent',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (hasBudget)
                                  Text(
                                    '$symbol${displayLimit.toStringAsFixed(0)} limit',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<Map<String, double>> _convertValues(double spent, double limit, String currency) async {
    if (currency == 'EUR') return {'spent': spent, 'limit': limit};
    
    final s = await CurrencyService.convert(amount: spent, from: 'EUR', to: currency);
    final l = await CurrencyService.convert(amount: limit, from: 'EUR', to: currency);
    return {'spent': s, 'limit': l};
  }

  void _showSetBudgetDialog(BuildContext context, String category, Budget? currentBudget) {
    final controller = TextEditingController(
      text: currentBudget?.limit.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Budget for $category'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Monthly Limit (EUR)',
            prefixText: '€',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final limit = double.tryParse(controller.text);
              if (limit != null) {
                try {
                  final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
                  final budget = Budget(
                    id: currentBudget?.id ?? category,
                    category: category,
                    limit: limit,
                    period: 'Monthly',
                  );
                  
                  await budgetProvider.setBudget(budget);
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Budget saved successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving budget: $e')),
                    );
                  }
                }
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid number')),
                 );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Food': return Colors.orange;
      case 'Transport': return Colors.blue;
      case 'Entertainment': return Colors.purple;
      case 'Shopping': return Colors.pink;
      case 'Health': return Colors.red;
      case 'Education': return Colors.green;
      case 'Bills': return Colors.brown;
      default: return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food': return Icons.restaurant;
      case 'Transport': return Icons.directions_car;
      case 'Entertainment': return Icons.movie;
      case 'Shopping': return Icons.shopping_bag;
      case 'Health': return Icons.local_hospital;
      case 'Education': return Icons.school;
      case 'Bills': return Icons.receipt;
      default: return Icons.category;
    }
  }
}
