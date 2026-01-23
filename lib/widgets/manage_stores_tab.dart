
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/store_model.dart';

class ManageStoresTab extends StatefulWidget {
  const ManageStoresTab({super.key});

  @override
  State<ManageStoresTab> createState() => _ManageStoresTabState();
}

class _ManageStoresTabState extends State<ManageStoresTab> {
  final CollectionReference _storesCollection =
      FirebaseFirestore.instance.collection('stores');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for the tab
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStoreDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Store'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.store, size: 32, color: Colors.blueGrey),
                const SizedBox(width: 12),
                Text(
                  'Manage Stores',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[900],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Add and manage your physical stores and assign Managers from Core Staff.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _storesCollection
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.store_mall_directory_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No stores added yet.',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => _showStoreDialog(),
                            child: const Text('Add your first Store'),
                          ),
                        ],
                      ),
                    );
                  }

                  // Responsive Grid
                  return LayoutBuilder(builder: (context, constraints) {
                    int crossAxisCount = 1;
                    if (constraints.maxWidth > 1200) crossAxisCount = 3;
                    else if (constraints.maxWidth > 800) crossAxisCount = 2;

                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.4, // Adjust for card height
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final store = StoreModel.fromFirestore(docs[index]);
                        return _buildStoreCard(store);
                      },
                    );
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreCard(StoreModel store) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: store.isActive ? Colors.blue[50] : Colors.grey[100],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                  bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: store.isActive ? Colors.green : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            store.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 12,
                              color: store.isActive
                                  ? Colors.green[700]
                                  : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      _showStoreDialog(store: store);
                    } else if (value == 'delete') {
                      _deleteStore(store);
                    } else if (value == 'toggle') {
                       await _storesCollection.doc(store.id).update({
                        'isActive': !store.isActive,
                      });
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit Store')],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(store.isActive ? Icons.toggle_off : Icons.toggle_on, size: 18), 
                          const SizedBox(width: 8), 
                          Text(store.isActive ? 'Deactivate' : 'Activate')
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                           Icon(Icons.delete, color: Colors.red, size: 18), 
                           SizedBox(width: 8), 
                           Text('Delete', style: TextStyle(color: Colors.red))
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          store.address,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                   const SizedBox(height: 8),
                  if (store.managerName != null)
                     Row(
                      children: [
                        const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                         const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Manager: ${store.managerName}',
                             style: const TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Operating Pincodes:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: store.pincodes.isEmpty 
                      ? const Text('No pincodes assigned', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
                      : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: store.pincodes.take(5).map<Widget>((pin) {
                            return Chip(
                              label: Text(pin),
                              labelStyle: const TextStyle(fontSize: 11),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.blue[50],
                              side: BorderSide(color: Colors.blue[100]!),
                            );
                          }).toList()
                          ..add(store.pincodes.length > 5 
                              ? Chip(
                                  label: Text('+${store.pincodes.length - 5} more'),
                                  labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: Colors.grey[100],
                                ) 
                              : const SizedBox.shrink()),
                        ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Added: ${DateFormat('dd MMM yyyy').format(store.createdAt.toDate())}',
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  void _showStoreDialog({StoreModel? store}) {
    final nameController = TextEditingController(text: store?.name ?? '');
    final addressController = TextEditingController(text: store?.address ?? '');
    final pincodesController =
        TextEditingController(text: store?.pincodes.join(', ') ?? '');
    
    String? selectedManagerId = store?.managerId;
    Map<String, dynamic>? selectedManagerData;
    
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(store == null ? 'Add Store' : 'Edit Store'),
          content: SizedBox(
            width: 600,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Store Details', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    const Divider(),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Store Name',
                        hintText: 'e.g. Main Warehouse',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.store),
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Please enter name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Full Address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      maxLines: 2,
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Please enter address' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: pincodesController,
                      decoration: const InputDecoration(
                        labelText: 'Service Pincodes (comma separated)',
                        hintText: 'e.g. 110001, 110002, 110005',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.map),
                      ),
                      maxLines: 2,
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Please enter at least one pincode' : null,
                    ),
                    const SizedBox(height: 24),
                    const Text('Assign Manager (Optional)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    // Core Staff Dropdown
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('role', whereIn: ['core_staff', 'store_manager']) // Fetch core staff and existing managers
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text('Error loading staff: ${snapshot.error}', style: const TextStyle(color: Colors.red));
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const LinearProgressIndicator();
                        }
                        
                        final staffDocs = snapshot.data?.docs ?? [];
                         // Filter out managers already assigned to OTHER stores (unless it's THIS store's manager)
                         // This is tricky without fetching all stores. For simplicity, just list them all.
                         
                         // If we are editing, current manager should be in the list even if we filter later.
                         
                         final items = staffDocs.map((doc) {
                           final data = doc.data() as Map<String, dynamic>;
                           final name = data['name'] ?? 'Unknown';
                           final email = data['email'] ?? '';
                           final role = data['role'] ?? '';
                           final currentStoreId = data['storeId'];
                           
                           // Add an indicator if already assigned
                           String label = '$name ($role)';
                           if (currentStoreId != null && (store == null || currentStoreId != store.id)) {
                             label += ' - assigned to another store';
                           }
                           
                           return DropdownMenuItem<String>(
                             value: doc.id,
                             child: Text(label, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                             onTap: () {
                               selectedManagerData = data;
                             },
                           );
                         }).toList();
                         
                         // Add a "None" option to unassign
                         items.insert(0, const DropdownMenuItem<String>(
                           value: null,
                           child: Text('None / Unassign'),
                         ));

                        // Ensure selectedManagerId is in the list of items
                        // If not, reset it to null (or specific handling if critical)
                        final validValues = items.map((e) => e.value).toSet();
                        if (selectedManagerId != null && !validValues.contains(selectedManagerId)) {
                           // If the previously selected manager is not in the list (e.g. role changed),
                           // we can either add them as a disabled item or just select 'None'.
                           // For safety, defaulting to null (None) to avoid crash.
                           // OR - if we can't find them, we should probably warn or show 'Unknown'.
                           // But safe bet for 'Assertion failed' fix is:
                           selectedManagerId = null;
                        }

                        return DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Select Core Staff to Promote/Assign',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_search),
                            helperText: 'Selecting a Core Staff will change their role to Store Manager',
                          ),
                          value: selectedManagerId,
                          isExpanded: true,
                          items: items,
                          onChanged: (value) {
                             setState(() {
                               selectedManagerId = value;
                             });
                          },
                        );
                      }
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (formKey.currentState?.validate() ?? false) {
                  setState(() => isLoading = true);
                  final pincodes = pincodesController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();

                  try {
                    // Update Store
                     final storeData = {
                      'name': nameController.text.trim(),
                      'address': addressController.text.trim(),
                      'pincodes': pincodes,
                      'isActive': store?.isActive ?? true,
                      'createdAt': store?.createdAt ?? FieldValue.serverTimestamp(),
                      'managerId': selectedManagerId,
                    };
                    
                    // If manager is selected, add their details to store for easy display
                    if (selectedManagerId != null && selectedManagerData != null) {
                       storeData['managerName'] = selectedManagerData!['name'];
                       storeData['managerEmail'] = selectedManagerData!['email'];
                       storeData['managerPhone'] = selectedManagerData!['phoneNumber'] ?? selectedManagerData!['phone'];
                    } else if (selectedManagerId == null) {
                       storeData['managerName'] = null;
                       storeData['managerEmail'] = null;
                       storeData['managerPhone'] = null;
                    }

                    DocumentReference storeRef;
                    if (store == null) {
                      storeRef = await _storesCollection.add(storeData);
                    } else {
                      storeRef = _storesCollection.doc(store.id);
                      await storeRef.update(storeData);
                      
                      // Handle unassigning previous manager if changed
                      if (store.managerId != null && store.managerId != selectedManagerId) {
                         // Reset previous manager
                         await FirebaseFirestore.instance.collection('users').doc(store.managerId).update({
                           'storeId': FieldValue.delete(),
                           // Optional: Revert role? Hard to know what they were before. 
                           // Safest to keep as store_manager or maybe manual update required.
                           // Actually, user requested "select core staff". If we unassign, 
                           // maybe they should go back to core_staff? 
                           // For now, let's leave their role as is to avoid permissions issues, just remove storeId.
                         });
                      }
                    }

                    // Update New Manager User Doc
                    if (selectedManagerId != null) {
                        await FirebaseFirestore.instance.collection('users').doc(selectedManagerId).update({
                          'storeId': storeRef.id,
                          'role': 'store_manager', // Promote/Assign role
                        });
                    }

                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')));
                  } finally {
                    if (mounted) setState(() => isLoading = false);
                  }
                }
              },
              child: isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : Text(store == null ? 'Add Store' : 'Update Store'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteStore(StoreModel store) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Store'),
        content: Text('Are you sure you want to delete "${store.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _storesCollection.doc(store.id).delete();
         // Unassign manager
         if (store.managerId != null) {
            await FirebaseFirestore.instance.collection('users').doc(store.managerId).update({
               'storeId': FieldValue.delete(),
            });
         }
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting store: $e')));
        }
      }
    }
  }
}
