import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';

class SellerStockReportScreen extends StatefulWidget {
  final AppUser user;

  const SellerStockReportScreen({super.key, required this.user});

  @override
  State<SellerStockReportScreen> createState() => _SellerStockReportScreenState();
}

class _SellerStockReportScreenState extends State<SellerStockReportScreen> {
  String _selectedRange = 'All Time';
  final List<String> _ranges = ['Today', 'Yesterday', 'Last 7 Days', 'Last 30 Days', 'All Time'];
  
  // Future that returns the report data
  Future<Map<String, dynamic>> _fetchReportData() async {
    final productsSnapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: widget.user.uid)
        .get();
        
    final ordersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .get(); // We fetch all orders and filter locally for complexity reasons with arrays

    // 1. Total Products
    final totalProducts = productsSnapshot.docs.length;

    // 2. Inventory Valuation & Total Stock Count
    double inventoryValuation = 0;
    int totalStockCount = 0;
    for (var doc in productsSnapshot.docs) {
      final data = doc.data();
      final price = _safeDouble(data['price']);
      final stock = _safeInt(data['stock']);
      inventoryValuation += (price * stock);
      totalStockCount += stock;
    }

    // Fetch Platform Fee Percentage
    double platformFeePercent = 0.0; // Default 0% if not set
    try {
      final settingsDoc = await FirebaseFirestore.instance.collection('app_settings').doc('general').get();
      if (settingsDoc.exists) {
        final data = settingsDoc.data();
        if (data != null) {
          double val = (data['sellerPlatformFeePercentage'] as num?)?.toDouble() ?? 
                       (data['platformFeePercentage'] as num?)?.toDouble() ?? 0.0;
          platformFeePercent = val / 100.0;
        }
      }
    } catch (e) {
      debugPrint('Error fetching platform fee: $e');
    }

    // Map for fast lookup of current base prices (fallback for old orders)
    final productBasePrices = <String, double>{};
    for (var doc in productsSnapshot.docs) {
      productBasePrices[doc.id] = _safeDouble(doc.data()['basePrice']);
    }

    // 3. Sales Value, Profit & Pending Orders (Date Filtered)
    double totalSalesValue = 0;
    double totalProfit = 0;
    int pendingOrdersCount = 0;

    DateTime now = DateTime.now();
    DateTime? start;
    DateTime? end = now;

    if (_selectedRange == 'Today') {
      start = DateTime(now.year, now.month, now.day);
    } else if (_selectedRange == 'Yesterday') {
      start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
      end = DateTime(now.year, now.month, now.day);
    } else if (_selectedRange == 'Last 7 Days') {
      start = now.subtract(const Duration(days: 7));
    } else if (_selectedRange == 'Last 30 Days') {
      start = now.subtract(const Duration(days: 30));
    } else {
      start = null; // All Time
    }
    
    // Sort products for list display (optional, can display max 50 for performance)
    final productList = productsSnapshot.docs.take(50).map((doc) => doc.data()).toList();

    for (var doc in ordersSnapshot.docs) {
      final data = doc.data();
      DateTime? orderDate;
      if (data['orderDate'] is Timestamp) {
        orderDate = (data['orderDate'] as Timestamp).toDate();
      }
      
      // Filter by date
      if (orderDate != null && start != null && end != null) {
          if (orderDate.isBefore(start) || orderDate.isAfter(end)) continue;
      }

      final items = data['items'] as List<dynamic>? ?? [];
      final status = data['status'] ?? 'pending';

      bool hasSellerItems = false;
      for (var item in items) {
        if (item['sellerId'] == widget.user.uid) {
          hasSellerItems = true;
          // Sales Value & Profit
          if (!['cancelled', 'returned', 'refunded'].contains(status)) {
            final price = _safeDouble(item['price']);
            final qty = _safeInt(item['quantity']);
            final revenue = price * qty;
            
            // Get base price (try item first, then current product data)
            double basePrice = _safeDouble(item['basePrice']);
            if (basePrice == 0) {
              basePrice = productBasePrices[item['productId']] ?? 0;
            }
            
            final cost = basePrice * qty;
            // Platform Fee is based on Selling Price
            final fee = revenue * platformFeePercent;
            
            totalSalesValue += revenue;
            // Profit = SellingPrice - BasePrice - PlatformFee
            totalProfit += (revenue - cost - fee);
          }
        }
      }

      if (hasSellerItems && status == 'pending') {
        pendingOrdersCount++;
      }
    }

    return {
      'totalProducts': totalProducts,
      'inventoryValuation': inventoryValuation,
      'totalSalesValue': totalSalesValue,
      'totalProfit': totalProfit,
      'pendingOrders': pendingOrdersCount,
      'totalStockCount': totalStockCount,
      'products': productList,
      'start': start, // Pass dates for PDF
      'end': end,
    };
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> _downloadPdf(Map<String, dynamic> data) async {
    try {
      final pdfBytes = await AnalyticsService().generateInventoryPdfReport(
        sellerName: widget.user.name,
        start: data['start'],
        end: data['end'],
        totalProducts: data['totalProducts'],
        inventoryValuation: data['inventoryValuation'],
        totalSalesValue: data['totalSalesValue'],
        totalProfit: data['totalProfit'], // Pass total profit
        pendingOrders: data['pendingOrders'],
        products: (data['products'] as List).cast<Map<String, dynamic>>(),
      );

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'stock_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Report'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRange,
                icon: const Icon(Icons.calendar_today, color: Colors.black54, size: 18),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedRange = val);
                },
                items: _ranges.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchReportData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Summary Cards
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: [
                     _buildSummaryCard('Total Profit', '₹${NumberFormat.compact().format(data['totalProfit'])}', Icons.monetization_on, Colors.blue),
                     _buildSummaryCard('Inventory Value', '₹${NumberFormat.compact().format(data['inventoryValuation'])}', Icons.inventory, Colors.orange),
                     _buildSummaryCard('Sales Value', '₹${NumberFormat.compact().format(data['totalSalesValue'])}', Icons.monetization_on, Colors.green),
                     _buildSummaryCard('Net Value (Inv - Sales)', '₹${NumberFormat.compact().format(data['inventoryValuation'] - data['totalSalesValue'])}', Icons.calculate, Colors.purple),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Export Button
                ElevatedButton.icon(
                  onPressed: () => _downloadPdf(data),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Download PDF Report'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                
                const Text('Quick Product List (Top 50)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: (data['products'] as List).length,
                  itemBuilder: (context, index) {
                    final p = (data['products'] as List)[index];
                    final stock = _safeInt(p['stock']);
                    final price = _safeDouble(p['price']);
                    final totalValue = stock * price;
                    
                    return Card(
                      child: ListTile(
                        leading: p['imageUrl'] != null 
                             ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(p['imageUrl'], width: 40, height: 40, fit: BoxFit.cover))
                             : const Icon(Icons.inventory_2),
                        title: Text(p['name'] ?? 'Unknown', overflow: TextOverflow.ellipsis),
                        subtitle: Text('Stock: $stock'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12)),
                            Text('Total: ₹${NumberFormat.compact().format(totalValue)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
       padding: const EdgeInsets.all(12),
       decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 4, offset:const Offset(0,2))],
       ),
       child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Icon(icon, color: color, size: 28),
             const SizedBox(height: 8),
             FittedBox(
               fit: BoxFit.scaleDown,
               child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800])),
             ),
             const SizedBox(height: 4),
             Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600]), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
       ),
    );
  }
}
