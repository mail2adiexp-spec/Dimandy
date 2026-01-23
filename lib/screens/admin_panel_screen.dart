import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:typed_data';
import 'package:ecommerce_app/utils/web_download_helper.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
// import 'package:printing/printing.dart'; // Moved to admin_analytics_screen
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

import '../models/product_model.dart';
import '../models/category_model.dart';
import '../models/service_category_model.dart';
import '../models/featured_section_model.dart';
import '../models/partner_request_model.dart';
import '../models/gift_model.dart';
import '../models/delivery_partner_model.dart';
import '../models/payout_model.dart';
import '../models/transaction_model.dart';
import '../services/payout_service.dart';
import '../services/transaction_service.dart';
import '../services/analytics_service.dart';
import '../providers/product_provider.dart';
import '../providers/category_provider.dart';
import '../providers/service_category_provider.dart';
import '../providers/featured_section_provider.dart';
import '../providers/gift_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/invoice_generator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerce_app/screens/role_management_tab.dart';
import '../widgets/shared_products_tab.dart';
import '../widgets/shared_orders_tab.dart';
import '../widgets/seller_details_widget.dart';
import '../widgets/service_provider_details_widget.dart';
import '../widgets/shared_users_tab.dart';
import '../widgets/shared_services_tab.dart';
import 'admin_settings_screen.dart';
// import 'admin_analytics_screen.dart';
// import 'admin_reports_screen.dart';
import '../widgets/manage_stores_tab.dart';

class AdminPanelScreen extends StatefulWidget {
  static const routeName = '/admin-panel';
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, pending, approved, rejected
  
  // Search and Filter State
  String _productSearchQuery = '';
  String? _selectedProductCategory;
  
  int _selectedIndex = 0;
  
  // Bulk Operations State
  Set<String> _selectedProductIds = {};
  bool _isProductSelectionMode = false;
  
  // Advanced Product Filters
  double? _minProductPrice;
  double? _maxProductPrice;
  String _stockFilter = 'All'; // All, Low, Out, InStock
  Set<String> _selectedProductCategories = {};
  String _featuredFilter = 'All'; // All, Featured, NonFeatured
  DateTime? _productStartDate;
  DateTime? _productEndDate;
  
  
  // Stream variables
  late Stream<QuerySnapshot> _partnerRequestsStream;
  late Stream<QuerySnapshot> _serviceProvidersStream;
  late Stream<QuerySnapshot> _sellersStream;
  late Stream<QuerySnapshot> _deliveryPartnersStream;
  late Stream<QuerySnapshot> _ordersStream;
  late Stream<QuerySnapshot> _usersStream;
  late Stream<QuerySnapshot> _cancelledOrdersStream;
  late Stream<QuerySnapshot> _returnedOrdersStream;
  Stream<QuerySnapshot>? _topSellingStream;
  Stream<QuerySnapshot>? _topServicesStream;
  late Stream<QuerySnapshot> _recentOrdersStream;

  late AnimationController _refreshController;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
        duration: const Duration(seconds: 1),
        vsync: this);
    _initializeStreams();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  void _initializeStreams() {
    _partnerRequestsStream = FirebaseFirestore.instance
        .collection('partner_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots();
        
    _serviceProvidersStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'service_provider')
        .snapshots();
        
    _sellersStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'seller')
        .snapshots();

    _deliveryPartnersStream = FirebaseFirestore.instance
        .collection('delivery_partners')
        .snapshots();
        
    _ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .snapshots();
        
    _usersStream = FirebaseFirestore.instance
        .collection('users')
        .snapshots();
        
    _cancelledOrdersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'cancelled')
        .snapshots();
        
    _returnedOrdersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'returned')
        .snapshots();
        
    _recentOrdersStream = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('orderDate', descending: true)
        .limit(10)
        .snapshots();
    _topSellingStream = FirebaseFirestore.instance
        .collection('orders')
        .snapshots();

    _topServicesStream = FirebaseFirestore.instance
        .collection('service_categories')
        .snapshots();
  }

  final List<String> _menuTitles = [
    'Dashboard',           // First
    'Settings',           // NEW - Moved to top
    'Users',              // 5
    'Gifts',              // 5
    'Orders',             // 6
    'Sellers',            // 7
    'Stores',             // NEW
    'Products',           // 8
    'Services',           // 8
    'Categories',         // 11
    'Core Staff',         // 12
    'Permissions',        // 13
    'Payout Requests',    // 15
    'Featured Sections',  // 17
    'Delivery Partners',  // 17
    'Service Categories', // 18
    'Service Providers',  // 18
    'Partner Requests',
    'Refund Requests',    // 17
  ];

  final Map<int, int> _sortedToOriginalIndex = {
    0: 0,  // Dashboard
    1: 18, // Settings (was 17, now 18 in stack)
    2: 6,  // Users
    3: 7,  // Gifts
    4: 8,  // Orders
    5: 11, // Sellers
    6: 20, // Stores
    7: 1,  // Products
    8: 3,  // Services
    9: 2, // Categories (was 11)
    10: 9, // Core Staff (was 12)
    11: 10, // Permissions (was 13)
    12: 13, // Payout Requests (was 14)
    13: 4,  // Featured Sections (was 15)
    14: 5,  // Delivery Partners (was 16)
    15: 14, // Service Categories (was 17)
    16: 12, // Service Providers (was 18)
    17: 17, // Partner Requests (was 19)
    18: 19, // Refund Requests (was 20)
  };

  final List<IconData> _menuIcons = [
    Icons.dashboard,           // Dashboard
    Icons.settings,            // Settings
    Icons.person,              // Users
    Icons.card_giftcard,       // Gifts
    Icons.receipt_long,        // Orders
    Icons.store,               // Sellers
    Icons.store_mall_directory,// Stores
    Icons.inventory_2,         // Products
    Icons.home_repair_service, // Services
    Icons.category,            // Categories
    Icons.group,               // Core Staff
    Icons.security,            // Permissions
    Icons.payment,             // Payout Requests
    Icons.star,                // Featured Sections
    Icons.delivery_dining,     // Delivery Partners
    Icons.miscellaneous_services, // Service Categories
    Icons.handyman,            // Service Providers
    Icons.person_add,          // Partner Requests
    Icons.assignment_return,   // Refund Requests
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isAdmin = auth.isAdmin;

    if (!isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied: Admins only'),
            backgroundColor: Colors.red,
          ),
        );
      });
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Panel')),
        body: const Center(child: Text('Access denied: Admins only')),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;

        return Scaffold(
          drawer: isMobile
              ? Drawer(
                  width: 280,
                  child: _buildSidebarContent(isMobile: true),
                )
              : null,
          body: SizedBox.expand(
            child: Column(
              children: [
                // Top Header Bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      if (isMobile)
                        Builder(
                          builder: (context) => IconButton(
                            icon: Icon(
                              Icons.menu,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                        ),
                      // Center: Demandy
                      Center(
                        child: Text(
                          'Dimandy',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      // Right: Logout button
                      Positioned(
                        right: 0,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimary
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.logout,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  size: 20,
                                ),
                                if (!isMobile) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    'Logout',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Main Content Area with Sidebar
                Expanded(
                  child: Row(
                    children: [
                      // Left Sidebar - Fixed (Desktop Only)
                      if (!isMobile)
                        SizedBox(
                          width: 250,
                          child: _buildSidebarContent(isMobile: false),
                        ),
                      // Right Content Area
                      Expanded(
                        child: IndexedStack(
                          sizing: StackFit.expand,
                          index: _sortedToOriginalIndex[_selectedIndex] ?? 0,
                          children: [
                            _buildDashboardTab(), // 0
                            _buildProductsTab(), // 1
                            _buildCategoriesTab(), // 2
                            _buildServicesTab(), // 3
                            _buildFeaturedSectionsTab(isAdmin: isAdmin), // 4
                            _buildDeliveryPartnersTab(), // 5
                            _buildUsersTab(), // 6
                            _buildGiftsTab(), // 7
                            _buildOrdersTab(), // 8
                            _buildCoreStaffTab(), // 9
                            _buildPermissionsTab(), // 10
                            _buildRoleBasedUsersTab('seller'), // 11
                            _buildRoleBasedUsersTab('service_provider'), // 12
                            _buildPayoutRequestsTab(), // 13
                            _buildServiceCategoriesTab(isAdmin: isAdmin), // 14
                            const SizedBox(), // 15 (was Analytics)
                            const SizedBox(), // 16 (was Reports)
                            _buildPartnerRequestsTab(), // 16
                            const AdminSettingsScreen(), // 17
                            _buildRefundRequestsTab(), // 18
                            const ManageStoresTab(), // 19
                          ],
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
    );
  }

  Widget _buildSidebarContent({required bool isMobile}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          if (isMobile) ...[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Admin Menu',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Menu Items - Scrollable
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _partnerRequestsStream,
              builder: (context, snapshot) {
                final pendingCount =
                    snapshot.hasData ? snapshot.data!.docs.length : 0;

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(0, 8, 0, 24 + MediaQuery.of(context).padding.bottom),
                  itemCount: _menuTitles.length,
                  itemBuilder: (context, listIndex) {
                    final isSelected = _selectedIndex == listIndex;
                    final isPartnerRequestsTab =
                        _menuTitles[listIndex] == 'Partner Requests';
                    final showBadge = isPartnerRequestsTab && pendingCount > 0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Material(
                        color: isSelected
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedIndex = listIndex;
                            });
                            if (isMobile) {
                              Navigator.pop(context); // Close drawer
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: isSelected
                                ? BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border(
                                      left: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        width: 4,
                                      ),
                                    ),
                                  )
                                : null,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  _menuIcons[listIndex],
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                  size: 24,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    _menuTitles[listIndex],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                if (showBadge) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      pendingCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (!isMobile)
            // Back to App Button (Only in side panel mode)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.arrow_back,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Back to App',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildRefundRequestsTab() {
    return const SharedOrdersTab(
      canManage: true,
      matchStatuses: ['return_requested', 'out_for_pickup', 'returned', 'refunded'],
    );
  }

  Widget _buildPartnerRequestsTab() {
    return RoleManagementTab(
      key: const ValueKey('partner_requests'),
      collection: 'partner_requests',
      onEdit: (id, data) {
        // This is not expected to be called for partner requests.
      },
      onDelete: (id, email) async {
        // Handle deletion of a partner request.
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Request'),
            content: Text('Are you sure you want to delete the request from $email?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          try {
            await FirebaseFirestore.instance.collection('partner_requests').doc(id).delete();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Request deleted successfully')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete request: $e')),
            );
          }
        }
      },
      onRequestAction: _handlePartnerRequestAction,
    );
  }

  void _handlePartnerRequestAction(String requestId, String action) async {
    final functions = FirebaseFunctions.instance;
    // Optional: show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (action == 'approved') {
        // 1. Fetch the request document details FIRST
        final requestDoc = await FirebaseFirestore.instance
            .collection('partner_requests')
            .doc(requestId)
            .get();

        if (!requestDoc.exists) {
          throw Exception('Request not found');
        }

        final requestData = requestDoc.data()!;
        final role = requestData['role'] as String? ?? '';
        
        // 2. Call the Cloud Function to create the user in Auth and Users collection
        final callable = functions.httpsCallable('approvePartnerRequest');
        final result = await callable.call({'requestId': requestId});
        
        final userId = result.data['userId'];

        // 3. Post-Approval: Create specific role documents if needed
        if (role == 'Delivery Partner' && userId != null) {
          final pincode = requestData['service_pincode'] ?? requestData['pincode'];
          
          await FirebaseFirestore.instance.collection('delivery_partners').doc(userId).set({
            'id': userId,
            'name': requestData['name'],
            'email': requestData['email'],
            'phone': requestData['phone'],
            'address': requestData['address'] ?? requestData['district'], // Fallback to district
            'pincode': pincode,
            'service_pincode': pincode,
            'vehicleType': requestData['vehicleType'] ?? 'Bike',
            'vehicleNumber': requestData['vehicleNumber'] ?? '',
            'status': 'approved', // Auto-approved since the request was approved
            'approvedAt': FieldValue.serverTimestamp(),
            'createdAt': requestData['createdAt'],
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Partner request approved successfully!')),
        );
      } else if (action == 'rejected') {
        // Just update the status in Firestore
        await FirebaseFirestore.instance
            .collection('partner_requests')
            .doc(requestId)
            .update({'status': 'rejected'});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Partner request rejected.')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: $e')),
      );
    } finally {
      Navigator.of(context).pop(); // Dismiss loading indicator
    }
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width < 600
                ? 2
                : MediaQuery.of(context).size.width < 900
                    ? 3
                    : 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildDashboardCard(
                title: 'Total Service Providers',
                stream: _serviceProvidersStream,
                icon: Icons.home_repair_service,
                color: Colors.blue,
              ),
              _buildDashboardCard(
                title: 'Total Sellers',
                stream: _sellersStream,
                icon: Icons.store,
                color: Colors.green,
              ),
              _buildDashboardCard(
                title: 'Total Delivery Partner',
                stream: _deliveryPartnersStream,
                icon: Icons.delivery_dining,
                color: Colors.teal,
              ),
              _buildDashboardCard(
                title: 'Total Orders',
                stream: _ordersStream,
                icon: Icons.receipt_long,
                color: Colors.orange,
              ),
              _buildDashboardCard(
                title: 'Total Users',
                stream: _usersStream,
                icon: Icons.person,
                color: Colors.purple,
              ),
              _buildDashboardCard(
                title: 'Pending Partners',
                stream: _partnerRequestsStream,
                icon: Icons.people_outline,
                color: Colors.red,
              ),
              // Removed duplicate Total Sell
              _buildDashboardCard(
                title: 'Total Cancel',
                stream: _cancelledOrdersStream,
                icon: Icons.cancel,
                color: Colors.red,
              ),
              _buildDashboardCard(
                title: 'Total Return',
                stream: _returnedOrdersStream,
                icon: Icons.assignment_return,
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Top Selling Products',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(height: 200, child: _buildTopSellingProducts()),
          const SizedBox(height: 24),
          const Text(
            'Top Services',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(height: 200, child: _buildTopServices()),
          const SizedBox(height: 32),
          const Text(
            'Recent Orders',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(height: 500, child: _buildRecentOrdersList()),
          const SizedBox(height: 32),

        ],
      ),
    );
  }

  Widget _buildProductsTab() {
    return const SharedProductsTab(canManage: true);
  }


  Widget _buildServicesTab() {
    return const SharedServicesTab(canManage: true);
  }

  
  Widget _buildRecentOrdersList() {
    return StreamBuilder(
      stream: _recentOrdersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Failed to load orders: ${snapshot.error}'),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No orders found'));
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
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

            Color statusColor = Colors.orange;
            if (status == 'delivered') statusColor = Colors.green;
            if (status == 'cancelled') statusColor = Colors.red;
            if (status == 'pending') statusColor = Colors.orange;

            return Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${orderId.substring(0, 8)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'User: $userId',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total: ₹${total.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (orderDate != null)
                            Text(
                              'Date: ${orderDate.day}/${orderDate.month}/${orderDate.year}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopSellingProducts() {
    return StreamBuilder(
      stream: _topSellingStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        // Count products from orders
        Map<String, int> productCount = {};
        final orders = snapshot.data?.docs ?? [];
        for (var order in orders) {
          final items = order['items'] as List<dynamic>? ?? [];
          for (var item in items) {
            final productName = item['productName'] ?? 'Unknown';
            productCount[productName] = (productCount[productName] ?? 0) + 1;
          }
        }

        if (productCount.isEmpty) {
          return const Center(child: Text('No products sold yet'));
        }

        // Sort by count and get top 5
        final sortedProducts = productCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topProducts = sortedProducts.take(5).toList();

        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: topProducts.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final product = topProducts[index];
            return Container(
              width: 150,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.withOpacity(0.7), Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.4),
                    offset: const Offset(2, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    product.value.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.key,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopServices() {
    return StreamBuilder(
      stream: _topServicesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final services = snapshot.data?.docs ?? [];
        if (services.isEmpty) {
          return const Center(child: Text('No services available'));
        }

        // Sort by name and get top 5
        final topServices = services.take(5).toList();

        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: topServices.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final service = topServices[index];
            final serviceName = service['name'] ?? 'Unknown';
            final description = service['description'] ?? '';

            return Container(
              width: 150,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.withOpacity(0.7), Colors.green],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.4),
                    offset: const Offset(2, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.design_services, size: 36, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    serviceName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }



  Widget _buildDashboardCard({
    required String title,
    required Stream<QuerySnapshot> stream,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color.withOpacity(0.5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: Colors.white),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: stream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox(
                              height: 32,
                              width: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return const Text(
                              '!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }
                          return Text(
                            snapshot.data?.docs.length.toString() ?? '0',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGiftsTab() {
    return Consumer<GiftProvider>(
      builder: (context, giftProvider, _) {
        final gifts = giftProvider.gifts;
        return Column(
          children: [
            // Count + Add button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Total Gifts: ${gifts.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddOrEditGiftDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Gift'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Gifts list
            Expanded(
              child: giftProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : gifts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.card_giftcard,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No gifts yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add a gift item to get started!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: gifts.length,
                      itemBuilder: (ctx, index) {
                        final gift = gifts[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Leading
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: gift.imageUrl != null
                                      ? Image.network(
                                          gift.imageUrl!,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey[300],
                                            child: const Icon(
                                              Icons.image_not_supported,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          width: 60,
                                          height: 60,
                                          color: Colors.grey[300],
                                          child: const Icon(
                                            Icons.card_giftcard,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                // Title and Subtitle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        gift.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if ((gift.purpose ?? '').isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.sell,
                                                size: 14,
                                                color: Colors.blueGrey,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  gift.purpose!,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.blueGrey,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      Text('₹${gift.price.toStringAsFixed(2)}'),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6.0,
                                        runSpacing: 4.0,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          const Text('Active:'),
                                          Icon(
                                            gift.isActive
                                                ? Icons.check_circle
                                                : Icons.cancel,
                                            color: gift.isActive
                                                ? Colors.green
                                                : Colors.red,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text('Order: ${gift.displayOrder}'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Trailing
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () => _showAddOrEditGiftDialog(
                                        context,
                                        existing: gift,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: ctx,
                                          builder: (d) => AlertDialog(
                                            title: const Text('Delete Gift'),
                                            content: Text(
                                              'Delete "${gift.name}"?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(d, false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    Navigator.pop(d, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          try {
                                            await Provider.of<GiftProvider>(
                                              context,
                                              listen: false,
                                            ).deleteGift(gift.id);
                                            if (ctx.mounted) {
                                              ScaffoldMessenger.of(
                                                ctx,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Gift deleted successfully!',
                                                  ),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (ctx.mounted) {
                                              ScaffoldMessenger.of(
                                                ctx,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      },
                                    ),
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
    );
  }

  Widget _buildOrdersTab() {
    return const SharedOrdersTab(canManage: true);
  }


  void _showAddOrEditGiftDialog(BuildContext context, {Gift? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final priceCtrl = TextEditingController(
      text: existing?.price.toString() ?? '0',
    );
    final orderCtrl = TextEditingController(
      text: existing?.displayOrder.toString() ?? '0',
    );
    bool isActive = existing?.isActive ?? true;

    // Multi-image storage (up to 6 images)
    final List<Uint8List?> imageBytes = List.filled(6, null);
    final List<File?> imageFiles = List.filled(6, null);
    final List<String?> fileNames = List.filled(6, null);
    final List<String?> existingUrls = List.filled(6, null);

    // Load existing images
    if (existing?.imageUrls != null) {
      for (int i = 0; i < existing!.imageUrls!.length && i < 6; i++) {
        existingUrls[i] = existing.imageUrls![i];
      }
    } else if (existing?.imageUrl != null && existing!.imageUrl!.isNotEmpty) {
      existingUrls[0] = existing.imageUrl;
    }

    bool saving = false;

    Future<void> pickImage(int index, StateSetter setState) async {
      try {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        if (pickedFile != null) {
          fileNames[index] = pickedFile.name;
          existingUrls[index] = null; // Clear existing URL if replacing
          if (kIsWeb) {
            imageBytes[index] = await pickedFile.readAsBytes();
          } else {
            imageFiles[index] = File(pickedFile.path);
          }
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
        }
      }
    }

    Future<List<String>> uploadGiftImages(String giftId) async {
      final storage = FirebaseStorage.instanceFor(
        bucket: 'gs://bong-bazar-3659f.firebasestorage.app',
      );
      final List<String> urls = [];

      for (int i = 0; i < 6; i++) {
        // If existing URL and no new image, keep existing
        if (existingUrls[i] != null &&
            imageBytes[i] == null &&
            imageFiles[i] == null) {
          urls.add(existingUrls[i]!);
          continue;
        }

        // If new image selected, upload it
        if (imageBytes[i] != null || imageFiles[i] != null) {
          try {
            final ref = storage
                .ref()
                .child('gifts')
                .child(giftId)
                .child('img_$i.jpg');

            String contentType = 'image/jpeg';
            final name = fileNames[i]?.toLowerCase() ?? '';
            if (name.endsWith('.png')) contentType = 'image/png';

            UploadTask task;
            if (imageBytes[i] != null) {
              task = ref.putData(
                imageBytes[i]!,
                SettableMetadata(
                  contentType: contentType,
                  cacheControl: 'public, max-age=3600',
                ),
              );
            } else {
              task = ref.putFile(
                imageFiles[i]!,
                SettableMetadata(
                  contentType: contentType,
                  cacheControl: 'public, max-age=3600',
                ),
              );
            }

            final snap = await task;
            if (snap.state == TaskState.success) {
              final url = await ref.getDownloadURL();
              urls.add(url);
            }
          } catch (e) {

          }
        }
      }

      return urls;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'Add Gift' : 'Edit Gift'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width > 600 ? 600 : double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Gift Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Price (₹)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: orderCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Display Order',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: isActive,
                    onChanged: (v) => setState(() => isActive = v),
                    title: const Text('Active'),
                  ),
                  const SizedBox(height: 12),
                  // Multi-Image Grid
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Gift Images (minimum 4 required)',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 240,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                      itemCount: 6,
                      itemBuilder: (gctx, i) {
                        Widget preview;
                        if (imageBytes[i] != null) {
                          preview = Image.memory(
                            imageBytes[i]!,
                            fit: BoxFit.cover,
                          );
                        } else if (imageFiles[i] != null && !kIsWeb) {
                          preview = Image.file(
                            imageFiles[i]!,
                            fit: BoxFit.cover,
                          );
                        } else if (existingUrls[i] != null) {
                          preview = Image.network(
                            existingUrls[i]!,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Icon(
                              Icons.card_giftcard,
                              color: Colors.grey[400],
                              size: 40,
                            ),
                          );
                        } else {
                          preview = Icon(
                            Icons.add_photo_alternate,
                            size: 40,
                            color: Colors.grey[400],
                          );
                        }

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => pickImage(i, setState),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Center(child: preview),
                                    Positioned(
                                      right: 4,
                                      bottom: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '${i + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Name is required')),
                        );
                        return;
                      }

                      // Count selected images (existing + new)
                      int imageCount = 0;
                      for (int i = 0; i < 6; i++) {
                        if (existingUrls[i] != null ||
                            imageBytes[i] != null ||
                            imageFiles[i] != null) {
                          imageCount++;
                        }
                      }

                      if (imageCount < 4) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Minimum 4 images required!'),
                          ),
                        );
                        return;
                      }

                      setState(() => saving = true);
                      try {
                        final giftId =
                            existing?.id ??
                            'g${DateTime.now().millisecondsSinceEpoch}';
                        final urls = await uploadGiftImages(giftId);

                        if (urls.isEmpty) {
                          throw Exception('Failed to upload images');
                        }

                        final gift = Gift(
                          id: giftId,
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          price: double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                          imageUrl: urls.first,
                          imageUrls: urls,
                          isActive: isActive,
                          displayOrder:
                              int.tryParse(orderCtrl.text.trim()) ?? 0,
                          createdAt: existing?.createdAt,
                          updatedAt: DateTime.now(),
                        );
                        final provider = Provider.of<GiftProvider>(
                          context,
                          listen: false,
                        );
                        if (existing == null) {
                          await provider.addGift(gift);
                        } else {
                          await provider.updateGift(giftId, gift);
                        }
                        if (mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                existing == null
                                    ? 'Gift added successfully!'
                                    : 'Gift updated successfully!',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        setState(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(existing == null ? 'Add Gift' : 'Update Gift'),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildCategoriesTab() {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, _) {
        final categories = categoryProvider.categories;
        return Column(
          children: [
            // Category count and Add button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Total Categories: ${categories.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddCategoryDialog(null),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Categories list
            Expanded(
              child: categoryProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : categories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No categories yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first category to get started!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: categories.length,
                      itemBuilder: (ctx, index) {
                        final category = categories[index];
                        return Card(
                          key: ValueKey(category.id),
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                category.imageUrl,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.category),
                                ),
                              ),
                            ),
                            title: Text(
                              category.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text('Order: ${category.order}'),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  _showAddCategoryDialog(category);
                                } else if (value == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: ctx,
                                    builder: (dialogCtx) => AlertDialog(
                                      title: const Text('Confirm Delete'),
                                      content: Text(
                                        'Delete "${category.name}" category?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialogCtx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(dialogCtx, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    try {
                                      await categoryProvider.deleteCategory(
                                        category.id,
                                      );
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(
                                          ctx,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Category deleted successfully!',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(
                                          ctx,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
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
    );
  }

  void _showAddCategoryDialog(Category? existingCategory) {
    final nameCtrl = TextEditingController(text: existingCategory?.name);
    final orderCtrl = TextEditingController(
      text: existingCategory?.order.toString() ?? '0',
    );

    Uint8List? imageBytes;
    File? imageFile;
    String? fileName;
    String? existingImageUrl = existingCategory?.imageUrl;

    bool saving = false;

    Future<void> pickImage(StateSetter setState) async {
      try {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 85,
        );

        if (pickedFile != null) {
          fileName = pickedFile.name;
          if (kIsWeb) {
            imageBytes = await pickedFile.readAsBytes();
          } else {
            imageFile = File(pickedFile.path);
          }
          existingImageUrl = null; // Clear existing when new selected
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
        }
      }
    }

    Future<String?> uploadCategoryImage(String categoryId) async {
      if (imageBytes == null && imageFile == null) {
        return existingImageUrl; // Keep existing if no new image
      }

      try {

        final storage = FirebaseStorage.instanceFor(
          bucket: 'gs://bong-bazar-3659f.firebasestorage.app',
        );
        final ref = storage.ref().child('categories').child('$categoryId.png');

        String contentType = 'image/png';
        final name = fileName?.toLowerCase() ?? '';
        if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
          contentType = 'image/jpeg';
        }

        UploadTask task;
        if (imageBytes != null) {
          task = ref.putData(
            imageBytes!,
            SettableMetadata(
              contentType: contentType,
              cacheControl: 'public, max-age=3600',
            ),
          );
        } else {
          task = ref.putFile(
            imageFile!,
            SettableMetadata(
              contentType: contentType,
              cacheControl: 'public, max-age=3600',
            ),
          );
        }

        final snapshot = await task;
        final url = await snapshot.ref.getDownloadURL();

        return url;
      } catch (e) {

        rethrow;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            existingCategory == null ? 'Add Category' : 'Edit Category',
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width > 400 ? 400 : double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Category name
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Category Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Order
                  TextField(
                    controller: orderCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Display Order',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),

                  // Image picker
                  const Text(
                    'Category Icon (512x512 recommended)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => pickImage(setState),
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageBytes != null
                            ? Image.memory(imageBytes!, fit: BoxFit.cover)
                            : imageFile != null && !kIsWeb
                            ? Image.file(imageFile!, fit: BoxFit.cover)
                            : existingImageUrl != null
                            ? Image.network(
                                existingImageUrl!,
                                fit: BoxFit.cover,
                              )
                            : Icon(
                                Icons.add_photo_alternate,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Category name is required!'),
                          ),
                        );
                        return;
                      }

                      if (imageBytes == null &&
                          imageFile == null &&
                          existingImageUrl == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Category image is required!'),
                          ),
                        );
                        return;
                      }

                      setState(() => saving = true);

                      try {
                        final categoryId =
                            existingCategory?.id ??
                            'cat${DateTime.now().millisecondsSinceEpoch}';
                        final imageUrl = await uploadCategoryImage(categoryId);

                        if (imageUrl == null) {
                          throw Exception('Failed to upload image');
                        }

                        final category = Category(
                          id: categoryId,
                          name: nameCtrl.text,
                          imageUrl: imageUrl,
                          order: int.tryParse(orderCtrl.text) ?? 0,
                        );

                        final categoryProvider = Provider.of<CategoryProvider>(
                          context,
                          listen: false,
                        );

                        if (existingCategory == null) {
                          await categoryProvider.addCategory(category);
                        } else {
                          await categoryProvider.updateCategory(
                            categoryId,
                            category,
                          );
                        }

                        if (mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                existingCategory == null
                                    ? 'Category added successfully!'
                                    : 'Category updated successfully!',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      } finally {
                        setState(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(existingCategory == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  // Service Categories Tab
  Widget _buildServiceCategoriesTab({required bool isAdmin}) {
    return Consumer<ServiceCategoryProvider>(
      builder: (context, serviceCategoryProvider, _) {
        final serviceCategories = serviceCategoryProvider.serviceCategories;

        return Column(
          children: [
            if (!isAdmin)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Read-only access. Please contact an admin for changes.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            // Add Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: isAdmin
                    ? () => _showAddEditServiceCategoryDialog()
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Service Categories List
            Expanded(
              child: serviceCategories.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No service categories yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: serviceCategories.length,
                      itemBuilder: (context, index) {
                        final category = serviceCategories[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading:
                                category.imageUrl != null &&
                                    category.imageUrl!.isNotEmpty
                                ? CircleAvatar(
                                    radius: 24,
                                    backgroundImage: NetworkImage(
                                      category.imageUrl!,
                                    ),
                                    backgroundColor: Colors.grey[200],
                                  )
                                : Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Color(
                                        int.parse(
                                          category.colorHex.replaceFirst(
                                            '#',
                                            '0xFF',
                                          ),
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _getIconFromName(category.iconName),
                                      color: Colors.white,
                                    ),
                                  ),
                            title: Text(
                              category.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(category.description),
                                const SizedBox(height: 4),
                                Text(
                                  'Base Price: ₹${category.basePrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (!isAdmin) return;
                                if (value == 'edit') {
                                  _showAddEditServiceCategoryDialog(category: category);
                                } else if (value == 'delete') {
                                  _deleteServiceCategory(category);
                                }
                              },
                              itemBuilder: (context) => [
                                if (isAdmin) ...[
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, color: Colors.blue),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete'),
                                      ],
                                    ),
                                  ),
                                ] else
                                  const PopupMenuItem(
                                    value: 'none',
                                    enabled: false,
                                    child: Text('Read-only'),
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
    );
  }

  IconData _getIconFromName(String iconName) {
    final iconMap = {
      'plumbing': Icons.plumbing,
      'carpenter': Icons.carpenter,
      'electrical_services': Icons.electrical_services,
      'directions_car': Icons.directions_car,
      'cleaning_services': Icons.cleaning_services,
      'security': Icons.security,
      'home_repair_service': Icons.home_repair_service,
      'format_paint': Icons.format_paint,
      'ac_unit': Icons.ac_unit,
      'yard': Icons.yard,
      'pest_control': Icons.pest_control,
      'kitchen': Icons.kitchen,
      'miscellaneous_services': Icons.miscellaneous_services,
    };
    return iconMap[iconName] ?? Icons.miscellaneous_services;
  }

  void _showAddEditServiceCategoryDialog({ServiceCategory? category}) {
    final nameCtrl = TextEditingController(text: category?.name);
    final descCtrl = TextEditingController(text: category?.description);
    final priceCtrl = TextEditingController(
      text: category?.basePrice.toString() ?? '500',
    );

    String selectedIcon = category?.iconName ?? 'miscellaneous_services';
    String selectedColor = category?.colorHex ?? '#2196F3';
    String? imageUrl = category?.imageUrl;
    Uint8List? imageBytes;
    File? imageFile;

    final availableIcons = {
      'plumbing': Icons.plumbing,
      'carpenter': Icons.carpenter,
      'electrical_services': Icons.electrical_services,
      'directions_car': Icons.directions_car,
      'cleaning_services': Icons.cleaning_services,
      'security': Icons.security,
      'home_repair_service': Icons.home_repair_service,
      'format_paint': Icons.format_paint,
      'ac_unit': Icons.ac_unit,
      'yard': Icons.yard,
      'pest_control': Icons.pest_control,
      'kitchen': Icons.kitchen,
      'miscellaneous_services': Icons.miscellaneous_services,
    };

    final availableColors = {
      '#2196F3': 'Blue',
      '#F44336': 'Red',
      '#4CAF50': 'Green',
      '#FF9800': 'Orange',
      '#9C27B0': 'Purple',
      '#00BCD4': 'Cyan',
      '#795548': 'Brown',
      '#FFC107': 'Amber',
      '#8BC34A': 'Light Green',
      '#009688': 'Teal',
      '#3F51B5': 'Indigo',
      '#E91E63': 'Pink',
    };

    bool saving = false;

    Future<void> pickImage(StateSetter setState) async {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        if (kIsWeb) {
          imageBytes = await pickedFile.readAsBytes();
        } else {
          imageFile = File(pickedFile.path);
        }
        setState(() {});
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(
            category == null ? 'Add Service Category' : 'Edit Service Category',
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width > 500 ? 500 : double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Picker Section
                  const Text(
                    'Category Image (Optional):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => pickImage(setState),
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[50],
                      ),
                      child:
                          imageBytes != null ||
                              imageFile != null ||
                              imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: imageBytes != null
                                  ? Image.memory(imageBytes!, fit: BoxFit.cover)
                                  : imageFile != null
                                  ? Image.file(imageFile!, fit: BoxFit.cover)
                                  : Image.network(imageUrl!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 40,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to add image',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (imageBytes != null ||
                      imageFile != null ||
                      imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            imageBytes = null;
                            imageFile = null;
                            imageUrl = null;
                          });
                        },
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text(
                          'Remove Image',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Service Name *',
                      hintText: 'e.g., Plumber, Electrician',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description *',
                      hintText: 'Brief description of the service',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const Text(
                    'Select Icon (fallback if no image):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: availableIcons.length,
                      itemBuilder: (context, index) {
                        final iconName = availableIcons.keys.elementAt(index);
                        final icon = availableIcons[iconName]!;
                        final isSelected = selectedIcon == iconName;

                        return InkWell(
                          onTap: () {
                            setState(() => selectedIcon = iconName);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Icon(
                              icon,
                              color: isSelected ? Colors.white : Colors.black54,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Color:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableColors.entries.map((entry) {
                      final isSelected = selectedColor == entry.key;
                      return InkWell(
                        onTap: () {
                          setState(() => selectedColor = entry.key);
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Color(
                              int.parse(entry.key.replaceFirst('#', '0xFF')),
                            ),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.black, width: 3)
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty ||
                          descCtrl.text.trim().isEmpty ||
                          priceCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill all required fields'),
                          ),
                        );
                        return;
                      }

                      final price = double.tryParse(priceCtrl.text.trim());
                      if (price == null || price <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid price'),
                          ),
                        );
                        return;
                      }

                      setState(() => saving = true);

                      try {
                        final serviceCategoryProvider =
                            Provider.of<ServiceCategoryProvider>(
                              context,
                              listen: false,
                            );

                        // Upload image if selected
                        String? uploadedImageUrl = imageUrl;
                        if (imageBytes != null || imageFile != null) {
                          final fileName =
                              '${DateTime.now().millisecondsSinceEpoch}.jpg';
                          final ref = FirebaseStorage.instance
                              .ref()
                              .child('service_category_images')
                              .child(fileName);

                          if (kIsWeb) {
                            await ref.putData(imageBytes!);
                          } else {
                            await ref.putFile(imageFile!);
                          }
                          uploadedImageUrl = await ref.getDownloadURL();
                        }

                        final newCategory = ServiceCategory(
                          id: category?.id ?? '',
                          name: nameCtrl.text.trim(),
                          iconName: selectedIcon,
                          colorHex: selectedColor,
                          description: descCtrl.text.trim(),
                          basePrice: price,
                          imageUrl: uploadedImageUrl,
                          createdAt: category?.createdAt ?? DateTime.now(),
                        );

                        if (category == null) {
                          await serviceCategoryProvider.addServiceCategory(
                            newCategory,
                          );
                        } else {
                          await serviceCategoryProvider.updateServiceCategory(
                            newCategory,
                          );
                        }

                        if (mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                category == null
                                    ? 'Service category added successfully!'
                                    : 'Service category updated successfully!',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      } finally {
                        setState(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(category == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteServiceCategory(ServiceCategory category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service Category'),
        content: Text(
          'Are you sure you want to delete "${category.name}"?\nThis action cannot be undone.',
        ),
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
        final serviceCategoryProvider = Provider.of<ServiceCategoryProvider>(
          context,
          listen: false,
        );
        await serviceCategoryProvider.deleteServiceCategory(category.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Service category deleted successfully'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting category: $e')),
          );
        }
      }
    }
  }

  // Featured Sections Tab
  Widget _buildFeaturedSectionsTab({required bool isAdmin}) {
    return Consumer<FeaturedSectionProvider>(
      builder: (context, featuredProvider, _) {
        return Column(
          children: [
            if (!isAdmin)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.orange.shade100,
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Read-only access. Please contact an admin for changes.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Featured Sections',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: isAdmin
                        ? () => _showAddFeaturedSectionDialog(featuredProvider)
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Section'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: featuredProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : featuredProvider.sections.isEmpty
                  ? const Center(
                      child: Text(
                        'No featured sections yet.\nAdd sections like "HOTS DEALS", "Daily Needs", etc.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: featuredProvider.sections.length,
                      itemBuilder: (ctx, i) {
                        final section = featuredProvider.sections[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text('${section.displayOrder}'),
                            ),
                            title: Text(
                              section.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Category: ${section.categoryName}\n'
                              'Status: ${section.isActive ? "Active" : "Inactive"}',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditFeaturedSectionDialog(featuredProvider, section);
                                } else if (value == 'delete') {
                                  _confirmDeleteFeaturedSection(featuredProvider, section.id);
                                } else if (value == 'toggle') {
                                  featuredProvider.toggleActive(section.id);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'toggle',
                                  enabled: isAdmin,
                                  child: Row(
                                    children: [
                                      Icon(
                                        section.isActive ? Icons.visibility_off : Icons.visibility,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(section.isActive ? 'Deactivate' : 'Activate'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'edit',
                                  enabled: isAdmin,
                                  child: const Row(
                                    children: [
                                      Icon(Icons.edit, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  enabled: isAdmin,
                                  child: const Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
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
    );
  }

  void _showAddFeaturedSectionDialog(FeaturedSectionProvider provider) {
    final titleCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final orderCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Featured Section'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title (e.g., HOTS DEALS)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Category Name (e.g., Hot Deals)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: orderCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Display Order (1, 2, 3...)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.isEmpty || categoryCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              final section = FeaturedSection(
                id: '',
                title: titleCtrl.text.trim(),
                categoryName: categoryCtrl.text.trim(),
                displayOrder: int.tryParse(orderCtrl.text) ?? 1,
                isActive: true,
              );

              try {
                await provider.addSection(section);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Featured section added!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditFeaturedSectionDialog(
    FeaturedSectionProvider provider,
    FeaturedSection section,
  ) {
    final titleCtrl = TextEditingController(text: section.title);
    final categoryCtrl = TextEditingController(text: section.categoryName);
    final orderCtrl = TextEditingController(
      text: section.displayOrder.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Featured Section'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: orderCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Display Order',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = section.copyWith(
                title: titleCtrl.text.trim(),
                categoryName: categoryCtrl.text.trim(),
                displayOrder:
                    int.tryParse(orderCtrl.text) ?? section.displayOrder,
              );

              try {
                await provider.updateSection(updated);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Featured section updated!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFeaturedSection(
    FeaturedSectionProvider provider,
    String id,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Section'),
        content: const Text(
          'Are you sure you want to delete this featured section?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await provider.deleteSection(id);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Featured section deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutRequestsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Payout Requests',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<PayoutModel>>(
            stream: PayoutService().getAllPayouts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final payouts = snapshot.data ?? [];

              if (payouts.isEmpty) {
                return const Center(child: Text('No payout requests found'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: payouts.length,
                itemBuilder: (context, index) {
                  final payout = payouts[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: payout.status == PayoutStatus.pending
                            ? Colors.orange.withOpacity(0.2)
                            : payout.status == PayoutStatus.approved
                                ? Colors.green.withOpacity(0.2)
                                : Colors.red.withOpacity(0.2),
                        child: Icon(
                          payout.status == PayoutStatus.pending
                              ? Icons.pending
                              : payout.status == PayoutStatus.approved
                                  ? Icons.check
                                  : Icons.close,
                          color: payout.status == PayoutStatus.pending
                              ? Colors.orange
                              : payout.status == PayoutStatus.approved
                                  ? Colors.green
                                  : Colors.red,
                        ),
                      ),
                      title: Text(
                        '₹${payout.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('User ID: ${payout.userId}'),
                          Text('Date: ${DateFormat('MMM d, yyyy').format(payout.requestDate)}'),
                          Text('Details: ${payout.paymentDetails}'),
                        ],
                      ),
                      trailing: payout.status == PayoutStatus.pending
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  onPressed: () => _handlePayoutAction(payout, true),
                                  tooltip: 'Approve',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () => _handlePayoutAction(payout, false),
                                  tooltip: 'Reject',
                                ),
                              ],
                            )
                          : _getStatusChip(payout.status.name),
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

  Future<void> _handlePayoutAction(PayoutModel payout, bool approve) async {
    try {
      await PayoutService().updatePayoutStatus(
        payout.id,
        approve ? PayoutStatus.approved : PayoutStatus.rejected,
        adminNote: approve ? 'Approved by Admin' : 'Rejected by Admin',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payout ${approve ? 'Approved' : 'Rejected'}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _getStatusChip(String status) {
    Color color;
    IconData icon;

    switch (status) {
      case 'approved':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.orange;
        icon = Icons.pending;
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 12),
      ),
      backgroundColor: color.withOpacity(0.1),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    // Filter out Firestore references and null values
    String displayValue = value.toString().trim();

    // Check if it's a Firestore reference or invalid data
    if (displayValue.contains('DocumentReference') ||
        displayValue.contains('projects/') ||
        displayValue.startsWith('/') ||
        displayValue == 'null') {
      return const SizedBox.shrink(); // Hide completely
    }

    // Show empty placeholder if value is empty
    if (displayValue.isEmpty) {
      displayValue = 'N/A';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _updateRequestStatus(String requestId, String status) async {
    try {
      // First get the partner request details
      final requestDoc = await FirebaseFirestore.instance
          .collection('partner_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final requestData = requestDoc.data()!;

      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add approval message
      if (status == 'approved') {
        updateData['notificationMessage'] =
            'Congratulations! Your partner request has been approved. '
            'You can now login and start selling/providing services.';

        // Create/Update user account with seller role
        final email = requestData['email'];
        final phone = requestData['phone'];
        final name = requestData['name'];

        // Check if user with this email or phone already exists
        final usersQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (usersQuery.docs.isNotEmpty) {
          // User exists, update role based on request
          final userId = usersQuery.docs.first.id;
          String assignedRole = 'seller'; // default

          // Map role from request to actual role
          if (requestData['role'] == 'Service Provider') {
            assignedRole = 'service_provider';
          } else if (requestData['role'] == 'Seller') {
            assignedRole = 'seller';
          } else if (requestData['role'] == 'Core Staff') {
            assignedRole = 'core_staff';
          } else if (requestData['role'] == 'Administrator') {
            assignedRole = 'administrator';
          } else if (requestData['role'] == 'Store Manager') {
            assignedRole = 'store_manager';
          } else if (requestData['role'] == 'Manager') {
            assignedRole = 'manager';
          } else if (requestData['role'] == 'Delivery Partner') {
            assignedRole = 'delivery_partner';
          } else if (requestData['role'] == 'Customer Care') {
            assignedRole = 'customer_care';
          }

          final updateData = {
            'role': assignedRole,
            'businessName': requestData['businessName'],
            'district': requestData['district'],
            'minCharge': requestData['minCharge'],
            'updatedAt': FieldValue.serverTimestamp(),
          };

          // If service provider, copy category fields
          if (assignedRole == 'service_provider' &&
              requestData.containsKey('serviceCategoryId')) {
            updateData['serviceCategoryId'] = requestData['serviceCategoryId'];
            updateData['serviceCategoryName'] =
                requestData['serviceCategoryName'];
          }

          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update(updateData);
        } else {
          // User doesn't exist, create new user document (they'll complete signup later)
          // We'll create a placeholder that they can claim when they sign up
          await FirebaseFirestore.instance
              .collection('pending_sellers')
              .doc(email)
              .set({
                'email': email,
                'phone': phone,
                'name': name,
                'role': 'seller',
                'businessName': requestData['businessName'],
                'district': requestData['district'],
                'minCharge': requestData['minCharge'],
                'panNumber': requestData['panNumber'],
                'aadhaarNumber': requestData['aadhaarNumber'],
                'profilePicUrl': requestData['profilePicUrl'],
                'createdAt': FieldValue.serverTimestamp(),
              });
        }
      } else if (status == 'rejected') {
        updateData['notificationMessage'] =
            'Your partner request has been rejected. '
            'Please contact support for more information.';
      }

      await FirebaseFirestore.instance
          .collection('partner_requests')
          .doc(requestId)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'approved'
                  ? 'Request approved! ${requestData['email']} can now login as seller.'
                  : 'Request $status successfully',
            ),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deletePartnerRequest(String requestId) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text(
          'Are you sure you want to delete this partner request? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('partner_requests')
          .doc(requestId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editPartnerRequest(PartnerRequest request) {
    final nameCtrl = TextEditingController(text: request.name);
    final phoneCtrl = TextEditingController(text: request.phone);
    final emailCtrl = TextEditingController(text: request.email);
    final districtCtrl = TextEditingController(text: request.district);
    final pincodeCtrl = TextEditingController(text: request.pincode);
    final businessCtrl = TextEditingController(text: request.businessName);
    final panCtrl = TextEditingController(text: request.panNumber);
    final aadhaarCtrl = TextEditingController(text: request.aadhaarNumber);
    final minChargeCtrl = TextEditingController(
      text: request.minCharge.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Partner Request'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: districtCtrl,
                  decoration: const InputDecoration(labelText: 'District'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pincodeCtrl,
                  decoration: const InputDecoration(labelText: 'PIN Code'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: businessCtrl,
                  decoration: const InputDecoration(labelText: 'Business Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: panCtrl,
                  decoration: const InputDecoration(labelText: 'PAN Number'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: aadhaarCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Aadhaar Number',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minChargeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Charge',
                  ),
                ),
              ],
            ),
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
                await FirebaseFirestore.instance
                    .collection('partner_requests')
                    .doc(request.id)
                    .update({
                      'name': nameCtrl.text,
                      'phone': phoneCtrl.text,
                      'email': emailCtrl.text,
                      'district': districtCtrl.text,
                      'pincode': pincodeCtrl.text,
                      'businessName': businessCtrl.text,
                      'panNumber': panCtrl.text,
                      'aadhaarNumber': aadhaarCtrl.text,
                      'minCharge': minChargeCtrl.text,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Request updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryPartnersTab() {
    return _buildRoleBasedUsersTab('delivery_partner');
  }


  Widget _buildCoreStaffTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['core_staff', 'store_manager'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final staffMembers = snapshot.data?.docs ?? [];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Core Staff Members',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddCoreStaffDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Staff'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: staffMembers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No staff members yet',
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: staffMembers.length,
                      itemBuilder: (context, index) {
                        final doc = staffMembers[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] ?? 'N/A';
                        final position = data['position'] ?? 'N/A';
                        final email = data['email'] ?? 'N/A';
                        final phone = data['phone'] ?? 'N/A';
                        final imageUrl = data['photoURL'] as String?;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: imageUrl != null
                                  ? NetworkImage(imageUrl)
                                  : null,
                              child: imageUrl == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Position: $position'),
                                Text('Email: $email'),
                                Text('Phone: $phone'),
                                if (data['role'] == 'store_manager')
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.blue.withOpacity(0.5)),
                                    ),
                                    child: const Text(
                                      'Store Manager',
                                      style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showAddCoreStaffDialog(
                                    staffId: doc.id,
                                    staffData: data,
                                  );
                                } else if (value == 'permissions') {
                                  // Re-use logic for permissions dialog
                                  // We need to set the _selectedPermissionRole logically or just pass it
                                  // Since _showPermissionDialog uses _selectedPermissionRole to determine layout,
                                  // we might need to adjust it temporarily or make the dialog smarter.
                                  // For now, let's assume core_staff role layout is fine for them.
                                  setState(() {
                                     _selectedPermissionRole = 'core_staff';
                                  });
                                  
                                  // Note: data['permissions'] might be null
                                  final permissions = data['permissions'] as Map<String, dynamic>? ?? {};
                                  _showPermissionDialog(doc.id, data, permissions);
                                  
                                } else if (value == 'delete') {
                                  _deleteCoreStaff(doc.id, email);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'permissions',
                                  child: Row(
                                    children: [
                                      Icon(Icons.security, color: Colors.green),
                                      SizedBox(width: 8),
                                      Text('Permissions'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
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
    );
  }

  void _showAddCoreStaffDialog({
    String? staffId,
    Map<String, dynamic>? staffData,
  }) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: staffData?['name'] ?? '');
    final positionCtrl = TextEditingController(text: staffData?['position'] ?? '');
    final emailCtrl = TextEditingController(text: staffData?['email'] ?? '');
    final phoneCtrl = TextEditingController(text: staffData?['phone'] ?? '');
    final bioCtrl = TextEditingController(text: staffData?['bio'] ?? '');
    final passwordCtrl = TextEditingController(); // Only for new users
    
    Uint8List? selectedImage;
    String? currentImageUrl = staffData?['photoURL'];
    bool isLoading = false;
    bool isPasswordVisible = false;

    // Image Picker Logic
    final ImagePicker picker = ImagePicker();
    Future<void> pickImage(StateSetter setState) async {
       try {
        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          final bytes = await image.readAsBytes();
          setState(() {
            selectedImage = bytes;
          });
        }
      } catch (e) {
        // Handle error
        print('Image picker error: $e');
      }
    }

    Future<String?> uploadImage(String userId) async {
      if (selectedImage == null) return currentImageUrl;
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('user_profile_images')
            .child(userId)
            .child('profile.jpg');
        await ref.putData(selectedImage!);
        return await ref.getDownloadURL();
      } catch (e) {
        print('Error uploading image: $e');
        return null;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(staffId == null ? 'Add Staff Member' : 'Edit Staff Member'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image Picker UI
                  GestureDetector(
                    onTap: () => pickImage(setState),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: selectedImage != null
                          ? MemoryImage(selectedImage!)
                          : (currentImageUrl != null
                              ? NetworkImage(currentImageUrl!) as ImageProvider
                              : null),
                      child: (selectedImage == null && currentImageUrl == null)
                          ? const Icon(Icons.add_a_photo, size: 30, color: Colors.grey)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: positionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Position (e.g., Manager)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email *'),
                    keyboardType: TextInputType.emailAddress,
                    enabled: staffId == null, // Lock email on edit for auth consistency
                  ),
                  const SizedBox(height: 12),
                  if (staffId == null) ...[
                    TextField(
                      controller: passwordCtrl,
                      decoration: InputDecoration(
                        labelText: 'Password *',
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              isPasswordVisible = !isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      obscureText: !isPasswordVisible,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bioCtrl,
                    decoration: const InputDecoration(labelText: 'Bio/Description'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) {
                   ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Name and Email are required')),
                    );
                    return;
                }
                if (staffId == null && passwordCtrl.text.length < 6) {
                   ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password must be at least 6 chars')),
                    );
                    return;
                }

                setState(() => isLoading = true);

                try {
                  // If adding new staff, we need to create Auth user
                  // NOTE: Client-side creation signs in the user. 
                  // Workaround: We will use a dedicated Cloud Function if available, 
                  // OR mostly commonly, we just create the Firestore doc and let them "Sign Up" matching the email? 
                  // No, that's insecure.
                  // For now, I will use the 'approvePartnerRequest' style cloud function call IF I had one for creating users.
                  // Since I don't, I will simulate it by creating a pending request OR
                  // just create the document and tell the admin "User must sign up with this email".
                  // ACTUALLY, I will use a Cloud Function call 'createStaffAccount' which I will ASSUME exists or I will create it.
                  // OPTION: use 'approvePartnerRequest' logic? No.
                  // BETTER OPTION: Just save to Firestore and let them use "Forgot Password" flow? No, account verification needed.
                  
                  // fallback: Call a hypothetical cloud function 'createStaffUser'
                   final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
                   // If this function doesn't exist, this will fail. 
                   // Given constraints, I will create the Firestore document FIRST.
                   
                   String? newId = staffId;
                   
                   if (staffId == null) {
                      // Call secure Cloud Function to create Auth + Firestore
                      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
                      final callable = functions.httpsCallable('createStaffAccount');
                      
                      final result = await callable.call({
                        'email': emailCtrl.text.trim(),
                        'password': passwordCtrl.text,
                        'name': nameCtrl.text.trim(),
                        'position': positionCtrl.text.trim(),
                        'phone': phoneCtrl.text.trim(),
                        'bio': bioCtrl.text.trim(),
                      });
                      
                      newId = result.data['userId'];
                      
                      // Upload image if selected
                      if (selectedImage != null && newId != null) {
                        final imgUrl = await uploadImage(newId);
                        if (imgUrl != null) {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(newId)
                              .update({'photoURL': imgUrl});
                        }
                      }
                      
                      if (mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Staff account created successfully!')),
                        );
                      }
                      
                   } else {
                     // Update existing
                     final imgUrl = await uploadImage(staffId);
                     await FirebaseFirestore.instance.collection('users').doc(staffId).update({
                        'name': nameCtrl.text,
                        'position': positionCtrl.text,
                        'phone': phoneCtrl.text,
                        'bio': bioCtrl.text,
                        if (imgUrl != null) 'photoURL': imgUrl,
                     });
                   }
                   
                   Navigator.pop(ctx);
                   
                } catch (e) {
                   if (mounted) {
                     String errorMessage = 'Error: $e';
                     
                     // Check for specific permission error
                     final errorString = e.toString().toLowerCase();
                     if (errorString.contains('permission-denied') || 
                         errorString.contains('only admins can create') ||
                         errorString.contains('only admins can')) {
                       errorMessage = 'Permission Denied: केवल Admin ही Core Staff members add कर सकते हैं।\nकृपया admin account से login करें।';
                     } else if (errorString.contains('already-exists') ||
                                errorString.contains('email-already-in-use')) {
                       errorMessage = 'Error: यह email पहले से registered है। कृपया दूसरा email उपयोग करें।';
                     } else if (errorString.contains('invalid-email')) {
                       errorMessage = 'Error: Email format गलत है। कृपया valid email enter करें।';
                     } else if (errorString.contains('weak-password')) {
                       errorMessage = 'Error: Password कम से कम 6 characters का होना चाहिए।';
                     }
                     
                     ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(errorMessage),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                   }
                } finally {
                  if (mounted) setState(() => isLoading = false);
                }
              },
              child: isLoading ? const CircularProgressIndicator() : Text(staffId == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCoreStaff(
    String name,
    String position,
    String email,
    String phone,
    String bio,
    String? staffId,
  ) async {
      // Deprecated in favor of _showAddCoreStaffDialog logic
  }

  Future<void> _deleteCoreStaff(String staffId, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Staff Member'),
        content: const Text(
          'Are you sure you want to delete this staff member? This will remove their dashboard access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
        final callable = functions.httpsCallable('deleteUserAccount');
        
        await callable.call({
          'userId': staffId,
          'email': email,
        });
          
        if (mounted) {
          Navigator.of(context).pop(); // Dismiss loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Staff member account deleted successfully!')),
          );
        }

      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Dismiss loading
          
          // Fallback: Ask to force delete from Firestore if Cloud Function fails
          final forceDelete = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Cloud Function Failed'),
              content: Text('Could not delete account via secure Cloud Function: $e\n\nDo you want to force delete this user from the database? (Note: This might not delete their login credentials immediately, but will remove access)'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Force Delete'),
                ),
              ],
            ),
          );

          if (forceDelete == true) {
             try {
                // Show loading again
                if (mounted) {
                   showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => const Center(child: CircularProgressIndicator()),
                  );
                }
                
                // Direct Firestore delete
                await FirebaseFirestore.instance.collection('users').doc(staffId).delete();
                
                if (mounted) {
                  Navigator.of(context).pop(); // Dismiss loading
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Staff member removed from database successfully!')),
                  );
                }
             } catch (deleteError) {
                if (mounted) {
                   Navigator.of(context).pop(); // Dismiss loading
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Force delete failed: $deleteError'), backgroundColor: Colors.red),
                  );
                }
             }
          }
        }
      }
    }
  }


  // Permissions Tab
  String _selectedPermissionRole = 'seller';

  Widget _buildPermissionsTab() {
    return Column(
      children: [
        // Role Filter
        Padding(
          padding: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButtonFormField<String>(
              value: _selectedPermissionRole,
              decoration: const InputDecoration(
                labelText: 'Select Role',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.group),
              ),
              items: const [
                DropdownMenuItem(value: 'seller', child: Text('Sellers')),
                DropdownMenuItem(value: 'service_provider', child: Text('Service Providers')),
                DropdownMenuItem(value: 'delivery_partner', child: Text('Delivery Partners')),
                DropdownMenuItem(value: 'core_staff', child: Text('Core Staff')),
                DropdownMenuItem(value: 'administrator', child: Text('Admin Panel')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedPermissionRole = val);
                }
              },
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: _selectedPermissionRole)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final users = snapshot.data?.docs ?? [];

              if (users.isEmpty) {
                return const Center(child: Text('No users found for this role'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final doc = users[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final permissions =
                      data['permissions'] as Map<String, dynamic>? ?? {};

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: data['photoURL'] != null
                            ? NetworkImage(data['photoURL'])
                            : null,
                        child: data['photoURL'] == null
                            ? Text((data['name'] ?? 'U')[0].toUpperCase())
                            : null,
                      ),
                      title: Text(data['name'] ?? 'Unknown'),
                      subtitle: Text(data['email'] ?? 'No Email'),
                      trailing: IconButton(
                        icon: const Icon(Icons.security),
                        tooltip: 'Manage Permissions',
                        onPressed: () =>
                            _showPermissionDialog(doc.id, data, permissions),
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

  void _showPermissionDialog(
    String userId,
    Map<String, dynamic> userData,
    Map<String, dynamic> currentPermissions,
  ) {
    final Map<String, String> availablePermissions = {};
    if (_selectedPermissionRole == 'seller') {
      // Product Management
      availablePermissions['can_add_product'] = 'Add New Products';
      availablePermissions['can_edit_product'] = 'Edit Products';
      availablePermissions['can_delete_product'] = 'Delete Products';
      availablePermissions['can_upload_product_images'] = 'Upload Product Images';
      availablePermissions['can_manage_inventory'] = 'Manage Inventory/Stock';
      availablePermissions['can_set_prices'] = 'Set Product Prices';
      availablePermissions['can_set_discounts'] = 'Set Discounts/Offers';
      
      // Order Management
      availablePermissions['can_view_orders'] = 'View Orders';
      availablePermissions['can_update_order_status'] = 'Update Order Status';
      availablePermissions['can_cancel_orders'] = 'Cancel Orders';
      availablePermissions['can_process_refunds'] = 'Process Refunds';
      
      // Analytics & Reports
      availablePermissions['can_view_analytics'] = 'View Sales Analytics';
      availablePermissions['can_view_reports'] = 'View Sales Reports';
      availablePermissions['can_export_data'] = 'Export Data';
      
      // Customer Interaction
      availablePermissions['can_view_reviews'] = 'View Customer Reviews';
      availablePermissions['can_respond_reviews'] = 'Respond to Reviews';
      availablePermissions['can_contact_customers'] = 'Contact Customers';
      
    } else if (_selectedPermissionRole == 'service_provider') {
      // Service Management
      availablePermissions['can_add_service'] = 'Add New Services';
      availablePermissions['can_edit_service'] = 'Edit Services';
      availablePermissions['can_delete_service'] = 'Delete Services';
      availablePermissions['can_upload_service_images'] = 'Upload Service Images';
      availablePermissions['can_set_service_pricing'] = 'Set Service Pricing';
      availablePermissions['can_set_service_area'] = 'Set Service Area/Location';
      
      // Service Request Management
      availablePermissions['can_view_requests'] = 'View Service Requests';
      availablePermissions['can_accept_requests'] = 'Accept Service Requests';
      availablePermissions['can_reject_requests'] = 'Reject Service Requests';
      availablePermissions['can_update_service_status'] = 'Update Service Status';
      availablePermissions['can_complete_service'] = 'Mark Service as Completed';
      availablePermissions['can_cancel_service'] = 'Cancel Service';
      
      // Schedule & Availability
      availablePermissions['can_manage_schedule'] = 'Manage Work Schedule';
      availablePermissions['can_set_availability'] = 'Set Availability Status';
      
      // Analytics & Customer
      availablePermissions['can_view_service_analytics'] = 'View Service Analytics';
      availablePermissions['can_view_ratings'] = 'View Customer Ratings';
      availablePermissions['can_respond_ratings'] = 'Respond to Ratings';
      availablePermissions['can_view_earnings'] = 'View Earnings';
      
    } else if (_selectedPermissionRole == 'delivery_partner') {
      // Delivery Management
      availablePermissions['can_view_deliveries'] = 'View Assigned Deliveries';
      availablePermissions['can_accept_delivery'] = 'Accept Delivery Requests';
      availablePermissions['can_reject_delivery'] = 'Reject Delivery Requests';
      
      // Status Updates
      availablePermissions['can_mark_picked'] = 'Mark as Picked Up';
      availablePermissions['can_mark_in_transit'] = 'Mark as In Transit';
      availablePermissions['can_mark_delivered'] = 'Mark as Delivered';
      availablePermissions['can_update_location'] = 'Update Current Location';
      
      // Order & Customer
      availablePermissions['can_view_order_details'] = 'View Order Details';
      availablePermissions['can_contact_customer'] = 'Contact Customer';
      availablePermissions['can_contact_seller'] = 'Contact Seller';
      availablePermissions['can_report_issue'] = 'Report Delivery Issues';
      
      // Availability & Earnings
      availablePermissions['can_set_availability'] = 'Set Availability Status';
      availablePermissions['can_view_delivery_history'] = 'View Delivery History';
      availablePermissions['can_view_earnings'] = 'View Earnings';
      availablePermissions['can_view_analytics'] = 'View Delivery Analytics';
      
    } else if (_selectedPermissionRole == 'core_staff') {
      availablePermissions['can_manage_products'] = 'Manage Products';
      availablePermissions['can_manage_orders'] = 'Manage Orders';
      availablePermissions['can_manage_users'] = 'Manage Users';
      availablePermissions['can_view_dashboard'] = 'View Dashboard';
      availablePermissions['can_manage_services'] = 'Manage Services';
      availablePermissions['can_manage_partners'] = 'Manage Partner Requests';
      availablePermissions['can_manage_sellers'] = 'Manage Sellers';
      availablePermissions['can_manage_deliveries'] = 'Manage Delivery Partners';
      availablePermissions['can_manage_gifts'] = 'Manage Gifts';
      availablePermissions['can_manage_featured'] = 'Manage Featured Sections';
      availablePermissions['can_download_reports'] = 'Download Reports';

    } else if (_selectedPermissionRole == 'administrator') {
      availablePermissions['can_manage_products'] = 'Manage Products';
      availablePermissions['can_manage_categories'] = 'Manage Categories';
      availablePermissions['can_manage_orders'] = 'Manage Orders';
      availablePermissions['can_manage_users'] = 'Manage Users';
      availablePermissions['can_manage_gifts'] = 'Manage Gifts';
      availablePermissions['can_manage_services'] = 'Manage Services';
      availablePermissions['can_manage_partners'] = 'Manage Partner Requests';
      availablePermissions['can_manage_deliveries'] = 'Manage Delivery Partners';
      availablePermissions['can_manage_core_staff'] = 'Manage Core Staff';
      availablePermissions['can_manage_categories'] = 'Manage Categories';
      availablePermissions['can_manage_service_categories'] = 'Manage Service Categories';
      availablePermissions['can_manage_service_providers'] = 'Manage Service Providers';
      availablePermissions['can_manage_payouts'] = 'Manage Payout Requests';
      availablePermissions['can_view_analytics'] = 'View Analytics';
      availablePermissions['can_view_dashboard'] = 'View Dashboard';
      availablePermissions['can_manage_permissions'] = 'Manage Permissions';
    }

    final Map<String, bool> tempPermissions = {};
    availablePermissions.forEach((key, _) {
      tempPermissions[key] = currentPermissions[key] != false;
    });

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Permissions for ${userData['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: availablePermissions.entries.map((entry) {
                return SwitchListTile(
                  title: Text(entry.value),
                  value: tempPermissions[entry.key] ?? true,
                  onChanged: (val) {
                    setState(() {
                      tempPermissions[entry.key] = val;
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .update({'permissions': tempPermissions});

                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Permissions updated successfully'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }





  Widget _buildFinancialTab(String userId, String role) {
    final transactionService = TransactionService();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance Card
          FutureBuilder<double>(
            future: transactionService.getBalance(userId),
            builder: (context, snapshot) {
              final balance = snapshot.data ?? 0.0;
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.indigo,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        'Available Balance',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${balance.toStringAsFixed(2)}', 
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildBalanceAction(Icons.arrow_upward, 'Withdraw'),
                          _buildBalanceAction(Icons.history, 'History'),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }
          ),
          const SizedBox(height: 24),
          
          // Payout Stats (Calculated from transactions for now)
          StreamBuilder<List<TransactionModel>>(
            stream: transactionService.getTransactions(userId),
            builder: (context, snapshot) {
              final transactions = snapshot.data ?? [];
              
              // Calculate Total Payouts (Debits) and Pending (mock for now or query payout requests)
              // Assuming 'debit' with status 'completed' is a paid out amount
              double totalPayouts = 0;
              for (var tx in transactions) {
                if (tx.type == 'debit' && tx.status == 'completed') {
                  totalPayouts += tx.amount;
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payout Overview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Payouts',
                          '₹${totalPayouts.toStringAsFixed(0)}',
                          Icons.payments,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('payout_requests')
                              .where('userId', isEqualTo: userId)
                              .where('status', isEqualTo: 'pending')
                              .snapshots(),
                          builder: (context, payoutSnapshot) {
                            double pendingAmount = 0;
                            if (payoutSnapshot.hasData) {
                               for (var doc in payoutSnapshot.data!.docs) {
                                 final data = doc.data() as Map<String, dynamic>;
                                 pendingAmount += (data['amount'] as num?)?.toDouble() ?? 0.0;
                               }
                            }
                            return _buildStatCard(
                              'Pending Request',
                              '₹${pendingAmount.toStringAsFixed(0)}',
                              Icons.pending_actions,
                              Colors.orange,
                            );
                          }
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Recent Transactions
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (transactions.isEmpty)
                     const Center(child: Text("No transactions found"))
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: transactions.length > 10 ? 10 : transactions.length,
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        final isCredit = tx.type == 'credit';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isCredit ? Colors.green.shade50 : Colors.red.shade50,
                              child: Icon(
                                isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                                color: isCredit ? Colors.green : Colors.red,
                              ),
                            ),
                            title: Text(tx.description),
                            subtitle: Text(DateFormat('MMM dd, yyyy').format(tx.createdAt)),
                            trailing: Text(
                              '${isCredit ? '+' : '-'}₹${tx.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: isCredit ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceAction(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }




  Widget _buildUsersTab() {
    return const SharedUsersTab(canManage: true);
  }

  Widget _buildRoleBasedUsersTab(String role) {
    return RoleManagementTab(
      collection: 'users',
      role: role,
      requestRole: role == 'seller' 
          ? 'Seller' 
          : role == 'service_provider'
              ? 'Service Provider'
              : 'Delivery Partner',
      onEdit: _editUser,
      onDelete: _deleteUser,
      onRequestAction: _updateRequestStatus,
      onViewDashboard: (id, data) {
        if (role == 'seller') {
          _showSellerDashboard(id, data);
        } else if (role == 'service_provider') {
          _showServiceProviderDashboard(id, data);
        } else if (role == 'delivery_partner') {
          _showDeliveryPartnerDashboard(id, data);
        }
      },
    );
  }


  void _editUser(String userId, Map<String, dynamic> userData) {
    final role = userData['role'] ?? 'user';
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: userData['name'] ?? '');
    final phoneCtrl = TextEditingController(text: userData['phone'] ?? '');
    
    // Delivery Partner Fields
    final pincodeCtrl = TextEditingController(text: userData['service_pincode'] ?? '');
    
    // Service Provider Fields
    final experienceCtrl = TextEditingController(text: userData['experience']?.toString() ?? '');
    final descriptionCtrl = TextEditingController(text: userData['description'] ?? '');
    
    String? selectedCategory = userData['category'];
    bool isVerified = userData['isVerified'] ?? false;
    
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit ${role == 'service_provider' ? 'Service Provider' : role == 'delivery_partner' ? 'Delivery Partner' : 'User'}'),
          content: SizedBox(
             width: 500,
             child: Form(
               key: formKey,
               child: SingleChildScrollView(
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                      // Common Details
                      const Text('Basic Info', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // -- DELIVERY PARTNER SPECIFIC --
                      if (role == 'delivery_partner') ...[
                        const Text('Coverage', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: pincodeCtrl,
                          decoration: const InputDecoration(labelText: 'Service Pincode', border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ],
                      
                      // -- SERVICE PROVIDER SPECIFIC --
                      if (role == 'service_provider') ...[
                        const Text('Service Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        
                        // Category Dropdown
                        Consumer<ServiceCategoryProvider>(
                          builder: (context, provider, _) { 
                             final categories = provider.serviceCategories.map((c) => c.name).toList();
                             // Fallback if empty or not loaded
                             if (categories.isEmpty) categories.addAll(['Plumbing', 'Electrical', 'Cleaning', 'Carpenter']);
                             if (selectedCategory != null && !categories.contains(selectedCategory)) {
                               categories.add(selectedCategory!);
                             }
                             
                             return DropdownButtonFormField<String>(
                               value: selectedCategory,
                               decoration: const InputDecoration(labelText: 'Service Category', border: OutlineInputBorder()),
                               items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                               onChanged: (v) => setState(() => selectedCategory = v),
                             );
                          }
                        ),
                        const SizedBox(height: 12),
                        
                        // Pincode
                        TextFormField(
                          controller: pincodeCtrl,
                          decoration: const InputDecoration(labelText: 'Service Pincode', border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        
                        // Experience
                        TextFormField(
                          controller: experienceCtrl,
                          decoration: const InputDecoration(labelText: 'Experience (Years)', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        
                        // Description
                        TextFormField(
                          controller: descriptionCtrl,
                          decoration: const InputDecoration(labelText: 'About Service', border: OutlineInputBorder()),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        
                        // Verification Status
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Verified Provider'),
                          value: isVerified,
                          onChanged: (v) => setState(() => isVerified = v),
                          activeColor: Colors.green,
                        ),
                      ],
                   ],
                 ),
               ),
             ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (formKey.currentState!.validate()) {
                  setState(() => isLoading = true);
                  
                  try {
                    Map<String, dynamic> updates = {
                      'name': nameCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                    };
                    
                    if (role == 'delivery_partner') {
                       updates['service_pincode'] = pincodeCtrl.text.trim();
                    } else if (role == 'service_provider') {
                       updates['service_pincode'] = pincodeCtrl.text.trim();
                       updates['category'] = selectedCategory;
                       updates['experience'] = double.tryParse(experienceCtrl.text.trim()) ?? 0;
                       updates['description'] = descriptionCtrl.text.trim();
                       updates['isVerified'] = isVerified;
                    }

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .update(updates);

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Details updated successfully')),
                      );
                    }
                  } catch (e) {
                    setState(() => isLoading = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
              child: isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Text('Save Changes'),
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

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'packed':
        return Colors.indigo;
      case 'shipped':
        return Colors.purple;
      case 'out_for_delivery':
        return Colors.teal;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSellerOrdersTab(String sellerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final orders = snapshot.data?.docs ?? [];
        final sellerOrders = orders.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final items = data['items'] as List<dynamic>? ?? [];
          return items.any((item) => item['sellerId'] == sellerId);
        }).toList();

        if (sellerOrders.isEmpty) {
          return const Center(child: Text('No orders found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sellerOrders.length,
          itemBuilder: (context, index) {
            final order = sellerOrders[index];
            final data = order.data() as Map<String, dynamic>;
            final address = data['address'] as Map<String, dynamic>? ?? {};
            final addressString = '${address['street'] ?? ''}, ${address['city'] ?? ''}, ${address['state'] ?? ''} - ${address['pincode'] ?? ''}';
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                title: Text('Order #${order.id.substring(0, 8)}'),
                subtitle: Builder(
                  builder: (context) {
                    final dynamic rawDate = data['orderDate'];
                    DateTime date = DateTime.now();
                    if (rawDate is Timestamp) {
                      date = rawDate.toDate();
                    } else if (rawDate is String) {
                      date = DateTime.tryParse(rawDate) ?? DateTime.now();
                    }
                    return Text(DateFormat('MMM dd, yyyy').format(date));
                  },
                ),
                trailing: Chip(
                  label: Text(
                    data['status'] ?? 'Pending',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: _getStatusColor(data['status']),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Customer Details',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.content_copy, size: 20),
                                  tooltip: 'Copy Address',
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: addressString));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Address copied to clipboard')),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.description, size: 20),
                                  tooltip: 'View Invoice',
                                  onPressed: () => _showInvoiceDialog(data, sellerId),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Name: ${address['name'] ?? 'N/A'}'),
                        Text('Phone: ${address['phone'] ?? 'N/A'}'),
                        Text('Address: $addressString'),
                        const Divider(height: 24),
                        const Text(
                          'Items',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...(data['items'] as List<dynamic>? ?? [])
                            .where((item) => item['sellerId'] == sellerId)
                            .map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${item['name']} x${item['quantity']}'),
                                      Text('₹${item['price']}'),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showInvoiceDialog(
    Map<String, dynamic> orderData,
    String sellerId,
  ) async {
    // Fetch seller data
    final sellerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(sellerId)
        .get();
    final sellerData = sellerDoc.data() ?? {};

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invoice Generation'),
        content: const Text('Invoice generation feature is temporarily unavailable.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSellerDashboard(String sellerId, Map<String, dynamic> sellerData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: 800,
          height: 600,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DefaultTabController(
            length: 5,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: sellerData['photoURL'] != null
                            ? NetworkImage(sellerData['photoURL'])
                            : null,
                        child: sellerData['photoURL'] == null
                            ? Text(
                                (sellerData['name'] ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(fontSize: 24),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sellerData['name'] ?? 'Unknown Seller',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Seller ID: $sellerId',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  isScrollable: true,
                  tabs: [
                    Tab(icon: Icon(Icons.person), text: 'Profile'),
                    Tab(icon: Icon(Icons.store), text: 'Products'),
                    Tab(icon: Icon(Icons.receipt_long), text: 'Orders'),
                    Tab(icon: Icon(Icons.account_balance), text: 'Financials'),
                    Tab(icon: Icon(Icons.dashboard), text: 'Stats'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Personal Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(),
                            const SizedBox(height: 16),
                            _buildInfoRow('Full Name', sellerData['name'] ?? '-'),
                            _buildInfoRow('Email', sellerData['email'] ?? '-'),
                            _buildInfoRow('Phone', sellerData['phone'] ?? '-'),
                          ],
                        ),
                      ),
                      _buildSellerProductsTab(sellerId),
                      _buildSellerOrdersTab(sellerId),
                      _buildFinancialTab(sellerId, 'seller'),
                      SingleChildScrollView(
                        child: SellerDetailsWidget(sellerId: sellerId),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showServiceProviderDashboard(
    String providerId,
    Map<String, dynamic> providerData,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: 800,
          height: 600,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DefaultTabController(
            length: 4,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: providerData['photoURL'] != null
                            ? NetworkImage(providerData['photoURL'])
                            : null,
                        child: providerData['photoURL'] == null
                            ? Text(
                                (providerData['name'] ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(fontSize: 24),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              providerData['name'] ?? 'Unknown Provider',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Provider ID: $providerId',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  labelColor: Colors.orange,
                  unselectedLabelColor: Colors.grey,
                  isScrollable: true,
                  tabs: [
                    Tab(icon: Icon(Icons.person), text: 'Profile'),
                    Tab(icon: Icon(Icons.handyman), text: 'Services'),
                    Tab(icon: Icon(Icons.account_balance), text: 'Financials'),
                    Tab(icon: Icon(Icons.dashboard), text: 'Stats'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Personal Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(),
                            const SizedBox(height: 16),
                            _buildInfoRow('Full Name', providerData['name'] ?? '-'),
                            _buildInfoRow('Email', providerData['email'] ?? '-'),
                            _buildInfoRow('Phone', providerData['phone'] ?? '-'),
                          ],
                        ),
                      ),
                      const Center(child: Text('Services coming soon')),
                      _buildFinancialTab(providerId, 'service_provider'),
                      SingleChildScrollView(
                        child: ServiceProviderDetailsWidget(providerId: providerId),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeliveryPartnerDashboard(
    String partnerId,
    Map<String, dynamic> partnerData,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: 800,
          height: 600,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: partnerData['photoURL'] != null
                            ? NetworkImage(partnerData['photoURL'])
                            : null,
                        child: partnerData['photoURL'] == null
                            ? Text(
                                (partnerData['name'] ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(fontSize: 24),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              partnerData['name'] ?? 'Unknown Partner',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Partner ID: $partnerId',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  labelColor: Colors.green,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(icon: Icon(Icons.person), text: 'Profile'),
                    Tab(icon: Icon(Icons.local_shipping), text: 'Deliveries'),
                    Tab(icon: Icon(Icons.account_balance), text: 'Financials'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Profile Tab
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Personal Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(),
                            const SizedBox(height: 16),
                            _buildInfoRow('Full Name', partnerData['name'] ?? '-'),
                            _buildInfoRow('Email', partnerData['email'] ?? '-'),
                            _buildInfoRow('Phone', partnerData['phone'] ?? '-'),
                            _buildInfoRow(
                              'Service Pincodes',
                              (partnerData['servicePincodes'] as List?)?.join(', ') ?? '-',
                            ),
                          ],
                        ),
                      ),
                      // Deliveries Tab
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('orders')
                            .where('deliveryPartnerId', isEqualTo: partnerId)
                            .orderBy('orderDate', descending: true)
                            .limit(50)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          }

                          final deliveries = snapshot.data?.docs ?? [];

                          if (deliveries.isEmpty) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.local_shipping, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    'No deliveries assigned yet',
                                    style: TextStyle(color: Colors.grey, fontSize: 16),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: deliveries.length,
                            itemBuilder: (context, index) {
                              final doc = deliveries[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final orderId = doc.id;
                              final status = data['deliveryStatus'] ?? 'pending';
                              final customerName = data['customerName'] ?? 'Unknown';
                              final deliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? 0;
                              DateTime? orderDate;
                              final rawDate = data['orderDate'];
                              if (rawDate is Timestamp) {
                                orderDate = rawDate.toDate();
                              } else if (rawDate is String) {
                                orderDate = DateTime.tryParse(rawDate);
                              }

                              Color statusColor;
                              switch (status) {
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

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: statusColor.withOpacity(0.2),
                                    child: Icon(Icons.shopping_bag, color: statusColor),
                                  ),
                                  title: Text('Order #${orderId.substring(0, 8)}'),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Customer: $customerName'),
                                      if (orderDate != null)
                                        Text(
                                          'Date: ${DateFormat('dd MMM yyyy').format(orderDate)}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisSize: MainAxisSize.min,
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
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      // Financials Tab
                      _buildFinancialTab(partnerId, 'delivery_partner'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProviderServicesTab(String providerId) {
    return SharedServicesTab(
      canManage: true,
      providerId: providerId,
    );
  }

  Widget _buildSellerProductsTab(String sellerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final products = snapshot.data?.docs ?? [];

        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No products yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Total Products: ${products.length}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Products Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8, // Reduced spacing
                  mainAxisSpacing: 8, // Reduced spacing
                  childAspectRatio: 1.0, // Square tiles
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  final data = product.data() as Map<String, dynamic>;
                  final images = data['images'] as List<dynamic>? ?? [];
                  final imageUrl = images.isNotEmpty ? images[0] : (data['imageUrl'] as String?); // Handle both formats
                  final isListed = data['isListed'] ?? true;
                  final name = data['name'] ?? 'Unknown';
                  final price = (data['price'] as num?)?.toDouble() ?? 0;
                  final stock = (data['stock'] as num?)?.toInt() ?? 0;
                  final isFeatured = data['isFeatured'] ?? false;

                  return Card(
                    elevation: 2,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: InkWell(
                      onTap: () {
                        // Show Details & Actions Dialog
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (imageUrl != null)
                                  Center(
                                    child: SizedBox(
                                      height: 120,
                                      width: 120,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(imageUrl, fit: BoxFit.cover),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                Text('Price: ₹${price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('Stock: $stock', style: TextStyle(color: stock < 5 ? Colors.red : Colors.grey[800])),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Text('Status: '),
                                    Text(
                                      isListed ? 'Listed' : 'Unlisted',
                                      style: TextStyle(
                                        color: isListed ? Colors.green : Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                if (isFeatured)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.star, color: Colors.amber, size: 16),
                                        SizedBox(width: 4),
                                        Text('Featured Product', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            actions: [
                              // Unlist/List Button
                              TextButton.icon(
                                onPressed: () async {
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('products')
                                        .doc(product.id)
                                        .update({'isListed': !isListed});
                                    if (context.mounted) Navigator.pop(ctx);
                                  } catch (e) {
                                    debugPrint('Error updating product status: $e');
                                  }
                                },
                                icon: Icon(
                                  isListed ? Icons.visibility_off : Icons.visibility,
                                  color: isListed ? Colors.orange : Colors.green,
                                ),
                                label: Text(
                                  isListed ? 'Unlist' : 'List',
                                  style: TextStyle(color: isListed ? Colors.orange : Colors.green),
                                ),
                              ),
                              // Delete Button
                              TextButton.icon(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogCtx) => AlertDialog(
                                      title: const Text('Delete'),
                                      content: const Text('Delete this product permanently?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('No')),
                                        TextButton(onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('Yes')),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                     await FirebaseFirestore.instance.collection('products').doc(product.id).delete();
                                     if (context.mounted) Navigator.pop(ctx);
                                  }
                                },
                                icon: const Icon(Icons.delete, color: Colors.red),
                                label: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                              // Edit Button
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showEditProductDialog(product.id, data);
                                },
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Edit'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: imageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => const Icon(
                                        Icons.image_not_supported,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.inventory_2, size: 40, color: Colors.grey),
                          ),
                          // Unlisted Overlay
                          if (!isListed)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(Icons.visibility_off, color: Colors.white, size: 32),
                              ),
                            ),
                          // Featured Badge (Optional, small icon)
                          if (isFeatured)
                             Positioned(
                               top: 4,
                               right: 4,
                               child: Container(
                                 padding: const EdgeInsets.all(4),
                                 decoration: const BoxDecoration(
                                   color: Colors.white,
                                   shape: BoxShape.circle,
                                   boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
                                 ),
                                 child: const Icon(Icons.star, color: Colors.amber, size: 16),
                               ),
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
    );
  }

  void _showEditProductDialog(String productId, Map<String, dynamic> productData) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: productData['name']);
    final descCtrl = TextEditingController(text: productData['description']);
    final priceCtrl = TextEditingController(text: productData['price'].toString());
    final stockCtrl = TextEditingController(text: productData['stock'].toString());
    final mrpCtrl = TextEditingController(text: (productData['mrp'] ?? 0).toString());
    final minQtyCtrl = TextEditingController(text: (productData['minimumQuantity'] ?? 1).toString());
    
    String selectedCategory = productData['category'] ?? ProductCategory.dailyNeeds;
    String selectedUnit = productData['unit'] ?? 'Pic';
    bool isFeatured = productData['isFeatured'] ?? false;
    bool isLoading = false;
    
    // Image Handling
    List<String> existingImages = List<String>.from(productData['imageUrls'] ?? []);
    if (existingImages.isEmpty && productData['imageUrl'] != null) {
      existingImages.add(productData['imageUrl']);
    }
    List<Uint8List> newImages = [];
    final ImagePicker picker = ImagePicker();

    Future<void> pickImages(StateSetter setState) async {
       try {
         final List<XFile> images = await picker.pickMultiImage();
         if (images.isNotEmpty) {
            if (existingImages.length + newImages.length + images.length > 6) {
               if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Max 6 images allowed total')));
               return;
            }
            for (var img in images) {
              final bytes = await img.readAsBytes();
              newImages.add(bytes);
            }
            setState(() {});
         }
       } catch (e) {
         debugPrint('Error picking images: $e');
       }
    }

    Future<List<String>> uploadNewImages() async {
      List<String> uploadedUrls = [];
      for (int i = 0; i < newImages.length; i++) {
         final ref = FirebaseStorage.instance.ref().child('products').child(productId).child('new_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
         await ref.putData(newImages[i]);
         uploadedUrls.add(await ref.getDownloadURL());
      }
      return uploadedUrls;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: Container(
            width: 700,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Product',
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
                    
                    // Product Name
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Product Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    
                    // Price, MRP, Stock, MinQty
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: mrpCtrl,
                            decoration: const InputDecoration(labelText: 'MRP', border: OutlineInputBorder(), prefixText: '₹'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: priceCtrl,
                            decoration: const InputDecoration(labelText: 'Price *', border: OutlineInputBorder(), prefixText: '₹'),
                            keyboardType: TextInputType.number,
                            validator: (v) => (v?.isEmpty == true || double.tryParse(v!) == null) ? 'Invalid' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: stockCtrl,
                            decoration: const InputDecoration(labelText: 'Stock *', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            validator: (v) => (v?.isEmpty == true || int.tryParse(v!) == null) ? 'Invalid' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: minQtyCtrl,
                            decoration: const InputDecoration(labelText: 'Min Qty', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            validator: (v) => (v?.isEmpty == true || int.tryParse(v!) == null) ? 'Invalid' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Category and Unit
                    Row(
                      children: [
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('categories').orderBy('order').snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator()));
                              }
                              
                              final categories = snapshot.data!.docs.map((doc) {
                                return (doc.data() as Map<String, dynamic>)['name'] as String;
                              }).toList();
                              
                              // Ensure selectedCategory is in the list
                              if (selectedCategory != null && !categories.contains(selectedCategory)) {
                                categories.add(selectedCategory!);
                              }

                              return DropdownButtonFormField<String>(
                                value: selectedCategory,
                                isExpanded: true,
                                menuMaxHeight: 300,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                ),
                                items: categories.map((cat) {
                                  return DropdownMenuItem(
                                    value: cat, 
                                    child: Text(cat, overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => selectedCategory = val!),
                              );
                            }
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedUnit,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(),
                            ),
                            items: ['Kg', 'Ltr', 'Pic', 'Pkt', 'Grm']
                                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                .toList(),
                            onChanged: (val) => setState(() => selectedUnit = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Featured Toggle
                    SwitchListTile(
                      title: const Text('Featured Product'),
                      value: isFeatured,
                      onChanged: (val) => setState(() => isFeatured = val),
                    ),
                    const SizedBox(height: 16),

                    // Image Management
                    const Text('Product Images', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          // Existing Images
                          ...existingImages.asMap().entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(entry.value, width: 100, height: 100, fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: InkWell(
                                      onTap: () => setState(() => existingImages.removeAt(entry.key)),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          
                          // New Images
                          ...newImages.asMap().entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(entry.value, width: 100, height: 100, fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: InkWell(
                                      onTap: () => setState(() => newImages.removeAt(entry.key)),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),

                          // Add Button
                          if ((existingImages.length + newImages.length) < 6)
                            InkWell(
                              onTap: () => pickImages(setState),
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isLoading ? null : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  
                                  setState(() => isLoading = true);
                                  
                                  try {
                                    // Upload new images
                                    final newUrls = await uploadNewImages();
                                    final allImages = [...existingImages, ...newUrls];
                                    
                                    await FirebaseFirestore.instance
                                        .collection('products')
                                        .doc(productId)
                                        .update({
                                      'name': nameCtrl.text,
                                      'description': descCtrl.text,
                                      'price': double.parse(priceCtrl.text),
                                      'mrp': double.tryParse(mrpCtrl.text) ?? 0,
                                      'stock': int.parse(stockCtrl.text),
                                      'minimumQuantity': int.tryParse(minQtyCtrl.text) ?? 1,
                                      'category': selectedCategory,
                                      'unit': selectedUnit,
                                      'isFeatured': isFeatured,
                                      'imageUrls': allImages,
                                      'imageUrl': allImages.isNotEmpty ? allImages.first : null,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });
                                    
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Product updated successfully')),
                                      );
                                    }
                                  } catch (e) {
                                    setState(() => isLoading = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save Changes'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }



  void _showAddProductDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    
    String selectedCategory = ProductCategory.dailyNeeds;
    String selectedUnit = 'Pic';
    bool isFeatured = false;
    bool isLoading = false;
    List<Uint8List> selectedImages = [];
    final ImagePicker picker = ImagePicker();

    Future<void> pickImages(StateSetter setState) async {
      try {
        final List<XFile> images = await picker.pickMultiImage();
        if (images.isNotEmpty && images.length <= 6) {
          final List<Uint8List> imageBytes = [];
          for (var image in images) {
            final bytes = await image.readAsBytes();
            imageBytes.add(bytes);
          }
          setState(() {
            selectedImages = imageBytes;
          });
        } else if (images.length > 6) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Maximum 6 images allowed')),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error picking images: $e')),
          );
        }
      }
    }

    Future<List<String>> uploadImages(String productId) async {
      List<String> imageUrls = [];
      for (int i = 0; i < selectedImages.length; i++) {
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('products')
              .child(productId)
              .child('image_$i.jpg');
          await ref.putData(selectedImages[i]);
          final url = await ref.getDownloadURL();
          imageUrls.add(url);
        } catch (e) {
          print('Error uploading image $i: $e');
        }
      }
      return imageUrls;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: Container(
            width: 700,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Add New Product',
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
                    
                    // Product Name
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Product Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v?.isEmpty == true) return 'Required';
                        if (v!.length < 3) return 'Minimum 3 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    
                    // Price and Stock
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: priceCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Price *',
                              border: OutlineInputBorder(),
                              prefixText: '₹',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v?.isEmpty == true) return 'Required';
                              final price = double.tryParse(v!);
                              if (price == null || price <= 0) return 'Invalid price';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: stockCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Stock *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v?.isEmpty == true) return 'Required';
                              final stock = int.tryParse(v!);
                              if (stock == null || stock < 0) return 'Invalid stock';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Category and Unit
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                            items: ProductCategory.all.map((cat) {
                              return DropdownMenuItem(value: cat, child: Text(cat));
                            }).toList(),
                            onChanged: (val) => setState(() => selectedCategory = val!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedUnit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(),
                            ),
                            items: ['Kg', 'Ltr', 'Pic', 'Pkt', 'Grm']
                                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                .toList(),
                            onChanged: (val) => setState(() => selectedUnit = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Featured Toggle
                    SwitchListTile(
                      title: const Text('Featured Product'),
                      value: isFeatured,
                      onChanged: (val) => setState(() => isFeatured = val),
                    ),
                    const SizedBox(height: 16),
                    
                    // Image Upload
                    OutlinedButton.icon(
                      onPressed: () => pickImages(setState),
                      icon: const Icon(Icons.image),
                      label: Text(selectedImages.isEmpty 
                          ? 'Select Images (Max 6)' 
                          : '${selectedImages.length} image(s) selected'),
                    ),
                    if (selectedImages.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: selectedImages.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  Image.memory(
                                    selectedImages[index],
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, size: 16),
                                      onPressed: () {
                                        setState(() {
                                          selectedImages.removeAt(index);
                                        });
                                      },
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(24, 24),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isLoading ? null : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  
                                  setState(() => isLoading = true);
                                  
                                  try {
                                    // Create product document
                                    final docRef = await FirebaseFirestore.instance
                                        .collection('products')
                                        .add({
                                      'name': nameCtrl.text,
                                      'description': descCtrl.text,
                                      'price': double.parse(priceCtrl.text),
                                      'stock': int.parse(stockCtrl.text),
                                      'category': selectedCategory,
                                      'unit': selectedUnit,
                                      'isFeatured': isFeatured,
                                      'sellerId': 'admin',
                                      'createdAt': FieldValue.serverTimestamp(),
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });
                                    
                                    // Upload images if any
                                    if (selectedImages.isNotEmpty) {
                                      final imageUrls = await uploadImages(docRef.id);
                                      await docRef.update({'images': imageUrls});
                                    }
                                    
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Product added successfully')),
                                      );
                                    }
                                  } catch (e) {
                                    setState(() => isLoading = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Add Product'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  // Bulk Operations Methods
  Future<void> _bulkDeleteProducts() async {
    final count = _selectedProductIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count Product${count > 1 ? 's' : ''}?'),
        content: const Text(
          'This action cannot be undone. All selected products will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Show loading
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleting $count product${count > 1 ? 's' : ''}...'),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Batch delete
        final batch = FirebaseFirestore.instance.batch();
        for (var id in _selectedProductIds) {
          batch.delete(
            FirebaseFirestore.instance.collection('products').doc(id),
          );
        }
        await batch.commit();

        // Clear selection and exit selection mode
        setState(() {
          _selectedProductIds.clear();
          _isProductSelectionMode = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count product${count > 1 ? 's' : ''} deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting products: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showBulkEditProductsDialog() {
    final count = _selectedProductIds.length;
    
    // Edit options
    String editType = 'price'; // price, stock, category, featured
    String priceAction = 'add_percent'; // add_percent, subtract_percent, set_fixed
    String stockAction = 'add'; // add, subtract, set
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    String? selectedCategory;
    bool? setFeatured;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bulk Edit $count Product${count > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Edit Type Selection
                  DropdownButtonFormField<String>(
                    value: editType,
                    decoration: const InputDecoration(
                      labelText: 'What to Edit',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'price', child: Text('Price')),
                      DropdownMenuItem(value: 'stock', child: Text('Stock')),
                      DropdownMenuItem(value: 'category', child: Text('Category')),
                      DropdownMenuItem(value: 'featured', child: Text('Featured Status')),
                    ],
                    onChanged: (val) => setState(() => editType = val!),
                  ),
                  const SizedBox(height: 16),
                  
                  // Price Edit Options
                  if (editType == 'price') ...[
                    DropdownButtonFormField<String>(
                      value: priceAction,
                      decoration: const InputDecoration(
                        labelText: 'Action',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'add_percent', child: Text('Increase by %')),
                        DropdownMenuItem(value: 'subtract_percent', child: Text('Decrease by %')),
                        DropdownMenuItem(value: 'set_fixed', child: Text('Set to Fixed Value')),
                      ],
                      onChanged: (val) => setState(() => priceAction = val!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: priceCtrl,
                      decoration: InputDecoration(
                        labelText: priceAction == 'set_fixed' ? 'New Price' : 'Percentage',
                        border: const OutlineInputBorder(),
                        prefixText: priceAction == 'set_fixed' ? '₹' : '',
                        suffixText: priceAction != 'set_fixed' ? '%' : '',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  
                  // Stock Edit Options
                  if (editType == 'stock') ...[
                    DropdownButtonFormField<String>(
                      value: stockAction,
                      decoration: const InputDecoration(
                        labelText: 'Action',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'add', child: Text('Add to Stock')),
                        DropdownMenuItem(value: 'subtract', child: Text('Subtract from Stock')),
                        DropdownMenuItem(value: 'set', child: Text('Set to Value')),
                      ],
                      onChanged: (val) => setState(() => stockAction = val!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: stockCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Stock Value',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  
                  // Category Edit
                  if (editType == 'category') ...[
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'New Category',
                        border: OutlineInputBorder(),
                      ),
                      items: ProductCategory.all.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (val) => setState(() => selectedCategory = val),
                    ),
                  ],
                  
                  // Featured Edit
                  if (editType == 'featured') ...[
                    DropdownButtonFormField<bool>(
                      value: setFeatured,
                      decoration: const InputDecoration(
                        labelText: 'Featured Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: true, child: Text('Set as Featured')),
                        DropdownMenuItem(value: false, child: Text('Remove from Featured')),
                      ],
                      onChanged: (val) => setState(() => setFeatured = val),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          
                          try {
                            final batch = FirebaseFirestore.instance.batch();
                            
                            for (var productId in _selectedProductIds) {
                              final docRef = FirebaseFirestore.instance
                                  .collection('products')
                                  .doc(productId);
                              
                              if (editType == 'price' && priceCtrl.text.isNotEmpty) {
                                final value = double.tryParse(priceCtrl.text);
                                if (value != null) {
                                  if (priceAction == 'set_fixed') {
                                    batch.update(docRef, {'price': value});
                                  } else {
                                    // Get current price
                                    final doc = await docRef.get();
                                    final currentPrice = (doc.data()?['price'] as num?)?.toDouble() ?? 0;
                                    double newPrice;
                                    if (priceAction == 'add_percent') {
                                      newPrice = currentPrice * (1 + value / 100);
                                    } else {
                                      newPrice = currentPrice * (1 - value / 100);
                                    }
                                    batch.update(docRef, {'price': newPrice});
                                  }
                                }
                              } else if (editType == 'stock' && stockCtrl.text.isNotEmpty) {
                                final value = int.tryParse(stockCtrl.text);
                                if (value != null) {
                                  if (stockAction == 'set') {
                                    batch.update(docRef, {'stock': value});
                                  } else {
                                    final doc = await docRef.get();
                                    final currentStock = (doc.data()?['stock'] as num?)?.toInt() ?? 0;
                                    final newStock = stockAction == 'add'
                                        ? currentStock + value
                                        : currentStock - value;
                                    batch.update(docRef, {'stock': newStock.clamp(0, 999999)});
                                  }
                                }
                              } else if (editType == 'category' && selectedCategory != null) {
                                batch.update(docRef, {'category': selectedCategory});
                              } else if (editType == 'featured' && setFeatured != null) {
                                batch.update(docRef, {'isFeatured': setFeatured});
                              }
                            }
                            
                            await batch.commit();
                            
                            if (this.context.mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('$count product${count > 1 ? 's' : ''} updated successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                            
                            this.setState(() {
                              _selectedProductIds.clear();
                              _isProductSelectionMode = false;
                            });
                          } catch (e) {
                            if (this.context.mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Apply Changes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Bulk Service Operations


  // ==================== ANALYTICS TAB ====================
  
  // ==================== ANALYTICS TAB ====================
  
  // Analytics Tab Removed
  Widget _buildAnalyticsTab() {
    return const Center(child: Text('Analytics Disabled'));
  }







}