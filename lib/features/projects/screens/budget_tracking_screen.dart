import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class BudgetTrackingScreen extends StatefulWidget {
  const BudgetTrackingScreen({super.key});

  @override
  State<BudgetTrackingScreen> createState() => _BudgetTrackingScreenState();
}

class _BudgetTrackingScreenState extends State<BudgetTrackingScreen> {
  List<Map<String, dynamic>> _budgetItems = [];
  String _selectedCurrency = 'KES';
  final Map<String, String> _currencySymbols = {
    'KES': 'KSh',
    'USD': '\$',
    'EUR': '€',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Load data from SharedPreferences
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedCurrency = prefs.getString('currency') ?? 'KES';
      final String? itemsJson = prefs.getString('budgetItems');
      if (itemsJson != null) {
        _budgetItems = List<Map<String, dynamic>>.from(
          json.decode(itemsJson).map((item) => Map<String, dynamic>.from(item)),
        );
      }
    });
  }

  // Save data to SharedPreferences
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', _selectedCurrency);
    await prefs.setString('budgetItems', json.encode(_budgetItems));
  }

  // Calculate total budget and spending
  Map<String, double> _calculateTotals() {
    double totalBudget = 0;
    double totalSpent = 0;
    for (var item in _budgetItems) {
      totalBudget += item['budget'];
      totalSpent += item['spent'];
    }
    return {'budget': totalBudget, 'spent': totalSpent};
  }

  // Delete budget item
  void _deleteBudgetItem(int index) {
    final removedItem = _budgetItems.removeAt(index);
    _saveData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${removedItem['category']} removed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _budgetItems.insert(index, removedItem);
              _saveData();
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totals = _calculateTotals();
    final totalPercentage = totals['budget'] != 0 
        ? ((totals['spent']! / totals['budget']!) * 100).round()
        : 0;
    final currencySymbol = _currencySymbols[_selectedCurrency] ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Budget Tracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Currency Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selected Currency',
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: DropdownButton<String>(
                        value: _selectedCurrency,
                        underline: Container(),
                        items: _currencySymbols.keys.map((currency) {
                          return DropdownMenuItem(
                            value: currency,
                            child: Text(
                              currency,
                              style: TextStyle(color: Colors.grey[800]),
                            ),
                          );
                        }).toList(),
                        onChanged: (newCurrency) {
                          setState(() {
                            _selectedCurrency = newCurrency!;
                            _saveData();
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Total Budget Overview Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Total Budget Overview',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                          Text(
                            '$currencySymbol${totals['spent']?.toStringAsFixed(2)} / $currencySymbol${totals['budget']?.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: totals['budget'] != 0 
                            ? totals['spent']! / totals['budget']!
                            : 0,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          totalPercentage > 90 ? Colors.red : Colors.deepPurple,
                        ),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$totalPercentage% of total budget used',
                        style: TextStyle(
                          color: totalPercentage > 90 ? Colors.red : Colors.grey[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Budget Items List
              Expanded(
                child: _budgetItems.isEmpty
                  ? Center(
                      child: Text(
                        'No budget items added yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    )
                  : ListView.separated(
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      shrinkWrap: true,
                      itemCount: _budgetItems.length,
                      itemBuilder: (context, index) {
                        final item = _budgetItems[index];
                        final percentage = (item['spent'] / item['budget'] * 100).round();
                        
                        return Dismissible(
                          key: Key(item['category']),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirm Deletion'),
                                content: Text('Are you sure you want to delete ${item['category']} budget item?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (direction) {
                            setState(() {
                              _deleteBudgetItem(index);
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['category'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.grey[800],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit, 
                                          color: Colors.deepPurple[300],
                                        ),
                                        onPressed: () => _showEditBudgetItemDialog(
                                          context,
                                          index,
                                          item,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: item['spent'] / item['budget'],
                                    backgroundColor: Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      percentage > 90 ? Colors.red : Colors.deepPurple,
                                    ),
                                    minHeight: 6,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$currencySymbol${item['spent']} / $currencySymbol${item['budget']} ($percentage%)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: percentage > 90 ? Colors.red : Colors.grey[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBudgetItemDialog(context),
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddBudgetItemDialog(BuildContext context) {
    final TextEditingController categoryController = TextEditingController();
    final TextEditingController spentController = TextEditingController();
    final TextEditingController budgetController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: const Text('Add Budget Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: categoryController,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: spentController,
                decoration: InputDecoration(
                  labelText: 'Amount Spent',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: budgetController,
                decoration: InputDecoration(
                  labelText: 'Budget Amount',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final String category = categoryController.text.trim();
              final double? spent = double.tryParse(spentController.text);
              final double? budget = double.tryParse(budgetController.text);

              if (category.isNotEmpty && spent != null && budget != null) {
                if (_budgetItems.any((item) => 
                    item['category'].toLowerCase() == category.toLowerCase())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('A category with this name already exists'),
                    ),
                  );
                  return;
                }

                setState(() {
                  _budgetItems.add({
                    'category': category,
                    'spent': spent,
                    'budget': budget,
                  });
                  _saveData();
                });
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields correctly'),
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditBudgetItemDialog(
    BuildContext context,
    int index,
    Map<String, dynamic> item,
  ) {
    final TextEditingController categoryController =
        TextEditingController(text: item['category']);
    final TextEditingController spentController =
        TextEditingController(text: item['spent'].toString());
    final TextEditingController budgetController =
        TextEditingController(text: item['budget'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: const Text('Edit Budget Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: categoryController,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: spentController,
                decoration: InputDecoration(
                  labelText: 'Amount Spent',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: budgetController,
                decoration: InputDecoration(
                  labelText: 'Budget Amount',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final String category = categoryController.text.trim();
              final double? spent = double.tryParse(spentController.text);
              final double? budget = double.tryParse(budgetController.text);

              if (category.isNotEmpty && spent != null && budget != null) {
                if (category.toLowerCase() != item['category'].toLowerCase() &&
                    _budgetItems.any((item) =>
                        item['category'].toLowerCase() == category.toLowerCase())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('A category with this name already exists'),
                    ),
                  );
                  return;
                }

                setState(() {
                  _budgetItems[index] = {
                    'category': category,
                    'spent': spent,
                    'budget': budget,
                  };
                  _saveData();
                });
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields correctly'),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}