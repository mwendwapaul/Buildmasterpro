import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class InventoryItem {
  final String name;
  int quantity;

  InventoryItem({required this.name, required this.quantity});

  Map<String, dynamic> toMap() {
    return {'name': name, 'quantity': quantity};
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      name: map['name'] as String,
      quantity: map['quantity'] as int,
    );
  }
}

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  State<InventoryManagementScreen> createState() => _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  List<InventoryItem> _inventoryItems = [];
  List<InventoryItem> _filteredItems = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInventoryItems(); // Load saved items
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  // Load items from SharedPreferences
  Future<void> _loadInventoryItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String? itemsJson = prefs.getString('inventoryItems');
    if (itemsJson != null) {
      final List<dynamic> itemsList = jsonDecode(itemsJson);
      setState(() {
        _inventoryItems = itemsList.map((item) => InventoryItem.fromMap(item)).toList();
        _filteredItems = List.from(_inventoryItems);
      });
    }
  }

  // Save items to SharedPreferences
  Future<void> _saveInventoryItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String itemsJson = jsonEncode(_inventoryItems.map((item) => item.toMap()).toList());
    await prefs.setString('inventoryItems', itemsJson);
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _inventoryItems
          .where((item) => item.name.toLowerCase().contains(query))
          .toList();
    });
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_validateInput()) {
                setState(() {
                  _inventoryItems.add(
                    InventoryItem(
                      name: _nameController.text.trim(),
                      quantity: int.parse(_quantityController.text),
                    ),
                  );
                  _filterItems();
                });
                _saveInventoryItems(); // Save after adding
                _nameController.clear();
                _quantityController.clear();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item added successfully')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editItem(InventoryItem item) {
    _nameController.text = item.name;
    _quantityController.text = item.quantity.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_validateInput()) {
                setState(() {
                  // Update the existing item (requires making name mutable or replacing the item)
                  final updatedItem = InventoryItem(
                    name: _nameController.text.trim(),
                    quantity: int.parse(_quantityController.text),
                  );
                  final index = _inventoryItems.indexOf(item);
                  _inventoryItems[index] = updatedItem;
                  _filterItems();
                });
                _saveInventoryItems(); // Save after editing
                _nameController.clear();
                _quantityController.clear();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item updated successfully')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteItem(InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete ${item.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _inventoryItems.remove(item);
                _filterItems();
              });
              _saveInventoryItems(); // Save after deleting
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${item.name} deleted successfully')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  bool _validateInput() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item name cannot be empty')),
      );
      return false;
    }
    if (_quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity cannot be empty')),
      );
      return false;
    }
    try {
      final quantity = int.parse(_quantityController.text);
      if (quantity < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quantity cannot be negative')),
        );
        return false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number for quantity')),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addItem,
            tooltip: 'Add New Item',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Inventory',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterItems();
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredItems.isEmpty
                  ? const Center(child: Text('No items found'))
                  : ListView.builder(
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        return Card(
                          elevation: 5,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text(item.name),
                            subtitle: Text('Quantity: ${item.quantity}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editItem(item),
                                  tooltip: 'Edit Item',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteItem(item),
                                  tooltip: 'Delete Item',
                                  color: Colors.red,
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
      ),
    );
  }
}