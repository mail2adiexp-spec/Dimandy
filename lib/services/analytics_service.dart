import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

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



class PlatformMetrics {
  final int totalSellers;
  final int activeSellers;
  final int totalUsers;
  final int activeUsers;
  final int totalProviders;
  final int activeProviders;
  final int totalDrivers;
  final int activeDrivers;
  final double totalPlatformFees;
  final double sellerPlatformFees;
  final double servicePlatformFees;

  PlatformMetrics({
    required this.totalSellers,
    required this.activeSellers,
    required this.totalUsers,
    required this.activeUsers,
    required this.totalProviders,
    required this.activeProviders,
    required this.totalDrivers,
    required this.activeDrivers,
    required this.totalPlatformFees,
    required this.sellerPlatformFees,
    required this.servicePlatformFees,
  });
}

class EntityPerformance {
  final String id;
  final String name;
  final int count; // Orders/Deliveries/Jobs
  final double revenue; // Revenue/Earnings
  final int items; // Items sold (optional)

  EntityPerformance({
    required this.id,
    required this.name,
    required this.count,
    required this.revenue,
    required this.items,
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

  // ==================== COMPREHENSIVE METRICS ====================

  Future<PlatformMetrics> getPlatformMetrics() async {
    try {
      // 1. Fetch Users Data
      final usersSnapshot = await _firestore.collection('users').get();
      
      int totalSellers = 0;
      int activeSellers = 0;
      int totalUsers = 0;
      int activeUsers = 0;
      int totalProviders = 0;
      int activeProviders = 0;
      int totalDrivers = 0;
      int activeDrivers = 0;

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final role = data['role'] as String? ?? 'user';
        final status = data['status'] as String? ?? 'approved'; // Default to approved for legacy data
        final isActive = status == 'approved';

        if (role == 'seller') {
          totalSellers++;
          if (isActive) activeSellers++;
        } else if (role == 'user') {
          totalUsers++;
          if (isActive) activeUsers++;
        } else if (role == 'service_provider') {
          totalProviders++;
          if (isActive) activeProviders++;
        } else if (role == 'delivery_partner') {
          totalDrivers++;
          if (isActive) activeDrivers++;
        }
      }

      // 2. Calculate Platform Fees (Split by Seller and Service)
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .get();

      double totalFees = 0.0;
      double sellerFees = 0.0;
      double serviceFees = 0.0;

      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        // Check for items to calculate split revenue
        // If items are available, iterate and split
        // If not (legacy), rely on totalAmount and assume it's a product order (seller)
        
        List<dynamic> items = [];
        if (data.containsKey('items')) {
            items = data['items'] as List<dynamic>;
        }

        if (items.isNotEmpty) {
            double orderSellerRevenue = 0.0;
            double orderServiceRevenue = 0.0;

            for (var item in items) {
                final category = item['category'] as String? ?? 'Products';
                final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                
                if (category == 'Services' || category == 'Service') {
                     orderServiceRevenue += (price * qty);
                } else {
                     orderSellerRevenue += (price * qty);
                }
            }
            
            // Apply 10% fee
            sellerFees += (orderSellerRevenue * 0.10);
            serviceFees += (orderServiceRevenue * 0.10);

        } else {
             // Fallback for legacy orders without items map in top level or if empty
             // Assume product order
             final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
             final deliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;
             double goodsValue = totalAmount - deliveryFee;
             if (goodsValue < 0) goodsValue = 0;
             sellerFees += (goodsValue * 0.10);
        }
      }
      
      totalFees = sellerFees + serviceFees;

      return PlatformMetrics(
        totalSellers: totalSellers,
        activeSellers: activeSellers,
        totalUsers: totalUsers,
        activeUsers: activeUsers,
        totalProviders: totalProviders,
        activeProviders: activeProviders,
        totalDrivers: totalDrivers,
        activeDrivers: activeDrivers,
        totalPlatformFees: totalFees,
        sellerPlatformFees: sellerFees,
        servicePlatformFees: serviceFees,
      );

    } catch (e) {
      print('Error getting platform metrics: $e');
      return PlatformMetrics(
        totalSellers: 0, activeSellers: 0,
        totalUsers: 0, activeUsers: 0,
        totalProviders: 0, activeProviders: 0,
        totalDrivers: 0, activeDrivers: 0,
        totalPlatformFees: 0.0,
        sellerPlatformFees: 0.0,
        servicePlatformFees: 0.0,
      );
    }
  }

  // ==================== GRANULAR REPORTS ====================

  /// Get performance metrics for all Sellers
  Future<List<EntityPerformance>> getSellersPerformance({DateTime? start, DateTime? end}) async {
    return _getEntityPerformance(
      start: start,
      end: end,
      role: 'seller',
      itemType: 'product',
    );
  }

  /// Get performance metrics for all Service Providers
  Future<List<EntityPerformance>> getServiceProvidersPerformance({DateTime? start, DateTime? end}) async {
    return _getEntityPerformance(
      start: start,
      end: end,
      role: 'service_provider',
      itemType: 'service',
    );
  }

  /// Helper to aggregate performance based on role and item type
  Future<List<EntityPerformance>> _getEntityPerformance({
    DateTime? start,
    DateTime? end,
    required String role,
    required String itemType,
  }) async {
    try {
      // 1. Fetch all users of this role to map IDs to Names
      final usersSnapshot = await _firestore.collection('users').where('role', isEqualTo: role).get();
      final Map<String, String> namesMap = {
        for (var doc in usersSnapshot.docs) doc.id: (doc.data()['businessName'] ?? doc.data()['name'] ?? 'Unknown Users') as String
      };

      // 2. Fetch Orders
      Query query = _firestore.collection('orders').where('status', isEqualTo: 'delivered');
      if (start != null) query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
      if (end != null) query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end));
      
      final ordersSnapshot = await query.get();

      // 3. Aggregate
      Map<String, EntityPerformance> performanceMap = {};

      for (var doc in ordersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final items = (data['items'] as List? ?? []);

        for (var item in items) {
          if (item['type'] == itemType) {
            // explicit safely cast
            final sellerId = item['sellerId'] as String? ?? '';
            if (sellerId.isEmpty) continue; // Skip if no ID

            final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
            final price = (item['price'] as num?)?.toDouble() ?? 0.0;
            final total = price * quantity;

            if (performanceMap.containsKey(sellerId)) {
              final existing = performanceMap[sellerId]!;
              performanceMap[sellerId] = EntityPerformance(
                id: sellerId,
                name: existing.name,
                count: existing.count + 1, // Count line items or orders? Let's count line items here for simplicity or track unique orders
                revenue: existing.revenue + total,
                items: existing.items + quantity,
              );
            } else {
              performanceMap[sellerId] = EntityPerformance(
                id: sellerId,
                name: namesMap[sellerId] ?? 'Unknown / Deleted',
                count: 1,
                revenue: total,
                items: quantity,
              );
            }
          }
        }
      }

      return performanceMap.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue));

    } catch (e) {
      print('Error getting $role performance: $e');
      return [];
    }
  }

  /// Get performance metrics for Delivery Partners
  Future<List<EntityPerformance>> getDeliveryPartnersPerformance({DateTime? start, DateTime? end}) async {
    try {
      Query query = _firestore.collection('orders').where('status', isEqualTo: 'delivered');
      if (start != null) query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
      if (end != null) query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end));
      
      final ordersSnapshot = await query.get();

      Map<String, EntityPerformance> performanceMap = {};

      for (var doc in ordersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final partnerId = data['deliveryPartnerId'] as String?;
        final partnerName = data['deliveryPartnerName'] as String? ?? 'Unknown';
        
        if (partnerId == null) continue;

        // For delivery partners, revenue usually means their earnings (deliveryFee), 
        // OR the total value of goods delivered.
        // Let's track BOTH delivery fee (earnings) and order value handled.
        // For this standard report, 'revenue' will store Delivery Fees (earnings). 
        // If we want order value, we could add another field. 
        // Let's stick to "Value for Business" which is Delivery Fee paid out.
        
        final deliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;
        
        if (performanceMap.containsKey(partnerId)) {
          final existing = performanceMap[partnerId]!;
          performanceMap[partnerId] = EntityPerformance(
            id: partnerId,
            name: partnerName,
            count: existing.count + 1, // Total deliveries
            revenue: existing.revenue + deliveryFee,
            items: 0, // Not relevant
          );
        } else {
          performanceMap[partnerId] = EntityPerformance(
            id: partnerId,
            name: partnerName,
            count: 1,
            revenue: deliveryFee,
            items: 0,
          );
        }
      }

       return performanceMap.values.toList()..sort((a, b) => b.count.compareTo(a.count)); // Sort by delivery count

    } catch (e) {
      print('Error getting delivery partner performance: $e');
      return [];
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

      // 1. Comprehensive Metrics (Live Status)
      final platformMetrics = await getPlatformMetrics();
      csv.writeln('COMPREHENSIVE METRICS (Live Status)');
      csv.writeln('Metric,Total,Active');
      csv.writeln('Sellers,${platformMetrics.totalSellers},${platformMetrics.activeSellers}');
      csv.writeln('Users,${platformMetrics.totalUsers},${platformMetrics.activeUsers}');
      csv.writeln('Service Providers,${platformMetrics.totalProviders},${platformMetrics.activeProviders}');
      csv.writeln('Delivery Partners,${platformMetrics.totalDrivers},${platformMetrics.activeDrivers}');
      csv.writeln('');
      csv.writeln('Total Platform Fees (Est. 10%),Rs. ${platformMetrics.totalPlatformFees.toStringAsFixed(2)}');
      csv.writeln(' - From Sellers,Rs. ${platformMetrics.sellerPlatformFees.toStringAsFixed(2)}');
      csv.writeln(' - From Services,Rs. ${platformMetrics.servicePlatformFees.toStringAsFixed(2)}');
      csv.writeln('');

      // 2. Overview Metrics (Selected Period)
      csv.writeln('OVERVIEW METRICS (Selected Period)');
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
    final platformMetrics = await getPlatformMetrics();
    
    // Generate PDF
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('Admin Analytics Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
               if (start != null && end != null)
                pw.Text('Period: ${DateFormat('yyyy-MM-dd').format(start)} to ${DateFormat('yyyy-MM-dd').format(end)}')
              else
                pw.Text('Period: All Time'),
              pw.SizedBox(height: 20),

              // Comprehensive Metrics Table
              pw.Text('COMPREHENSIVE OVERVIEW (Live Status)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Table.fromTextArray(
                context: context,
                border: pw.TableBorder.all(),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                headers: ['Entity', 'Total', 'Active'],
                data: [
                  ['Sellers', '${platformMetrics.totalSellers}', '${platformMetrics.activeSellers}'],
                  ['Users', '${platformMetrics.totalUsers}', '${platformMetrics.activeUsers}'],
                  ['Service Providers', '${platformMetrics.totalProviders}', '${platformMetrics.activeProviders}'],
                  ['Delivery Partners', '${platformMetrics.totalDrivers}', '${platformMetrics.activeDrivers}'],
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Text('Total Platform Fees (Est. 10%): Rs. ${platformMetrics.totalPlatformFees.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 10, top: 4),
                child: pw.Text('• From Sellers: Rs. ${platformMetrics.sellerPlatformFees.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 10, top: 2),
                child: pw.Text('• From Services: Rs. ${platformMetrics.servicePlatformFees.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ),
              pw.Divider(),
              pw.SizedBox(height: 10),

              pw.Text('SELECTED PERIOD ANALYTICS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  if (metrics.contains('Total Revenue'))
                    _buildPdfMetricCard('Total Revenue', 'Rs. ${revenue.toStringAsFixed(2)}'),
                  if (metrics.contains('Total Orders'))
                    _buildPdfMetricCard('Total Orders', orders.toString()),
                  if (metrics.contains('Products Sold'))
                    _buildPdfMetricCard('Products Sold', productsSold.toString()),
                  if (metrics.contains('Active Users'))
                     _buildPdfMetricCard('New Users', users.toString()),
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

  /// Generate CSV report for generic entity performance
  String generateEntityCsvReport(List<EntityPerformance> data, String title) {
    final StringBuffer csv = StringBuffer();
    csv.writeln('$title Report');
    csv.writeln('Generated on: ${DateTime.now().toString()}');
    csv.writeln('');
    
    // Adjust headers based on context if needed, but generic works
    csv.writeln('Name,ID,Orders/Jobs/Deliveries,Revenue/Earnings,Items Sold');
    
    for (var item in data) {
       // Escape commas in names
       final name = item.name.contains(',') ? '"${item.name}"' : item.name;
       csv.writeln('$name,${item.id},${item.count},${item.revenue.toStringAsFixed(2)},${item.items}');
    }
    return csv.toString();
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

  /// Generate Inventory PDF Report
  Future<Uint8List> generateInventoryPdfReport({
    required String sellerName,
    required DateTime? start,
    required DateTime? end,
    required int totalProducts,
    required double inventoryValuation,
    required double totalSalesValue,
    required double totalProfit, // Added required parameter
    required int pendingOrders,
    List<Map<String, dynamic>> products = const [],
  }) async {
    final pdf = pw.Document();
    
    // Chunk products for pagination if needed, but for now we'll just add them to the page
    // Note: pw.MultiPage or similar supports automatic pagination of tables
    
    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Text(
                  'Stock & Inventory Report',
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
                if (start != null && end != null)
                  pw.Text(
                    'Sales Period: ${start.toString().split(' ')[0]} to ${end.toString().split(' ')[0]}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                pw.SizedBox(height: 20),
                
                // Key Metrics Table
                pw.Text(
                  'Inventory Overview',
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
                          child: pw.Text('Total Products Listed'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('$totalProducts'),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Inventory Valuation (Unsold Price)'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Rs.${inventoryValuation.toStringAsFixed(2)}'),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Total Sales Value'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Rs.${totalSalesValue.toStringAsFixed(2)}'),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Total Profit (Net)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Rs.${totalProfit.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Net Value (Inv - Sales)'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Rs.${(inventoryValuation - totalSalesValue).toStringAsFixed(2)}'),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                
                // Detailed Product List
                if (products.isNotEmpty) ...[
                  pw.Text(
                    'Product Inventory List',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Table(
                    border: pw.TableBorder.all(),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3), // Name
                      1: const pw.FlexColumnWidth(1), // Stock
                      2: const pw.FlexColumnWidth(1.5), // Price
                      3: const pw.FlexColumnWidth(1.5), // Total Value
                    },
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
                            child: pw.Text('Stock', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Value', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                      ...products.map((p) {
                         // Safe parsing within the map
                         double price = 0.0;
                         int stock = 0;
                         
                         if (p['price'] is num) price = (p['price'] as num).toDouble();
                         else if (p['price'] is String) price = double.tryParse(p['price']) ?? 0.0;
                         
                         if (p['stock'] is num) stock = (p['stock'] as num).toInt();
                         else if (p['stock'] is String) stock = int.tryParse(p['stock']) ?? 0;
                         
                         double totalVal = price * stock;
                         
                         return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(p['name'] ?? 'Unknown'),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('$stock'),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('Rs.${price.toStringAsFixed(0)}'),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('Rs.${totalVal.toStringAsFixed(0)}'),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                ],

                pw.Text(
                  'Note: Inventory Valuation is based on current stock and listing price. Sales Value is based on the selected period (or all time if not specified).',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ],
            ),
          ];
        },
      ),
    );
    
    return pdf.save();
  }
  pw.Widget _buildPdfMetricCard(String title, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      width: 150,
      child: pw.Column(
        children: [
          pw.Text(title, style: const pw.TextStyle(color: PdfColors.grey700)),
          pw.SizedBox(height: 5),
          pw.Text(value, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}

