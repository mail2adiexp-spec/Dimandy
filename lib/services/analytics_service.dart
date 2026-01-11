import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Data Models for Analytics
class DailySales {
  final DateTime date;
  final double revenue;
  final int orderCount;

  DailySales({
    required this.date,
    required this.revenue,
    required this.orderCount,
  });
}

class TopProduct {
  final String productId;
  final String name;
  final int salesCount;
  final double revenue;

  TopProduct({
    required this.productId,
    required this.name,
    required this.salesCount,
    required this.revenue,
  });
}

class UserGrowth {
  final DateTime date;
  final int newUsers;
  final int totalUsers;

  UserGrowth({
    required this.date,
    required this.newUsers,
    required this.totalUsers,
  });
}

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== REVENUE ANALYTICS ====================

  /// Get total revenue from all completed orders
  /// Get total revenue from all completed orders (optional date range)
  Future<double> getTotalRevenue({DateTime? start, DateTime? end}) async {
    try {
      Query query = _firestore
          .collection('orders')
          .where('status', isEqualTo: 'delivered');

      if (start != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
      }
      if (end != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end));
      }

      final snapshot = await query.get();

      return snapshot.docs.fold<double>(
        0,
        (sum, doc) {
          final data = doc.data() as Map<String, dynamic>;
          final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
          return sum + amount;
        },
      );
    } catch (e) {
      print('Error getting total revenue: $e');
      return 0;
    }
  }

  /// Get revenue by date range
  Future<Map<String, double>> getRevenueByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      double productsRevenue = 0;
      double servicesRevenue = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
        final items = data['items'] as List? ?? [];

        // Check if order contains products or services
        bool hasProducts = items.any((item) => item['type'] == 'product');
        bool hasServices = items.any((item) => item['type'] == 'service');

        if (hasProducts) productsRevenue += amount;
        if (hasServices) servicesRevenue += amount;
      }

      return {
        'products': productsRevenue,
        'services': servicesRevenue,
      };
    } catch (e) {
      print('Error getting revenue by date range: $e');
      return {'products': 0, 'services': 0};
    }
  }

  /// Get daily sales for a date range
  Future<List<DailySales>> getDailySales(DateTime start, DateTime end) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('createdAt')
          .get();

      // Group by date
      Map<String, DailySales> salesByDate = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt == null) continue;

        final dateKey = DateTime(createdAt.year, createdAt.month, createdAt.day).toString();
        final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0;

        if (salesByDate.containsKey(dateKey)) {
          salesByDate[dateKey] = DailySales(
            date: salesByDate[dateKey]!.date,
            revenue: salesByDate[dateKey]!.revenue + amount,
            orderCount: salesByDate[dateKey]!.orderCount + 1,
          );
        } else {
          salesByDate[dateKey] = DailySales(
            date: DateTime(createdAt.year, createdAt.month, createdAt.day),
            revenue: amount,
            orderCount: 1,
          );
        }
      }

      return salesByDate.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    } catch (e) {
      print('Error getting daily sales: $e');
      return [];
    }
  }

  // ==================== ORDER ANALYTICS ====================

  /// Get total number of orders
  /// Get total number of orders (optional date range)
  Future<int> getTotalOrders({DateTime? start, DateTime? end}) async {
    try {
      Query query = _firestore.collection('orders');

      if (start != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
      }
      if (end != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end));
      }

      final snapshot = await query.get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting total orders: $e');
      return 0;
    }
  }

  /// Get orders count by status
  Future<Map<String, int>> getOrdersByStatus() async {
    try {
      final snapshot = await _firestore.collection('orders').get();

      Map<String, int> statusCounts = {
        'pending': 0,
        'processing': 0,
        'delivered': 0,
        'returned': 0,
      };

      for (var doc in snapshot.docs) {
        final status = doc.data()['status'] as String? ?? 'pending';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }

      return statusCounts;
    } catch (e) {
      print('Error getting orders by status: $e');
      return {};
    }
  }

  // ==================== PRODUCT ANALYTICS ====================

  /// Get total number of products sold
  /// Get total number of products sold (optional date range)
  Future<int> getTotalProductsSold({DateTime? start, DateTime? end}) async {
    try {
      Query query = _firestore
          .collection('orders')
          .where('status', isEqualTo: 'delivered');

      if (start != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
      }
      if (end != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end));
      }

      final snapshot = await query.get();

      int totalQuantity = 0;
      for (var doc in snapshot.docs) {
        final items = (doc.data() as Map<String, dynamic>)['items'] as List? ?? [];
        for (var item in items) {
          if (item['type'] == 'product') {
            totalQuantity += (item['quantity'] as int?) ?? 0;
          }
        }
      }

      return totalQuantity;
    } catch (e) {
      print('Error getting total products sold: $e');
      return 0;
    }
  }

  /// Get top selling products
  Future<List<TopProduct>> getTopProducts(int limit) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .get();

      Map<String, TopProduct> productSales = {};

      for (var doc in snapshot.docs) {
        final items = doc.data()['items'] as List? ?? [];
        for (var item in items) {
          if (item['type'] == 'product') {
            final productId = item['id'] as String? ?? '';
            final productName = item['name'] as String? ?? 'Unknown';
            final quantity = (item['quantity'] as int?) ?? 0;
            final price = (item['price'] as num?)?.toDouble() ?? 0;

            if (productSales.containsKey(productId)) {
              productSales[productId] = TopProduct(
                productId: productId,
                name: productName,
                salesCount: productSales[productId]!.salesCount + quantity,
                revenue: productSales[productId]!.revenue + (price * quantity),
              );
            } else {
              productSales[productId] = TopProduct(
                productId: productId,
                name: productName,
                salesCount: quantity,
                revenue: price * quantity,
              );
            }
          }
        }
      }

      final sorted = productSales.values.toList()
        ..sort((a, b) => b.salesCount.compareTo(a.salesCount));

      return sorted.take(limit).toList();
    } catch (e) {
      print('Error getting top products: $e');
      return [];
    }
  }

  /// Get sales by product category
  Future<Map<String, int>> getSalesByCategory() async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .get();

      Map<String, int> categorySales = {};

      for (var doc in snapshot.docs) {
        final items = doc.data()['items'] as List? ?? [];
        for (var item in items) {
          if (item['type'] == 'product') {
            final category = item['category'] as String? ?? 'Uncategorized';
            final quantity = (item['quantity'] as int?) ?? 0;
            categorySales[category] = (categorySales[category] ?? 0) + quantity;
          }
        }
      }

      return categorySales;
    } catch (e) {
      print('Error getting sales by category: $e');
      return {};
    }
  }

  // ==================== USER ANALYTICS ====================

  /// Get active users count
  Future<int> getActiveUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting active users: $e');
      return 0;
    }
  }

  /// Get user growth over time
  Future<List<UserGrowth>> getUserGrowth(DateTime start, DateTime end) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('createdAt')
          .get();

      Map<String, UserGrowth> growthByDate = {};
      int cumulativeCount = 0;

      for (var doc in snapshot.docs) {
        final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        if (createdAt == null) continue;

        final dateKey = DateTime(createdAt.year, createdAt.month, createdAt.day).toString();
        cumulativeCount++;

        if (growthByDate.containsKey(dateKey)) {
          growthByDate[dateKey] = UserGrowth(
            date: growthByDate[dateKey]!.date,
            newUsers: growthByDate[dateKey]!.newUsers + 1,
            totalUsers: cumulativeCount,
          );
        } else {
          growthByDate[dateKey] = UserGrowth(
            date: DateTime(createdAt.year, createdAt.month, createdAt.day),
            newUsers: 1,
            totalUsers: cumulativeCount,
          );
        }
      }

      return growthByDate.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    } catch (e) {
      print('Error getting user growth: $e');
      return [];
    }
  }

  /// Get users by role
  Future<Map<String, int>> getUsersByRole() async {
    try {
      final snapshot = await _firestore.collection('users').get();

      Map<String, int> roleCounts = {
        'user': 0,
        'seller': 0,
        'service_provider': 0,
        'admin': 0,
        'delivery_partner': 0,
      };

      for (var doc in snapshot.docs) {
        final role = doc.data()['role'] as String? ?? 'user';
        roleCounts[role] = (roleCounts[role] ?? 0) + 1;
      }

      return roleCounts;
    } catch (e) {
      print('Error getting users by role: $e');
      return {};
    }
  }
  // ==================== EXPORT ====================

  /// Generate CSV report of key analytics
  /// Generate CSV report of key analytics with filters
  Future<String> downloadAnalyticsReport({
    DateTime? start,
    DateTime? end,
    List<String> metrics = const ['Total Revenue', 'Total Orders', 'Products Sold', 'Active Users'],
  }) async {
    try {
      final StringBuffer csv = StringBuffer();
      
      // Header
      csv.writeln('Analytics Report');
      csv.writeln('Generated on: ${DateTime.now().toString()}');
      if (start != null && end != null) {
        csv.writeln('Period: ${start.toString().split(' ')[0]} to ${end.toString().split(' ')[0]}');
      } else {
        csv.writeln('Period: All Time');
      }
      csv.writeln('');

      // 1. Overview Metrics
      csv.writeln('OVERVIEW METRICS');
      csv.writeln('Metric,Value');
      
      if (metrics.contains('Total Revenue')) {
        final revenue = await getTotalRevenue(start: start, end: end);
        csv.writeln('Total Revenue,${revenue.toStringAsFixed(2)}');
      }
      
      if (metrics.contains('Total Orders')) {
        final orders = await getTotalOrders(start: start, end: end);
        csv.writeln('Total Orders,$orders');
      }
      
      if (metrics.contains('Active Users')) {
        // Note: Active users usually means total registered users, date range might imply "New Users"
        // For now, we'll just show total users if no date range, or new users if date range
        if (start != null && end != null) {
          final growth = await getUserGrowth(start, end);
          final newUsers = growth.fold<int>(0, (sum, item) => sum + item.newUsers);
          csv.writeln('New Users (in period),$newUsers');
        } else {
          final users = await getActiveUsers();
          csv.writeln('Total Active Users,$users');
        }
      }
      
      if (metrics.contains('Products Sold')) {
        final productsSold = await getTotalProductsSold(start: start, end: end);
        csv.writeln('Products Sold,$productsSold');
      }
      csv.writeln('');

      // 2. Orders by Status (Only if requested or default)
      // Note: getOrdersByStatus doesn't support date range yet, so we'll skip or implement later
      // For now, let's keep it simple and only show if no date range or if we implement it
      // To keep it simple for this iteration, we'll exclude it if date range is set, or include it as "All Time"
      if (start == null && end == null) {
        csv.writeln('ORDERS BY STATUS (All Time)');
        csv.writeln('Status,Count');
        final orderStats = await getOrdersByStatus();
        orderStats.forEach((status, count) {
          csv.writeln('$status,$count');
        });
        csv.writeln('');
      }

      // 3. Top Products
      csv.writeln('TOP 5 PRODUCTS (All Time)'); // Update this if we add date support to getTopProducts
      csv.writeln('Product Name,Sales Count,Revenue');
      final topProducts = await getTopProducts(5);
      for (var product in topProducts) {
        csv.writeln('${product.name},${product.salesCount},${product.revenue.toStringAsFixed(2)}');
      }

      return csv.toString();
    } catch (e) {
      print('Error generating report: $e');
      throw Exception('Failed to generate report');
    }
  }

  /// Generate PDF report of key analytics with filters
  Future<Uint8List> generatePdfReport({
    DateTime? start,
    DateTime? end,
    List<String> metrics = const ['Total Revenue', 'Total Orders', 'Products Sold', 'Active Users'],
  }) async {
    final pdf = pw.Document();
    
    // Fetch data
    double revenue = 0;
    int orders = 0;
    int productsSold = 0;
    int users = 0;
    
    if (metrics.contains('Total Revenue')) {
      revenue = await getTotalRevenue(start: start, end: end);
    }
    if (metrics.contains('Total Orders')) {
      orders = await getTotalOrders(start: start, end: end);
    }
    if (metrics.contains('Products Sold')) {
      productsSold = await getTotalProductsSold(start: start, end: end);
    }
    if (metrics.contains('Active Users')) {
      if (start != null && end != null) {
        final growth = await getUserGrowth(start, end);
        users = growth.fold<int>(0, (sum, item) => sum + item.newUsers);
      } else {
        users = await getActiveUsers();
      }
    }
    
    final topProducts = await getTopProducts(5);
    
    // Generate PDF
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Text(
                'Analytics Report',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Generated on: ${DateTime.now().toString().split('.')[0]}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                start != null && end != null
                    ? 'Period: ${start.toString().split(' ')[0]} to ${end.toString().split(' ')[0]}'
                    : 'Period: All Time',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 20),
              
              // Overview Metrics
              pw.Text(
                'Overview Metrics',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Metric', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Value', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  if (metrics.contains('Total Revenue'))
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Total Revenue'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('₹${revenue.toStringAsFixed(2)}'),
                        ),
                      ],
                    ),
                  if (metrics.contains('Total Orders'))
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Total Orders'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('$orders'),
                        ),
                      ],
                    ),
                  if (metrics.contains('Active Users'))
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(start != null && end != null ? 'New Users (in period)' : 'Total Active Users'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('$users'),
                        ),
                      ],
                    ),
                  if (metrics.contains('Products Sold'))
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Products Sold'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('$productsSold'),
                        ),
                      ],
                    ),
                ],
              ),
              pw.SizedBox(height: 20),
              
              // Top Products
              pw.Text(
                'Top 5 Products',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Product Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Sales Count', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Revenue', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...topProducts.map(
                    (product) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(product.name),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('${product.salesCount}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('₹${product.revenue.toStringAsFixed(2)}'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    
    return pdf.save();
  }

  /// Generate Seller specific PDF report from pre-calculated data
  Future<Uint8List> generateSellerPdfReport({
    required String sellerName,
    required DateTime? start,
    required DateTime? end,
    required double totalSales,
    required int totalOrders,
    required int itemsSold,
    required List<Map<String, dynamic>> topProducts, // {name, qty, revenue}
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Text(
                'Seller Analytics Report',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Seller: $sellerName',
                style: const pw.TextStyle(fontSize: 16),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Generated on: ${DateTime.now().toString().split('.')[0]}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                start != null && end != null
                    ? 'Period: ${start.toString().split(' ')[0]} to ${end.toString().split(' ')[0]}'
                    : 'Period: All Time',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 20),
              
              // Overview Metrics
              pw.Text(
                'Performance Overview',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Metric', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Value', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Total Revenue'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('₹${totalSales.toStringAsFixed(2)}'),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Total Orders'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('$totalOrders'),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Items Sold'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('$itemsSold'),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Avg. Order Value'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('₹${(totalOrders > 0 ? totalSales / totalOrders : 0).toStringAsFixed(2)}'),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              
              // Top Products
              pw.Text(
                'Top Performing Products',
                 style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Product Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Qty Sold', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Revenue', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  if (topProducts.isEmpty)
                    pw.TableRow(children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('No sales data')),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('-')),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('-')),
                    ])
                  else
                    ...topProducts.map(
                      (product) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(product['name'] ?? 'Unknown'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('${product['qty']}'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('₹${(product['revenue'] as double).toStringAsFixed(2)}'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
    
    return pdf.save();
  }
}
