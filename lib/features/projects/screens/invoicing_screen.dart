import 'package:flutter/material.dart';

class InvoicingScreen extends StatefulWidget {
  const InvoicingScreen({super.key});

  @override
  State<InvoicingScreen> createState() => _InvoicingScreenState();
}

class _InvoicingScreenState extends State<InvoicingScreen> {
  final List<Map<String, dynamic>> _invoices = [
    {
      'id': 'INV-001',
      'client': 'John Doe',
      'amount': 1500.00,
      'date': '2024-03-01',
      'status': 'Paid',
    },
    {
      'id': 'INV-002',
      'client': 'Jane Smith',
      'amount': 2500.00,
      'date': '2024-03-15',
      'status': 'Pending',
    },
  ];

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredInvoices = [];

  // Currency selection
  String _selectedCurrency = 'KES';
  final Map<String, String> _currencySymbols = {
    'KES': 'KSh',
    'USD': '\$',
    'EUR': '€',
  };

  @override
  void initState() {
    super.initState();
    _filteredInvoices = List.from(_invoices);
    _searchController.addListener(_filterInvoices);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterInvoices);
    _searchController.dispose();
    super.dispose();
  }

  void _filterInvoices() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredInvoices = _invoices.where((invoice) {
        final client = invoice['client'].toLowerCase();
        final id = invoice['id'].toLowerCase();
        return client.contains(query) || id.contains(query);
      }).toList();
    });
  }

  void _handleAddOrEditInvoice({Map<String, dynamic>? existingInvoice}) {
    final TextEditingController clientController = TextEditingController(
      text: existingInvoice?['client'] ?? '',
    );
    final TextEditingController amountController = TextEditingController(
      text: existingInvoice != null ? existingInvoice['amount'].toString() : '',
    );
    final TextEditingController dateController = TextEditingController(
      text: existingInvoice?['date'] ?? '',
    );
    String status = existingInvoice?['status'] ?? 'Pending';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingInvoice == null ? 'Add New Invoice' : 'Edit Invoice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: clientController,
              decoration: const InputDecoration(labelText: 'Client'),
            ),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: dateController,
              decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
              keyboardType: TextInputType.datetime,
            ),
            DropdownButtonFormField<String>(
              value: status,
              items: ['Pending', 'Paid'].map((status) {
                return DropdownMenuItem(value: status, child: Text(status));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  status = value!;
                });
              },
              decoration: const InputDecoration(labelText: 'Status'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final String client = clientController.text;
              final double? amount = double.tryParse(amountController.text);
              final String date = dateController.text;

              if (client.isNotEmpty && amount != null && date.isNotEmpty) {
                setState(() {
                  if (existingInvoice != null) {
                    existingInvoice['client'] = client;
                    existingInvoice['amount'] = amount;
                    existingInvoice['date'] = date;
                    existingInvoice['status'] = status;
                  } else {
                    _invoices.add({
                      'id': 'INV-${_invoices.length + 1}'.padLeft(3, '0'),
                      'client': client,
                      'amount': amount,
                      'date': date,
                      'status': status,
                    });
                  }
                  _filteredInvoices = List.from(_invoices);
                });
                Navigator.pop(context);
              }
            },
            child: Text(existingInvoice == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _deleteInvoice(Map<String, dynamic> invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Invoice ${invoice['id']}?'),
        content: const Text('Are you sure you want to delete this invoice?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _invoices.remove(invoice);
                _filteredInvoices = List.from(_invoices);
              });
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = _currencySymbols[_selectedCurrency] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoicing'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search invoices...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _handleAddOrEditInvoice(),
                  icon: const Icon(Icons.add),
                  label: const Text('New Invoice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Currency:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedCurrency,
                  items: _currencySymbols.keys.map((currency) {
                    return DropdownMenuItem(
                      value: currency,
                      child: Text(currency),
                    );
                  }).toList(),
                  onChanged: (newCurrency) {
                    setState(() {
                      _selectedCurrency = newCurrency!;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredInvoices.length,
              itemBuilder: (context, index) {
                final invoice = _filteredInvoices[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      '${invoice['client']} - ${invoice['id']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Date: ${invoice['date']}'),
                        Text(
                          'Amount: $currencySymbol${invoice['amount'].toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _handleAddOrEditInvoice(existingInvoice: invoice),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteInvoice(invoice),
                        ),
                        Chip(
                          label: Text(
                            invoice['status'],
                            style: TextStyle(
                              color: invoice['status'] == 'Paid'
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: invoice['status'] == 'Paid'
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
