import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/order_model.dart';
import '../models/app_settings_model.dart';
import '../widgets/qr_code_display_dialog.dart';
import '../widgets/payment_proof_upload_widget.dart';
import '../widgets/barcode_scanner_screen.dart';
import 'package:intl/intl.dart';
import '../services/transaction_service.dart';
import '../models/transaction_model.dart';
import 'seller_wallet_screen.dart';

class DeliveryPartnerDashboardScreen extends StatefulWidget {
  static const routeName = '/delivery-dashboard';
  const DeliveryPartnerDashboardScreen({super.key});

  @override
  State<DeliveryPartnerDashboardScreen> createState() =>
      _DeliveryPartnerDashboardScreenState();
}

class _DeliveryPartnerDashboardScreenState
    extends State<DeliveryPartnerDashboardScreen> with SingleTickerProviderStateMixin {
  String _selectedFilter = 'assigned'; // assigned, in_progress, completed
  String _selectedDateFilter = 'all'; // all, today, week, month
  String? _servicePincode;
  bool _isLoadingPincode = true;
  late AnimationController _refreshController;

  // Cached streams to prevent "Unexpected state" errors
  Stream<QuerySnapshot>? _availableOrdersStream;
  Stream<QuerySnapshot>? _myDeliveriesStream;
  Stream<QuerySnapshot>? _statsStream;
  Stream<QuerySnapshot>? _recentActivityStream;

  Stream<QuerySnapshot>? _totalEarningsStream;
  Stream<QuerySnapshot>? _returnsStream;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _fetchServicePincode();
    // Initialize my deliveries stream immediately as it only depends on user ID
    // We'll update it in build once we have the ID, or here if possible.
    // Better to do it when we have the ID.
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final deliveryPartnerId = auth.currentUser?.uid;
    if (deliveryPartnerId != null) {
      if (_myDeliveriesStream == null) {
        _updateMyDeliveriesStream(deliveryPartnerId);
      }
      if (_statsStream == null) {
        _statsStream = FirebaseFirestore.instance
            .collection('orders')
            .where('deliveryPartnerId', isEqualTo: deliveryPartnerId)
            .snapshots();
      }
      if (_recentActivityStream == null) {
        _recentActivityStream = FirebaseFirestore.instance
            .collection('orders')
            .where('deliveryPartnerId', isEqualTo: deliveryPartnerId)
            .orderBy('createdAt', descending: true)
            .limit(5)
            .snapshots();
      }
      if (_totalEarningsStream == null) {
        _totalEarningsStream = FirebaseFirestore.instance
            .collection('orders')
            .where('deliveryPartnerId', isEqualTo: deliveryPartnerId)
            .where('deliveryStatus', isEqualTo: 'delivered')
            .snapshots();
      }
      if (_returnsStream == null) {
        _returnsStream = FirebaseFirestore.instance
            .collection('orders')
            .where('status', isEqualTo: 'return_requested')
            //.where('deliveryPincode', isEqualTo: _servicePincode) // Ideally filter by pincode
            .snapshots();
      }
    }
  }

  void _updateMyDeliveriesStream(String partnerId) {
    _myDeliveriesStream = _getOrdersStream(partnerId);
  }

  void _updateAvailableOrdersStream() {
    if (_servicePincode == null) return;
    
    // Fetch all orders with matching pincode, then filter on client side
    // This is because Firestore's isNull doesn't work well with empty strings
    _availableOrdersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('deliveryPincode', isEqualTo: _servicePincode)
        .snapshots();
  }

  Future<void> _fetchServicePincode() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (mounted) {
        setState(() {
          _servicePincode = doc.data()?['service_pincode'];
          _isLoadingPincode = false;
          _updateAvailableOrdersStream(); // Initialize stream once pincode is available
        });
      }
    } catch (e) {
      print('Error fetching pincode: $e');
      if (mounted) {
        setState(() => _isLoadingPincode = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final deliveryPartnerId = auth.currentUser?.uid;
    print('DEBUG: Delivery Dashboard - ID: $deliveryPartnerId');
    if (deliveryPartnerId != null) {
      FirebaseFirestore.instance.collection('users').doc(deliveryPartnerId).get().then((doc) {
        print('DEBUG: User Role from Firestore: ${doc.data()?['role']}');
      });
    }

    if (deliveryPartnerId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery Dashboard')),
        body: const Center(child: Text('Please log in')),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Delivery Partner Dashboard'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
              Tab(text: 'Available Orders', icon: Icon(Icons.notifications_active)),
              Tab(text: 'My Deliveries', icon: Icon(Icons.local_shipping)),
              Tab(text: 'Returns', icon: Icon(Icons.assignment_return)),
            ],
          ),
          actions: [
            RotationTransition(
              turns: _refreshController,
              child: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  _refreshController.repeat();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Refreshing data...'), duration: Duration(seconds: 1)),
                  );
                  _fetchServicePincode();
                  await Future.delayed(const Duration(seconds: 1));
                  if (mounted) {
                    setState(() {});
                    _refreshController.stop();
                    _refreshController.reset();
                  }
                },
                tooltip: 'Refresh',
              ),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildOverviewTab(deliveryPartnerId),
            _buildAvailableOrdersTab(deliveryPartnerId),
            _buildMyDeliveriesTab(deliveryPartnerId),
            _buildReturnsTab(deliveryPartnerId),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableOrdersTab(String partnerId) {
    if (_isLoadingPincode) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_servicePincode == null || _servicePincode!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Service Area Not Set',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please contact Admin to set your Service Pincode\nto receive order broadcasts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.blue[50],
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Showing orders in Pincode: $_servicePincode',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _availableOrdersStream, // Use cached stream
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Client-side filter for unassigned orders + correct status
              final allDocs = snapshot.data?.docs ?? [];
              print('DEBUG Available Orders: Total docs from Firestore: ${allDocs.length}');
              
              final docs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] as String?;
                final deliveryPartnerId = data['deliveryPartnerId'];
                final deliveryPincode = data['deliveryPincode'];
                
                final isUnassigned = deliveryPartnerId == null || deliveryPartnerId == '';
                final isValidStatus = status == 'pending' || status == 'confirmed' || status == 'packed';
                
                print('DEBUG Order ${doc.id}: status=$status, partnerId=$deliveryPartnerId, pincode=$deliveryPincode, unassigned=$isUnassigned, validStatus=$isValidStatus');
                
                return isUnassigned && isValidStatus;
              }).toList();

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text(
                        'No new orders in your area',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final order = OrderModel.fromMap(data, doc.id);
                  return _buildBroadcastOrderCard(order, partnerId);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBroadcastOrderCard(OrderModel order, String partnerId) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.withOpacity(0.5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'NEW REQUEST',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '₹${order.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Order #${order.id.substring(0, 8)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.deliveryAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _acceptOrder(order.id, partnerId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'ACCEPT ORDER',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptOrder(String orderId, String partnerId) async {
    try {
      // Use transaction to prevent race conditions
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
        final orderDoc = await transaction.get(orderRef);

        if (!orderDoc.exists) {
          throw Exception("Order does not exist!");
        }

        final data = orderDoc.data() as Map<String, dynamic>;
        if (data['deliveryPartnerId'] != null && data['deliveryPartnerId'] != '') {
          throw Exception("Order already taken by another partner!");
        }

        transaction.update(orderRef, {
          'deliveryPartnerId': partnerId,
          'status': 'confirmed', // Ensure it's in a valid state for delivery
          'statusHistory.assigned': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order Accepted Successfully! 🚀'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMyDeliveriesTab(String partnerId) {
    return Column(
      children: [
        // Filters Container
        Container(
          color: Colors.white,
          child: Column(
            children: [
              // Date Filter Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Time Period:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedDateFilter,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All Time')),
                              DropdownMenuItem(value: 'today', child: Text('Today')),
                              DropdownMenuItem(value: 'week', child: Text('Last 7 Days')),
                              DropdownMenuItem(value: 'month', child: Text('Last 30 Days')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedDateFilter = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Status Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildFilterChip('assigned', 'Active'),
                    const SizedBox(width: 8),
                    _buildFilterChip('shipped', 'Picked'),
                    const SizedBox(width: 8),
                    _buildFilterChip('out_for_delivery', 'Out for'),
                    const SizedBox(width: 8),
                    _buildFilterChip('out_for_pickup', 'Returning'),
                    const SizedBox(width: 8),
                    _buildFilterChip('delivered', 'Delivered'),
                    const SizedBox(width: 8),
                    _buildFilterChip('returned', 'Returned'),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
          ),
        ),

        // Orders List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _myDeliveriesStream, // Use cached stream
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              // Filter by Date Logic
              var docs = snapshot.data?.docs ?? [];
              
              if (_selectedDateFilter != 'all') {
                final now = DateTime.now();
                final todayStart = DateTime(now.year, now.month, now.day);
                
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  // Use createdAt or orderDate
                  final dateVal = data['orderDate'] ?? data['createdAt'];
                  DateTime? orderDate;
                  
                  if (dateVal is Timestamp) orderDate = dateVal.toDate();
                  else if (dateVal is String) orderDate = DateTime.tryParse(dateVal);
                  
                  if (orderDate == null) return false;

                  if (_selectedDateFilter == 'today') {
                    return orderDate.isAfter(todayStart);
                  } else if (_selectedDateFilter == 'week') {
                    return orderDate.isAfter(now.subtract(const Duration(days: 7)));
                  } else if (_selectedDateFilter == 'month') {
                    return orderDate.isAfter(now.subtract(const Duration(days: 30)));
                  }
                  return true;
                }).toList();
              }

              // Sort by date (descending)
              docs.sort((a, b) {
                final dataA = a.data() as Map<String, dynamic>;
                final dataB = b.data() as Map<String, dynamic>;
                
                // Try createdAt first (timestamp), then orderDate
                final dateA = dataA['createdAt'] ?? dataA['orderDate'];
                final dateB = dataB['createdAt'] ?? dataB['orderDate'];
                
                DateTime timeA = DateTime(2000);
                DateTime timeB = DateTime(2000);
                
                if (dateA is Timestamp) timeA = dateA.toDate();
                else if (dateA is String) timeA = DateTime.tryParse(dateA) ?? timeA;

                if (dateB is Timestamp) timeB = dateB.toDate();
                else if (dateB is String) timeB = DateTime.tryParse(dateB) ?? timeB;
                
                return timeB.compareTo(timeA);
              });
              
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.delivery_dining,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No ${_selectedFilter == 'assigned' ? 'active' : _selectedFilter} deliveries',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final order = OrderModel.fromMap(data, doc.id);

                  return _buildOrderCard(order, doc.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReturnsTab(String partnerId) {
    if (_servicePincode == null) {
      return const Center(child: Text('Service Pincode Required'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _returnsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final docs = snapshot.data?.docs ?? [];
        
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.assignment_return_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No Return Requests', style: TextStyle(fontSize: 18, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final order = OrderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            return _buildReturnOrderCard(order, partnerId);
          },
        );
      },
    );
  }

  Widget _buildReturnOrderCard(OrderModel order, String partnerId) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), 
        side: const BorderSide(color: Colors.orange, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(4)),
                  child: const Text('RETURN REQUEST', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
                Text('Order #${order.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.location_on, 'Pickup Address', order.deliveryAddress),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.phone, 'Customer Phone', order.phoneNumber),
             const SizedBox(height: 16),
             
             // Actions
             SizedBox(
               width: double.infinity,
               child: ElevatedButton.icon(
                 onPressed: () => _acceptReturnPickup(order.id, partnerId),
                 icon: const Icon(Icons.local_shipping),
                 label: const Text('Accept Pickup'),
                 style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
               ),
             ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptReturnPickup(String orderId, String partnerId) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': 'out_for_pickup',
        'deliveryPartnerId': partnerId,
        'statusHistory.out_for_pickup': DateTime.now().toIso8601String(),
      });
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pickup Accepted!')));
         setState(() {
           _selectedFilter = 'out_for_pickup'; 
         });
         // Refresh streams if needed
         final auth = Provider.of<AuthProvider>(context, listen: false);
         final id = auth.currentUser?.uid;
         if (id != null) _updateMyDeliveriesStream(id);
      }
    } catch (e) {
      debugPrint('Error accepting pickup: $e');
    }
  }

  Widget _buildFilterChip(String filter, String label) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = filter;
          // Update the stream when filter changes
          final auth = Provider.of<AuthProvider>(context, listen: false);
          final id = auth.currentUser?.uid;
          if (id != null) {
            _updateMyDeliveriesStream(id);
          }
        });
      },
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }

  Stream<QuerySnapshot> _getOrdersStream(String deliveryPartnerId) {
    var query = FirebaseFirestore.instance
        .collection('orders')
        .where('deliveryPartnerId', isEqualTo: deliveryPartnerId);

    // Filter by status
    if (_selectedFilter == 'assigned') {
      // Show orders that are confirmed or packed (ready to pick)
      query = query.where('status', whereIn: ['confirmed', 'packed']);
    } else if (_selectedFilter == 'out_for_pickup') {
      // Show return pickups
      query = query.where('status', isEqualTo: 'out_for_pickup');
    } else {
      query = query.where('status', isEqualTo: _selectedFilter);
    }

    // Remove orderBy to avoid requiring a composite index
    // We'll sort on client side instead
    return query.snapshots();
  }

  Widget _buildOrderCard(OrderModel order, String orderId) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    final hasPermission = user?.hasPermission('can_update_status') ?? false;

    final statusColor = _getStatusColor(order.status);
    final canUpdateStatus = _canUpdateStatus(order.status) && hasPermission;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Order #${orderId.substring(0, orderId.length >= 8 ? 8 : orderId.length)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    order.getStatusText(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Order Details
            _buildDetailRow(
              Icons.calendar_today,
              'Date',
              DateFormat('dd-MM-yyyy HH:mm').format(order.orderDate),
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.shopping_bag,
              'Items',
              '${order.items.length} items',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.currency_rupee,
              'Total',
              '₹${order.totalAmount.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.location_on,
              'Address',
              order.deliveryAddress,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.phone, 'Phone', order.phoneNumber),

            if (canUpdateStatus) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _updateOrderStatus(orderId, order.status),
                      icon: const Icon(Icons.check_circle),
                      label: Text(_getNextActionLabel(order.status)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // QR Code & Payment Section (for out_for_delivery status)
            if (order.status == 'out_for_delivery') ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              
              // Show QR Code Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showQRCode(context),
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Show QR Code to Customer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              
              // Payment Proof Upload
              if (order.paymentProofUrl == null)
                PaymentProofUploadWidget(
                  orderId: orderId,
                  deliveryPartnerId: order.deliveryPartnerId ?? '',
                  onUploadComplete: () {
                    setState(() {}); // Refresh to show updated data
                  },
                )
              else ...[              const SizedBox(height: 12),
                Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment Proof Uploaded',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[900],
                                ),
                              ),
                              if (!order.paymentVerified)
                                Text(
                                  'Awaiting admin verification',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[700],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.image),
                          onPressed: () => _viewPaymentProof(context, order.paymentProofUrl!),
                          tooltip: 'View Screenshot',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],

            // Release Order Button (Only if not yet picked up)
            if (order.status == 'confirmed' || order.status == 'packed') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _releaseOrder(orderId),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Release / Reject Order'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],

            // View Details Button
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _showOrderDetails(order, orderId),
              icon: const Icon(Icons.info_outline),
              label: const Text('View Details'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _releaseOrder(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Release Order?'),
        content: const Text(
          'Are you sure you want to release this order? It will be made available to other delivery partners.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Release'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
            'deliveryPartnerId': null, // Remove assignment
            'status': 'confirmed', // Reset status if needed
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order released successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
      case 'packed':
      case 'return_requested': // Added
        return Colors.orange;
      case 'shipped':
      case 'returned': // Added
        return Colors.blue;
      case 'out_for_delivery':
      case 'out_for_pickup': // Added
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  bool _canUpdateStatus(String currentStatus) {
    return currentStatus == 'confirmed' ||
        currentStatus == 'packed' ||
        currentStatus == 'shipped' ||
        currentStatus == 'out_for_delivery' ||
        currentStatus == 'out_for_pickup'; // Added
  }

  String _getNextActionLabel(String currentStatus) {
    switch (currentStatus) {
      case 'confirmed':
      case 'packed':
        return 'Mark as Picked';
      case 'shipped':
        return 'Start Delivery';
      case 'out_for_delivery':
        return 'Mark Delivered';
      case 'out_for_pickup': // Added
        return 'Mark Returned';
      default:
        return 'Update';
    }
  }

  String _getNextStatus(String currentStatus) {
    switch (currentStatus) {
      case 'confirmed':
      case 'packed':
        return 'shipped';
      case 'shipped':
        return 'out_for_delivery';
      case 'out_for_delivery':
        return 'delivered';
      case 'out_for_pickup': // Added
        return 'returned';
      default:
        return currentStatus;
    }
  }

  Future<void> _updateOrderStatus(String orderId, String currentStatus) async {
    final nextStatus = _getNextStatus(currentStatus);

    // If moving to 'shipped' (picked), 'delivered', or 'returned', require barcode scan first
    if (nextStatus == 'shipped' || nextStatus == 'delivered' || nextStatus == 'returned') {
      final scanResult = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => BarcodeScannerScreen(
            expectedOrderId: orderId,
          ),
        ),
      );

      // If scan was cancelled or failed, don't proceed
      if (scanResult != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order verification cancelled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return; // Exit without updating status
      }
    }

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
            'status': nextStatus,
            'statusHistory.$nextStatus': FieldValue.serverTimestamp(),
            if (nextStatus == 'delivered')
               'actualDelivery': DateTime.now().toIso8601String(),
            if (nextStatus == 'delivered')
               'deliveredAt': FieldValue.serverTimestamp(),
            if (nextStatus == 'delivered')
              'deliveryStatus': 'delivered',
          });

      // Record Transaction for Delivery Fee
      if (nextStatus == 'delivered') {
        final orderDoc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
        final data = orderDoc.data();
        final deliveryFee = (data?['deliveryFee'] as num?)?.toDouble() ?? 0.0;
        final deliveryPartnerId = data?['deliveryPartnerId'];

        if (deliveryFee > 0 && deliveryPartnerId != null) {
          await TransactionService().recordTransaction(
            TransactionModel(
              id: '',
              userId: deliveryPartnerId,
              amount: deliveryFee,
              type: TransactionType.credit,
              description: 'Delivery Fee for Order #${orderId.length >= 8 ? orderId.substring(0, 8) : orderId}',
              status: TransactionStatus.completed,
              referenceId: orderId,
              createdAt: DateTime.now(),
              metadata: {'source': 'delivery_fee'},
            ),
          );
        }
      }

      // Special handling for QR payment verification
      if (nextStatus == 'delivered') {
        final orderDoc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
        if (orderDoc.exists) {
          final data = orderDoc.data();
          if (data != null && data['paymentMethod'] == 'qr_code' && data['paymentProofUrl'] == null) {
            // Revert if payment proof missing for QR code payment
             await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
              'status': 'out_for_delivery',
              'statusHistory.delivered': FieldValue.delete(),
              'actualDelivery': FieldValue.delete(),
              'deliveredAt': FieldValue.delete(),
              'deliveryStatus': FieldValue.delete(),
            });
            throw 'Payment proof required for QR payment before marking delivered';
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Order verified and marked as ${_getStatusLabel(nextStatus)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'shipped':
        return 'Picked';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'out_for_pickup': // Added
        return 'Picking Up Return';
      case 'returned': // Added
        return 'Returned to Seller';
      default:
        return status;
    }
  }

  void _showOrderDetails(OrderModel order, String orderId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (sheetContext, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  bottomSheetContext,
                ).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Order Details',
                      style: Theme.of(bottomSheetContext).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(bottomSheetContext),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Order #${orderId.substring(0, orderId.length >= 8 ? 8 : orderId.length)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Customer Info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Customer Info',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.location_on),
                            title: const Text('Address'),
                            subtitle: Text(order.deliveryAddress),
                            contentPadding: EdgeInsets.zero,
                          ),
                          ListTile(
                            leading: const Icon(Icons.phone),
                            title: const Text('Phone'),
                            subtitle: Text(order.phoneNumber),
                            contentPadding: EdgeInsets.zero,
                            trailing: IconButton(
                              icon: const Icon(Icons.call),
                              onPressed: () {},
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Order Items
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Order Items',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          ...order.items.map(
                            (item) => ListTile(
                              leading: item.imageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        item.imageUrl!,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.shopping_bag),
                                    ),
                              title: Text(item.productName),
                              subtitle: Text('Qty: ${item.quantity}'),
                              trailing: Text(
                                '₹${item.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Amount',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '₹${order.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== OVERVIEW TAB ====================
  Widget _buildOverviewTab(String deliveryPartnerId) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.delivery_dining,
                          size: 30,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${user?.name ?? "Partner"}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Delivery Partner',
                              style: TextStyle(fontSize: 14, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Business Stats
          Text(
            'Business Stats',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Single StreamBuilder for all stats
          StreamBuilder<QuerySnapshot>(
            stream: _statsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Total Deliveries',
                            '0',
                            Icons.local_shipping,
                            Colors.blue,
                            isLoading: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Completed Today',
                            '0',
                            Icons.today,
                            Colors.green,
                            isLoading: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Total Earnings',
                            '₹0',
                            Icons.currency_rupee,
                            Colors.orange,
                            isLoading: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Success Rate',
                            '0%',
                            Icons.trending_up,
                            Colors.purple,
                            isLoading: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              final allOrders = snapshot.data?.docs ?? [];
              final totalCount = allOrders.length;

              // Filter completed orders
              final completedOrders = allOrders.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['deliveryStatus'] == 'delivered';
              }).toList();

              // Calculate today's deliveries
              final today = DateTime.now();
              final todayStart = DateTime(today.year, today.month, today.day);
              int todayCount = 0;
              for (var doc in completedOrders) {
                final data = doc.data() as Map<String, dynamic>;
                final deliveredAt = data['deliveredAt'] as Timestamp?;
                if (deliveredAt != null) {
                  final deliveredDate = deliveredAt.toDate();
                  if (deliveredDate.isAfter(todayStart)) {
                    todayCount++;
                  }
                }
              }

              // Calculate total earnings
              double totalEarnings = 0;
              for (var doc in completedOrders) {
                final data = doc.data() as Map<String, dynamic>;
                final deliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? 0;
                totalEarnings += deliveryFee;
              }

              // Calculate success rate
              final successRate = totalCount > 0
                  ? (completedOrders.length / totalCount * 100)
                  : 0.0;

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Total Deliveries',
                          '$totalCount',
                          Icons.local_shipping,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Completed Today',
                          '$todayCount',
                          Icons.today,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Total Earnings',
                          '₹${totalEarnings.toStringAsFixed(0)}',
                          Icons.currency_rupee,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Success Rate',
                          '${successRate.toStringAsFixed(0)}%',
                          Icons.trending_up,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Quick Actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.orange,
                child: Icon(Icons.account_balance_wallet, color: Colors.white),
              ),
              title: const Text('View Earnings'),
              subtitle: const Text('Track your income and payments'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showEarningsDialog(deliveryPartnerId);
              },
            ),
          ),
          const SizedBox(height: 12),
          
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.purple,
                child: Icon(Icons.bar_chart, color: Colors.white),
              ),
              title: const Text('Performance Stats'),
              subtitle: const Text('View your delivery metrics'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showPerformanceDialog(deliveryPartnerId);
              },
            ),
          ),
          const SizedBox(height: 24),

          // Recent Deliveries
          Text(
            'Recent Deliveries',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          StreamBuilder<QuerySnapshot>(
            stream: _recentActivityStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              final deliveries = snapshot.data?.docs ?? [];

              if (deliveries.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'No recent deliveries',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Card(
                child: Column(
                  children: deliveries.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final orderId = doc.id;
                    final customerName = data['userName'] ?? 'Customer';
                    final status = data['deliveryStatus'] ?? 'assigned';
                    final deliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? 0;

                    Color statusColor;
                    switch (status.toLowerCase()) {
                      case 'delivered':
                        statusColor = Colors.green;
                        break;
                      case 'in_transit':
                        statusColor = Colors.blue;
                        break;
                      case 'picked_up':
                        statusColor = Colors.orange;
                        break;
                      default:
                        statusColor = Colors.grey;
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: statusColor.withOpacity(0.1),
                        child: Icon(Icons.local_shipping, color: statusColor, size: 20),
                      ),
                      title: Text('Order #${orderId.substring(0, 8)}...'),
                      subtitle: Text(customerName),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${deliveryFee.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getStatusLabel(status).toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isLoading = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== PHASE 3: QR CODE & PAYMENT ====================
  Future<void> _showQRCode(BuildContext context) async {
    try {
      // Fetch admin settings for QR code
      final settingsDoc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('general')
          .get();

      if (!settingsDoc.exists || settingsDoc.data()?['upiQRCodeUrl'] == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR Code not configured by admin yet'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final data = settingsDoc.data()!;
      final qrUrl = data['upiQRCodeUrl'];
      final upiId = data['upiId'];

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => QRCodeDisplayDialog(
            qrCodeUrl: qrUrl,
            upiId: upiId,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading QR code: $e')),
        );
      }
    }
  }

  void _viewPaymentProof(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const CircularProgressIndicator(color: Colors.white);
                },
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== PHASE 2: EARNINGS DIALOG ====================
  void _showEarningsDialog(String deliveryPartnerId) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: 800,
          height: 600,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Earnings History',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),

              // Total Earnings Card
              StreamBuilder<QuerySnapshot>(
                stream: _totalEarningsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  double totalEarnings = 0;
                  final deliveries = snapshot.data?.docs ?? [];
                  
                  for (var doc in deliveries) {
                    final data = doc.data() as Map<String, dynamic>;
                    final fee = (data['deliveryFee'] as num?)?.toDouble() ?? 0;
                    totalEarnings += fee;
                  }

                  return Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.currency_rupee,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Earnings',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${totalEarnings.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  'From ${deliveries.length} completed deliveries',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Wallet Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    if (auth.currentUser != null) {
                       Navigator.push(
                         context,
                         MaterialPageRoute(builder: (_) => SellerWalletScreen(user: auth.currentUser!)),
                       );
                    }
                  },
                  icon: const Icon(Icons.account_balance_wallet),
                  label: const Text('Manage Wallet & Withdraw'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Deliveries List
              const Text(
                'Completed Deliveries',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('orders')
                      .where('deliveryPartnerId', isEqualTo: deliveryPartnerId)
                      .where('deliveryStatus', isEqualTo: 'delivered')
                      .orderBy('deliveredAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final deliveries = snapshot.data?.docs ?? [];

                    if (deliveries.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            const Text(
                              'No completed deliveries yet',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: deliveries.length,
                      itemBuilder: (context, index) {
                        final data = deliveries[index].data() as Map<String, dynamic>;
                        final orderId = deliveries[index].id;
                        final deliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? 0;
                        final customerName = data['userName'] ?? 'Customer';
                        final deliveredAt = (data['deliveredAt'] as Timestamp?)?.toDate();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade100,
                              child: const Icon(Icons.check, color: Colors.green),
                            ),
                            title: Text('Order #${orderId.substring(0, 8)}...'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(customerName),
                                if (deliveredAt != null)
                                  Text(
                                    'Delivered: ${DateFormat('MMM d, yyyy - h:mm a').format(deliveredAt)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Text(
                              '₹${deliveryFee.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
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
          ),
        ),
      ),
    );
  }

  // ==================== PHASE 3: PERFORMANCE DIALOG ====================
  void _showPerformanceDialog(String deliveryPartnerId) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: 700,
          height: 600,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Performance Stats',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('orders')
                      .where('deliveryPartnerId', isEqualTo: deliveryPartnerId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allOrders = snapshot.data?.docs ?? [];
                    final completedOrders = allOrders.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['deliveryStatus'] == 'delivered';
                    }).toList();

                    // Calculate metrics
                    final totalDeliveries = allOrders.length;
                    final successfulDeliveries = completedOrders.length;
                    final successRate = totalDeliveries > 0
                        ? (successfulDeliveries / totalDeliveries * 100)
                        : 0.0;

                    // Today's deliveries
                    final today = DateTime.now();
                    final todayStart = DateTime(today.year, today.month, today.day);
                    final todayDeliveries = completedOrders.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final deliveredAt = (data['deliveredAt'] as Timestamp?)?.toDate();
                      return deliveredAt != null && deliveredAt.isAfter(todayStart);
                    }).length;

                    // This month's deliveries
                    final monthStart = DateTime(today.year, today.month, 1);
                    final monthDeliveries = completedOrders.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final deliveredAt = (data['deliveredAt'] as Timestamp?)?.toDate();
                      return deliveredAt != null && deliveredAt.isAfter(monthStart);
                    }).length;

                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          // Success Rate Card
                          Card(
                            color: Colors.purple.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.purple,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.trending_up,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Success Rate',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${successRate.toStringAsFixed(1)}%',
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple,
                                          ),
                                        ),
                                        Text(
                                          '$successfulDeliveries of $totalDeliveries completed',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black54,
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

                          // Performance Grid
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.85,
                            children: [
                              // Today's Performance
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.today,
                                              color: Colors.blue.shade700,
                                              size: 24,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      const Text(
                                        'Today',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$todayDeliveries',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Text(
                                        'deliveries',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // This Month
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.calendar_month,
                                              color: Colors.green.shade700,
                                              size: 24,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      const Text(
                                        'This Month',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$monthDeliveries',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Text(
                                        'deliveries',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Total Completed
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.check_circle,
                                              color: Colors.orange.shade700,
                                              size: 24,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      const Text(
                                        'Completed',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$successfulDeliveries',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Text(
                                        'total',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Active Deliveries
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.local_shipping,
                                              color: Colors.red.shade700,
                                              size: 24,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      const Text(
                                        'Active',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${totalDeliveries - successfulDeliveries}',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Text(
                                        'in progress',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
