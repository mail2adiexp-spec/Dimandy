import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/auth_provider.dart';
import 'order_details_dialog.dart';
import 'barcode_scanner_dialog.dart';
import 'add_manual_order_dialog.dart'; // New

class SharedOrdersTab extends StatefulWidget {
  final bool canManage;
  final String? sellerId; // Optional: to filter orders for a specific seller
  final bool isDeliveryPartner; // Optional: for Delivery Partner dashboard specific view
  final List<String>? matchStatuses; // Optional: to show only specific orders
  final List<String>? pincodes; // Optional: to filter orders for a specific store service area
  final bool showAddButton; // Optional: to hide the 'Add Order' button (Guest Order)

  const SharedOrdersTab({
    Key? key, 
    this.canManage = true,
    this.sellerId,
    this.isDeliveryPartner = false,
    this.matchStatuses,
    this.pincodes,
    this.showAddButton = true,
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
  String _selectedDateFilter = 'Today'; // 7 Days, 30 Days, 1 Year, Custom, All Time
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
    if (widget.sellerId != oldWidget.sellerId || 
        widget.isDeliveryPartner != oldWidget.isDeliveryPartner ||
        !listEquals(widget.pincodes, oldWidget.pincodes)) {
      _initializeStream();
    }
  }

  void _initializeStream() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    Query query = FirebaseFirestore.instance.collection('orders');
    
    // State Admin Filter
    if (auth.isStateAdmin && auth.currentUser?.assignedState != null) {
      query = query.where('state', isEqualTo: auth.currentUser!.assignedState);
    }
    
    // Store Manager / Pincodes Filter
    if (widget.pincodes != null && widget.pincodes!.isNotEmpty) {
      // Note: This requires an index on deliveryPincode (or whichever field stores the pincode)
      // Usually, it's 'deliveryPincode' or 'pincode' in order data
      query = query.where('deliveryPincode', whereIn: widget.pincodes);
    }
    
    // Seller ID Filter
    if (widget.sellerId != null) {
      query = query.where('sellerIds', arrayContains: widget.sellerId);
    }
    
    query = query.orderBy('orderDate', descending: true);
    
    if (widget.isDeliveryPartner) {
        // Implementation for delivery partner specific stream if needed
    }

    _ordersStream = query.snapshots();
  }

  void _resetFilters() {
    setState(() {
      _selectedDateFilter = 'Today';
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
                      if (_selectedDateFilter != 'Today' || _selectedStatusFilter != 'All')
                        TextButton.icon(
                          onPressed: _resetFilters,
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Clear All'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      if (widget.canManage && widget.showAddButton)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => const AddManualOrderDialog(),
                              );
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Order', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
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
                          initialValue: _selectedDateFilter,
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
                          initialValue: _selectedStatusFilter,
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
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Failed to load orders: ${snapshot.error}\n\n(Wait for index to build or copy error below)',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: snapshot.error.toString()));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Error copied to clipboard! Paste it in your browser.'))
                              );
                            },
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy Error'),
                          ),
                        ],
                      ),
                    ),
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
                  final dynamic rawDate = data['orderDate'];
                  DateTime? orderDate;
                  
                  if (rawDate is Timestamp) {
                    orderDate = rawDate.toDate();
                  } else if (rawDate is String) {
                    orderDate = DateTime.tryParse(rawDate);
                  }

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

                return Column(
                  children: [
                    if (widget.canManage)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: InkWell(
                          onTap: () => _generateProductSalesReport(docs),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.picture_as_pdf, color: Colors.blue, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Download Selling Report (PDF)',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final orderId = doc.id;
                    final userId = data['userId'] as String? ?? '-';
                    final total = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
                    final status = data['status'] as String? ?? 'pending';
                    final dynamic rawDate = data['orderDate'];
                    DateTime? orderDate;
                    if (rawDate is Timestamp) {
                      orderDate = rawDate.toDate();
                    } else if (rawDate is String) {
                      orderDate = DateTime.tryParse(rawDate);
                    }

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
                                          color: Colors.blue.withValues(alpha: 0.1),
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
                                            if (data['isGuest'] == true)
                                              Container(
                                                margin: const EdgeInsets.only(top: 4),
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                                                ),
                                                child: const Text(
                                                  'GUEST ORDER',
                                                  style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
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
                                      color: _getStatusColor(status).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: _getStatusColor(status).withValues(alpha: 0.5)),
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
                                        items: _statuses.where((s) {
                                          if (!widget.canManage) return true;
                                          // If Delivery Partner, see only relevant (usually they don't change status here, but let's keep logic simple)
                                          // If Seller (assuming canManage=true and not isDeliveryPartner implies seller/admin)
                                          // Restrict 'shipped', 'out_for_delivery', 'delivered', 'cancelled' for Sellers
                                          // But if it IS already one of those, we must show it so it can be viewed.
                                          final isRestricted = ['shipped', 'out_for_delivery', 'delivered', 'cancelled'].contains(s);
                                          final isCurrent = status == s;
                                          
                                          // If I am just a seller (not admin, assuming isAdmin is handled by parent passing canManage=true)
                                          // We need a way to know if 'admin' or 'seller'. 
                                          // SharedOrdersTab doesn't explicitly know 'role', but text says "Seller Dashboard".
                                          // We will assume if canManage is true, we apply restrictions unless we add an 'isAdmin' flag.
                                          // However, for now, enforcing restrictions for everyone using this widget in this context 
                                          // as per user request "seller dashboard main...".
                                          // Ideally, Admin uses a different view or we pass 'isSeller' flag.
                                          // Given the prompt context, I will apply restriction.
                                          
                                          if (isRestricted && !isCurrent) return false;
                                          return true; 
                                        }).map((s) => DropdownMenuItem(
                                          value: s, 
                                          child: Text(s.replaceAll('_', ' ').toUpperCase()),
                                        )).toList(),
                                        onChanged: status == 'cancelled' ? null : (val) async {
                                          if (val == null || status == 'cancelled') return;
                                          
                                          // Barcode Verification for 'Packed'
                                          if (val == 'packed') {
                                            final scannedCode = await showDialog<String>(
                                              context: context,
                                              builder: (context) => const BarcodeScannerDialog(),
                                            );

                                            if (scannedCode == null) return; // Cancelled
                                            final normalizedScannedCode = scannedCode.trim().toLowerCase();

                                            // Verify barcode
                                            // As verified in plan, we check match against items or the Order ID itself.
                                            // Shipping labels often contain the Order ID as a barcode.
                                            
                                            // data['items'] is List<dynamic>
                                            final items = data['items'] as List<dynamic>? ?? [];
                                            bool matchFound = false;

                                            // 1. Check against Order ID (Shipping Label Barcode) with flexible logic
                                            final expectedOrderId = orderId.trim().toLowerCase();
                                            if (normalizedScannedCode.replaceAll('#', '') == expectedOrderId || 
                                                (expectedOrderId.startsWith(normalizedScannedCode.replaceAll('#', '')) && normalizedScannedCode.replaceAll('#', '').length >= 6)) {
                                              matchFound = true;
                                            }

                                            // 2. Check against Product IDs if no Order ID match
                                            if (!matchFound) {
                                              for (var item in items) {
                                                 // Check 'productId' or 'id'
                                                 final pId = (item['productId']?.toString() ?? item['id']?.toString() ?? '').trim().toLowerCase();
                                                 if (pId == normalizedScannedCode) {
                                                   matchFound = true;
                                                   break;
                                                 }
                                              }
                                            }

                                            if (!matchFound) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Verification Failed: Scanned code $scannedCode does not match any product in this order.'),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                              return;
                                            }
                                            if (mounted) {
                                               ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Barcode Verified! Marking as Packed...'), backgroundColor: Colors.green),
                                               );
                                            }
                                          }

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
                                      color: _getStatusColor(status).withValues(alpha: 0.1),
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
                            // Body: User, Items, Runner, Total (Vertical)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow(Icons.person_outline, 'User ID', userId),
                                const SizedBox(height: 8),
                                _buildInfoRow(Icons.inventory_2_outlined, 'Items', '$itemCount items'),
                                if (data['deliveryPartnerName'] != null) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow(Icons.delivery_dining_outlined, 'Runner', data['deliveryPartnerName']),
                                ],
                                const SizedBox(height: 12),
                                // Total Amount Row
                                Container(
                                  padding: const EdgeInsets.only(top: 12),
                                  decoration: const BoxDecoration(
                                    border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Total Amount', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                                      Text(
                                        NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(total),
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[800]),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Footer: Actions
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.info_outline, size: 14),
                                    label: const Text('Details', style: TextStyle(fontSize: 11)),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => OrderDetailsDialog(orderId: orderId, orderData: data),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                                if (widget.canManage && !widget.isDeliveryPartner) ...[
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.person_add_outlined, size: 14),
                                      label: const Text('Assign', style: TextStyle(fontSize: 11)),
                                      onPressed: () => _showAssignDeliveryPartnerDialog(orderId, data),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                  if (['pending', 'confirmed', 'packed'].contains(status)) ...[
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.cancel_outlined, size: 14),
                                        label: const Text('Reject', style: TextStyle(fontSize: 11, color: Colors.red)),
                                        onPressed: () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Reject Order?'),
                                              content: const Text('Are you sure you want to reject this order? This action cannot be undone.'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                  child: const Text('Yes, Reject'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed == true) {
                                            try {
                                              await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
                                                'status': 'cancelled',
                                                'statusHistory.cancelled': FieldValue.serverTimestamp(),
                                                'rejectedBy': Provider.of<AuthProvider>(context, listen: false).currentUser?.uid,
                                              });
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order Rejected Successfully')));
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reject order: $e')));
                                              }
                                            }
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          side: const BorderSide(color: Colors.red),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                                if (status == 'returned') ...[
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.replay_circle_filled, size: 14),
                                      label: const Text('Refund', style: TextStyle(fontSize: 11)),
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
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          );
        },
      ),
    ),
  ],
),
);
}

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column( // Changed to Column for vertical layout
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text('$label:', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 24.0),
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
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

  Future<void> _generateProductSalesReport(List<QueryDocumentSnapshot> docs) async {
    // Aggregate sales by product
    final Map<String, Map<String, dynamic>> productSales = {};
    double grandTotalSales = 0.0;
    int grandTotalQty = 0;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'pending';

      // Selling means completed/delivered as per user request
      if (status != 'delivered' && status != 'completed') continue;

      final items = (data['items'] as List<dynamic>?) ?? [];
      for (var item in items) {
        final pId = item['productId']?.toString() ?? item['id']?.toString() ?? 'N/A';
        final pName = item['productName']?.toString() ?? item['name']?.toString() ?? 'Unknown Product';
        final qty = (item['quantity'] as num?)?.toInt() ?? 0;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final lineTotal = price * qty;

        if (productSales.containsKey(pId)) {
          productSales[pId]!['qty'] += qty;
          productSales[pId]!['total'] += lineTotal;
        } else {
          productSales[pId] = {
            'name': pName,
            'qty': qty,
            'total': lineTotal,
          };
        }
        grandTotalQty += qty;
        grandTotalSales += lineTotal;
      }
    }

    if (productSales.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No delivered/completed orders found to generate report.')),
        );
      }
      return;
    }

    // Generate PDF
    final pdf = pw.Document();
    final period = _selectedDateFilter == 'Custom Range'
        ? '${DateFormat('dd/MM/yy').format(_customStartDate!)} - ${DateFormat('dd/MM/yy').format(_customEndDate!)}'
        : _selectedDateFilter;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, text: 'Product Selling Report (Sold Items)'),
            pw.SizedBox(height: 10),
            pw.Text('Note: This report only includes orders with status "delivered" or "completed".'),
            pw.SizedBox(height: 5),
            pw.Text('Period: $period'),
            pw.Text('Report Generated: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}'),
            pw.Divider(),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Product Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Qty Sold', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Total Sales Value', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                ...productSales.values.map((p) => pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(p['name'])),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(p['qty'].toString())),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Rs.${p['total'].toStringAsFixed(2)}')),
                      ],
                    )),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('GRAND TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(grandTotalQty.toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Rs.${grandTotalSales.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('DEMANDY - Sales Analytics Summary')),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
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
    final auth = Provider.of<AuthProvider>(context, listen: false);
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'delivery_partner');

    if (auth.isStateAdmin && auth.currentUser?.assignedState != null) {
      query = query.where('state', isEqualTo: auth.currentUser!.assignedState);
    }

    final deliveryPartnersSnapshot = await query.get();

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
                initialValue: selectedPartnerId,
                decoration: const InputDecoration(labelText: 'Select Delivery Partner', border: OutlineInputBorder()),
                items: deliveryPartners.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
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
                        final Map<String, dynamic> partnerData = partnerDoc.data() as Map<String, dynamic>;
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
