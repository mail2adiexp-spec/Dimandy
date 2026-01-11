
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SharedUsersTab extends StatefulWidget {
  final bool canManage;

  const SharedUsersTab({
    super.key, 
    required this.canManage,
  });

  @override
  State<SharedUsersTab> createState() => _SharedUsersTabState();
}

class _SharedUsersTabState extends State<SharedUsersTab> {
  String _userFilter = 'All';

  late Stream<QuerySnapshot> _stream;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'user')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Chips
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Most Active', 'Active', 'Inactive'].map((filter) {
                final isSelected = _userFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _userFilter = filter);
                    },
                    backgroundColor: Colors.grey[100],
                    selectedColor: Colors.blue[100],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.blue[900] : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var users = snapshot.data?.docs ?? [];
              
              // Client-side filtering and sorting based on _userFilter
              if (_userFilter == 'Most Active') {
                users.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aCount = (aData['orderCount'] as num?)?.toInt() ?? 0;
                  final bCount = (bData['orderCount'] as num?)?.toInt() ?? 0;
                  return bCount.compareTo(aCount); // Descending
                });
              } else if (_userFilter == 'Active') {
                // Active: Logged in within last 30 days
                final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
                users = users.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final lastLogin = data['lastLogin'] as Timestamp?;
                  if (lastLogin == null) return false;
                  return lastLogin.toDate().isAfter(thirtyDaysAgo);
                }).toList();
                // Sort by lastLogin descending
                users.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['lastLogin'] as Timestamp?;
                  final bTime = bData['lastLogin'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });
              } else if (_userFilter == 'Inactive') {
                // Inactive: No login or older than 30 days
                final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
                users = users.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final lastLogin = data['lastLogin'] as Timestamp?;
                  if (lastLogin == null) return true;
                  return lastLogin.toDate().isBefore(thirtyDaysAgo);
                }).toList();
                 // Sort by createdAt descending (newest inactive users first)
                users.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['createdAt'] as Timestamp?;
                  final bTime = bData['createdAt'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });
              } else {
                // All: Sort by createdAt descending
                users.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['createdAt'] as Timestamp?;
                  final bTime = bData['createdAt'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });
              }

              if (users.isEmpty) {
                return const Center(child: Text('No users found'));
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final userData = users[index].data() as Map<String, dynamic>;
                  final userId = users[index].id;
                  final name = userData['name'] ?? 'N/A';
                  final email = userData['email'] ?? 'N/A';
                  final phone = userData['phone'] ?? 'N/A';
                  final role = userData['role'] ?? 'user';
                  final servicePincode = userData['service_pincode'] as String?;
                  final createdAt = userData['createdAt'] != null
                      ? (userData['createdAt'] as Timestamp).toDate()
                      : null;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: role == 'admin'
                            ? Colors.red
                            : role == 'seller'
                            ? Colors.blue
                            : role == 'delivery_partner'
                            ? Colors.orange
                            : Colors.green,
                        child: Icon(
                          role == 'admin'
                              ? Icons.admin_panel_settings
                              : role == 'seller'
                              ? Icons.store
                              : role == 'delivery_partner'
                              ? Icons.delivery_dining
                              : Icons.person,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(email),
                      trailing: Chip(
                        label: Text(
                          role.toUpperCase(),
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: role == 'admin'
                            ? Colors.red[100]
                            : role == 'seller'
                            ? Colors.blue[100]
                            : role == 'delivery_partner'
                            ? Colors.orange[100]
                            : Colors.green[100],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow('User ID', userId),
                              _buildInfoRow('Name', name),
                              _buildInfoRow('Email', email),
                              _buildInfoRow('Phone', phone),
                              _buildInfoRow('Role', role),
                              if (servicePincode != null)
                                _buildInfoRow('Service Pincode', servicePincode),
                              if (createdAt != null)
                                _buildInfoRow('Joined', DateFormat('dd MMM yyyy, hh:mm a').format(createdAt)),
                              const SizedBox(height: 16),
                              if (widget.canManage)
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 4.0,
                                  alignment: WrapAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => _editUser(
                                        userId,
                                        name,
                                        email,
                                        phone,
                                        role,
                                        servicePincode,
                                      ),
                                      icon: const Icon(Icons.edit),
                                      label: const Text('Edit'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _changeUserRole(userId, role),
                                      icon: const Icon(Icons.swap_horiz),
                                      label: const Text('Change Role'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.orange,
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _deleteUser(userId, email),
                                      icon: const Icon(Icons.delete),
                                      label: const Text('Delete'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                    ),
                                  ],
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
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _editUser(
    String userId,
    String name,
    String email,
    String phone,
    String role,
    String? servicePincode,
  ) {
    final nameController = TextEditingController(text: name);
    final phoneController = TextEditingController(text: phone);
    final pincodeController = TextEditingController(text: servicePincode ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              if (role == 'delivery_partner')
                TextField(
                  controller: pincodeController,
                  decoration: const InputDecoration(labelText: 'Service Pincode'),
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
            onPressed: () async {
              try {
                final updates = {
                  'name': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                };
                if (role == 'delivery_partner') {
                  updates['service_pincode'] = pincodeController.text.trim();
                }

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .update(updates);

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User updated successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _changeUserRole(String userId, String currentRole) {
    String? selectedRole = currentRole == 'admin' ? 'administrator' : currentRole;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change User Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select new role for user:'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('User')),
                  DropdownMenuItem(value: 'seller', child: Text('Seller')),
                  DropdownMenuItem(
                    value: 'delivery_partner',
                    child: Text('Delivery Partner'),
                  ),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'core_staff', child: Text('Core Staff')),
                ],
                onChanged: (value) {
                  setState(() => selectedRole = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedRole != null && selectedRole != currentRole) {
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .update({'role': selectedRole});

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('User role updated successfully'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('Update Role'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteUser(String userId, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text('Are you sure you want to delete user $email?'),
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
        await FirebaseFirestore.instance.collection('users').doc(userId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}
