import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../models/currency.dart';
import '../services/currency_service.dart';
import 'expense_form_screen.dart';
import 'expense_detail_screen.dart';
import 'statistics_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import '../providers/settings_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedCategory;
  DateTimeRange? _dateRange;
  // _selectedCurrency moved to SettingsProvider
  Map<String, double> _convertedAmounts = {};

  @override
  void initState() {
    super.initState();
  }
  
  // _loadPreferredCurrency removed

  Future<void> _changeCurrency(String newCurrency) async {
    // Cache clearing is handled by key change or we can clear here
    setState(() {
      _convertedAmounts.clear();
    });
    
    await Provider.of<SettingsProvider>(context, listen: false).setCurrency(newCurrency);
  }

  Future<double> _getConvertedAmount(double amount) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currency = settings.currency;
    
    if (currency == 'EUR') return amount;

    final key = '${amount}_$currency';
    if (_convertedAmounts.containsKey(key)) {
      return _convertedAmounts[key]!;
    }

    final converted = await CurrencyService.convert(
      amount: amount,
      from: 'EUR',
      to: currency,
    );

    _convertedAmounts[key] = converted;
    return converted;
  }

  @override
  Widget build(BuildContext context) {
    // Listen to settings changes
    final settings = Provider.of<SettingsProvider>(context);
    final provider = Provider.of<ExpenseProvider>(context);

    // Filtrar despesas
    List<Expense> filteredExpenses = provider.expenses;

    if (_selectedCategory != null) {
      filteredExpenses = filteredExpenses
          .where((e) => e.category == _selectedCategory)
          .toList();
    }

    if (_dateRange != null) {
      filteredExpenses = filteredExpenses.where((e) {
        return e.date.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
            e.date.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // Calcular total (em EUR)
    double totalEUR = filteredExpenses.fold(0, (sum, expense) => sum + expense.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Statistics',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatisticsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'clear') {
                setState(() {
                  _selectedCategory = null;
                  _dateRange = null;
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Text('Clear Filters'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).brightness == Brightness.dark 
                ? Theme.of(context).cardColor.withOpacity(0.5)
                : Theme.of(context).primaryColor.withOpacity(0.1),
            child: Column(
              children: [
                // Total display
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FutureBuilder<double>(
                      future: _getConvertedAmount(totalEUR),
                      builder: (context, snapshot) {
                        final displayTotal = snapshot.data ?? totalEUR;
                        final symbol = CurrencyService.getCurrencySymbol(settings.currency);
                        
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total:',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (snapshot.connectionState == ConnectionState.waiting)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                else
                                   Text(
                                    '$symbol${displayTotal.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilterChip(
                        label: Text(_selectedCategory ?? 'All Categories'),
                        selected: _selectedCategory != null,
                        onSelected: (_) => _showCategoryFilter(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Currency Selector
                    PopupMenuButton<String>(
                      tooltip: 'Change Currency',
                      onSelected: _changeCurrency,
                      itemBuilder: (context) => Currency.popular.map((currency) {
                        return PopupMenuItem(
                          value: currency.code,
                          child: Row(
                            children: [
                              Text(currency.flag, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Text('${currency.code} - ${currency.name}'),
                              if (currency.code == settings.currency)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.check, size: 16),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              Currency.getByCode(settings.currency)?.flag ?? '', 
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              settings.currency,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilterChip(
                        label: Text(_dateRange == null
                            ? 'All Dates'
                            : '${_dateRange!.start.day}/${_dateRange!.start.month} - ${_dateRange!.end.day}/${_dateRange!.end.month}'),
                        selected: _dateRange != null,
                        onSelected: (_) => _selectDateRange(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lista de despesas
          Expanded(
            child: filteredExpenses.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No expenses yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add your first expense',
                    style: TextStyle(
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: filteredExpenses.length,
              itemBuilder: (context, index) {
                final expense = filteredExpenses[index];
                return Dismissible(
                  key: Key(expense.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Expense'),
                        content: const Text('Are you sure you want to delete this expense?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) async {
                    try {
                      await provider.deleteExpense(expense.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Expense deleted')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: ${e.toString()}')),
                        );
                      }
                    }
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(_getCategoryIcon(expense.category)),
                      ),
                      title: Text(
                        expense.description,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '${expense.category} • ${expense.date.day}/${expense.date.month}/${expense.date.year}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FutureBuilder<double>(
                            future: _getConvertedAmount(expense.amount),
                            builder: (context, snapshot) {
                              final amount = snapshot.data ?? expense.amount;
                              final symbol = CurrencyService.getCurrencySymbol(settings.currency);
                              return Text(
                                '$symbol${amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ExpenseFormScreen(expense: expense),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExpenseDetailScreen(expense: expense),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExpenseFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCategoryFilter() {
    final categories = ['Food', 'Transport', 'Entertainment', 'Shopping', 'Health', 'Education', 'Bills', 'Other'];

    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('All Categories'),
            leading: const Icon(Icons.clear),
            onTap: () {
              setState(() => _selectedCategory = null);
              Navigator.pop(context);
            },
          ),
          const Divider(),
          ...categories.map((category) => ListTile(
            title: Text(category),
            leading: Icon(_getCategoryIcon(category)),
            onTap: () {
              setState(() => _selectedCategory = category);
              Navigator.pop(context);
            },
          )),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant;
      case 'Transport':
        return Icons.directions_car;
      case 'Entertainment':
        return Icons.movie;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Health':
        return Icons.local_hospital;
      case 'Education':
        return Icons.school;
      case 'Bills':
        return Icons.receipt;
      default:
        return Icons.category;
    }
  }
}