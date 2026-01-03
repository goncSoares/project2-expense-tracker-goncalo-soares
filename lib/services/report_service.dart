import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/expense.dart';
import 'package:intl/intl.dart';

class ReportService {
  
  /// Normalize expenses for export (sort by date)
  List<Expense> _prepareExpenses(List<Expense> expenses) {
    final sorted = List<Expense>.from(expenses);
    sorted.sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }

  /// Export to CSV
  Future<void> exportCSV(List<Expense> expenses) async {
    final data = _prepareExpenses(expenses);
    
    List<List<dynamic>> rows = [];
    rows.add(['Date', 'Category', 'Amount', 'Currency', 'Description', 'Location']);
    
    for (var e in data) {
      rows.add([
        DateFormat('yyyy-MM-dd').format(e.date),
        e.category,
        e.amount,
        e.currency,
        e.description,
        e.locationName ?? ''
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);
    
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/expenses_report.csv');
    await file.writeAsString(csv);
    
    await Share.shareXFiles([XFile(file.path)], text: 'Expense Report (CSV)');
  }

  /// Export to PDF
  Future<void> exportPDF(List<Expense> expenses, String title) async {
    final data = _prepareExpenses(expenses);
    final doc = pw.Document();
    final font = await PdfGoogleFonts.nunitoExtraLight();
    
    // Calculate total per currency
    Map<String, double> totals = {};
    for (var e in data) {
      totals[e.currency] = (totals[e.currency] ?? 0) + e.amount;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                   pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                   pw.Text(DateFormat('yyyy-MM-dd').format(DateTime.now())),
                ]
              )
            ),
            pw.SizedBox(height: 20),
            pw.Text('Summary:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ...totals.entries.map((e) => pw.Text('${e.key} ${e.value.toStringAsFixed(2)}')),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              context: context,
              data: <List<String>>[
                <String>['Date', 'Category', 'Description', 'Amount'],
                ...data.map((e) => [
                  DateFormat('MM/dd/yyyy').format(e.date),
                  e.category,
                  e.description,
                  '${e.currency} ${e.amount.toStringAsFixed(2)}'
                ]),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'expenses_report.pdf');
  }
}
