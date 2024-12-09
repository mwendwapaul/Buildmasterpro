import 'equipment_lifecycle_management_screen.dart';
import 'package:build_masterpro/features/projects/screens/inventory_management_screen.dart';
import 'package:build_masterpro/features/projects/screens/supplier_management_screen.dart';
import 'package:flutter/material.dart';

class ResourceManagementScreen extends StatelessWidget {
  const ResourceManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resource Management'),
        centerTitle: true,
        backgroundColor: Colors.indigoAccent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage Your Resources',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800],
                  ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _resourceOptions.length,
                itemBuilder: (context, index) {
                  final option = _resourceOptions[index];
                  return _buildResourceCard(
                    context,
                    option['title'] as String,
                    option['icon'] as IconData,
                    option['color'] as Color,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceCard(
      BuildContext context, String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        // Navigate to respective resource management feature
        switch (title) {
          case 'Inventory Management':
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const InventoryManagementScreen()),
            );
            break;
          case 'Equipment Lifecycle':
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const EquipmentLifecycleScreen()),
            );
            break;
          case 'Supplier Management':
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const SupplierManagementScreen()),
            );
            break;
          default:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$title selected')),
            );
        }
      },
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 42,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final List<Map<String, dynamic>> _resourceOptions = [
  {
    'title': 'Inventory Management',
    'icon': Icons.inventory,
    'color': Colors.blue,
  },
  {
    'title': 'Equipment Lifecycle',
    'icon': Icons.build,
    'color': Colors.green,
  },
  {
    'title': 'Supplier Management',
    'icon': Icons.business,
    'color': Colors.orange,
  },
];
