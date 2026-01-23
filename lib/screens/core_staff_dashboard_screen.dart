import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/permission_checker.dart';
import 'auth_screen.dart';
import '../widgets/shared_products_tab.dart';
import '../widgets/shared_orders_tab.dart';
import '../widgets/shared_users_tab.dart';
import '../widgets/shared_services_tab.dart';

import '../screens/role_management_tab.dart';

class CoreStaffDashboardScreen extends StatefulWidget {
  static const routeName = '/core-staff-dashboard';

  const CoreStaffDashboardScreen({super.key});

  @override
  State<CoreStaffDashboardScreen> createState() => _CoreStaffDashboardScreenState();
}

class _CoreStaffDashboardScreenState extends State<CoreStaffDashboardScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _refreshController;
  PermissionChecker? _permissionChecker;
  bool _isLoading = true;
  List<Widget> _tabs = [];
  List<Widget> _tabViews = [];
  
  // Dashboard Metrics
  Map<String, String> _metrics = {
    'products': '-',
    'orders': '-',
    'users': '-',
    'revenue': '₹0',
  };
  String? _lastError;

  // ... (rest of class)

  Future<void> _fetchDashboardMetrics() async {
    print('Fetching dashboard metrics...');
    setState(() => _lastError = null); // Clear previous error

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final storeId = authProvider.currentUser?.storeId;

      int productCount = 0;
      int orderCount = 0;
      int userCount = 0;

      if (storeId != null && storeId.isNotEmpty) {
        print('🔒 Fetching store-specific metrics for store: $storeId');
        
        // 1. Fetch Store Pincodes for Order filtering
        List<String> pincodes = [];
        try {
          final storeDoc = await FirebaseFirestore.instance.collection('stores').doc(storeId).get();
          if (storeDoc.exists) {
            pincodes = List<String>.from(storeDoc.data()?['pincodes'] ?? []);
          }
        } catch (e) {
          print('Error fetching store details: $e');
        }

        // 2. Filter Products
        final productsSnap = await FirebaseFirestore.instance
            .collection('products')
            .where('storeIds', arrayContains: storeId)
            .count()
            .get();
        productCount = productsSnap.count ?? 0;

        // 3. Filter Orders (by pincode)
        // Firestore 'whereIn' limit is 10. If more, we might need multiple queries or partial data.
        if (pincodes.isNotEmpty) {
           if (pincodes.length <= 10) {
             final ordersSnap = await FirebaseFirestore.instance
                 .collection('orders')
                 .where('deliveryPincode', whereIn: pincodes)
                 .count()
                 .get();
             orderCount = ordersSnap.count ?? 0;
           } else {
             // Handling > 10 pincodes: split into chunks
             int totalOrders = 0;
             for (var i = 0; i < pincodes.length; i += 10) {
                final end = (i + 10 < pincodes.length) ? i + 10 : pincodes.length;
                final chunk = pincodes.sublist(i, end);
                final chunkSnap = await FirebaseFirestore.instance
                    .collection('orders')
                    .where('deliveryPincode', whereIn: chunk)
                    .count()
                    .get();
                totalOrders += (chunkSnap.count ?? 0);
             }
             orderCount = totalOrders;
           }
        } else {
          // If store has no pincodes, it theoretically has no orders?
          orderCount = 0;
        }

        // 4. Users - N/A for specific store views usually, or just leave as is?
        // Setting to 0/Hyphen to avoid confusion, or count all if permission allows?
        // Assuming 'store staff' shouldn't see global user count.
        userCount = 0; 

      } else {
        print('🌍 Fetching global metrics');
        final productsSnap = await FirebaseFirestore.instance.collection('products').count().get();
        final ordersSnap = await FirebaseFirestore.instance.collection('orders').count().get();
        final usersSnap = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'user').count().get();
        
        productCount = productsSnap.count ?? 0;
        orderCount = ordersSnap.count ?? 0;
        userCount = usersSnap.count ?? 0;
      }

      print('Products: $productCount, Orders: $orderCount, Users: $userCount');

      if (mounted) {
        setState(() {
          _metrics['products'] = productCount.toString();
          _metrics['orders'] = orderCount.toString();
          _metrics['users'] = storeId != null ? 'N/A' : userCount.toString();
          _metrics['revenue'] = '₹0'; // Placeholder
          _lastError = null;
          
          // CRITICAL FIX: Rebuild the Dashboard tab widget to reflect new values
          if (_tabViews.isNotEmpty) {
            _tabViews[0] = KeyedSubtree(
              key: ValueKey('dashboard_${_metrics.toString()}'),
              child: _buildDashboardHome(),
            );
             // Create new list reference so TabBarView detects change
             _tabViews = List.from(_tabViews);
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching metrics: $e');
      if (mounted) {
        setState(() {
          _lastError = e.toString();
          // Update view to show error
          if (_tabViews.isNotEmpty) {
            _tabViews[0] = _buildDashboardHome();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
        duration: const Duration(seconds: 1),
        vsync: this);
    _fetchPermissions();
  }

  Future<void> _fetchPermissions() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          _permissionChecker = PermissionChecker.fromDocument(doc);
          _setupTabs();
        }
      }
    } catch (e) {
      debugPrint('Error fetching permissions: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupTabs() {
    _tabs = [];
    _tabViews = [];

    // Always add Dashboard Home
    _tabs.add(const Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'));
    _tabViews.add(KeyedSubtree(
      key: ValueKey('dashboard_${_metrics.toString()}'),
      child: _buildDashboardHome(),
    ));
    
    // Trigger metrics fetch
    _fetchDashboardMetrics();

    if (_permissionChecker?.canViewProducts == true) {
      _tabs.add(const Tab(icon: Icon(Icons.inventory), text: 'Products'));
      _tabViews.add(SharedProductsTab(
        canManage: _permissionChecker?.canManageProducts ?? false,
      ));
    }

    if (_permissionChecker?.canViewOrders == true) {
      _tabs.add(const Tab(icon: Icon(Icons.shopping_bag), text: 'Orders'));
      _tabViews.add(SharedOrdersTab(
        canManage: _permissionChecker?.canManageOrders ?? false,
      ));
    }
    
    if (_permissionChecker?.canViewUsers == true) {
      _tabs.add(const Tab(icon: Icon(Icons.people), text: 'Users'));
      _tabViews.add(SharedUsersTab(
        canManage: _permissionChecker?.canManageUsers ?? false,
      ));
    }

    if (_permissionChecker?.canViewServices == true) {
      _tabs.add(const Tab(icon: Icon(Icons.handyman), text: 'Services'));
      _tabViews.add(SharedServicesTab(
        canManage: _permissionChecker?.canManageServices ?? false,
      ));
    }
    
    // Partner Requests Management
    if (_permissionChecker?.canManagePartners == true) {
       _tabs.add(const Tab(icon: Icon(Icons.group_add), text: 'Requests'));
       _tabViews.add(_buildPartnerRequestsTab());
    }

    // Sellers Management
    if (_permissionChecker?.canManageSellers == true) {
       _tabs.add(const Tab(icon: Icon(Icons.store), text: 'Sellers'));
       _tabViews.add(_buildRoleBasedUsersTab('seller'));
    }

    // Reports Download
    if (_permissionChecker?.canDownloadReports == true) {
       _tabs.add(const Tab(icon: Icon(Icons.file_download), text: 'Reports'));
       _tabViews.add(_buildSimpleListTab('reports', 'Reports & Downloads'));
    }

    // Delivery Management
    // Note: Use canManageDeliveries (which falls back to partners if deliveries not explicit)
    if (_permissionChecker?.canManageDeliveries == true) {
       _tabs.add(const Tab(icon: Icon(Icons.local_shipping), text: 'Delivery'));
       _tabViews.add(_buildRoleBasedUsersTab('delivery_partner'));
    }

    // Gifts Management
    if (_permissionChecker?.canManageGifts == true) {
      _tabs.add(const Tab(icon: Icon(Icons.card_giftcard), text: 'Gifts'));
      _tabViews.add(_buildSimpleListTab('gifts', 'Gifts'));
    }

    // Featured Sections Management
    if (_permissionChecker?.canManageFeatured == true) {
      _tabs.add(const Tab(icon: Icon(Icons.star), text: 'Featured'));
      _tabViews.add(_buildSimpleListTab('featured_sections', 'Featured Sections'));
    }

    // Core Staff Management
    if (_permissionChecker?.canManageCoreStaff == true) {
      _tabs.add(const Tab(icon: Icon(Icons.group), text: 'Staff'));
      _tabViews.add(_buildRoleBasedUsersTab('core_staff'));
    }

    // Categories Management
    if (_permissionChecker?.canManageCategories == true) {
      _tabs.add(const Tab(icon: Icon(Icons.category), text: 'Categories'));
      _tabViews.add(_buildSimpleListTab('categories', 'Product Categories'));
    }

    // Service Categories Management
    if (_permissionChecker?.canManageServiceCategories == true) {
      _tabs.add(const Tab(icon: Icon(Icons.miscellaneous_services), text: 'Srv Categories'));
      _tabViews.add(_buildSimpleListTab('service_categories', 'Service Categories'));
    }

    // Service Providers Management
    if (_permissionChecker?.canManageServiceProviders == true) {
      _tabs.add(const Tab(icon: Icon(Icons.handyman), text: 'Providers'));
      _tabViews.add(_buildRoleBasedUsersTab('service_provider'));
    }

    // Payout Requests
    if (_permissionChecker?.canManagePayouts == true) {
      _tabs.add(const Tab(icon: Icon(Icons.payment), text: 'Payouts'));
      // Payouts collection logic
      _tabViews.add(_buildSimpleListTab('payout_requests', 'Payout Requests')); 
    }

    // Analytics
    if (_permissionChecker?.canViewAnalytics == true) {
      _tabs.add(const Tab(icon: Icon(Icons.analytics), text: 'Analytics'));
      _tabViews.add(const Center(child: Text('Analytics Dashboard Placeholder')));
    }

    _tabController = TabController(length: _tabs.length, vsync: this);
  }
  
  Widget _buildSimpleListTab(String collection, String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_open, size: 48, color: Colors.green),
          const SizedBox(height: 16),
          Text('$title Management Access Granted'),
          const SizedBox(height: 8),
          const Text('Full management UI coming soon.'),
        ],
      ),
    );
  }


  @override
  void dispose() {
    _refreshController.dispose();
    if (_tabs.isNotEmpty) {
      _tabController.dispose();
    }
    super.dispose();
  }

  Future<void> _logout() async {
    await Provider.of<AuthProvider>(context, listen: false).signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(AuthScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_permissionChecker == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Error loading profile or permissions.'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _logout, child: const Text('Logout')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
        bottom: _tabs.isNotEmpty
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: _tabs,
              )
            : null,
      ),
      body: _tabs.isEmpty
          ? const Center(child: Text('No access to any modules.'))
          : TabBarView(
              controller: _tabController,
              children: _tabViews,
            ),
    );
  }

  Widget _buildDashboardHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Welcome, Staff Member',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
               RotationTransition(
                 turns: _refreshController,
                 child: IconButton(
                   icon: const Icon(Icons.refresh),
                   onPressed: () async {
                     _refreshController.repeat();
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Refreshing metrics...'), duration: Duration(seconds: 1)),
                     );
                     await _fetchDashboardMetrics();
                     await Future.delayed(const Duration(seconds: 1));
                     if (mounted) {
                        _refreshController.stop();
                        _refreshController.reset();
                     }
                   },
                   tooltip: 'Refresh Metrics',
                 ),
               ),
            ],
          ),
          if (_lastError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red[100],
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Error: $_lastError', style: const TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildMetricCard(
                title: 'Products',
                value: _metrics['products']!, // Uses '0', '-', or real count
                icon: Icons.inventory,
                color: Colors.blue,
              ),
              _buildMetricCard(
                title: 'Orders',
                value: _metrics['orders']!,
                icon: Icons.shopping_cart,
                color: Colors.orange,
              ),
              _buildMetricCard(
                title: 'Users (Customers)', // Clarified label
                value: _metrics['users']!,
                icon: Icons.people,
                color: Colors.green,
              ),
              _buildMetricCard(
                title: 'Revenue',
                value: _metrics['revenue']!,
                icon: Icons.currency_rupee,
                color: Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }



  Widget _buildPartnerRequestsTab() {
    return RoleManagementTab(
      key: const ValueKey('partner_requests'),
      collection: 'partner_requests',
      // role is n/a for requests collection usually, or we filter by something else
      // In Admin Panel it is used without role filter for this collection
      onEdit: (id, data) {}, // Requests usually not editable like users
      onDelete: (id, email) { _deleteRequest(id); },
      onRequestAction: _updateRequestStatus,
    );
  }

  Widget _buildRoleBasedUsersTab(String role) {
    return RoleManagementTab(
      collection: 'users',
      role: role,
      requestRole: role == 'seller' ? 'Seller' : 'Delivery Partner',
      onEdit: _editUser,
      onDelete: _deleteUser,
      onRequestAction: _updateRequestStatus,
      onViewDashboard: (id, data) {
        // Simplified dashboard for core staff
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Detailed dashboard available in Admin Panel')));
      },
    );
  }

  Future<void> _updateRequestStatus(String id, String status) async {
     try {
       await FirebaseFirestore.instance.collection('partner_requests').doc(id).update({'status': status});
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request $status')));
     } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
     }
  }

  Future<void> _deleteRequest(String id) async {
     try {
       await FirebaseFirestore.instance.collection('partner_requests').doc(id).delete();
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request deleted')));
     } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
     }
  }

  void _editUser(String userId, Map<String, dynamic> data) {
      // Use SharedUsersTab style dialog or similar. 
      // For brevity, implementing simple edit dialog
      final name = data['name'] ?? '';
      final phone = data['phone'] ?? '';
      final role = data['role'] ?? '';
      final servicePincode = data['service_pincode'];

      final nameCtrl = TextEditingController(text: name);
      final phoneCtrl = TextEditingController(text: phone);
      final pincodeCtrl = TextEditingController(text: servicePincode ?? '');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Edit User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
              if (role == 'delivery_partner') TextField(controller: pincodeCtrl, decoration: const InputDecoration(labelText: 'Pincode')),
            ],
          ),
          actions: [
             TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
             ElevatedButton(onPressed: () async {
                 try {
                   final updates = {'name': nameCtrl.text, 'phone': phoneCtrl.text};
                   if (role == 'delivery_partner') updates['service_pincode'] = pincodeCtrl.text;
                   await FirebaseFirestore.instance.collection('users').doc(userId).update(updates);
                   if (mounted) Navigator.pop(context);
                 } catch (e) { print(e); }
             }, child: const Text('Save'))
          ],
        ),
      );
  }

  Future<void> _deleteUser(String userId, String email) async {
     final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
         title: const Text('Delete?'), actions: [
             TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text('No')),
             ElevatedButton(onPressed: ()=>Navigator.pop(c, true), child: const Text('Yes')),
         ]));
     if (confirm == true) {
        await FirebaseFirestore.instance.collection('users').doc(userId).delete();
     }
  }

}