import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EquipmentLifecycleScreen extends StatefulWidget {
  const EquipmentLifecycleScreen({super.key});

  @override
  State<EquipmentLifecycleScreen> createState() => _EquipmentLifecycleScreenState();
}

class _EquipmentLifecycleScreenState extends State<EquipmentLifecycleScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<String> _statusOptions = ['Active', 'Inactive', 'Pending', 'Under Repair'];
  static const List<String> _lifecycleStages = [
    'Procurement',
    'Operational',
    'Maintenance',
    'End of Life',
    'Decommissioned'
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {Color backgroundColor = Colors.green}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  Future<void> _showAddEquipmentDialog() async {
    if (!mounted) return;

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedStatus = _statusOptions.first;
    String selectedLifecycleStage = _lifecycleStages.first;

    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New Equipment'),
          content: _buildDialogContent(
            nameController: nameController,
            descriptionController: descriptionController,
            selectedStatus: selectedStatus,
            selectedLifecycleStage: selectedLifecycleStage,
            onStatusChanged: (value) => setState(() => selectedStatus = value!),
            onStageChanged: (value) => setState(() => selectedLifecycleStage = value!),
          ),
          actions: _buildDialogActions(
            dialogContext: dialogContext,
            onSave: () async {
              if (!_validateInput(nameController.text)) return;
              await _addEquipment(
                nameController.text.trim(),
                descriptionController.text.trim(),
                selectedStatus,
                selectedLifecycleStage,
                dialogContext,
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(DocumentSnapshot equipment) async {
    if (!mounted) return;

    final nameController = TextEditingController(text: equipment['name']);
    final descriptionController = TextEditingController(text: equipment['description'] ?? '');
    String selectedStatus = equipment['status'];
    String selectedLifecycleStage = equipment['lifecycleStage'];

    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Equipment'),
          content: _buildDialogContent(
            nameController: nameController,
            descriptionController: descriptionController,
            selectedStatus: selectedStatus,
            selectedLifecycleStage: selectedLifecycleStage,
            onStatusChanged: (value) => setState(() => selectedStatus = value!),
            onStageChanged: (value) => setState(() => selectedLifecycleStage = value!),
          ),
          actions: _buildDialogActions(
            dialogContext: dialogContext,
            saveText: 'Save',
            onSave: () async {
              if (!_validateInput(nameController.text)) return;
              await _updateEquipment(
                equipment.id,
                nameController.text.trim(),
                descriptionController.text.trim(),
                selectedStatus,
                selectedLifecycleStage,
                dialogContext,
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmationDialog(DocumentSnapshot equipment) async {
    if (!mounted) return;

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete ${equipment['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
 
  await FirebaseFirestore.instance.collection('equipment').doc(equipment.id).delete();
  if (dialogContext.mounted) { 
    Navigator.pop(dialogContext, true);
  }
  if (mounted) {
    _showMessage('Equipment deleted successfully');
  }
} catch (e) {
  if (mounted) {
    _showMessage('Error deleting equipment: $e', backgroundColor: Colors.red);
  }
}
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (mounted && result == true) {
      _showMessage('Equipment deleted successfully');
    }
  }

  Future<void> _addEquipment(String name, String description, String status, String lifecycleStage, BuildContext dialogContext) async {
    try {
      await FirebaseFirestore.instance.collection('equipment').add({
        'name': name,
        'description': description,
        'status': status,
        'lifecycleStage': lifecycleStage,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
      });
      if (dialogContext.mounted) {
        Navigator.pop(dialogContext, true);
        _showMessage('Equipment added successfully');
      }
    } catch (e) {
      if (dialogContext.mounted) {
        _showMessage('Error adding equipment: $e', backgroundColor: Colors.red);
      }
    }
  }

  Future<void> _updateEquipment(String id, String name, String description, String status, String lifecycleStage, BuildContext dialogContext) async {
    try {
      await FirebaseFirestore.instance.collection('equipment').doc(id).update({
        'name': name,
        'description': description,
        'status': status,
        'lifecycleStage': lifecycleStage,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (dialogContext.mounted) {
        Navigator.pop(dialogContext, true);
        _showMessage('Equipment updated successfully');
      }
    } catch (e) {
      if (dialogContext.mounted) {
        _showMessage('Error updating equipment: $e', backgroundColor: Colors.red);
      }
    }
  }

  bool _validateInput(String name) {
    if (name.trim().isEmpty) {
      _showMessage('Equipment name is required', backgroundColor: Colors.red);
      return false;
    }
    return true;
  }

  Widget _buildDialogContent({
    required TextEditingController nameController,
    required TextEditingController descriptionController,
    required String selectedStatus,
    required String selectedLifecycleStage,
    required ValueChanged<String?> onStatusChanged,
    required ValueChanged<String?> onStageChanged,
  }) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Equipment Name',
              hintText: 'Enter equipment name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Enter equipment description',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: _statusOptions.map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
            onChanged: onStatusChanged,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: selectedLifecycleStage,
            decoration: const InputDecoration(
              labelText: 'Lifecycle Stage',
              border: OutlineInputBorder(),
            ),
            items: _lifecycleStages.map((stage) => DropdownMenuItem(value: stage, child: Text(stage))).toList(),
            onChanged: onStageChanged,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDialogActions({
    required BuildContext dialogContext,
    String saveText = 'Add',
    required VoidCallback onSave,
  }) {
    return [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext, false),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: onSave,
        child: Text(saveText),
      ),
    ];
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active': return Colors.green;
      case 'inactive': return Colors.grey;
      case 'pending': return Colors.orange;
      case 'under repair': return Colors.blue;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipment Lifecycle Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddEquipmentDialog,
            tooltip: 'Add Equipment',
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
                labelText: 'Search Equipment',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('equipment')
                    .orderBy('updatedAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final equipment = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['name'].toString().toLowerCase().contains(_searchQuery) ||
                        data['status'].toString().toLowerCase().contains(_searchQuery) ||
                        data['lifecycleStage'].toString().toLowerCase().contains(_searchQuery);
                  }).toList();

                  if (equipment.isEmpty) {
                    return const Center(child: Text('No equipment found'));
                  }

                  return ListView.builder(
                    itemCount: equipment.length,
                    itemBuilder: (context, index) {
                      final item = equipment[index];
                      final data = item.data() as Map<String, dynamic>;
                      return Card(
                        elevation: 5,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ExpansionTile(
                          title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(data['status']),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(data['status'], style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              Text(data['lifecycleStage'], style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showEditDialog(item),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _showDeleteConfirmationDialog(item),
                                tooltip: 'Delete',
                                color: Colors.red,
                              ),
                            ],
                          ),
                          children: [
                            if (data['description']?.isNotEmpty ?? false)
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Description:', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(data['description']),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Last Updated: ${(data['updatedAt'] as Timestamp?)?.toDate().toString() ?? 'N/A'}',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
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