import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/auth_provider.dart';
import '../models/store_model.dart';
import '../widgets/shared_orders_tab.dart';
import '../widgets/shared_products_tab.dart';
import 'main_navigation_screen.dart';

class StorePartnerDashboardScreen extends StatefulWidget {
  static const routeName = '/store-partner-dashboard';

  const StorePartnerDashboardScreen({super.key});

  @override
  State<StorePartnerDashboardScreen> createState() => _StorePartnerDashboardScreenState();
}

class _StorePartnerDashboardScreenState extends State<StorePartnerDashboardScreen> with SingleTickerProviderStateMixin {
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
    await auth.refreshUser(); // Ensure fresh storeId
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
        appBar: AppBar(title: const Text('Store Partner Dashboard')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.handshake_outlined, size: 80, color: Colors.grey),
                const SizedBox(height: 24),
                const Text(
                  'No Store Assigned',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your account is not linked to any store as a Partner. Please contact an Admin.',
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
            Text('${_store!.name} - Partner', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Partner ID: ${context.read<AuthProvider>().currentUser?.uid.substring(0, 8)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Financials', icon: Icon(Icons.account_balance_wallet_outlined)),
            Tab(text: 'Selling Details', icon: Icon(Icons.receipt_long_outlined)),
            Tab(text: 'Inventory/Purchase', icon: Icon(Icons.inventory_2_outlined)),
            Tab(text: 'Store Info', icon: Icon(Icons.store_outlined)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Back to Shopping',
            onPressed: () => Navigator.of(context).pushNamed(MainNavigationScreen.routeName),
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
          _FinancialsTab(store: _store!),
          SharedOrdersTab(canManage: true, pincodes: _store!.pincodes),
          SharedProductsTab(canManage: true, storeId: _store!.id, isPartnerView: true),
          _StoreInfoTab(store: _store!),
        ],
      ),
    );
  }
}

class _FinancialsTab extends StatefulWidget {
  final StoreModel store;
  const _FinancialsTab({required this.store});

  @override
  State<_FinancialsTab> createState() => _FinancialsTabState();
}

class _FinancialsTabState extends State<_FinancialsTab> {
  DateTimeRange? _selectedDateRange;
  String _selectedFilter = 'Today';
  late Stream<QuerySnapshot> _ordersStream;
  late Stream<QuerySnapshot> _purchasesStream;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _selectedDateRange = DateTimeRange(start: today, end: today);
    _updateStream();
  }

  @override
  void didUpdateWidget(_FinancialsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.store.id != oldWidget.store.id || 
        widget.store.pincodes.length != oldWidget.store.pincodes.length) {
      _updateStream();
    }
  }

  void _updateStream() {
    Query query = FirebaseFirestore.instance
        .collection('orders')
        .where('deliveryPincode', whereIn: widget.store.pincodes);

    if (_selectedDateRange != null) {
      query = query
          .where('orderDate', isGreaterThanOrEqualTo: _selectedDateRange!.start)
          .where('orderDate', isLessThanOrEqualTo: _selectedDateRange!.end.add(const Duration(hours: 23, minutes: 59)));
    }
    _ordersStream = query.snapshots();

    Query pQuery = FirebaseFirestore.instance
        .collection('purchases')
        .where('storeId', isEqualTo: widget.store.id);

    if (_selectedDateRange != null) {
      pQuery = pQuery
          .where('createdAt', isGreaterThanOrEqualTo: _selectedDateRange!.start)
          .where('createdAt', isLessThanOrEqualTo: _selectedDateRange!.end.add(const Duration(hours: 23, minutes: 59)));
    }
    _purchasesStream = pQuery.snapshots();
  }

  void _handleFilterChange(String? value) {
    if (value == null) return;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTimeRange? newRange;

    switch (value) {
      case 'Today':
        newRange = DateTimeRange(start: today, end: today);
        break;
      case 'Yesterday':
        final yesterday = today.subtract(const Duration(days: 1));
        newRange = DateTimeRange(start: yesterday, end: yesterday);
        break;
      case 'Last 7 Days':
        newRange = DateTimeRange(start: today.subtract(const Duration(days: 7)), end: today);
        break;
      case 'Last 30 Days':
        newRange = DateTimeRange(start: today.subtract(const Duration(days: 30)), end: today);
        break;
      case 'All Time':
        newRange = null;
        break;
      case 'Custom Range':
        _selectCustomDateRange(context);
        return;
    }

    setState(() {
      _selectedFilter = value;
      _selectedDateRange = newRange;
      _updateStream();
    });
  }

  Future<void> _selectCustomDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _selectedDateRange ?? DateTimeRange(start: DateTime.now(), end: DateTime.now()),
    );
    if (picked != null) {
      setState(() {
        _selectedFilter = 'Custom Range';
        _selectedDateRange = picked;
        _updateStream();
      });
    }
  }

  Future<void> _generatePDF({
    required double sales,
    required double purchase,
    required double profit,
    required int totalOrders,
    required int cancelled,
    required int refunded,
  }) async {
    final pdf = pw.Document();

    // Fetch products for valuation details
    final productSnapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('storeIds', arrayContains: widget.store.id)
        .get();

    final List<Map<String, dynamic>> productValuationList = [];
    double totalValuation = 0.0;
    
    for (var doc in productSnapshot.docs) {
      final data = doc.data();
      final name = data['name'] as String? ?? 'N/A';
      final basePrice = (data['basePrice'] as num?)?.toDouble() ?? 0.0;
      final stock = (data['stock'] as num?)?.toInt() ?? 0;
      final valuation = basePrice * stock;
      
      productValuationList.add({
        'name': name,
        'rate': basePrice,
        'stock': stock,
        'valuation': valuation,
      });
      totalValuation += valuation;
    }

    final dateStr = _selectedDateRange == null 
        ? 'All Time' 
        : '${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, text: 'Store Performance Report'),
            pw.SizedBox(height: 10),
            pw.Text('Store: ${widget.store.name}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
            pw.Text('Period: $dateStr'),
            pw.Divider(),
            pw.SizedBox(height: 20),
            
            pw.Text('Financial Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 10),
            _buildPdfRow('Total Sales', 'Rs. ${sales.toStringAsFixed(2)}'),
            _buildPdfRow('Total Spent on Stock', 'Rs. ${purchase.toStringAsFixed(2)}'),
            _buildPdfRow('Gross Profit (on Sales)', 'Rs. ${profit.toStringAsFixed(2)}'),
            _buildPdfRow('Your Net Profit (75%)', 'Rs. ${(profit * 0.75).toStringAsFixed(2)}'),
            
            pw.SizedBox(height: 30),
            pw.Text('Order Statistics', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 10),
            _buildPdfRow('Total Orders', '$totalOrders'),
            _buildPdfRow('Cancelled Orders', '$cancelled'),
            _buildPdfRow('Refunded Orders', '$refunded'),

            pw.SizedBox(height: 30),
            pw.Text('Inventory Valuation Breakdown', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Product', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Rate', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Stock', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Valuation', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                ...productValuationList.map((p) => pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(p['name'])),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Rs.${p['rate'].toStringAsFixed(2)}')),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(p['stock'].toString())),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Rs.${p['valuation'].toStringAsFixed(2)}')),
                  ],
                )),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('TOTAL INVENTORY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Rs. ${totalValuation.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ],
                ),
              ],
            ),
            
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Generated by DEMANDY App on ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}'),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        double totalSales = 0.0;
        double totalPurchaseCost = 0.0;
        int totalSoldQty = 0;
        int cancelledOrders = 0;
        int refundedOrders = 0;
        int totalOrders = snapshot.data!.docs.length;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] as String? ?? '').toLowerCase();
          
          if (status == 'cancelled') {
            cancelledOrders++;
            continue; 
          }
          if (status == 'refunded' || status == 'returned') {
            refundedOrders++;
            continue; 
          }

          if (status != 'delivered' && status != 'completed') {
            continue; 
          }

          final items = (data['items'] as List<dynamic>?) ?? [];
          for (var item in items) {
            final price = (item['price'] as num?)?.toDouble() ?? 0.0;
            final buyingPrice = (item['basePrice'] as num?)?.toDouble() ?? 0.0;
            final qty = (item['quantity'] as num?)?.toInt() ?? 1;
            
            totalSales += (price * qty);
            totalPurchaseCost += (buyingPrice * qty);
            totalSoldQty += qty;
          }
        }

        double totalGrossProfit = totalSales - totalPurchaseCost;

        double platformShare = totalGrossProfit * 0.25;
        double netPartnerProfit = totalGrossProfit * 0.75;

        return StreamBuilder<QuerySnapshot>(
          stream: _purchasesStream,
          builder: (context, purchaseSnap) {
            double totalInventoryInvestment = 0.0;
            if (purchaseSnap.hasData) {
              for (var doc in purchaseSnap.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                totalInventoryInvestment += (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Financial Summary', 
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _generatePDF(
                              sales: totalSales,
                              purchase: totalPurchaseCost,
                              profit: totalGrossProfit,
                              totalOrders: totalOrders,
                              cancelled: cancelledOrders,
                              refunded: refundedOrders,
                            ),
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.blueGrey, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Generate Report',
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedFilter,
                                icon: const Icon(Icons.arrow_drop_down, size: 20, color: Colors.blue),
                                style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold),
                                items: ['All Time', 'Today', 'Yesterday', 'Last 7 Days', 'Last 30 Days', 'Custom Range']
                                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                                    .toList(),
                                onChanged: _handleFilterChange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_selectedDateRange != null && _selectedFilter == 'Custom Range')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Chip(
                        label: Text(
                          '${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM').format(_selectedDateRange!.end)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onDeleted: () => _handleFilterChange('Today'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  _buildNetProfitCard(netPartnerProfit),
                  const SizedBox(height: 20),
                  
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _SummaryMiniCard(title: 'Total Sales', value: '₹${totalSales.toStringAsFixed(2)}', icon: Icons.trending_up, color: Colors.blue),
                      _SummaryMiniCard(title: 'Total Purchase', value: '₹${totalInventoryInvestment.toStringAsFixed(2)}', icon: Icons.shopping_cart_checkout, color: Colors.orange),
                      _SummaryMiniCard(title: 'Gross Profit', value: '₹${totalGrossProfit.toStringAsFixed(2)}', icon: Icons.analytics, color: Colors.green),
                      _SummaryMiniCard(title: 'Admin Share (25%)', value: '₹${platformShare.toStringAsFixed(2)}', icon: Icons.account_balance, color: Colors.deepOrange),
                      _SummaryMiniCard(title: 'Total Orders', value: '$totalOrders', icon: Icons.receipt_long, color: Colors.purple),
                      _SummaryMiniCard(title: 'Total Cancelled', value: '$cancelledOrders', icon: Icons.cancel_outlined, color: Colors.red),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  const Text('Product Details Valuation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _ProductValuationCard(storeId: widget.store.id),
                  const SizedBox(height: 80),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNetProfitCard(double profit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          const Text('YOUR NET PROFIT', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('₹${profit.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ProductValuationCard extends StatelessWidget {
  final String storeId;
  const _ProductValuationCard({required this.storeId});

  void _showValuationDetails(BuildContext context, List<QueryDocumentSnapshot> docs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Product Valuation Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              const Divider(),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (ctx, idx) => const Divider(),
                  itemBuilder: (ctx, idx) {
                    final data = docs[idx].data() as Map<String, dynamic>;
                    final name = data['name'] as String? ?? 'Unknown Product';
                    final basePrice = (data['basePrice'] as num?)?.toDouble() ?? 0.0;
                    final stock = (data['stock'] as num?)?.toInt() ?? 0;
                    final valuation = basePrice * stock;

                    return ListTile(
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Qty: $stock units | Piece Rate: ₹${basePrice.toStringAsFixed(2)}'),
                      trailing: Text('₹${valuation.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('storeIds', arrayContains: storeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        double totalValuation = 0.0;
        int totalStock = 0;
        int productCount = snapshot.data!.docs.length;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final buyingPrice = (data['basePrice'] as num?)?.toDouble() ?? 0.0;
          final stock = (data['stock'] as num?)?.toInt() ?? 0;
          
          totalValuation += (buyingPrice * stock);
          totalStock += stock;
        }

        return InkWell(
          onTap: () => _showValuationDetails(context, snapshot.data!.docs),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _ValuationRow(label: 'Total Products', value: '$productCount'),
                  const Divider(),
                  _ValuationRow(label: 'Total Stock Quantity', value: '$totalStock Units'),
                  const Divider(),
                  _ValuationRow(
                    label: 'Current Valuation', 
                    value: '₹${totalValuation.toStringAsFixed(2)}',
                    valueStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue),
                  ),
                  const SizedBox(height: 8),
                  const Text('Click for detailed product breakdown', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ValuationRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;
  const _ValuationRow({required this.label, required this.value, this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: valueStyle ?? const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _SummaryMiniCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryMiniCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _StoreInfoTab extends StatelessWidget {
  final StoreModel store;
  const _StoreInfoTab({required this.store});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Store Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildInfoItem('Store Name', store.name, Icons.store),
          _buildInfoItem('Location', store.address ?? 'N/A', Icons.location_on),
          _buildInfoItem('State', store.state ?? 'N/A', Icons.map),
          _buildInfoItem('Pincodes', store.pincodes.join(', '), Icons.pin_drop),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'As a Partner, your net profit is calculated as 75% of the total Gross Profit (Sales Price - Base Price of items sold).',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
