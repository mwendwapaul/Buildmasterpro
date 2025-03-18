import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PayrollManagementScreen extends StatefulWidget {
  const PayrollManagementScreen({super.key});

  @override
  State<PayrollManagementScreen> createState() => _PayrollManagementScreenState();
}

class _PayrollManagementScreenState extends State<PayrollManagementScreen> {
  List<Map<String, dynamic>> _employees = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    final String? employeesJson = prefs.getString('employees');
    if (employeesJson != null) {
      setState(() {
        _employees = List<Map<String, dynamic>>.from(jsonDecode(employeesJson));
      });
    }
  }

  Future<void> _saveEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('employees', jsonEncode(_employees));
  }

  void _showEmployeeDetails(Map<String, dynamic> employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(employee['name']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Employee ID', employee['id']),
              _buildDetailRow('Position', employee['position']),
              _buildDetailRow('Salary', NumberFormat.currency(symbol: '\$').format(employee['salary'])),
              _buildDetailRow('Status', employee['status']),
              _buildDetailRow('Payment Method', employee['paymentMethod']),
              _buildDetailRow('Last Payment', employee['lastPayment']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteEmployee(employee);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditEmployeeDialog(employee);
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  void _showEditEmployeeDialog(Map<String, dynamic> employee) {
    final nameController = TextEditingController(text: employee['name']);
    final positionController = TextEditingController(text: employee['position']);
    final salaryController = TextEditingController(text: employee['salary'].toString());
    String status = employee['status'];
    String paymentMethod = employee['paymentMethod'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Employee'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: positionController,
                decoration: const InputDecoration(labelText: 'Position', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: salaryController,
                decoration: const InputDecoration(labelText: 'Salary', border: OutlineInputBorder(), prefixText: '\$'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: ['Active', 'Inactive', 'On Leave'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (value) => status = value!,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: paymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                items: ['Direct Deposit', 'Check'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (value) => paymentMethod = value!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (_validateEmployeeInput(nameController.text, positionController.text, salaryController.text)) {
                setState(() {
                  employee['name'] = nameController.text.trim();
                  employee['position'] = positionController.text.trim();
                  employee['salary'] = int.parse(salaryController.text);
                  employee['status'] = status;
                  employee['paymentMethod'] = paymentMethod;
                });
                _saveEmployees();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee updated successfully')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddEmployeeDialog() {
    final nameController = TextEditingController();
    final positionController = TextEditingController();
    final salaryController = TextEditingController();
    String status = 'Active';
    String paymentMethod = 'Direct Deposit';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Employee'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: positionController,
                decoration: const InputDecoration(labelText: 'Position', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: salaryController,
                decoration: const InputDecoration(labelText: 'Salary', border: OutlineInputBorder(), prefixText: '\$'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: ['Active', 'Inactive', 'On Leave'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (value) => status = value!,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: paymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                items: ['Direct Deposit', 'Check'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (value) => paymentMethod = value!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (_validateEmployeeInput(nameController.text, positionController.text, salaryController.text)) {
                setState(() {
                  _employees.add({
                    'id': '00${_employees.length + 1}'.padLeft(3, '0'), // Simple ID generation
                    'name': nameController.text.trim(),
                    'position': positionController.text.trim(),
                    'salary': int.parse(salaryController.text),
                    'status': status,
                    'paymentMethod': paymentMethod,
                    'lastPayment': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  });
                });
                _saveEmployees();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee added successfully')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteEmployee(Map<String, dynamic> employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Are you sure you want to delete ${employee['name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _employees.remove(employee);
              });
              _saveEmployees();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${employee['name']} deleted successfully')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  bool _validateEmployeeInput(String name, String position, String salary) {
    if (name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return false;
    }
    if (position.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Position cannot be empty')));
      return false;
    }
    if (salary.isEmpty || int.tryParse(salary) == null || int.parse(salary) < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid salary')));
      return false;
    }
    return true;
  }

  void _showPayrollRunDialog() {
    final activeCount = _employees.where((e) => e['status'] == 'Active').length;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Run Payroll'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to run payroll for all active employees?'),
            const SizedBox(height: 16),
            Text('Total employees: $activeCount', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: activeCount > 0
                ? () {
                    setState(() {
                      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                      for (var employee in _employees.where((e) => e['status'] == 'Active')) {
                        employee['lastPayment'] = today;
                      }
                    });
                    _saveEmployees();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payroll processed successfully')));
                  }
                : null,
            child: const Text('Run Payroll'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredEmployees = _employees.where((employee) {
      final matchesSearch = employee['name'].toString().toLowerCase().contains(_searchController.text.toLowerCase());
      return matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll Management'),
        actions: [
          IconButton(
            onPressed: _showAddEmployeeDialog,
            icon: const Icon(Icons.add),
            tooltip: 'Add Employee',
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
                labelText: 'Search by Employee Name',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showPayrollRunDialog,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run Payroll'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: filteredEmployees.isEmpty
                  ? const Center(child: Text('No employees found'))
                  : ListView.builder(
                      itemCount: filteredEmployees.length,
                      itemBuilder: (context, index) {
                        final employee = filteredEmployees[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                          child: ListTile(
                            title: Text(employee['name']),
                            subtitle: Text(employee['position']),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showEmployeeDetails(employee),
                                  tooltip: 'Edit',
                                ),
                              ],
                            ),
                            onTap: () => _showEmployeeDetails(employee),
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