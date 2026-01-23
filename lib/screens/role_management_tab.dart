import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RoleManagementTab extends StatefulWidget {
  final String collection;
  final String? role;
  final String? requestRole;
  final Function(String, Map<String, dynamic>) onEdit;
  final Function(String, String) onDelete;
  final Function(String, String)? onRequestAction;
  final Function(String, Map<String, dynamic>)? onViewDashboard;

  const RoleManagementTab({
    super.key,
    required this.collection,
    this.role,
    this.requestRole,
    required this.onEdit,
    required this.onDelete,
    this.onRequestAction,
    this.onViewDashboard,
  });

  @override
  State<RoleManagementTab> createState() => _RoleManagementTabState();
}

class _RoleManagementTabState extends State<RoleManagementTab> {
  String _searchQuery = '';
  String _selectedStatus = 'All';

  late Stream<QuerySnapshot> _stream;

  @override
  void initState() {
    super.initState();
    _initializeStream();
  }

  @override
  void didUpdateWidget(RoleManagementTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.collection != oldWidget.collection || widget.role != oldWidget.role) {
      _initializeStream();
    }
  }

  void _initializeStream() {
    Query query = FirebaseFirestore.instance.collection(widget.collection);
    if (widget.role != null) {
      query = query.where('role', isEqualTo: widget.role);
    }
    _stream = query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by name, email, or phone',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _selectedStatus,
                items: ['All', 'Approved', 'Pending', 'Rejected', 'Requests']
                    .map((status) => DropdownMenuItem(value: status, child: Text(status)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedStatus = value);
                },
              ),
            ],
          ),
        ),
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

              var docs = snapshot.data?.docs ?? [];

              // Client-side filtering
              final filteredDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                
                // Search Filter
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final phone = (data['phone'] ?? '').toString().toLowerCase();
                  if (!name.contains(q) && !email.contains(q) && !phone.contains(q)) {
                    return false;
                  }
                }

                // Status Filter
                if (_selectedStatus != 'All') {
                  final status = data.containsKey('status') ? (data['status'] as String? ?? 'pending') : 'approved';

                  if ((_selectedStatus == 'Requests' || _selectedStatus == 'Pending') && status != 'pending') return false;
                  if (_selectedStatus == 'Approved' && status != 'approved') return false;
                  if (_selectedStatus == 'Rejected' && status != 'rejected') return false;
                }

                return true;
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.role == 'seller' ? Icons.store : 
                        widget.role == 'service_provider' ? Icons.handyman :
                        Icons.delivery_dining,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No ${_selectedStatus == 'All' ? '' : _selectedStatus} ${widget.role == 'seller' ? 'Sellers' : widget.role == 'service_provider' ? 'Service Providers' : 'Delivery Partners'} found',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final id = doc.id;
                  final name = data['name'] ?? 'N/A';
                  final email = data['email'] ?? 'N/A';
                  final phone = data['phone'] ?? 'N/A';
                  final servicePincode = data['service_pincode'] as String?;
                  
                  final dynamic createdAtData = data['createdAt'];
                  final DateTime? createdAt;
                  if (createdAtData is Timestamp) {
                    createdAt = createdAtData.toDate();
                  } else if (createdAtData is String) {
                    createdAt = DateTime.tryParse(createdAtData);
                  } else {
                    createdAt = null;
                  }
                  
                  // Determine if it's a request or a user
                  final status = data.containsKey('status') ? (data['status'] as String? ?? 'pending') : 'approved';
                  final isRequest = status != 'approved';

                  Color statusColor;
                  switch (status.toLowerCase()) {
                    case 'approved': statusColor = Colors.green; break;
                    case 'pending': statusColor = Colors.orange; break;
                    case 'rejected': statusColor = Colors.red; break;
                    default: statusColor = Colors.grey;
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        if (widget.onViewDashboard != null && !isRequest) {
                          widget.onViewDashboard!(id, data);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Leading Avatar
                            CircleAvatar(
                              backgroundColor: statusColor.withOpacity(0.1),
                              child: Icon(
                                widget.role == 'seller' ? Icons.store : 
                                widget.role == 'service_provider' ? Icons.handyman :
                                Icons.delivery_dining,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Main Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Name
                                  Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  // Email
                                  Row(
                                    children: [
                                      const Icon(Icons.email, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Flexible(child: Text(email, overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  // Phone
                                  Row(
                                    children: [
                                      const Icon(Icons.phone, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(phone),
                                    ],
                                  ),
                                  // Pincode
                                  if (servicePincode != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text('Pincode: $servicePincode'),
                                        ],
                                      ),
                                    ),
                                  // Created Date
                                  if (createdAt != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Joined: ${DateFormat('MMM d, yyyy').format(createdAt)}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Right side column with badge on top and menu in center
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Approved badge at top
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: statusColor.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // 3-dot menu in center
                                if (isRequest && widget.onRequestAction != null && status == 'pending')
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check, color: Colors.green),
                                        onPressed: () => widget.onRequestAction!(id, 'approved'),
                                        tooltip: 'Approve',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, color: Colors.red),
                                        onPressed: () => widget.onRequestAction!(id, 'rejected'),
                                        tooltip: 'Reject',
                                      ),
                                    ],
                                  )
                                else if (!isRequest)
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        widget.onEdit(id, data);
                                      } else if (value == 'delete') {
                                        widget.onDelete(id, email);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, size: 20, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
}
