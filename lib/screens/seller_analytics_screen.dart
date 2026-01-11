import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';

class SellerAnalyticsScreen extends StatefulWidget {
  final AppUser user;

  const SellerAnalyticsScreen({super.key, required this.user});

  @override
  State<SellerAnalyticsScreen> createState() => _SellerAnalyticsScreenState();
}

class _SellerAnalyticsScreenState extends State<SellerAnalyticsScreen> {
  String _selectedRange = 'Last 7 Days';
  final List<String> _ranges = ['Last 7 Days', 'Last 30 Days', 'All Time'];
  
  Map<String, double> _dailySales = {};
  double _totalSales = 0;
  int _totalOrders = 0;
  int _totalItemsSold = 0;
  Map<String, Map<String, dynamic>> _productPerformance = {}; // productId -> {name, qty, revenue}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Analytics'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _downloadPdf,
              tooltip: 'Download PDF Report',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRange,
                icon: const Icon(Icons.calendar_today, size: 18),
                items: _ranges.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedRange = val);
                },
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('status', isNotEqualTo: 'cancelled') // Basic filtering
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No analytics data available'));
          }

          _processData(snapshot.data!.docs);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards
                Row(
                  children: [
                    Expanded(child: _buildSummaryCard('Total Sales', '₹${NumberFormat.compact().format(_totalSales)}', Icons.currency_rupee, Colors.green)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSummaryCard('Orders', '$_totalOrders', Icons.shopping_bag, Colors.blue)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildSummaryCard('Items Sold', '$_totalItemsSold', Icons.inventory_2, Colors.orange)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSummaryCard('Avg. Order', '₹${(_totalOrders > 0 ? _totalSales / _totalOrders : 0).toStringAsFixed(0)}', Icons.trending_up, Colors.purple)),
                  ],
                ),
                const SizedBox(height: 24),



                // Top Products
                Text('Top Selling Products', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Card(
                   child: ListView.separated(
                     shrinkWrap: true,
                     physics: const NeverScrollableScrollPhysics(),
                     itemCount: _productPerformance.length > 5 ? 5 : _productPerformance.length,
                     separatorBuilder: (context, index) => const Divider(height: 1),
                     itemBuilder: (context, index) {
                       final entries = _productPerformance.entries.toList()
                         ..sort((a, b) => (b.value['revenue'] as double).compareTo(a.value['revenue'] as double));
                       
                       final product = entries[index].value;
                       return ListTile(
                         leading: CircleAvatar(
                           backgroundColor: Colors.teal.withOpacity(0.1),
                           child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                         ),
                         title: Text(product['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                         subtitle: Text('${product['qty']} sold'),
                         trailing: Text('₹${NumberFormat.compact().format(product['revenue'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
                       );
                     },
                   ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  void _processData(List<QueryDocumentSnapshot> docs) {
    _totalSales = 0;
    _totalOrders = 0;
    _totalItemsSold = 0;
    _productPerformance = {};
    _dailySales = {}; // YYYY-MM-DD -> Amount

    // Pre-fill dates for line chart continuity
    DateTime now = DateTime.now();
    int days = _selectedRange == 'Last 7 Days' ? 7 : (_selectedRange == 'Last 30 Days' ? 30 : 0);
    
    if (days > 0) {
      for (int i = days - 1; i >= 0; i--) {
        String dateKey = DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: i)));
        _dailySales[dateKey] = 0.0;
      }
    }

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final dynamic rawDate = data['orderDate'];
      DateTime? orderDate;
      if (rawDate is Timestamp) {
        orderDate = rawDate.toDate();
      } else if (rawDate is String) {
        orderDate = DateTime.tryParse(rawDate);
      }
      
      if (orderDate == null) continue;

      // Date Filtering
      if (_selectedRange == 'Last 7 Days' && now.difference(orderDate).inDays > 7) continue;
      if (_selectedRange == 'Last 30 Days' && now.difference(orderDate).inDays > 30) continue;
      
      final items = data['items'] as List<dynamic>? ?? [];
      final status = data['status'] ?? 'pending';
      
      // Exclude cancelled/returned for revenue calculation
      bool isRevenueOrder = !['cancelled', 'returned', 'refunded'].contains(status);

      double orderSellerRevenue = 0;
      bool hasSellerItems = false;

      for (var item in items) {
        if (item['sellerId'] == widget.user.uid) {
          hasSellerItems = true;
          double price = (item['price'] as num?)?.toDouble() ?? 0;
          int qty = (item['quantity'] as num?)?.toInt() ?? 0;
          double total = price * qty;

          _totalItemsSold += qty;
          
          if (isRevenueOrder) {
             orderSellerRevenue += total;
             // Update Product Performance
             String prodId = item['productId'] ?? item['name']; // Fallback
             if (!_productPerformance.containsKey(prodId)) {
               _productPerformance[prodId] = {'name': item['name'], 'qty': 0, 'revenue': 0.0};
             }
             _productPerformance[prodId]!['qty'] += qty;
             _productPerformance[prodId]!['revenue'] += total;
          }
        }
      }

      if (hasSellerItems) {
        _totalOrders++;
        if (isRevenueOrder) {
          _totalSales += orderSellerRevenue;
          String dateKey = DateFormat('yyyy-MM-dd').format(orderDate);
          
          // Only track daily sales if within range or if range is All Time
          if (days > 0) {
              if (_dailySales.containsKey(dateKey)) {
                  _dailySales[dateKey] = (_dailySales[dateKey] ?? 0) + orderSellerRevenue;
              }
          } else {
             // All Time: Create keys dynamically
             _dailySales[dateKey] = (_dailySales[dateKey] ?? 0) + orderSellerRevenue;
          }
        }
      }
    }
    
    // Sort Date Keys for Chart
    if (_selectedRange == 'All Time') {
        var sortedKeys = _dailySales.keys.toList()..sort();
        Map<String, double> sortedMap = {};
        for (var key in sortedKeys) {
            sortedMap[key] = _dailySales[key]!;
        }
      _dailySales = sortedMap;
    }

  }

  Future<void> _downloadPdf() async {
    try {
      if (_totalOrders == 0 && _totalSales == 0) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export')));
        return;
      }

      final topProductsList = _productPerformance.values.toList()
        ..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
      
      final top5 = topProductsList.take(5).toList();

      DateTime? start, end;
      final now = DateTime.now();
      if (_selectedRange == 'Last 7 Days') {
        start = now.subtract(const Duration(days: 7));
        end = now;
      } else if (_selectedRange == 'Last 30 Days') {
         start = now.subtract(const Duration(days: 30));
         end = now;
      }

      final pdfBytes = await AnalyticsService().generateSellerPdfReport(
        sellerName: widget.user.name,
        start: start,
        end: end,
        totalSales: _totalSales,
        totalOrders: _totalOrders,
        itemsSold: _totalItemsSold,
        topProducts: top5,
      );

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'analytics_report_${DateFormat('yyyyMMdd').format(now)}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    }
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }
}
