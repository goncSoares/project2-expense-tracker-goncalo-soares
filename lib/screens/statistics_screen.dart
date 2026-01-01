import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _selectedPeriod = 'This Month';

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Statistics'),
        elevation: 0,
      ),
      body: filteredExpenses.isEmpty
          ? const Center(
        child: Text('No expenses in this period'),
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

            // Total Card - CENTRALIZADO
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 4,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text(
                          'Total Spending',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '€${grandTotal.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${filteredExpenses.length} transaction${filteredExpenses.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Average per day - MELHORADO COM GRÁFICO
            if (filteredExpenses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        const SizedBox(height: 16),

                        // Mini gráfico de linha
                        SizedBox(
                          height: 100,
                          child: CustomPaint(
                            painter: LineChartPainter(
                              expenses: filteredExpenses,
                              period: _selectedPeriod,
                            ),
                            size: Size.infinite,
                          ),
                        ),

                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),

                        // Média por dia
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Average per day',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '€${_calculateAveragePerDay(filteredExpenses).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Spending by Category
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getCategoryIcon(entry.key),
                              size: 20,
                              color: _getCategoryColor(entry.key),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '€${entry.value.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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

// Custom Painter para o gráfico de linha
class LineChartPainter extends CustomPainter {
  final List<Expense> expenses;
  final String period;

  LineChartPainter({required this.expenses, required this.period});

  @override
  void paint(Canvas canvas, Size size) {
    if (expenses.isEmpty) return;

    // Organizar despesas por dia
    Map<DateTime, double> dailyTotals = {};

    for (var expense in expenses) {
      DateTime day = DateTime(expense.date.year, expense.date.month, expense.date.day);
      dailyTotals[day] = (dailyTotals[day] ?? 0) + expense.amount;
    }

    // Ordenar datas
    List<DateTime> sortedDates = dailyTotals.keys.toList()..sort();

    if (sortedDates.isEmpty) return;

    // Encontrar valores máximos
    double maxAmount = dailyTotals.values.reduce((a, b) => a > b ? a : b);

    // Configurar paint para linha
    final linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Configurar paint para pontos
    final pointPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    // Configurar paint para área sob a linha
    final areaPaint = Paint()
      ..color = Colors.blue.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Calcular pontos
    List<Offset> points = [];
    double width = size.width;
    double height = size.height;
    double padding = 20;

    for (int i = 0; i < sortedDates.length; i++) {
      double x = padding + (i / (sortedDates.length - 1)) * (width - 2 * padding);
      double amount = dailyTotals[sortedDates[i]]!;
      double y = height - padding - (amount / maxAmount) * (height - 2 * padding);
      points.add(Offset(x, y));
    }

    // Desenhar área sob a linha
    if (points.length > 1) {
      Path areaPath = Path();
      areaPath.moveTo(points.first.dx, height - padding);
      for (var point in points) {
        areaPath.lineTo(point.dx, point.dy);
      }
      areaPath.lineTo(points.last.dx, height - padding);
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
      canvas.drawCircle(point, 4, pointPaint);
      canvas.drawCircle(point, 6, Paint()
        ..color = Colors.blue.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}