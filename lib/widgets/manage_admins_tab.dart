
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

class ManageAdminsTab extends StatefulWidget {
  const ManageAdminsTab({super.key});

  @override
  State<ManageAdminsTab> createState() => _ManageAdminsTabState();
}

class _ManageAdminsTabState extends State<ManageAdminsTab> {
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');

  // List of Indian States/UTs for Dropdown
  final List<String> _indianStates = [
    'Andaman and Nicobar Islands',
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chandigarh',
    'Chhattisgarh',
    'Dadra and Nagar Haveli',
    'Daman and Diu',
    'Delhi',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jammu and Kashmir',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Ladakh',
    'Lakshadweep',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Puducherry',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'manage_admins_fab',
        onPressed: () => _showPromoteDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Add State Admin'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.admin_panel_settings, size: 32, color: Colors.deepPurple),
                const SizedBox(width: 12),
                Text(
                  'Manage State Admins',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[900],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Assign admins to specific states. They will only see data related to their assigned state.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _usersCollection
                    .where('role', isEqualTo: 'state_admin')
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
                          Icon(Icons.supervised_user_circle_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No State Admins assigned yet.',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => _showPromoteDialog(),
                            child: const Text('Assign Your First State Admin'),
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
                        childAspectRatio: 1.8, // Adjust for card height
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final id = docs[index].id;
                        return _buildAdminCard(id, data);
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

  Widget _buildAdminCard(String id, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Unknown';
    final email = data['email'] ?? 'No Email';
    final assignedState = data['assignedState'] ?? 'Unassigned';
    final phone = data['phoneNumber'] ?? data['phone'] ?? 'N/A';
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
               children: [
                 CircleAvatar(
                   backgroundColor: Colors.deepPurple.shade100,
                   child: Text(name.substring(0,1).toUpperCase(), 
                      style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                 ),
                 const SizedBox(width: 12),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(email, style: TextStyle(color: Colors.grey[600], fontSize: 12), overflow: TextOverflow.ellipsis),
                     ],
                   ),
                 ),
                 PopupMenuButton<String>(
                   onSelected: (value) {
                     if (value == 'edit') {
                       _showPromoteDialog(existingId: id, currentData: data);
                     } else if (value == 'remove') {
                       _demoteAdmin(id, name);
                     }
                   },
                   itemBuilder: (context) => [
                      const PopupMenuItem(
                       value: 'edit',
                       child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit State')]),
                     ),
                     const PopupMenuItem(
                       value: 'remove',
                       child: Row(children: [Icon(Icons.remove_circle_outline, color: Colors.red, size: 18), SizedBox(width: 8), Text('Remove Admin Role', style: TextStyle(color: Colors.red))]),
                     ),
                   ],
                 )
               ],
             ),
             const Divider(height: 24),
             const Text('Assigned State', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
             const SizedBox(height: 4),
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
               decoration: BoxDecoration(
                 color: Colors.deepPurple.shade50,
                 borderRadius: BorderRadius.circular(8),
                 border: Border.all(color: Colors.deepPurple.shade100),
               ),
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   const Icon(Icons.map, size: 16, color: Colors.deepPurple),
                   const SizedBox(width: 6),
                   Text(assignedState, style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w600)),
                 ],
               ),
             ),
             const Spacer(),
             Row(
               children: [
                 const Icon(Icons.phone, size: 14, color: Colors.grey),
                 const SizedBox(width: 4),
                 Text(phone, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
               ],
             )
          ],
        ),
      ),
    );
  }

  void _showPromoteDialog({String? existingId, Map<String, dynamic>? currentData}) {
    final emailController = TextEditingController(text: currentData?['email'] ?? '');
    final nameController = TextEditingController(text: currentData?['name'] ?? '');
    final phoneController = TextEditingController(text: currentData?['phoneNumber'] ?? currentData?['phone'] ?? '');
    final passwordController = TextEditingController();
    
    String? selectedState = currentData?['assignedState'];
    
    // If editing, email should be read-only
    final isEditing = existingId != null;
    
    // Toggle for adding new user vs promoting existing
    // If editing, forced to "Promote" mode (which acts as update) to hide toggle
    bool createNewUser = false;
    
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    String? errorMsg;
    String? verifiedUserName;
    String? verifiedUserPhone;
    
    // Debounce for checking user
    // Timer? _debounce;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          
          Future<void> checkUser() async {
            if (emailController.text.trim().isEmpty) return;
            setState(() { errorMsg = null; verifiedUserName = null; });
            
            try {
              final query = await _usersCollection.where('email', isEqualTo: emailController.text.trim()).get();
              if (query.docs.isNotEmpty) {
                 final data = query.docs.first.data() as Map<String, dynamic>;
                 setState(() {
                   verifiedUserName = data['name'];
                   verifiedUserPhone = data['phoneNumber'] ?? data['phone'];
                 });
              } else {
                 setState(() { errorMsg = 'User not found. Switch to "Create New" to add them.'; });
              }
            } catch (e) {
              print('Check error: $e');
            }
          }

          return AlertDialog(
            title: Text(isEditing ? 'Edit State Admin' : 'Add State Admin'),
            content: SizedBox(
              width: 450,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       if (!isEditing) ...[
                         Row(
                           children: [
                             Expanded(
                               child: RadioListTile<bool>(
                                 title: const Text('Promote Existing'),
                                 subtitle: const Text('User already has app account'),
                                 value: false,
                                 groupValue: createNewUser,
                                 onChanged: (val) => setState(() { 
                                   createNewUser = val!; 
                                   errorMsg = null; 
                                 }),
                                 contentPadding: EdgeInsets.zero,
                               ),
                             ),
                             Expanded(
                               child: RadioListTile<bool>(
                                 title: const Text('Create New'),
                                 subtitle: const Text('Create fresh account'),
                                 value: true,
                                 groupValue: createNewUser,
                                 onChanged: (val) => setState(() { 
                                   createNewUser = val!; 
                                   errorMsg = null;
                                 }),
                                 contentPadding: EdgeInsets.zero,
                               ),
                             ),
                           ],
                         ),
                         const Divider(),
                         const SizedBox(height: 16),
                       ],
                  
                       // 1. Email Field
                       TextFormField(
                         controller: emailController,
                         decoration: InputDecoration(
                           labelText: 'User Email',
                           border: const OutlineInputBorder(),
                           prefixIcon: const Icon(Icons.email),
                           suffixIcon: (!isEditing && !createNewUser) 
                              ? IconButton(onPressed: checkUser, icon: const Icon(Icons.search, color: Colors.deepPurple))
                              : null,
                         ),
                         enabled: !isEditing, // Lock email if editing
                         validator: (value) => value == null || value.isEmpty ? 'Enter email' : null,
                         onEditingComplete: () {
                           if (!createNewUser && !isEditing) checkUser();
                         },
                       ),
                       
                       // 2. Verified User Info (Only for Promote Mode)
                       if (!createNewUser && verifiedUserName != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Found: $verifiedUserName', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    if (verifiedUserPhone != null) Text('Phone: $verifiedUserPhone', style: const TextStyle(fontSize: 12)),
                                  ],
                                )
                              ],
                            ),
                          )
                       ],
                       
                       const SizedBox(height: 16),
                       
                       // 3. Name & Phone & Password (Only for Create Mode)
                       if (createNewUser) ...[
                         Row(
                           children: [
                             Expanded(
                               child: TextFormField(
                                 controller: nameController,
                                 decoration: const InputDecoration(
                                   labelText: 'Full Name',
                                   border: OutlineInputBorder(),
                                   prefixIcon: Icon(Icons.person),
                                 ),
                                 validator: (v) => v!.isEmpty ? 'Required' : null,
                               ),
                             ),
                             const SizedBox(width: 12),
                             Expanded(
                               child: TextFormField(
                                 controller: phoneController,
                                 decoration: const InputDecoration(
                                   labelText: 'Phone',
                                   border: OutlineInputBorder(),
                                   prefixIcon: Icon(Icons.phone),
                                 ),
                                 validator: (v) => v!.isEmpty ? 'Required' : null,
                               ),
                             ),
                           ],
                         ),
                         const SizedBox(height: 16),
                         TextFormField(
                           controller: passwordController,
                           decoration: const InputDecoration(
                             labelText: 'Password',
                             border: OutlineInputBorder(),
                             prefixIcon: Icon(Icons.lock),
                           ),
                           obscureText: true,
                           validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                         ),
                         const SizedBox(height: 16),
                       ],
                  
                       // 4. State Dropdown
                       DropdownButtonFormField<String>(
                         value: selectedState,
                         decoration: const InputDecoration(
                           labelText: 'Assign State',
                           border: OutlineInputBorder(),
                           prefixIcon: Icon(Icons.map),
                         ),
                         items: _indianStates.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                         onChanged: (val) => setState(() => selectedState = val),
                         validator: (value) => value == null ? 'Select a state' : null,
                       ),
                       
                       if (errorMsg != null) ...[
                         const SizedBox(height: 16),
                         Text(errorMsg!, style: const TextStyle(color: Colors.red)),
                       ]
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  if (formKey.currentState?.validate() ?? false) {
                    setState(() { isLoading = true; errorMsg = null; });
                    
                    try {
                      // Scenario A: Create New User via Cloud Function
                      if (createNewUser) {
                        try {
                           final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('createStateAdminAccount');
                           await callable.call({
                             'email': emailController.text.trim(),
                             'password': passwordController.text.trim(),
                             'name': nameController.text.trim(),
                             'phone': phoneController.text.trim().startsWith('+') 
                                 ? phoneController.text.trim() 
                                 : '+91${phoneController.text.trim()}',
                             'assignedState': selectedState,
                           });
                        } catch (e) {
                          // Handle Cloud Function errors
                           if (e is FirebaseFunctionsException) {
                              throw Exception(e.message ?? e.details ?? 'Cloud Function Error');
                           }
                           throw Exception(e.toString());
                        }
                      } 
                      // Scenario B: Promote Existing User via Firestore
                      else {
                          if (verifiedUserName == null && !isEditing) {
                             // Force check before saving if not checked
                             await checkUser();
                             if (verifiedUserName == null) throw Exception('Please verify user exists first (Click Search Icon)');
                          }
                        
                          String uid = existingId ?? '';
                          // If Adding (not editing), finding UID happens in checkUser logic or here again
                          if (!isEditing) {
                             // We re-fetch to be safe or use what we found
                             final query = await _usersCollection.where('email', isEqualTo: emailController.text.trim()).get();
                             if (query.docs.isEmpty) throw Exception('User not found');
                             uid = query.docs.first.id;
                          }
                          
                          // Update User Doc
                          await _usersCollection.doc(uid).update({
                             'role': 'state_admin',
                             'assignedState': selectedState,
                          });
                      }
                      
                      if (mounted) Navigator.pop(context);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('Successfully saved state admin for $selectedState')),
                      );
                      
                    } catch (e) {
                      if (mounted) setState(() => errorMsg = e.toString().replaceAll('Exception: ', ''));
                    } finally {
                      if (mounted) setState(() => isLoading = false);
                    }
                  }
                },
                child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Text('Save'),
              )
            ],
          );
        }
      ),
    );
  }

  Future<void> _demoteAdmin(String id, String name) async {
      final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Admin Role'),
        content: Text('Are you sure you want to demote "$name" back to a regular user? They will lose access to the Admin Panel.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _usersCollection.doc(id).update({
          'role': 'user',
          'assignedState': FieldValue.delete(),
        });
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User demoted successfully')));
        }
      } catch (e) {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
         }
      }
    }
  }
}
