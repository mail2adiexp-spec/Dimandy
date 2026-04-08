import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'order_tracking_screen.dart';
import '../models/order_model.dart';
import '../models/app_settings_model.dart';
import '../widgets/qr_code_display_dialog.dart';
import '../widgets/payment_proof_upload_widget.dart';
import '../widgets/barcode_scanner_screen.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/transaction_service.dart';
import '../models/transaction_model.dart';
import 'seller_wallet_screen.dart';
import 'delivery_partner_earnings_screen.dart';

class DeliveryPartnerDashboardScreen extends StatefulWidget {
  static const routeName = '/delivery-dashboard';
  const DeliveryPartnerDashboardScreen({super.key});

  @override
  State<DeliveryPartnerDashboardScreen> createState() =>
      _DeliveryPartnerDashboardScreenState();
}

class _DeliveryPartnerDashboardScreenState
    extends State<DeliveryPartnerDashboardScreen> with TickerProviderStateMixin {
  String _selectedFilter = 'assigned'; // assigned, in_progress, completed
  String _selectedDateFilter = 'all'; // all, today, week, month
  String? _servicePincode;
  bool _isLoadingPincode = true;
  late AnimationController _refreshController;
  late TabController _tabController;
  bool _isInitialized = false;

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
    print('DEBUG: DeliveryPartnerDashboardScreen initState()');
    _refreshController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    print('DEBUG: DeliveryPartnerDashboardScreen dispose()');
    _refreshController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context);
    final deliveryPartnerId = auth.currentUser?.uid;
    print('DEBUG: didChangeDependencies() - partnerId: $deliveryPartnerId, _isInitialized: $_isInitialized');

    if (deliveryPartnerId != null && !_isInitialized) {
      _isInitialized = true;
      print('DEBUG: Initializing dashboard for partner: $deliveryPartnerId');
      _fetchServicePincode();

      // Initialize cached streams
      print('DEBUG: Initializing other cached streams...');
      _myDeliveriesStream = FirebaseFirestore.instance
          .collection('orders')
          .where('deliveryPartnerId', isEqualTo: deliveryPartnerId)
          .snapshots();

      _statsStream = FirebaseFirestore.instance
          .collection('orders')
          .where('deliveryPartnerId', isEqualTo: deliveryPartnerId)
          .snapshots();

      _recentActivityStream = FirebaseFirestore.instance
          .collection('orders')
          .where('deliveryPartnerId', isEqualTo: deliveryPartnerId)
          // Removed orderBy to avoid requiring a composite index for new accounts
          .limit(50) 
          .snapshots();

      _totalEarningsStream = FirebaseFirestore.instance
          .collection('orders')
          .where('deliveryPartnerId', isEqualTo: deliveryPartnerId)
          .where('deliveryStatus', isEqualTo: 'delivered')
          .snapshots();

      _returnsStream = FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'return_requested')
          .snapshots();

      // Final fallback to ensure Available Stream is triggered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (_availableOrdersStream == null || !_isInitialized)) {
          print('DEBUG: addPostFrameCallback - re-triggering initialization');
          _fetchServicePincode();
        }
      });
    }
  }

  void _updateMyDeliveriesStream(String partnerId) {
    if (!mounted) return;
    print('DEBUG: _updateMyDeliveriesStream called for partner: $partnerId');
    setState(() {
      _myDeliveriesStream = _getOrdersStream(partnerId);
    });
  }

  void _updateAvailableOrdersStream() {
    if (_servicePincode == null || _servicePincode!.isEmpty) {
      print('DEBUG: _updateAvailableOrdersStream aborted - pincode is null/empty');
      return;
    }

    print('DEBUG: Setting up _availableOrdersStream for pincode: $_servicePincode');
    
    // Try querying as both String and Int to be safe
    final pincodeStr = _servicePincode!;
    final int? pincodeInt = int.tryParse(pincodeStr);

    if (pincodeInt != null && pincodeInt != 0) {
      _availableOrdersStream = FirebaseFirestore.instance
          .collection('orders')
          .where('deliveryPincode', whereIn: [pincodeStr, pincodeInt])
          .snapshots();
    } else {
      _availableOrdersStream = FirebaseFirestore.instance
          .collection('orders')
          .where('deliveryPincode', isEqualTo: pincodeStr)
          .snapshots();
    }
  }

  Future<void> _fetchServicePincode() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.uid;
    print('DEBUG: _fetchServicePincode starting for userId: $userId');
    if (userId == null) {
      if (mounted) setState(() => _isLoadingPincode = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 10));

      print('DEBUG: User doc exists: ${doc.exists}');
      if (mounted) {
        setState(() {
          final rawPincode = doc.data()?['service_pincode'];
          print('DEBUG: Raw pincode from doc: $rawPincode (type: ${rawPincode.runtimeType})');
          _servicePincode = rawPincode?.toString();
          print('DEBUG: _servicePincode set to: $_servicePincode');
          _isLoadingPincode = false;
          _updateAvailableOrdersStream();
        });
      }
    } catch (e) {
      print('DEBUG: Error in _fetchServicePincode: $e');
      if (mounted) {
        setState(() => _isLoadingPincode = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: DeliveryPartnerDashboardScreen build() called');
    final auth = Provider.of<AuthProvider>(context);
    final deliveryPartnerId = auth.currentUser?.uid;
    print('DEBUG: partnerId: $deliveryPartnerId, _servicePincode: $_servicePincode, _isLoadingPincode: $_isLoadingPincode');
    print('DEBUG: _availableOrdersStream is null: ${_availableOrdersStream == null}');

    if (deliveryPartnerId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery Dashboard')),
        body: const Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Partner Dashboard'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(
              text: 'Available',
              icon: _NotificationBadge(stream: _availableOrdersStream),
            ),
            const Tab(text: 'My Deliveries', icon: Icon(Icons.local_shipping)),
            const Tab(text: 'Returns', icon: Icon(Icons.assignment_return)),
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
                  const SnackBar(
                      content: Text('Refreshing data...'),
                      duration: Duration(seconds: 1)),
                );
                _fetchServicePincode();
                if (deliveryPartnerId != null) {
                   _updateMyDeliveriesStream(deliveryPartnerId);
                }
                await Future.delayed(const Duration(seconds: 1));
                if (mounted) {
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
        controller: _tabController,
        children: [
          _buildOverviewTab(deliveryPartnerId),
          _buildAvailableOrdersTab(deliveryPartnerId),
          _buildMyDeliveriesTab(deliveryPartnerId),
          _buildReturnsTab(deliveryPartnerId),
        ],
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
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Colors.blue.withOpacity(0.1),
          child: Text(
            'Showing orders in Pincode: ${_servicePincode ?? "All"}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: _availableOrdersStream == null 
          ? const Center(child: Text('Service area not properly set or loading...'))
          : StreamBuilder<QuerySnapshot>(
            stream: _availableOrdersStream,
            builder: (context, snapshot) {
              print('DEBUG: AvailableOrders StreamBuilder state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}');
              
              if (snapshot.hasError) {
                print('DEBUG: AvailableOrders ERROR: ${snapshot.error}');
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('Error loading orders: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() => _updateAvailableOrdersStream()),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // If waiting but we have no data yet
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                // Auto-retry if stuck for 3 seconds
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted && _availableOrdersStream != null && snapshot.connectionState == ConnectionState.waiting) {
                    print('DEBUG: Auto-retry triggered for stalled stream');
                    setState(() => _updateAvailableOrdersStream());
                  }
                });

                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      Text('Searching for orders in $_servicePincode...', 
                        style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                           print('DEBUG: Manual stream reset triggered');
                           setState(() => _updateAvailableOrdersStream());
                        },
                        child: const Text('Tap to refresh manually'),
                      ),
                    ],
                  ),
                );
              }

              // Even if it's not "waiting", we might have no data if stream finished (rare)
              if (!snapshot.hasData) {
                return const Center(child: Text('Connecting to server...'));
              }

              final allDocs = snapshot.data?.docs ?? [];
              print('DEBUG: AvailableOrders - Total docs from Firestore: ${allDocs.length}');
              
              final docs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] as String?;
                final deliveryPartnerId = data['deliveryPartnerId'];
                
                final isUnassigned = deliveryPartnerId == null || deliveryPartnerId == '' || deliveryPartnerId == 'null';
                final isValidStatus = status == 'packed';
                
                final match = isUnassigned && isValidStatus;
                
                if (!match) {
                  print('DEBUG: Order ${doc.id} FILTERED OUT - status: $status, partnerId: $deliveryPartnerId, isUnassigned: $isUnassigned, isValidStatus: $isValidStatus');
                } else {
                  print('DEBUG: Order ${doc.id} MATCHED - status: $status');
                }
                
                return match;
              }).toList();
              
              print('DEBUG: AvailableOrders - Filtered docs: ${docs.length}');
              
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
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
        side: BorderSide(color: Colors.blue.withValues(alpha: 0.5), width: 1),
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
                  '₹${(order.totalAmount + order.deliveryFee).toStringAsFixed(0)}',
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
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptOrder(order.id, partnerId),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text(
                      'ACCEPT',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Reject Order'),
                          content: const Text('Are you sure you want to reject this order?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, 'cancel'),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context, 'reject');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Request dismissed')),
                                );
                              },
                              child: const Text('Reject', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('REJECT'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Extra bottom padding
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
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
        final orderDoc = await transaction.get(orderRef);

        if (!orderDoc.exists) {
          throw Exception("Order does not exist!");
        }

        final data = orderDoc.data() as Map<String, dynamic>;
        
        // Safety check: Ensure it's not already taken
        if (data['deliveryPartnerId'] != null && data['deliveryPartnerId'] != '') {
          throw Exception("Return pickup already taken by another partner!");
        }

        transaction.update(orderRef, {
          'status': 'out_for_pickup',
          'deliveryPartnerId': partnerId,
          'statusHistory.out_for_pickup': DateTime.now().toIso8601String(),
        });
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
                    color: statusColor.withValues(alpha: 0.2),
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
              '₹${(order.totalAmount + order.deliveryFee).toStringAsFixed(2)}',
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
                          _updateOrderStatus(order, orderId, order.status),
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

            // QR Code Section (for out_for_delivery status)
            if (order.status == 'out_for_delivery') ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Request payment from customer:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              // Show QR Code Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showQRCode(context),
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Show Store QR Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Confirm payment type during "Mark Delivered" step.', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label: ',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
        ),
        if (label.toLowerCase().contains('phone') && value.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.call, size: 20, color: Colors.blue),
            onPressed: () => _makePhoneCall(value),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        throw 'Could not launch $launchUri';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error calling: $e')),
        );
      }
    }
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
      case 'out_for_pickup':
        return 'returned';
      default:
        return currentStatus;
    }
  }

  Future<void> _updateOrderStatus(OrderModel order, String orderId, String currentStatus) async {
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

    if (nextStatus == 'delivered') {
      // 1. Fetch Store QR Code
      String? qrCodeUrl;
      String? upiId;
      final orderDoc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
      final latestData = orderDoc.data();
      final latestPaymentMethod = (latestData?['paymentMethod'] ?? order.paymentMethod)?.toString().toUpperCase() ?? 'COD';

      if (latestPaymentMethod.contains('QR') || latestPaymentMethod.contains('COD') || latestPaymentMethod == 'CASH_ON_DELIVERY') {
        try {
          final settingsDoc = await FirebaseFirestore.instance.collection('app_settings').doc('general').get();
          if (settingsDoc.exists) {
            qrCodeUrl = settingsDoc.data()?['upiQRCodeUrl'];
            upiId = settingsDoc.data()?['upiId'];
          }
        } catch (e) {
          debugPrint('Error fetching QR code: $e');
        }
      }

      // 2. Show Confirmation Dialog
      if (mounted) {
        String? selectedMode;
        final paymentSelection = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) {
              bool isPrepaid = latestPaymentMethod == 'ONLINE' || latestPaymentMethod == 'PREPAID';

              return AlertDialog(
                title: const Text('Payment Confirmation'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       const Text('Verify if you have received the payment from customer.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                       const SizedBox(height: 16),
                      Text('Amount to Collect: ₹${(order.totalAmount + order.deliveryFee).toStringAsFixed(2)}', 
                           style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 12),
                      const Divider(),
                      
                      if (isPrepaid) ...[
                         const SizedBox(height: 8),
                         const Center(
                           child: Column(
                             children: [
                               Icon(Icons.check_circle, color: Colors.green, size: 48),
                               SizedBox(height: 8),
                               Text('PREPAID ORDER', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                               Text('No cash to collect from customer.', style: TextStyle(color: Colors.grey)),
                             ],
                           ),
                         ),
                      ] else if (selectedMode == null) ...[
                         const SizedBox(height: 8),
                         const Text('Select Payment Mode:', style: TextStyle(fontWeight: FontWeight.bold)),
                         const SizedBox(height: 16),
                         Row(
                           children: [
                             Expanded(
                               child: ElevatedButton.icon(
                                 onPressed: () => setState(() => selectedMode = 'cash'),
                                 icon: const Icon(Icons.money),
                                 style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                                 label: const Text('Cash'),
                               ),
                             ),
                             const SizedBox(width: 12),
                             Expanded(
                               child: ElevatedButton.icon(
                                 onPressed: () => setState(() => selectedMode = 'qr'),
                                 icon: const Icon(Icons.qr_code),
                                 style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                                 label: const Text('QR Code'),
                               ),
                             ),
                           ],
                         ),
                      ] else if (selectedMode == 'cash') ...[
                         const SizedBox(height: 8),
                         const Center(
                           child: Column(
                             children: [
                               Icon(Icons.money, color: Colors.blue, size: 48),
                               SizedBox(height: 8),
                               Text('CASH COLLECTION', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
                               Text('Collect exactly the amount shown above.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                             ],
                           ),
                         ),
                      ] else if (selectedMode == 'qr') ...[
                         const SizedBox(height: 8),
                         const Text('Ask customer to scan QR code:', style: TextStyle(fontWeight: FontWeight.bold)),
                         if (qrCodeUrl != null) ...[
                            const SizedBox(height: 12),
                            Center(
                              child: Column(
                                children: [
                                  Image.network(
                                    qrCodeUrl,
                                    height: 180,
                                    width: 180,
                                    fit: BoxFit.contain,
                                    errorBuilder: (ctx, _, __) => const Icon(Icons.broken_image, size: 50),
                                  ),
                                  if (upiId != null) ...[
                                    const SizedBox(height: 4),
                                    Text('UPI ID: $upiId', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                                  ],
                                ],
                              ),
                            ),
                         ] else ...[
                            const SizedBox(height: 12),
                            const Center(child: Text('QR Code not configured by Store.', style: TextStyle(color: Colors.red))),
                         ]
                      ],
                    ],
                  ),
                ),
                actions: [
                  if (!isPrepaid && selectedMode != null)
                    TextButton(
                      onPressed: () => setState(() => selectedMode = null),
                      child: const Text('Back'),
                    )
                  else
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'cancel'),
                      child: const Text('Cancel'),
                    ),
                  
                  if (isPrepaid) 
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, 'delivered'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      child: const Text('Confirm Delivery'),
                    )
                  else if (selectedMode == 'cash')
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, 'delivered_cash'),
                       icon: const Icon(Icons.check_circle),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                      label: const Text('Verify Cash & Done'),
                    )
                  else if (selectedMode == 'qr')
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, 'delivered_qr'),
                      icon: const Icon(Icons.check_circle),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                      label: const Text('Verify QR & Done'),
                    ),
                ],
              );
            },
          ),
        );

        if (paymentSelection == null || paymentSelection == 'cancel') return;

        try {
          final Map<String, dynamic> updateData = {
            'status': 'delivered',
            'deliveryStatus': 'delivered',
            'statusHistory.delivered': FieldValue.serverTimestamp(),
            'deliveredAt': FieldValue.serverTimestamp(),
            'actualDelivery': DateTime.now().toIso8601String(),
          };

          if (paymentSelection == 'delivered_qr') {
            updateData['qrAtDoorstep'] = true;
            updateData['paymentVerified'] = true;
          } else if (paymentSelection == 'delivered_cash') {
            updateData['qrAtDoorstep'] = false;
            updateData['paymentVerified'] = true;
          } else {
             updateData['paymentVerified'] = true;
          }

          await FirebaseFirestore.instance.collection('orders').doc(orderId).update(updateData);
          
          // Record transaction for delivery partner earnings
          try {
            final payout = (latestData?['partnerPayout'] as num?)?.toDouble() ?? (latestData?['deliveryFee'] as num?)?.toDouble() ?? 0.0;
            final partnerId = latestData?['deliveryPartnerId'] as String?;
            
            if (payout > 0 && partnerId != null) {
              await TransactionService().recordTransaction(
                TransactionModel(
                  id: '', // Firestore will generate
                  userId: partnerId,
                  amount: payout,
                  type: TransactionType.credit,
                  description: 'Delivery Partner Fee: #${orderId.substring(0, 8)}',
                  status: TransactionStatus.completed,
                  referenceId: orderId,
                  metadata: {
                    'orderId': orderId,
                    'type': 'delivery_earning',
                    'sellerId': partnerId, // Standard for revenue tracking
                  },
                  createdAt: DateTime.now(),
                ),
              );
              debugPrint('Transaction recorded for partner: $partnerId, amount: $payout');
            }
          } catch (te) {
            debugPrint('Error recording earning transaction: $te');
          }

          // Record transactions for each seller in the order (Product Earnings)
          try {
            final Map<String, double> sellerEarnings = {};
            for (var item in order.items) {
              if (item.sellerId.isEmpty) continue;
              
              // Profit = (Price - BasePrice) * Quantity
              final profit = (item.price - item.basePrice) * item.quantity;
              // Commission %: Use item's custom percentage or default 0%
              final commissionPercent = item.adminProfitPercentage ?? 0.0;
              final adminShare = profit * (commissionPercent / 100);
              
              // Seller gets: (BasePrice * Quantity) + (Profit - AdminShare)
              final sellerShare = (item.basePrice * item.quantity) + (profit - adminShare);
              
              sellerEarnings[item.sellerId] = (sellerEarnings[item.sellerId] ?? 0.0) + sellerShare;
              debugPrint('Calculating earning for seller ${item.sellerId}: Price=${item.price}, Base=${item.basePrice}, Profit=$profit, Comm%=$commissionPercent, SellerShare=$sellerShare');
            }

            final txService = TransactionService();
            for (var entry in sellerEarnings.entries) {
              final sellerId = entry.key;
              final amount = entry.value;
              if (amount > 0) {
                await txService.recordTransaction(
                  TransactionModel(
                    id: '',
                    userId: sellerId,
                    amount: amount,
                    type: TransactionType.credit,
                    description: 'Sales Earning: Order #${orderId.substring(0, 8)}',
                    status: TransactionStatus.completed,
                    referenceId: orderId,
                    metadata: {
                      'orderId': orderId,
                      'type': 'product_earning',
                      'sellerId': sellerId,
                    },
                    createdAt: DateTime.now(),
                  ),
                );
                debugPrint('Recorded earning of ₹${amount.toStringAsFixed(2)} for seller: $sellerId');
              }
            }
          } catch (se) {
            debugPrint('Error recording seller earnings: $se');
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Order delivered successfully!')),
            );
            setState(() {});
          }
          return; 
        } catch (e) {
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating order: $e')));
           return;
        }
      }
    }

    // Default status update for other transitions (shipped, out_for_delivery, etc.)
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': nextStatus,
        'deliveryStatus': nextStatus,
        'statusHistory.$nextStatus': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to ${_getStatusLabel(nextStatus)}')),
        );
        setState(() {});
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderTrackingScreen(
          order: order,
          isAdminOrPartner: true,
        ),
      ),
    );
  }

  // ==================== OVERVIEW TAB ====================
  Widget _buildOverviewTab(String deliveryPartnerId) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Extra bottom padding
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

          // Stats Filter Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDateFilterChip('Today', 'today'),
                const SizedBox(width: 8),
                _buildDateFilterChip('Yesterday', 'yesterday'),
                const SizedBox(width: 8),
                _buildDateFilterChip('7 Days', 'week'),
                const SizedBox(width: 8),
                _buildDateFilterChip('All Time', 'all'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Business Stats
          Text(
            'Business Performance',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Single StreamBuilder for all stats
          StreamBuilder<QuerySnapshot>(
            stream: _statsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allOrders = snapshot.data?.docs ?? [];
              final now = DateTime.now();
              final todayStart = DateTime(now.year, now.month, now.day);
              
              DateTime? filterDate;
              if (_selectedDateFilter == 'today') {
                filterDate = todayStart;
              } else if (_selectedDateFilter == 'yesterday') {
                filterDate = todayStart.subtract(const Duration(days: 1));
              } else if (_selectedDateFilter == 'week') {
                filterDate = todayStart.subtract(const Duration(days: 7));
              }

              // Filter orders based on the selected period
              final filteredOrders = allOrders.where((doc) {
                if (_selectedDateFilter == 'all') return true;
                
                final data = doc.data() as Map<String, dynamic>;
                final date = (data['deliveredAt'] as Timestamp? ?? data['createdAt'] as Timestamp?)?.toDate();
                if (date == null) return false;

                if (_selectedDateFilter == 'yesterday') {
                  final yesterdayEnd = todayStart;
                  final yesterdayStart = todayStart.subtract(const Duration(days: 1));
                  return date.isAfter(yesterdayStart) && date.isBefore(yesterdayEnd);
                }

                return date.isAfter(filterDate!);
              }).toList();

              final totalCount = filteredOrders.length;
              final completedOrders = filteredOrders.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['deliveryStatus'] == 'delivered';
              }).toList();

              int todayCount = 0;
              double cashToDeposit = 0;
              double qrCollections = 0;
              double prePaidOnline = 0;
              double totalEarnings = 0;

              for (var doc in completedOrders) {
                final data = doc.data() as Map<String, dynamic>;
                final deliveredAt = data['deliveredAt'] as Timestamp?;
                final method = data['paymentMethod']?.toString().toUpperCase() ?? 'COD'; 
                final subtotal = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
                final fee = (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;
                final amount = subtotal + fee; // Full collection amount

                final pointOfSaleQR = data['paymentProofUrl'] != null || data['qrAtDoorstep'] == true;

                if (deliveredAt != null) {
                  final deliveredDate = deliveredAt.toDate();
                  if (deliveredDate.isAfter(todayStart)) {
                    todayCount++;
                  }
                }

                if (method == 'ONLINE' || method == 'PREPAID') {
                  prePaidOnline += amount;
                } else if (pointOfSaleQR) {
                  qrCollections += amount;
                } else {
                  cashToDeposit += amount;
                }
                
                totalEarnings += (data['partnerPayout'] as num?)?.toDouble() ?? fee;
              }

              final successRate = totalCount > 0 
                ? (completedOrders.length / totalCount * 100).toStringAsFixed(1) 
                : '0';

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Filtered Orders',
                          '$totalCount',
                          Icons.local_shipping,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Delivered',
                          '${completedOrders.length}',
                          Icons.check_circle,
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
                          '$successRate%',
                          Icons.trending_up,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Financial Summary Section
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Financial Breakdown',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                         _selectedDateFilter.toUpperCase(),
                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Cash To Deposit',
                          '₹${cashToDeposit.toStringAsFixed(0)}',
                          Icons.money_off,
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'QR Collection',
                          '₹${qrCollections.toStringAsFixed(0)}',
                          Icons.qr_code,
                          Colors.teal,
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
                          'Pre-paid Online',
                          '₹${prePaidOnline.toStringAsFixed(0)}',
                          Icons.account_balance,
                          Colors.indigo,
                        ),
                      ),
                      const Expanded(child: SizedBox()), // Placeholder for alignment
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeliveryPartnerEarningsScreen(deliveryPartnerId: deliveryPartnerId),
                  ),
                );
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
              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 12))),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              // Robust date parsing for sorting
              DateTime _parseAnyDate(dynamic v) {
                if (v == null) return DateTime(2000);
                if (v is Timestamp) return v.toDate();
                if (v is DateTime) return v;
                if (v is String) return DateTime.tryParse(v) ?? DateTime(2000);
                return DateTime(2000);
              }

              // Sort on client side to avoid index requirements
              final rawDocs = snapshot.data?.docs ?? [];
              final deliveries = List<QueryDocumentSnapshot>.from(rawDocs);
              deliveries.sort((a, b) {
                final dataA = a.data() as Map<String, dynamic>;
                final dataB = b.data() as Map<String, dynamic>;
                final dateA = _parseAnyDate(dataA['orderDate']);
                final dateB = _parseAnyDate(dataB['orderDate']);
                return dateB.compareTo(dateA);
              });

              // Just take first 5
              final recentDeliveries = deliveries.take(5).toList();

              if (recentDeliveries.isEmpty) {
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
                  children: recentDeliveries.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final orderId = doc.id;
                    final customerName = data['userName'] ?? 'Customer';
                    final status = data['deliveryStatus'] ?? 'assigned';
                    final payout = (data['partnerPayout'] as num?)?.toDouble() ?? (data['deliveryFee'] as num?)?.toDouble() ?? 0;

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
                        backgroundColor: statusColor.withValues(alpha: 0.1),
                        child: Icon(Icons.local_shipping, color: statusColor, size: 20),
                      ),
                      title: Text('Order #${orderId.substring(0, 8)}...'),
                      subtitle: Text(customerName),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${payout.toStringAsFixed(0)}',
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
                              color: statusColor.withValues(alpha: 0.1),
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
                    color: color.withValues(alpha: 0.1),
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

  // ==================== PHASE 2: EARNINGS DIALOG   // Earnings screen logic moved to DeliveryPartnerEarningsScreen

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
  Widget _buildDateFilterChip(String label, String value) {
    final isSelected = _selectedDateFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _selectedDateFilter = value;
          });
        }
      },
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class _NotificationBadge extends StatelessWidget {
  final Stream<QuerySnapshot>? stream;
  const _NotificationBadge({this.stream});

  @override
  Widget build(BuildContext context) {
    // Reduced logging to prevent terminal flooding
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('DEBUG: _NotificationBadge error: ${snapshot.error}');
        }
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] as String?;
            final partnerId = data['deliveryPartnerId'];
            final isUnassigned = partnerId == null || partnerId == '' || partnerId == 'null';
            final isValidStatus = status == 'packed';
            return isUnassigned && isValidStatus;
          }).length;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_active),
            if (count > 0)
              Positioned(
                right: -8,
                top: -8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
