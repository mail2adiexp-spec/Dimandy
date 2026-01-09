import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'order_details_dialog.dart';

class SharedOrdersTab extends StatefulWidget {
  final bool canManage;
  final String? sellerId; // Optional: to filter orders for a specific seller
  final bool isDeliveryPartner; // Optional: for Delivery Partner dashboard specific view
  final List<String>? matchStatuses; // Optional: to show only specific orders

  const SharedOrdersTab({
    Key? key, 
    this.canManage = true,
    this.sellerId,
    this.isDeliveryPartner = false,
    this.matchStatuses,
  }) : super(key: key);

  @override
  State<SharedOrdersTab> createState() => _SharedOrdersTabState();
}

class _SharedOrdersTabState extends State<SharedOrdersTab> {
  final List<String> _statuses = const [
    'pending',
    'confirmed',
    'packed',
    'shipped',
    'out_for_delivery',
    'delivered',
    'cancelled',
    'return_requested',
    'out_for_pickup',
    'returned',
    'refunded',
  ];

  late Stream<QuerySnapshot> _ordersStream;

  // Filter States
  String _selectedDateFilter = 'All Time'; // 7 Days, 30 Days, 1 Year, Custom, All Time
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String _selectedStatusFilter = 'All'; // All, pending, confirmed, ...

  final List<String> _dateFilters = [
    'All Time',
    'Today',
    'Yesterday',
    'Last 7 Days',
    'Last 30 Days',
    'This Month',
    'Last Month',
    'This Year',
    'Custom Range'
  ];

  @override
  void initState() {
    super.initState();
    _initializeStream();
  }

  @override
  void didUpdateWidget(SharedOrdersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sellerId != oldWidget.sellerId || widget.isDeliveryPartner != oldWidget.isDeliveryPartner) {
      _initializeStream();
    }
  }

  void _initializeStream() {
    Query query = FirebaseFirestore.instance.collection('orders').orderBy('orderDate', descending: true);
    
    if (widget.isDeliveryPartner) {
        // Implementation for delivery partner specific stream if needed
    }

    _ordersStream = query.snapshots();
  }

  void _resetFilters() {
    setState(() {
      _selectedDateFilter = 'All Time';
      _customStartDate = null;
      _customEndDate = null;
      _selectedStatusFilter = 'All';
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23, 59, 59
        ); // End of day
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FILTERS SECTION
          Card(
            elevation: 0,
            color: Colors.grey[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.filter_list, size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text('Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (_selectedDateFilter != 'All Time' || _selectedStatusFilter != 'All')
                        TextButton.icon(
                          onPressed: _resetFilters,
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Clear All'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                      // Date Filter Dropdown
                      SizedBox(
                        width: 140,
                        child: DropdownButtonFormField<String>(
                          value: _selectedDateFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Date Range',
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _dateFilters.map((filter) {
                            return DropdownMenuItem(
                              value: filter, 
                              child: Text(
                                filter, 
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedDateFilter = value);
                              if (value == 'Custom Range') {
                                _selectDateRange(context);
                              }
                            }
                          },
                        ),
                      ),
                      
                      

                      // Spacing between filters
                      const SizedBox(width: 12),

                      // Custom Range Display
                      if (_selectedDateFilter == 'Custom Range') ...[
                        InkWell(
                          onTap: () => _selectDateRange(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                              color: Colors.white,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today, size: 14),
                                const SizedBox(width: 8),
                                Text(
                                   _customStartDate == null
                                      ? 'Select Dates'
                                      : '${DateFormat('dd/MM/yy').format(_customStartDate!)} - ${DateFormat('dd/MM/yy').format(_customEndDate!)}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Status Filter Dropdown
                      SizedBox(
                        width: 140,
                        child: DropdownButtonFormField<String>(
                          value: _selectedStatusFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: ['All', ..._statuses].map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(
                                status == 'All' ? 'All Statuses' : status.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) setState(() => _selectedStatusFilter = value);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _ordersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Failed to load orders: ${snapshot.error}'),
                  );
                }
                var docs = snapshot.data?.docs ?? [];
                
                // Client-side filtering if matchStatuses is provided (e.g. for tabs like "Refund Requests" passed from parent)
                if (widget.matchStatuses != null && widget.matchStatuses!.isNotEmpty) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return widget.matchStatuses!.contains(data['status']);
                  }).toList();
                }

                // Apply UI Filters
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final orderDateStr = data['orderDate'] as String?; // Assuming stored as ISO string or timestamp handled elsewhere?
                  // Wait, looking at code below: orderDate = DateTime.tryParse(orderDateStr);
                  // But previously I saw 'orderBy('orderDate')' which implies it might be a Timestamp or string that sorts correctly.
                  // Line 110 says: orderDate = DateTime.tryParse(orderDateStr);
                  
                  DateTime? orderDate;
                  try {
                    if (data['orderDate'] is Timestamp) {
                       orderDate = (data['orderDate'] as Timestamp).toDate();
                    } else if (orderDateStr != null) {
                       orderDate = DateTime.tryParse(orderDateStr);
                    }
                  } catch (_) {}

                  // 1. Status Filter
                  if (_selectedStatusFilter != 'All') {
                    if (data['status'] != _selectedStatusFilter) return false;
                  }

                  // 2. Date Filter
                  if (_selectedDateFilter != 'All Time' && orderDate != null) {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    
                    switch (_selectedDateFilter) {
                      case 'Today':
                        if (orderDate.isBefore(today)) return false;
                        break;
                      case 'Yesterday':
                        final yesterday = today.subtract(const Duration(days: 1));
                        if (orderDate.isBefore(yesterday) || orderDate.isAfter(today)) return false;
                        break;
                      case 'Last 7 Days':
                        if (orderDate.isBefore(now.subtract(const Duration(days: 7)))) return false;
                        break;
                      case 'Last 30 Days':
                         if (orderDate.isBefore(now.subtract(const Duration(days: 30)))) return false;
                        break;
                      case 'This Month':
                        if (orderDate.month != now.month || orderDate.year != now.year) return false;
                        break;
                      case 'Last Month':
                        final lastMonth = DateTime(now.year, now.month - 1, 1);
                        if (orderDate.month != lastMonth.month || orderDate.year != lastMonth.year) return false;
                        break;
                      case 'This Year':
                        if (orderDate.year != now.year) return false;
                        break;
                      case 'Custom Range':
                        if (_customStartDate != null && _customEndDate != null) {
                           if (orderDate.isBefore(_customStartDate!) || orderDate.isAfter(_customEndDate!)) return false;
                        }
                        break;
                    }
                  }

                  return true;
                }).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text('No matching orders found'));
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final orderId = doc.id;
                    final userId = data['userId'] as String? ?? '-';
                    final total = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
                    final status = data['status'] as String? ?? 'pending';
                    final orderDateStr = data['orderDate'] as String?;
                    DateTime? orderDate;
                    try {
                      if (orderDateStr != null) {
                        orderDate = DateTime.tryParse(orderDateStr);
                      }
                    } catch (_) {}

                    final items = data['items'] as List<dynamic>? ?? [];
                    final itemCount = items.length;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Order ID & Status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.shopping_bag_outlined, color: Colors.blue, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Order #${orderId.substring(0, 8)}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              orderDate != null ? DateFormat('MMM dd, yyyy • hh:mm a').format(orderDate) : '-',
                                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.canManage)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: _getStatusColor(status).withOpacity(0.5)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _statuses.contains(status) ? status : 'pending',
                                        icon: Icon(Icons.arrow_drop_down, color: _getStatusColor(status)),
                                        style: TextStyle(
                                          color: _getStatusColor(status),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        isDense: true,
                                        items: _statuses.map((s) => DropdownMenuItem(
                                          value: s, 
                                          child: Text(s.replaceAll('_', ' ').toUpperCase()),
                                        )).toList(),
                                        onChanged: (val) async {
                                          if (val == null) return;
                                          try {
                                            final batch = FirebaseFirestore.instance.batch();
                                            final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
                                            batch.update(orderRef, {
                                              'status': val,
                                              'statusHistory.$val': FieldValue.serverTimestamp(),
                                            });
                                            await batch.commit();
                                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to ${val.replaceAll('_', ' ')}')));
                                          } catch (e) {
                                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
                                          }
                                        },
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: _getStatusColor(status)),
                                    ),
                                    child: Text(
                                      status.toUpperCase().replaceAll('_', ' '),
                                      style: TextStyle(
                                        color: _getStatusColor(status),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const Divider(height: 24),
                            // Body: User, Items, Runner
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildInfoRow(Icons.person_outline, 'User ID', userId),
                                      const SizedBox(height: 8),
                                      _buildInfoRow(Icons.inventory_2_outlined, 'Items', '$itemCount items'),
                                      if (data['deliveryPartnerName'] != null) ...[
                                        const SizedBox(height: 8),
                                        _buildInfoRow(Icons.delivery_dining_outlined, 'Runner', data['deliveryPartnerName']),
                                      ]
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Total Amount', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text(
                                      NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(total),
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[800]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Footer: Actions
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.info_outline, size: 18),
                                  label: const Text('Details'),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => OrderDetailsDialog(orderId: orderId, orderData: data),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                if (widget.canManage && !widget.isDeliveryPartner) ...[
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.person_add_outlined, size: 18),
                                    label: const Text('Assign Runner'),
                                    onPressed: () => _showAssignDeliveryPartnerDialog(orderId, data),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                                if (status == 'returned') ...[
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.replay_circle_filled, size: 18),
                                    label: const Text('Refund'),
                                    onPressed: () async {
                                      // ... Refund Logic (Keep existing logic but formatted) ...
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) {
                                          final refundInfo = data['refundDetails'] != null 
                                              ? data['refundDetails']['paymentInfo'] 
                                              : 'Not provided';
                                          return AlertDialog(
                                            title: const Text('Process Refund'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Refund Amount: ₹${total.toStringAsFixed(2)}', 
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                const SizedBox(height: 16),
                                                const Text('User Payment Details (UPI/Bank):', 
                                                  style: TextStyle(color: Colors.grey, fontSize: 12)),
                                                const SizedBox(height: 4),
                                                Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[100],
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.grey.shade300),
                                                  ),
                                                  child: SelectableText(
                                                    refundInfo,
                                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                const Text('Mark this order as refunded after sending existing payment?',
                                                  style: TextStyle(fontSize: 14)),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                                child: const Text('Confirm Refund'),
                                              ),
                                            ],
                                          );
                                        },
                                      );

                                      if (confirm == true) {
                                        try {
                                          final batch = FirebaseFirestore.instance.batch();
                                          final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
                                          batch.update(orderRef, {
                                            'status': 'refunded',
                                            'statusHistory.refunded': FieldValue.serverTimestamp(),
                                          });
                                          await batch.commit();
                                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refund Processed Successfully')));
                                        } catch (e) {
                                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to process refund: $e')));
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Stream<QuerySnapshot> _getOrdersStream() {
    Query query = FirebaseFirestore.instance.collection('orders').orderBy('orderDate', descending: true);
    
    // Future: Apply filters if needed (e.g. sellerId) across "order items" subcollections or if sellerId is on main order.
    // Assuming sellerId is not on main order for now (multi-vendor orders usually split or complex).
    // If widget.sellerId is passed, we might need a different structure or query. 
    // Allowing default admin view (all orders) for now.
    
    if (widget.isDeliveryPartner) {
        // Implementation for delivery partner specific stream if needed
        // For now, core staff might see all or filter.
    }

    return query.snapshots();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.blue;
      case 'packed': return Colors.indigo;
      case 'shipped': return Colors.purple;
      case 'out_for_delivery': return Colors.teal;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'return_requested': return Colors.orange;
      case 'out_for_pickup': return Colors.blue;
      case 'returned': return Colors.purple;
      case 'refunded': return Colors.green;
      default: return Colors.grey;
    }
  }

  Future<void> _showAssignDeliveryPartnerDialog(String orderId, Map<String, dynamic> orderData) async {
    final deliveryPartnersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'delivery_partner')
        .get();

    if (!mounted) return;

    final deliveryPartners = deliveryPartnersSnapshot.docs;

    if (deliveryPartners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No delivery partners found')));
      return;
    }

    String? selectedPartnerId = orderData['deliveryPartnerId'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Assign Delivery Partner'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (orderData['deliveryPartnerName'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Currently assigned to: ${orderData['deliveryPartnerName']}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              DropdownButtonFormField<String>(
                value: selectedPartnerId,
                decoration: const InputDecoration(labelText: 'Select Delivery Partner', border: OutlineInputBorder()),
                items: deliveryPartners.map((doc) {
                  final data = doc.data();
                  return DropdownMenuItem(value: doc.id, child: Text(data['name'] ?? doc.id));
                }).toList(),
                onChanged: (value) => setState(() => selectedPartnerId = value),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            if (selectedPartnerId != null && orderData['deliveryPartnerId'] != null)
              TextButton(
                onPressed: () async {
                  try {
                    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
                      'deliveryPartnerId': FieldValue.delete(),
                      'deliveryPartnerName': FieldValue.delete(),
                    });
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery partner unassigned')));
                    }
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Unassign', style: TextStyle(color: Colors.red)),
              ),
            ElevatedButton(
              onPressed: selectedPartnerId == null
                  ? null
                  : () async {
                      try {
                        final partnerDoc = deliveryPartners.firstWhere((doc) => doc.id == selectedPartnerId);
                        final partnerData = partnerDoc.data();
                        await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
                          'deliveryPartnerId': selectedPartnerId,
                          'deliveryPartnerName': partnerData['name'] ?? 'Unknown',
                        });
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery partner assigned successfully')));
                        }
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }
}
