import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';

class SellerOrdersScreen extends StatelessWidget {
  static const routeName = '/seller-orders';

  const SellerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final sellerId = auth.currentUser?.uid;

    if (sellerId == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view orders')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .orderBy('orderDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allOrders = snapshot.data?.docs ?? [];
          
          // Filter orders that contain items from this seller
          final sellerOrders = allOrders.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final items = data['items'] as List<dynamic>? ?? [];
            return items.any((item) => item['sellerId'] == sellerId);
          }).toList();

          if (sellerOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No orders found',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sellerOrders.length,
            itemBuilder: (context, index) {
              final doc = sellerOrders[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildOrderCard(context, doc.id, data, sellerId);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    String orderId,
    Map<String, dynamic> data,
    String sellerId,
  ) {
    final status = data['status'] as String? ?? 'pending';
    final orderDate = DateTime.tryParse(data['orderDate'] ?? '') ?? DateTime.now();
    final items = (data['items'] as List<dynamic>? ?? [])
        .where((item) => item['sellerId'] == sellerId)
        .toList();
    
    // Calculate total for this seller only
    double sellerTotal = 0;
    for (var item in items) {
      sellerTotal += (item['price'] as num) * (item['quantity'] as num);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text('Order #${orderId.substring(0, 8)}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMM dd, yyyy hh:mm a').format(orderDate)),
            Text(
              'Your Items: ${items.length} • Total: ₹${sellerTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        trailing: _buildStatusChip(status),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Details
                const Text(
                  'Customer Details',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('Address: ${data['deliveryAddress'] ?? 'N/A'}'),
                Text('Phone: ${data['phoneNumber'] ?? 'N/A'}'),
                const Divider(height: 24),
                
                // Items
                const Text(
                  'Items',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('${item['productName']} x${item['quantity']}'),
                      ),
                      Text('₹${((item['price'] as num) * (item['quantity'] as num)).toStringAsFixed(2)}'),
                    ],
                  ),
                )),
                
                // Actions
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (['pending', 'confirmed', 'packed'].contains(status))
                      ElevatedButton.icon(
                        onPressed: () => _showCancelDialog(context, orderId),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancel Order'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'delivered': color = Colors.green; break;
      case 'cancelled': color = Colors.red; break;
      case 'out_for_delivery': color = Colors.orange; break;
      case 'shipped': color = Colors.blue; break;
      case 'packed': color = Colors.indigo; break;
      default: color = Colors.grey;
    }

    return Chip(
      label: Text(
        status.toUpperCase().replaceAll('_', ' '),
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  void _showCancelDialog(BuildContext context, String orderId) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to cancel this order?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Reason required')),
                );
                return;
              }
              Navigator.pop(ctx);
              
              try {
                await Provider.of<OrderProvider>(context, listen: false)
                    .cancelOrder(orderId, reasonCtrl.text.trim(), 'seller');
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Order cancelled')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
  }
}
