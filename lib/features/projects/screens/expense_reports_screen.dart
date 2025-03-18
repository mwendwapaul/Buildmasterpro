import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class Currency {
  final String code;
  final String symbol;
  final String name;
  final double rateToKES; // conversion rate to Kenyan Shilling

  Currency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.rateToKES,
  });
}

class ExpenseCategory {
  final String id;
  final String name;
  final IconData icon;

  ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
  });
}

class Expense {
  String id;
  String title;
  double amount;
  DateTime date;
  String category;
  String? notes;
  String? attachmentUrl;
  String currency;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    this.notes,
    this.attachmentUrl,
    required this.currency,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'notes': notes,
      'attachmentUrl': attachmentUrl,
      'currency': currency,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      title: map['title'],
      amount: map['amount'].toDouble(),
      date: DateTime.parse(map['date']),
      category: map['category'],
      notes: map['notes'],
      attachmentUrl: map['attachmentUrl'],
      currency: map['currency'] ?? 'KES',
    );
  }
}

class ExpenseReportsScreen extends StatefulWidget {
  const ExpenseReportsScreen({super.key});

  @override
  State<ExpenseReportsScreen> createState() => _ExpenseReportsScreenState();
}

class _ExpenseReportsScreenState extends State<ExpenseReportsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  final DateTime _endDate = DateTime.now();
  String _selectedCategory = 'All';
  String _selectedCurrency = 'KES';
  double _previousTotal = 0;
  double _previousMonthly = 0;

  final List<Currency> _currencies = [
    Currency(code: 'KES', symbol: 'KSh', name: 'Kenyan Shilling', rateToKES: 1.0),
    Currency(code: 'USD', symbol: '\$', name: 'US Dollar', rateToKES: 134.50),
    Currency(code: 'EUR', symbol: '€', name: 'Euro', rateToKES: 146.80),
    Currency(code: 'GBP', symbol: '£', name: 'British Pound', rateToKES: 171.20),
  ];

  final List<ExpenseCategory> _categories = [
    ExpenseCategory(id: '1', name: 'Travel', icon: Icons.flight),
    ExpenseCategory(id: '2', name: 'Food', icon: Icons.restaurant),
    ExpenseCategory(id: '3', name: 'Shopping', icon: Icons.shopping_cart),
    ExpenseCategory(id: '4', name: 'Entertainment', icon: Icons.movie),
    ExpenseCategory(id: '5', name: 'Bills', icon: Icons.receipt),
    ExpenseCategory(id: '6', name: 'Other', icon: Icons.more_horiz),
  ];
  
  get _showFilterDialog => null;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedCurrency = prefs.getString('selectedCurrency') ?? 'KES';
    });
  }

   _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedCurrency', _selectedCurrency);
  }

  String _formatAmount(double amount, String currency) {
    final selectedCurrencyData = _currencies.firstWhere((c) => c.code == currency);
    final amountInKES = amount * selectedCurrencyData.rateToKES;
    final displayAmount = amountInKES / _currencies.firstWhere((c) => c.code == _selectedCurrency).rateToKES;
    
    return '${_currencies.firstWhere((c) => c.code == _selectedCurrency).symbol}${displayAmount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Reports'),
        centerTitle: true,
        backgroundColor: Colors.orange,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.currency_exchange),
            onPressed: _showCurrencyDialog,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generatePDFReport,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCards(),
          _buildFilterChips(),
          Expanded(
            child: _buildExpensesList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showExpenseDialog(),
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCurrencyDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Currency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _currencies
              .map(
                (currency) => RadioListTile<String>(
                  title: Text('${currency.name} (${currency.symbol})'),
                  value: currency.code,
                  groupValue: _selectedCurrency,
                  onChanged: (value) {
                    setState(() {
                      _selectedCurrency = value!;
                      _savePreferences();
                    });
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getExpensesStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final expenses = snapshot.data!.docs
            .map((doc) => Expense.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        double totalAmount = _calculateTotalInSelectedCurrency(expenses);
        double monthlyTotal = _calculateMonthlyTotalInSelectedCurrency(expenses);

        // Calculate changes
        double totalChange = totalAmount - _previousTotal;
        double monthlyChange = monthlyTotal - _previousMonthly;

        // Update previous values
        _previousTotal = totalAmount;
        _previousMonthly = monthlyTotal;

        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Expenses',
                  _formatAmount(totalAmount, _selectedCurrency),
                  Icons.attach_money,
                  Colors.green,
                  change: totalChange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'This Month',
                  _formatAmount(monthlyTotal, _selectedCurrency),
                  Icons.calendar_today,
                  Colors.blue,
                  change: monthlyChange,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
      String title, String amount, IconData icon, Color color,
      {double? change}) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              amount,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (change != null && change != 0)
              Text(
                '${change > 0 ? '+' : ''}${_formatAmount(change, _selectedCurrency)}',
                style: TextStyle(
                  color: change > 0 ? Colors.green : Colors.red,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePDFReport() async {
    final pdf = pw.Document();
    final expenses = await _firestore
        .collection('expenses')
        .where('date',
            isGreaterThanOrEqualTo: _startDate.toIso8601String())
        .where('date', isLessThanOrEqualTo: _endDate.toIso8601String())
        .get();

    final expensesList = expenses.docs
        .map((doc) => Expense.fromMap(doc.data()))
        .toList();

    // Sort expenses by date
    expensesList.sort((a, b) => b.date.compareTo(a.date));

    // Calculate totals
    final totalAmount = _calculateTotalInSelectedCurrency(expensesList);
    final monthlyTotal = _calculateMonthlyTotalInSelectedCurrency(expensesList);

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Expense Report',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 20, bottom: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Date Range: ${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}'),
                pw.Text('Currency: $_selectedCurrency'),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text('Total Expenses'),
                    pw.Text(_formatAmount(totalAmount, _selectedCurrency),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('Monthly Total'),
                    pw.Text(_formatAmount(monthlyTotal, _selectedCurrency),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          // ignore: deprecated_member_use
          pw.Table.fromTextArray(
            context: context,
            headers: ['Date', 'Category', 'Title', 'Amount', 'Notes'],
            data: expensesList
                .map((expense) => [
                      DateFormat('MMM dd, yyyy').format(expense.date),
                      expense.category,
                      expense.title,
                      _formatAmount(expense.amount, expense.currency),
                      expense.notes ?? '-',
                    ])
                .toList(),
          ),
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/expense_report.pdf');
    await file.writeAsBytes(await pdf.save());

    await OpenFile.open(file.path);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF Report generated successfully!')),
      );
    }
  }

  double _calculateTotalInSelectedCurrency(List<Expense> expenses) {
    // ignore: avoid_types_as_parameter_names
    return expenses.fold(0, (sum, expense) {
      final expenseCurrencyRate = _currencies
          .firstWhere((c) => c.code == expense.currency)
          .rateToKES;
      final selectedCurrencyRate =
          _currencies.firstWhere((c) => c.code == _selectedCurrency).rateToKES;
      return sum +
          (expense.amount * expenseCurrencyRate / selectedCurrencyRate);
    });
  }

  double _calculateMonthlyTotalInSelectedCurrency(List<Expense> expenses) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    return expenses
        .where((expense) =>
            expense.date.isAfter(monthStart) &&
            expense.date.isBefore(monthEnd))
        // ignore: avoid_types_as_parameter_names
        .fold(0, (sum, expense) {
      final expenseCurrencyRate = _currencies
          .firstWhere((c) => c.code == expense.currency)
          .rateToKES;
      final selectedCurrencyRate =
          _currencies.firstWhere((c) => c.code == _selectedCurrency).rateToKES;
      return sum +
          (expense.amount * expenseCurrencyRate / selectedCurrencyRate);
    });
  }
  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _categories
            .map(
              (category) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(category.name),
                  selected: _selectedCategory == category.name,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = selected ? category.name : 'All';
                    });
                  },
                  avatar: Icon(category.icon),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildExpensesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getExpensesStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final expenses = snapshot.data!.docs
            .map((doc) => Expense.fromMap(doc.data() as Map<String, dynamic>))
            .where((expense) =>
                _selectedCategory == 'All' ||
                expense.category == _selectedCategory)
            .toList();

        if (expenses.isEmpty) {
          return const Center(
            child: Text('No expenses found for the selected criteria'),
          );
        }

        // Sort expenses by date (newest first)
        expenses.sort((a, b) => b.date.compareTo(a.date));

        return ListView.builder(
          itemCount: expenses.length,
          itemBuilder: (context, index) {
            final expense = expenses[index];
            return _buildExpenseCard(expense);
          },
        );
      },
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withValues(alpha:0.2),
          child: Icon(
            _getCategoryIcon(expense.category),
            color: Colors.orange,
          ),
        ),
        title: Text(expense.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DateFormat('MMM dd, yyyy').format(expense.date)} • ${expense.category}',
            ),
            if (expense.notes?.isNotEmpty ?? false)
              Text(
                expense.notes!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatAmount(expense.amount, expense.currency),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              expense.currency,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        onTap: () => _showExpenseDialog(expense: expense),
      ),
    );
  }

  Future<void> _showExpenseDialog({Expense? expense}) async {
    final isEditing = expense != null;
    final titleController = TextEditingController(text: expense?.title ?? '');
    final amountController =
        TextEditingController(text: expense?.amount.toString() ?? '');
    final notesController = TextEditingController(text: expense?.notes ?? '');
    String selectedCategory = expense?.category ?? _categories[0].name;
    String selectedCurrency = expense?.currency ?? _selectedCurrency;
    DateTime selectedDate = expense?.date ?? DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Expense' : 'Add Expense'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                textCapitalization: TextCapitalization.sentences,
              ),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: amountController,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      value: selectedCurrency,
                      items: _currencies
                          .map((currency) => DropdownMenuItem(
                                value: currency.code,
                                child: Text(currency.code),
                              ))
                          .toList(),
                      onChanged: (value) {
                        selectedCurrency = value!;
                      },
                      decoration: const InputDecoration(labelText: 'Currency'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: _categories
                    .map((category) => DropdownMenuItem(
                          value: category.name,
                          child: Row(
                            children: [
                              Icon(category.icon, size: 20),
                              const SizedBox(width: 8),
                              Text(category.name),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  selectedCategory = value!;
                },
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Date'),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    selectedDate = picked;
                  }
                },
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
        actions: [
          if (isEditing)
            TextButton(
              onPressed: () async {

              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (titleController.text.isEmpty ||
                  amountController.text.isEmpty ||
                  double.tryParse(amountController.text) == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all required fields correctly'),
                  ),
                );
                return;
              }

              final newExpense = Expense(
                id: expense?.id ?? DateTime.now().toString(),
                title: titleController.text,
                amount: double.parse(amountController.text),
                date: selectedDate,
                category: selectedCategory,
                notes: notesController.text,
                currency: selectedCurrency,
              );

              if (isEditing) {
                _updateExpense(newExpense);
              } else {
                _addExpense(newExpense);
              }

              Navigator.pop(context);
            },
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getExpensesStream() {
    return _firestore
        .collection('expenses')
        .where('date',
            isGreaterThanOrEqualTo: _startDate.toIso8601String())
        .where('date', isLessThanOrEqualTo: _endDate.toIso8601String())
        .snapshots();
  }

  IconData _getCategoryIcon(String category) {
    return _categories
        .firstWhere((c) => c.name == category,
            orElse: () => ExpenseCategory(
                id: '0', name: 'Other', icon: Icons.help_outline))
        .icon;
  }

  Future<void> _addExpense(Expense expense) async {
    try {
      await _firestore.collection('expenses').add(expense.toMap());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense added successfully')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding expense: $e')),
      );
    }
  }

  Future<void> _updateExpense(Expense expense) async { 
  try {
    await _firestore.collection('expenses').doc(expense.id).update(expense.toMap());

    if (mounted) { // Check if the widget is still mounted
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense updated successfully')),
      );
    }
  } catch (e) {
    if (mounted) { // Check if the widget is still mounted
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating expense: $e')),
      );
    }
  }
}

}