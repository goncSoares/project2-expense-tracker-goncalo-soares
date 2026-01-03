import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';

class CurrencySelectorWidget extends StatelessWidget {
  const CurrencySelectorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CurrencyProvider>(
      builder: (context, currencyProvider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.currency_exchange, size: 20),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: currencyProvider.selectedCurrency,
                underline: const SizedBox(),
                isDense: true,
                items: CurrencyProvider.availableCurrencies.map((currency) {
                  return DropdownMenuItem(
                    value: currency['code'],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currency['symbol']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          currency['code']!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    currencyProvider.changeCurrency(value);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Currency changed to ${currencyProvider.getCurrencyName()}',
                        ),
                        duration: const Duration(seconds: 2),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
              if (currencyProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Dialog for detailed currency selection
class CurrencySelectionDialog extends StatelessWidget {
  const CurrencySelectionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.currency_exchange),
          SizedBox(width: 8),
          Text('Select Currency'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: CurrencyProvider.availableCurrencies.length,
          itemBuilder: (context, index) {
            final currency = CurrencyProvider.availableCurrencies[index];
            final isSelected =
                currency['code'] == currencyProvider.selectedCurrency;

            return Card(
              elevation: isSelected ? 4 : 1,
              color: isSelected
                  ? Theme.of(context).primaryColor.withOpacity(0.1)
                  : null,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    currency['symbol']!,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Theme.of(context).primaryColor : null,
                    ),
                  ),
                ),
                title: Text(
                  currency['name']!,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : null,
                  ),
                ),
                subtitle: Text(currency['code']!),
                trailing: isSelected
                    ? Icon(
                  Icons.check_circle,
                  color: Theme.of(context).primaryColor,
                )
                    : null,
                onTap: () {
                  currencyProvider.changeCurrency(currency['code']!);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Currency changed to ${currency['name']}',
                      ),
                      duration: const Duration(seconds: 2),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      actions: [
        if (currencyProvider.error != null)
          TextButton.icon(
            onPressed: () async {
              await currencyProvider.refreshRates();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Rates'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}