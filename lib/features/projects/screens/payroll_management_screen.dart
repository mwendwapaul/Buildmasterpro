import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PayrollManagementScreen extends StatefulWidget {
  const PayrollManagementScreen({super.key});

  @override
  State<PayrollManagementScreen> createState() =>
      _PayrollManagementScreenState();
}

class _PayrollManagementScreenState extends State<PayrollManagementScreen> {
  final List<Map<String, dynamic>> _employees = [
    {
      'id': '001',
      'name': 'John Doe',
      'position': 'Software Engineer',
      'salary': 75000,
      'status': 'Active',
      'paymentMethod': 'Direct Deposit',
      'lastPayment': '2024-03-01',
    },
    {
      'id': '002',
      'name': 'Jane Smith',
      'position': 'Product Manager',
      'salary': 85000,
      'status': 'Active',
      'paymentMethod': 'Direct Deposit',
      'lastPayment': '2024-03-01',
    },
    {
      'id': '003',
      'name': 'Mike Johnson',
      'position': 'UI Designer',
      'salary': 65000,
      'status': 'Active',
      'paymentMethod': 'Check',
      'lastPayment': '2024-03-01',
    },
  ];

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              _buildDetailRow(
                  'Salary',
                  NumberFormat.currency(symbol: '\$')
                      .format(employee['salary'])),
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
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditEmployeeDialog(Map<String, dynamic> employee) {
    final nameController = TextEditingController(text: employee['name']);
    final positionController =
        TextEditingController(text: employee['position']);
    final salaryController =
        TextEditingController(text: employee['salary'].toString());
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
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: positionController,
                decoration: const InputDecoration(labelText: 'Position'),
              ),
              TextField(
                controller: salaryController,
                decoration: const InputDecoration(labelText: 'Salary'),
                keyboardType: TextInputType.number,
              ),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: ['Active', 'Inactive', 'On Leave']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) => status = value!,
              ),
              DropdownButtonFormField<String>(
                value: paymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method'),
                items: ['Direct Deposit', 'Check']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) => paymentMethod = value!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                employee['name'] = nameController.text;
                employee['position'] = positionController.text;
                employee['salary'] = int.parse(salaryController.text);
                employee['status'] = status;
                employee['paymentMethod'] = paymentMethod;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Employee updated successfully')),
              );
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
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: positionController,
                decoration: const InputDecoration(labelText: 'Position'),
              ),
              TextField(
                controller: salaryController,
                decoration: const InputDecoration(labelText: 'Salary'),
                keyboardType: TextInputType.number,
              ),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: ['Active', 'Inactive', 'On Leave']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) => status = value!,
              ),
              DropdownButtonFormField<String>(
                value: paymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method'),
                items: ['Direct Deposit', 'Check']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) => paymentMethod = value!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _employees.add({
                  'id': '00${_employees.length + 1}',
                  'name': nameController.text,
                  'position': positionController.text,
                  'salary': int.parse(salaryController.text),
                  'status': status,
                  'paymentMethod': paymentMethod,
                  'lastPayment':
                      DateFormat('yyyy-MM-dd').format(DateTime.now()),
                });
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Employee added successfully')),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showPayrollRunDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Run Payroll'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Are you sure you want to run payroll for all active employees?'),
            const SizedBox(height: 16),
            Text(
              'Total employees: ${_employees.where((e) => e['status'] == 'Active').length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
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
              setState(() {
                final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                for (var employee in _employees) {
                  if (employee['status'] == 'Active') {
                    employee['lastPayment'] = today;
                  }
                }
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payroll processed successfully')),
              );
            },
            child: const Text('Run Payroll'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredEmployees = _employees.where((employee) {
      final matchesSearch = employee['name']
          .toString()
          .toLowerCase()
          .contains(_searchController.text.toLowerCase());
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
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by Employee Name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _showPayrollRunDialog,
              child: const Text('Run Payroll'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: filteredEmployees.length,
                itemBuilder: (context, index) {
                  final employee = filteredEmployees[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(employee['name']),
                      subtitle: Text(employee['position']),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEmployeeDetails(employee),
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
