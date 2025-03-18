import 'package:flutter/material.dart';
import 'budget_tracking_screen.dart';
import 'invoicing_screen.dart';
import 'payroll_management_screen.dart';
import 'expense_reports_screen.dart';

class FinancialManagementScreen extends StatelessWidget {
  const FinancialManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Management'),
        centerTitle: true,
        backgroundColor: Colors.indigoAccent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage Your Finances',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[800],
                    ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _financialOptions.length,
                  itemBuilder: (context, index) {
                    final option = _financialOptions[index];
                    return _buildFinancialCard(
                      context,
                      option['title'] as String,
                      option['icon'] as IconData,
                      option['color'] as Color,
                      option['description'] as String,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialCard(BuildContext context, String title, IconData icon,
      Color color, String description) {
    return GestureDetector(
      onTap: () => _navigateToScreen(context, title),
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 36,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToScreen(BuildContext context, String title) {
    final routes = {
      'Budget Tracking': const BudgetTrackingScreen(),
      'Invoicing': const InvoicingScreen(),
      'Expense Reports': const ExpenseReportsScreen(),
      'Payroll Management': const PayrollManagementScreen(),
    };

    final screen = routes[title];
    if (screen != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => screen),
      );
    }
  }
}

final List<Map<String, dynamic>> _financialOptions = [
  {
    'title': 'Budget Tracking',
    'icon': Icons.pie_chart,
    'color': Colors.blue,
    'description': 'Keep track of your spending and savings.',
  },
  {
    'title': 'Invoicing',
    'icon': Icons.receipt,
    'color': Colors.green,
    'description': 'Create and manage your invoices easily.',
  },
  {
    'title': 'Expense Reports',
    'icon': Icons.assessment,
    'color': Colors.orange,
    'description': 'Generate reports on your expenses.',
  },
  {
    'title': 'Payroll Management',
    'icon': Icons.payments,
    'color': Colors.red,
    'description': 'Manage employee payroll efficiently.',
  },
];