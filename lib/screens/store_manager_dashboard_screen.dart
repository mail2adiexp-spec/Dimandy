
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/auth_provider.dart';
import '../models/store_model.dart';
import '../widgets/shared_orders_tab.dart';
import '../widgets/shared_products_tab.dart';
import '../widgets/barcode_scanner_dialog.dart';
import '../utils/locations_data.dart';

class StoreManagerDashboardScreen extends StatefulWidget {
  static const routeName = '/store-manager-dashboard';

  const StoreManagerDashboardScreen({super.key});

  @override
  State<StoreManagerDashboardScreen> createState() => _StoreManagerDashboardScreenState();
}

class _StoreManagerDashboardScreenState extends State<StoreManagerDashboardScreen> with SingleTickerProviderStateMixin {
  StoreModel? _store;
  bool _isLoadingStore = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchStoreDetails();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchStoreDetails() async {
    final auth = context.read<AuthProvider>();
    await auth.refreshUser();
    final storeId = auth.currentUser?.storeId;

    if (storeId == null) {
      if (mounted) setState(() => _isLoadingStore = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('stores').doc(storeId).get();
      if (doc.exists) {
        if (mounted) {
          setState(() {
            _store = StoreModel.fromFirestore(doc);
            _isLoadingStore = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingStore = false);
      }
    } catch (e) {
      debugPrint('Error fetching store: $e');
      if (mounted) setState(() => _isLoadingStore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStore) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_store == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Store Manager Dashboard')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.store, size: 80, color: Colors.grey),
                const SizedBox(height: 24),
                const Text(
                  'No Store Assigned',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your account is not linked to any store. Please contact an Admin.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_store!.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Store ID: ${_store!.id}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Dashboard', icon: Icon(Icons.dashboard_outlined)),
            Tab(text: 'Orders', icon: Icon(Icons.receipt_long_outlined)),
            Tab(text: 'Inventory', icon: Icon(Icons.inventory_2_outlined)),
            Tab(text: 'Settings', icon: Icon(Icons.settings_outlined)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _openScanner(context),
            tooltip: 'Quick Scan',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStoreDetails,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DashboardTab(store: _store!),
          SharedOrdersTab(canManage: true, pincodes: _store!.pincodes),
          SharedProductsTab(canManage: true, storeId: _store!.id),
          _SettingsTab(store: _store!, onUpdate: _fetchStoreDetails),
        ],
      ),
    );
  }

  void _openScanner(BuildContext context) async {
    final scannedCode = await showDialog<String>(
      context: context,
      builder: (context) => const BarcodeScannerDialog(),
    );
    
    if (scannedCode != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scanned: $scannedCode. Processing feature coming soon.')),
      );
    }
  }
}

class _DashboardTab extends StatelessWidget {
  final StoreModel store;
  const _DashboardTab({required this.store});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 24),
          const Text('7-Day Sales Trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildPerformanceChart(context),
          const SizedBox(height: 24),
          const Text('Top Selling Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildTopProductsList(sortBy: 'salesCount', icon: Icons.trending_up, iconColor: Colors.green),
          const SizedBox(height: 24),
          const Text('Top Viewed Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildTopProductsList(sortBy: 'viewCount', icon: Icons.visibility, iconColor: Colors.blue),
          const SizedBox(height: 24),
          const Text('Inventory Alerts (Low Stock)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildLowStockList(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('deliveryPincode', whereIn: store.pincodes)
          .snapshots(),
      builder: (context, snapshot) {
        int totalOrders = snapshot.data?.docs.length ?? 0;
        int pendingOrders = snapshot.data?.docs.where((d) => ['pending', 'confirmed', 'packed'].contains(d['status'])).length ?? 0;
        double totalRevenue = snapshot.data?.docs.fold(0.0, (sum, d) => sum! + (d['totalAmount'] ?? 0.0)) ?? 0.0;

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _Card(title: 'Total Revenue', value: '₹${NumberFormat('#,##,###').format(totalRevenue)}', icon: Icons.currency_rupee, color: Colors.green, bgColor: Colors.green.shade50),
            _Card(title: 'Total Orders', value: '$totalOrders', icon: Icons.shopping_bag, color: Colors.blue, bgColor: Colors.blue.shade50),
            _Card(title: 'Pending', value: '$pendingOrders', icon: Icons.pending_actions, color: Colors.orange, bgColor: Colors.orange.shade50),
            _Card(title: 'Service Areas', value: '${store.pincodes.length}', icon: Icons.map, color: Colors.purple, bgColor: Colors.purple.shade50),
          ],
        );
      },
    );
  }

  Widget _buildPerformanceChart(BuildContext context) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 250,
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('deliveryPincode', whereIn: store.pincodes)
              .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day)))
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final orders = snapshot.data?.docs ?? [];
            final dailyTotals = <DateTime, double>{};
            
            // Initialize last 7 days with 0
            for (int i = 0; i < 7; i++) {
              final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
              dailyTotals[date] = 0.0;
            }

            for (var doc in orders) {
              final date = (doc['orderDate'] as Timestamp).toDate();
              final day = DateTime(date.year, date.month, date.day);
              if (dailyTotals.containsKey(day)) {
                dailyTotals[day] = dailyTotals[day]! + (doc['totalAmount'] ?? 0.0);
              }
            }

            final sortedDays = dailyTotals.keys.toList()..sort();
            final barGroups = sortedDays.asMap().entries.map((entry) {
              final day = entry.value;
              final amount = dailyTotals[day] ?? 0.0;
              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: amount,
                    color: Colors.blue,
                    width: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }).toList();

            return BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (dailyTotals.values.isEmpty ? 1000 : dailyTotals.values.reduce((a, b) => a > b ? a : b)) * 1.2,
                barGroups: barGroups,
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final date = sortedDays[value.toInt()];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(DateFormat('dd').format(date), style: const TextStyle(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopProductsList({required String sortBy, required IconData icon, required Color iconColor}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('storeIds', arrayContains: store.id)
          .orderBy(sortBy, descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No data available.')));
        }
        return Column(
          children: snapshot.data!.docs.map((doc) {
             final data = doc.data() as Map<String, dynamic>;
             final count = data[sortBy] ?? 0;
             return Card(
               margin: const EdgeInsets.only(bottom: 8),
               child: ListTile(
                 leading: CircleAvatar(
                   backgroundColor: iconColor.withValues(alpha: 0.1),
                   child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: iconColor)),
                 ),
                 title: Text(data['name'] ?? 'Unknown'),
                 subtitle: Text('Price: ₹${data['price']}'),
                 trailing: Icon(icon, color: iconColor, size: 16),
               ),
             );
          }).toList(),
        );
      },
    );
  }

  Widget _buildLowStockList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('storeIds', arrayContains: store.id)
          .where('stock', isLessThanOrEqualTo: 10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('All stock levels are healthy.')));
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final stock = doc['stock'] ?? 0;
            return ListTile(
              leading: Icon(Icons.warning_amber_rounded, color: stock <= 0 ? Colors.red : Colors.orange),
              title: Text(doc['name']),
              subtitle: Text('Current Stock: $stock'),
              trailing: TextButton(
                onPressed: () {
                  // TODO: Navigate to inventory tab or show quick restock dialog
                }, 
                child: const Text('RESTOCK')
              ),
            );
          },
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  const _Card({required this.title, required this.value, required this.icon, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Icon(Icons.arrow_forward_ios, color: color.withValues(alpha: 0.3), size: 12),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _SettingsTab extends StatefulWidget {
  final StoreModel store;
  final VoidCallback onUpdate;
  const _SettingsTab({required this.store, required this.onUpdate});

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _addrCtrl;
  late TextEditingController _pincodesCtrl;
  String? _selectedState;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.store.name);
    _addrCtrl = TextEditingController(text: widget.store.address);
    _pincodesCtrl = TextEditingController(text: widget.store.pincodes.join(', '));
    _selectedState = widget.store.state;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Store Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Store Name', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addrCtrl,
              decoration: const InputDecoration(labelText: 'Store Address', border: OutlineInputBorder()),
              maxLines: 2,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedState,
              decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
              items: LocationsData.cities
                  .map((e) => e.state)
                  .toSet()
                  .toList()
                  .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s, overflow: TextOverflow.ellipsis)))
                  .toList()
                ..sort((a, b) => a.value!.compareTo(b.value!)),
              onChanged: (v) => setState(() => _selectedState = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pincodesCtrl,
              decoration: const InputDecoration(
                labelText: 'Operating Pincodes (comma separated)', 
                border: OutlineInputBorder(),
                helperText: 'Enter pincodes where this store fulfills orders.',
              ),
              maxLines: 3,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveSettings,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: _isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final pincodes = _pincodesCtrl.text.split(',').map((e) => e.trim()).toList();
      await FirebaseFirestore.instance.collection('stores').doc(widget.store.id).update({
        'name': _nameCtrl.text.trim(),
        'address': _addrCtrl.text.trim(),
        'state': _selectedState,
        'pincodes': pincodes,
      });
      widget.onUpdate();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store details updated!')));
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
