import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SellerDetailsWidget extends StatefulWidget {
  final String sellerId;

  const SellerDetailsWidget({Key? key, required this.sellerId}) : super(key: key);

  @override
  State<SellerDetailsWidget> createState() => _SellerDetailsWidgetState();
}

class _SellerDetailsWidgetState extends State<SellerDetailsWidget> {
  late Stream<QuerySnapshot> _productsStream;
  late Stream<QuerySnapshot> _ordersStream;

  @override
  void initState() {
    super.initState();
    _productsStream = FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: widget.sellerId)
        .snapshots();
    
    _ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: StreamBuilder<QuerySnapshot>(
        stream: _productsStream,
        builder: (context, productSnapshot) {
          final productCount = productSnapshot.data?.docs.length ?? 0;

          return StreamBuilder<QuerySnapshot>(
            stream: _ordersStream,
            builder: (context, orderSnapshot) {
              final orders = orderSnapshot.data?.docs ?? [];
              final sellerOrders = orders.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final items = data['items'] as List<dynamic>? ?? [];
                return items.any((item) => item['sellerId'] == widget.sellerId);
              }).toList();

              final orderCount = sellerOrders.length;

              double totalRevenue = 0;
              for (var order in sellerOrders) {
                final data = order.data() as Map<String, dynamic>;
                final items = data['items'] as List<dynamic>? ?? [];
                for (var item in items) {
                  if (item['sellerId'] == widget.sellerId) {
                    totalRevenue += ((item['price'] as num?)?.toDouble() ?? 0) * 
                                  ((item['quantity'] as num?)?.toInt() ?? 1);
                  }
                }
              }

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatCard(
                    'Total Products',
                    productCount.toString(),
                    Icons.inventory,
                    Colors.blue,
                  ),
                  _buildStatCard(
                    'Total Orders',
                    orderCount.toString(),
                    Icons.shopping_bag,
                    Colors.orange,
                  ),
                  _buildStatCard(
                    'Total Revenue',
                    NumberFormat.currency(locale: 'en_IN', symbol: '₹')
                        .format(totalRevenue),
                    Icons.currency_rupee,
                    Colors.green,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
