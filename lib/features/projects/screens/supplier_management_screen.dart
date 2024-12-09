import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Supplier model with JSON serialization
class Supplier {
  final String name;
  final String contactInfo;
  final String id; // Added unique identifier

  Supplier({
    required this.name,
    required this.contactInfo,
    String? id,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  // Convert Supplier to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contactInfo': contactInfo,
    };
  }

  // Create Supplier from JSON
  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'],
      name: json['name'],
      contactInfo: json['contactInfo'],
    );
  }
}

class SupplierManagementScreen extends StatefulWidget {
  const SupplierManagementScreen({super.key});

  @override
  SupplierManagementScreenState createState() => SupplierManagementScreenState();
}

class SupplierManagementScreenState extends State<SupplierManagementScreen> {
  List<Supplier> _suppliers = [];
  final String _prefsKey = 'suppliers_data';

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  // Load suppliers from SharedPreferences
  Future<void> _loadSuppliers() async {
    final prefs = await SharedPreferences.getInstance();
    final suppliersJson = prefs.getString(_prefsKey);
    if (suppliersJson != null) {
      final List<dynamic> decodedData = json.decode(suppliersJson);
      setState(() {
        _suppliers = decodedData
            .map((item) => Supplier.fromJson(item as Map<String, dynamic>))
            .toList();
      });
    }
  }

  // Save suppliers to SharedPreferences
  Future<void> _saveSuppliers() async {
    final prefs = await SharedPreferences.getInstance();
    final suppliersJson =
        json.encode(_suppliers.map((supplier) => supplier.toJson()).toList());
    await prefs.setString(_prefsKey, suppliersJson);
  }

  void _addSupplier(Supplier supplier) {
    setState(() {
      _suppliers.add(supplier);
    });
    _saveSuppliers();
  }

  void _editSupplier(String id, Supplier supplier) {
    setState(() {
      final index = _suppliers.indexWhere((s) => s.id == id);
      if (index != -1) {
        _suppliers[index] = supplier;
      }
    });
    _saveSuppliers();
  }

  Future<void> _removeSupplier(String id) async {
    setState(() {
      _suppliers.removeWhere((supplier) => supplier.id == id);
    });
    await _saveSuppliers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showSupplierForm(context),
            tooltip: 'Add Supplier',
          ),
        ],
      ),
      body: _suppliers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.business, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No suppliers yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showSupplierForm(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Supplier'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _suppliers.length,
              itemBuilder: (context, index) {
                final supplier = _suppliers[index];
                return Dismissible(
                  key: Key(supplier.id),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Confirm Delete'),
                          content: Text(
                              'Are you sure you want to remove ${supplier.name}?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('CANCEL'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('DELETE'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  onDismissed: (direction) {
                    _removeSupplier(supplier.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${supplier.name} removed'),
                        action: SnackBarAction(
                          label: 'UNDO',
                          onPressed: () {
                            _addSupplier(supplier);
                          },
                        ),
                      ),
                    );
                  },
                  child: Card(
                    margin:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(supplier.name[0].toUpperCase()),
                      ),
                      title: Text(supplier.name),
                      subtitle: Text(supplier.contactInfo),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          _showSupplierForm(context,
                              supplier: supplier, id: supplier.id);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showSupplierForm(BuildContext context,
      {Supplier? supplier, String? id}) {
    final nameController = TextEditingController(text: supplier?.name);
    final contactInfoController =
        TextEditingController(text: supplier?.contactInfo);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(supplier == null ? 'Add Supplier' : 'Edit Supplier'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Supplier Name',
                  hintText: 'Enter supplier name',
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contactInfoController,
                decoration: const InputDecoration(
                  labelText: 'Contact Information',
                  hintText: 'Enter contact details',
                ),
                keyboardType: TextInputType.multiline,
                maxLines: null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    contactInfoController.text.isNotEmpty) {
                  final newSupplier = Supplier(
                    id: supplier?.id,
                    name: nameController.text.trim(),
                    contactInfo: contactInfoController.text.trim(),
                  );

                  if (supplier == null) {
                    _addSupplier(newSupplier);
                  } else {
                    _editSupplier(supplier.id, newSupplier);
                  }

                  Navigator.of(context).pop();
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }
}