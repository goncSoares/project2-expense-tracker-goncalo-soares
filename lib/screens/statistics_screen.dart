import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../models/currency.dart';
import '../services/currency_service.dart';
import '../providers/settings_provider.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _selectedPeriod = 'This Month';
  // Currency state moved to SettingsProvider

  @override
  void initState() {
    super.initState();
  }
  
  // _loadPreferredCurrency removed

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final provider = Provider.of<ExpenseProvider>(context);

    // Filtrar por período
    List<Expense> filteredExpenses = _filterByPeriod(provider.expenses);

    // Calcular totais por categoria
    Map<String, double> categoryTotals = {};
    double grandTotal = 0;

    for (var expense in filteredExpenses) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0) + expense.amount;
      grandTotal += expense.amount;
    }

    // Ordenar categorias por valor
    var sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Statistics'),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                settings.currency,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.currency_exchange),
            tooltip: 'Change Currency',
            onSelected: (currency) {
              settings.setCurrency(currency);
            },
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
          ),
        ],
      ),
      body: filteredExpenses.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No expenses in this period',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period Selector
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPeriodChip('This Week'),
                  _buildPeriodChip('This Month'),
                  _buildPeriodChip('This Year'),
                ],
              ),
            ),

            // 🎯 TOTAL CARD - DESTACADO NO TOPO
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 8,
                color: Theme.of(context).primaryColor,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'TOTAL SPENDING',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<double>(
                        future: CurrencyService.convert(
                          amount: grandTotal,
                          from: 'EUR',
                          to: settings.currency,
                        ),
                        builder: (context, snapshot) {
                          final displayTotal = snapshot.data ?? grandTotal;
                          final symbol = CurrencyService.getCurrencySymbol(settings.currency);
                          return Text(
                            '$symbol${displayTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${filteredExpenses.length} transaction${filteredExpenses.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 📈 DAILY SPENDING TREND - MELHORADO
            if (filteredExpenses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FutureBuilder<double>(
                  future: CurrencyService.convert(amount: 1, from: 'EUR', to: settings.currency),
                  builder: (context, snapshot) {
                    final rate = snapshot.data ?? 1.0;
                    final symbol = CurrencyService.getCurrencySymbol(settings.currency);
                    
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.show_chart,
                                      color: Theme.of(context).primaryColor,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Daily Spending Trend',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'in $symbol',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // 🎨 GRÁFICO DE LINHA
                            SizedBox(
                              height: 150,
                              child: CustomPaint(
                                painter: LineChartPainter(
                                  expenses: filteredExpenses,
                                  period: _selectedPeriod,
                                  primaryColor: Theme.of(context).primaryColor,
                                  conversionRate: rate,
                                  currencySymbol: symbol,
                                ),
                                size: Size.infinite,
                              ),
                            ),

                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 12),

                            // 💰 AVERAGE PER DAY - POSICIONADO MELHOR
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Theme.of(context).cardColor
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Average per day',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'In this period',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '$symbol${(_calculateAveragePerDay(filteredExpenses) * rate).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),

            // 📊 SPENDING BY CATEGORY
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Spending by Category',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Category Breakdown
            ...sortedCategories.map((entry) {
              double percentage = (entry.value / grandTotal) * 100;
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(entry.key)
                                        .withOpacity(0.2),
                                    borderRadius:
                                    BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(entry.key),
                                    size: 24,
                                    color: _getCategoryColor(entry.key),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${percentage.toStringAsFixed(1)}% of total',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            FutureBuilder<double>(
                              future: CurrencyService.convert(
                                amount: entry.value,
                                from: 'EUR',
                                to: settings.currency,
                              ),
                              builder: (context, snapshot) {
                                final amount = snapshot.data ?? entry.value;
                                final symbol = CurrencyService.getCurrencySymbol(settings.currency);
                                return Text(
                                  '$symbol${amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            minHeight: 10,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getCategoryColor(entry.key),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String period) {
    bool isSelected = _selectedPeriod == period;
    return ChoiceChip(
      label: Text(period),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedPeriod = period;
        });
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),
    );
  }

  List<Expense> _filterByPeriod(List<Expense> expenses) {
    DateTime now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case 'This Week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case 'This Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'This Year':
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        return expenses;
    }

    return expenses.where((expense) {
      return expense.date.isAfter(startDate.subtract(const Duration(days: 1)));
    }).toList();
  }

  double _calculateAveragePerDay(List<Expense> expenses) {
    if (expenses.isEmpty) return 0;

    DateTime now = DateTime.now();
    int days;

    switch (_selectedPeriod) {
      case 'This Week':
        days = now.weekday;
        break;
      case 'This Month':
        days = now.day;
        break;
      case 'This Year':
        DateTime startDate = DateTime(now.year, 1, 1);
        days = now.difference(startDate).inDays + 1;
        break;
      default:
        days = 1;
    }

    double total = expenses.fold(0, (sum, expense) => sum + expense.amount);
    return total / days;
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

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Food':
        return Colors.orange;
      case 'Transport':
        return Colors.blue;
      case 'Entertainment':
        return Colors.purple;
      case 'Shopping':
        return Colors.pink;
      case 'Health':
        return Colors.red;
      case 'Education':
        return Colors.green;
      case 'Bills':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
}

// 🎨 Custom Painter para o gráfico de linha - MELHORADO
class LineChartPainter extends CustomPainter {
  final List<Expense> expenses;
  final String period;
  final Color primaryColor;
  final double conversionRate;
  final String currencySymbol;

  LineChartPainter({
    required this.expenses,
    required this.period,
    required this.primaryColor,
    required this.conversionRate,
    required this.currencySymbol,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (expenses.isEmpty) return;

    // Organizar despesas por dia
    Map<DateTime, double> dailyTotals = {};

    for (var expense in expenses) {
      DateTime day =
      DateTime(expense.date.year, expense.date.month, expense.date.day);
      dailyTotals[day] = (dailyTotals[day] ?? 0) + (expense.amount * conversionRate);
    }

    if (dailyTotals.isEmpty) return;

    // Ordenar datas
    List<DateTime> sortedDates = dailyTotals.keys.toList()..sort();

    // Encontrar valores máximos
    double maxAmount = dailyTotals.values.reduce((a, b) => a > b ? a : b);
    if (maxAmount == 0) return;

    // Configurar paint
    final linePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pointPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final areaPaint = Paint()
      ..color = primaryColor.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;

    // Dimensões
    double width = size.width;
    double height = size.height;
    double paddingLeft = 40;
    double paddingRight = 20;
    double paddingTop = 20;
    double paddingBottom = 30;

    double chartWidth = width - paddingLeft - paddingRight;
    double chartHeight = height - paddingTop - paddingBottom;

    // Desenhar grid horizontal
    for (int i = 0; i <= 4; i++) {
      double y = paddingTop + (chartHeight / 4) * i;
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(width - paddingRight, y),
        gridPaint,
      );
    }

    // Calcular pontos
    List<Offset> points = [];
    for (int i = 0; i < sortedDates.length; i++) {
      double x = paddingLeft + (i / (sortedDates.length - 1).clamp(1, 999)) * chartWidth;
      double amount = dailyTotals[sortedDates[i]]!;
      double y = paddingTop + chartHeight - (amount / maxAmount) * chartHeight;
      points.add(Offset(x, y));
    }

    // Desenhar área sob a linha
    if (points.length > 1) {
      Path areaPath = Path();
      areaPath.moveTo(points.first.dx, height - paddingBottom);
      for (var point in points) {
        areaPath.lineTo(point.dx, point.dy);
      }
      areaPath.lineTo(points.last.dx, height - paddingBottom);
      areaPath.close();
      canvas.drawPath(areaPath, areaPaint);
    }

    // Desenhar linha
    if (points.length > 1) {
      Path linePath = Path();
      linePath.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(linePath, linePaint);
    }

    // Desenhar pontos
    for (var point in points) {
      canvas.drawCircle(point, 5, pointPaint);
      canvas.drawCircle(
          point,
          8,
          Paint()
            ..color = primaryColor.withOpacity(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    // Labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Label de valor máximo
    textPainter.text = TextSpan(
      text: '$currencySymbol${maxAmount.toStringAsFixed(0)}',
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
    textPainter.layout();
    textPainter.paint(
        canvas, Offset(5, paddingTop - textPainter.height / 2));

    // Label de valor zero
    textPainter.text = TextSpan(
      text: '${currencySymbol}0',
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
    textPainter.layout();
    textPainter.paint(
        canvas,
        Offset(5,
            height - paddingBottom - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}