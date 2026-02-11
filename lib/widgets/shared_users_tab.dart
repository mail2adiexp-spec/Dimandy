
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

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
  String _searchQuery = '';

  late Stream<QuerySnapshot> _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeStream();
  }

  void _initializeStream() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    Query query = FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'user');
    
    if (auth.isStateAdmin && auth.currentUser?.assignedState != null) {
      query = query.where('state', isEqualTo: auth.currentUser!.assignedState);
    }
    
    _stream = query.snapshots();
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
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by Mobile Number, Name or Email',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
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
              
              // Filter by Search Query
              if (_searchQuery.isNotEmpty) {
                users = users.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final phone = (data['phone'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || 
                         email.contains(_searchQuery) || 
                         phone.contains(_searchQuery);
                }).toList();
              }
              
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
                  final address = userData['address'] as String?;
                  final deliveryAddress = userData['deliveryAddress'] ?? userData['shippingAddress']; // Flexible key
                  final servicePincode = userData['service_pincode'] as String?;
                  final List<String> servicePincodes = (userData['servicePincodes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
                  
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
                              if (servicePincodes.isNotEmpty)
                                _buildInfoRow('Service Areas (Pincodes)', servicePincodes.join(', ')),
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
                                        address,
                                        deliveryAddress,
                                        servicePincode,
                                        servicePincodes,
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
    String? address,
    dynamic deliveryAddress, // String or Map
    String? servicePincode,
    List<String>? currentServicePincodes,
  ) {
    final nameController = TextEditingController(text: name);
    final emailController = TextEditingController(text: email);
    final phoneController = TextEditingController(text: phone);
    final addressController = TextEditingController(text: address ?? '');
    
    // Handle Delivery Address
    String initialDeliveryAddress = '';
    if (deliveryAddress is String) {
      initialDeliveryAddress = deliveryAddress;
    } else if (deliveryAddress is Map) {
      // If it's a map, try to format it nicely stringified, or just pick addressLine1
      // For simplicity let's just JSON encode or pick a specific field if we knew schema
      // Common schema: {addressLine1, city, state, pincode}
      final l1 = deliveryAddress['addressLine1'] ?? '';
      final city = deliveryAddress['city'] ?? '';
      final state = deliveryAddress['state'] ?? '';
      final pin = deliveryAddress['pincode'] ?? '';
      initialDeliveryAddress = '$l1, $city, $state - $pin';
    }
    final deliveryAddressController = TextEditingController(text: initialDeliveryAddress);

    final pincodeController = TextEditingController(text: servicePincode ?? '');
    final servicePincodesController = TextEditingController(text: currentServicePincodes?.join(', ') ?? '');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500, // Fixed width for "Square Box" feel on larger screens
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit User Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                      ),
                       const SizedBox(height: 16),
                      TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Profile Address',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.home),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: deliveryAddressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Delivery Address (Primary)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.local_shipping),
                          helperText: 'Note: Updating this might affect simple string addresses only.',
                        ),
                      ),
                      if (role == 'delivery_partner') ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: pincodeController,
                          decoration: const InputDecoration(
                            labelText: 'Service Pincode',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.map),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final Map<String, dynamic> updates = {
                        'name': nameController.text.trim(),
                        'email': emailController.text.trim(),
                        'phone': phoneController.text.trim(),
                        'address': addressController.text.trim(),
                        // For delivery address, if it was a string we update it as string.
                        // If it was a map, we might be breaking structure if we save as string.
                        // To be safe, let's save to a generic 'deliveryAddress' field as string if it wasn't a map,
                        // or if user edited it we might just save it as text note for now.
                        // Better approach: Update 'address' (profile) and 'phone'. 
                        // For delivery address, let's update 'shippingAddress' if it exists as string, else create.
                        'shippingAddress': deliveryAddressController.text.trim(), 
                      };
                      if (role == 'delivery_partner') {
                        updates['service_pincode'] = pincodeController.text.trim();
                      }
                      if (role == 'seller') {
                         final raw = servicePincodesController.text.trim();
                         if (raw.isNotEmpty) {
                           updates['servicePincodes'] = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                         } else {
                           updates['servicePincodes'] = [];
                         }
                      }

                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .update(updates);

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('User details updated successfully')),
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
                  icon: const Icon(Icons.save),
                  label: const Text('Save Changes'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _changeUserRole(String userId, String currentRole) {
    String? selectedRole = currentRole == 'admin' ? 'administrator' : currentRole;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isSuperAdmin = auth.isSuperAdmin;

    final List<DropdownMenuItem<String>> items = [
      const DropdownMenuItem(value: 'user', child: Text('User')),
      const DropdownMenuItem(value: 'seller', child: Text('Seller')),
      const DropdownMenuItem(
        value: 'delivery_partner',
        child: Text('Delivery Partner'),
      ),
    ];

    if (isSuperAdmin) {
      items.add(const DropdownMenuItem(value: 'admin', child: Text('Admin')));
      items.add(const DropdownMenuItem(value: 'core_staff', child: Text('Core Staff')));
    }

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
                initialValue: selectedRole,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: items,
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
