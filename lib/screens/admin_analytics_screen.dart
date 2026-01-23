import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/analytics_service.dart';

class MasterAnalyticsScreen extends StatefulWidget {
  const MasterAnalyticsScreen({super.key});

  @override
  State<MasterAnalyticsScreen> createState() => _MasterAnalyticsScreenState();
}

class _MasterAnalyticsScreenState extends State<MasterAnalyticsScreen> with SingleTickerProviderStateMixin {
  final AnalyticsService _analytics = AnalyticsService();
  late AnimationController _refreshController;
  
  // Data State
  bool _isLoading = true;
  double _totalRevenue = 0;
  int _totalOrders = 0;
  int _activeUsers = 0;
  int _productsSold = 0;
  List<DailySales> _salesTrend = [];
  List<TopProduct> _topProducts = [];
  
  // New Data State
  Map<String, int> _ordersByStatus = {};
  Map<String, int> _salesByCategory = {};
  List<UserGrowth> _userGrowth = [];
  
  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
        duration: const Duration(seconds: 1),
        vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final revenue = await _analytics.getTotalRevenue();
      final orders = await _analytics.getTotalOrders();
      final users = await _analytics.getActiveUsers();
      final products = await _analytics.getTotalProductsSold();
      
      // Default to last 30 days for trend
      final end = DateTime.now();
      final start = end.subtract(const Duration(days: 30));
      final trend = await _analytics.getDailySales(start, end);
      final growth = await _analytics.getUserGrowth(start, end);
      
      final topProds = await _analytics.getTopProducts(5);
      final status = await _analytics.getOrdersByStatus();
      final catSales = await _analytics.getSalesByCategory();

      if (mounted) {
        setState(() {
          _totalRevenue = revenue;
          _totalOrders = orders;
          _activeUsers = users;
          _productsSold = products;
          _salesTrend = trend;
          _topProducts = topProds;
          _ordersByStatus = status;
          _salesByCategory = catSales;
          _userGrowth = growth;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching analytics: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onRefresh() async {
    _refreshController.repeat();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Refreshing data...'), duration: Duration(seconds: 1)),
    );
    await _fetchData();
    if (mounted) {
      _refreshController.stop();
      _refreshController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),
          const SizedBox(height: 24),

          // Key Metrics Grid
          _buildMetricsGrid(),
          const SizedBox(height: 32),

          // Charts Section
          if (_salesTrend.isNotEmpty) ...[
            const Text('Sales Trend (Last 30 Days)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
             SizedBox(
              height: 300,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LineChart(_mainData()),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
          
          if (_ordersByStatus.isNotEmpty) ...[
            const Text('Orders by Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                 child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: PieChart(
                    PieChartData(
                      sections: _getPieSections(_ordersByStatus),
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
              ),
            ),
             const SizedBox(height: 32),
          ],

          if (_salesByCategory.isNotEmpty) ...[
            const Text('Sales by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
             SizedBox(
              height: 300,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                 child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: PieChart(
                    PieChartData(
                      sections: _getPieSections(_salesByCategory),
                      centerSpaceRadius: 40,
                       sectionsSpace: 2,
                    ),
                  ),
                ),
              ),
            ),
             const SizedBox(height: 32),
          ],
          
           if (_userGrowth.isNotEmpty) ...[
            const Text('User Growth (Last 30 Days)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LineChart(_userGrowthData()),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],

          // Top Products List
          const Text('Top Selling Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildTopProductsList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Visual Analytics',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        RotationTransition(
          turns: _refreshController,
          child: IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: _onRefresh,
            tooltip: 'Refresh Data',
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    final width = MediaQuery.of(context).size.width;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: width < 900 ? 2 : 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: width < 600 ? 1.1 : 1.5,
      children: [
        _buildMetricCard(
          title: 'Total Revenue',
          value: NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(_totalRevenue),
          icon: Icons.currency_rupee,
          color: Colors.green,
        ),
        _buildMetricCard(
          title: 'Total Orders',
          value: NumberFormat.compact().format(_totalOrders),
          icon: Icons.shopping_cart,
          color: Colors.blue,
        ),
        _buildMetricCard(
          title: 'Active Users',
          value: NumberFormat.compact().format(_activeUsers),
          icon: Icons.people,
          color: Colors.orange,
        ),
        _buildMetricCard(
          title: 'Products Sold',
          value: NumberFormat.compact().format(_productsSold),
          icon: Icons.inventory,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _isLoading ? '...' : value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title, 
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsList() {
    if (_topProducts.isEmpty) {
      if (_isLoading) return const Center(child: CircularProgressIndicator());
      return const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No sales data yet')));
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _topProducts.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final product = _topProducts[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.1),
              child: Text('${index + 1}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
            title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${product.salesCount} sold'),
            trailing: Text(
              NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(product.revenue),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
          );
        },
      ),
    );
  }

  LineChartData _mainData() {
    double maxY = _salesTrend.isEmpty ? 100 : _salesTrend.map((e) => e.revenue).reduce((a, b) => a > b ? a : b);
    if (maxY == 0) maxY = 100;
    
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY / 5,
        getDrawingHorizontalLine: (value) {
          return const FlLine(color: Color(0xffe7e8ec), strokeWidth: 1);
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 5,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= 0 && value.toInt() < _salesTrend.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('dd/MM').format(_salesTrend[value.toInt()].date),
                    style: const TextStyle(color: Color(0xff68737d), fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                );
              }
              return const Text('');
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 42,
            interval: maxY / 5,
            getTitlesWidget: (value, meta) {
              return Text(
                NumberFormat.compact().format(value),
                style: const TextStyle(color: Color(0xff67727d), fontWeight: FontWeight.bold, fontSize: 10),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: (_salesTrend.length - 1).toDouble(),
      minY: 0,
      maxY: maxY * 1.1,
      lineBarsData: [
        LineChartBarData(
          spots: _salesTrend.asMap().entries.map((e) {
            return FlSpot(e.key.toDouble(), e.value.revenue);
          }).toList(),
          isCurved: true,
          color: Colors.blue,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.blue.withOpacity(0.1),
          ),
        ),
      ],
    );
  }

  LineChartData _userGrowthData() {
    double maxY = _userGrowth.isEmpty ? 100 : _userGrowth.map((e) => e.totalUsers).reduce((a, b) => a > b ? a : b).toDouble();
    if (maxY == 0) maxY = 100;
     
    return LineChartData(
      gridData: FlGridData(show: true, drawVerticalLine: false),
      titlesData: FlTitlesData(
         show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
         bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
             reservedSize: 30,
             interval: 5,
             getTitlesWidget: (value, meta) {
               if (value.toInt() >= 0 && value.toInt() < _userGrowth.length) {
                 return Padding(
                   padding: const EdgeInsets.only(top: 8.0),
                   child: Text(
                     DateFormat('dd/MM').format(_userGrowth[value.toInt()].date),
                     style: const TextStyle(color: Color(0xff68737d), fontWeight: FontWeight.bold, fontSize: 10),
                   ),
                 );
               }
               return const Text('');
             },
          ),
        ),
      ),
       lineBarsData: [
        LineChartBarData(
          spots: _userGrowth.asMap().entries.map((e) {
            return FlSpot(e.key.toDouble(), e.value.totalUsers.toDouble()); 
          }).toList(),
           isCurved: true,
          color: Colors.orange,
           barWidth: 3,
           belowBarData: BarAreaData(show: true, color: Colors.orange.withOpacity(0.1)),
        ),
       ],
    );
  }

  List<PieChartSectionData> _getPieSections(Map<String, int> data) {
    // Basic color palette
    final colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal];
    int colorIndex = 0;
    
    return data.entries.map((entry) {
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      
      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${entry.key}\n${entry.value}',
        radius: 60,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }
}

extension on UserGrowth {
   int get users => totalUsers;
}
