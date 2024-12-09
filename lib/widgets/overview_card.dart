import 'package:flutter/material.dart';

class OverviewCard extends StatelessWidget {
  final List<OverviewItem> items;

  const OverviewCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((item) {
            final index = items.indexOf(item);
            return Column(
              children: [
                _buildOverviewItem(item),
                if (index < items.length - 1) const Divider(),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOverviewItem(OverviewItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(item.title),
          Text(
            '${item.value} (${item.change})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class OverviewItem {
  final String title;
  final String value;
  final String change;

  OverviewItem({
    required this.title,
    required this.value,
    required this.change, required trend,
  });
}
