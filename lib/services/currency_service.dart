import 'dart:convert';
import 'package:http/http.dart' as http;

class CurrencyService {
  // Função para converter um valor de uma moeda para outra
  static Future<double> convert({
    required double amount,
    required String from,
    required String to,
  }) async {
    try {
      final url = Uri.parse(
          'https://api.frankfurter.app/latest?from=$from&to=$to');

      print("=== PEDIDO ===");
      print(url);

      final response = await http.get(url);

      print("=== RESPOSTA STATUS ===");
      print(response.statusCode);

      print("=== BODY ===");
      print(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        print("=== DATA MAP ===");
        print(data);

        print("=== RATES MAP ===");
        print(data['rates']);

        print("=== RATE ($to) ===");
        print(data['rates'][to]);

        final rate = (data['rates'][to] as num?)?.toDouble();
        if (rate != null) {
          return amount * rate;
        } else {
          print("RATE veio null!");
          throw Exception('Taxa de câmbio inválida');
        }
      } else {
        throw Exception('Falha na API: ${response.statusCode}');
      }
    } catch (e) {
      print("=== ERRO NO CATCH ===");
      print(e);
      return amount; // fallback: mostra valor original
    }
  }
}
