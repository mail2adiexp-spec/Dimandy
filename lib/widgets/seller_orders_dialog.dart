

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../providers/auth_provider.dart';
import '../widgets/barcode_scanner_screen.dart';
import '../utils/shipping_label_generator.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../services/transaction_service.dart';
import '../models/transaction_model.dart';
import '../utils/toast_utils.dart';




class SellerOrdersDialog extends StatefulWidget {
  final AppUser user;

  const SellerOrdersDialog({super.key, required this.user});

  @override
  State<SellerOrdersDialog> createState() => _SellerOrdersDialogState();
}

class _SellerOrdersDialogState extends State<SellerOrdersDialog> {
  String _selectedStatus = 'All';
  late Stream<QuerySnapshot> _ordersStream;

  @override
  void initState() {
    super.initState();
    // Initialize stream only once
    _ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('orderDate', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 900,
      height: 700,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Orders',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),
          
          // Status Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'pending', 'confirmed', 'packed', 'shipped', 'out_for_delivery', 'delivered', 'cancelled']
                  .map((status) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(status == 'All' ? status : status.replaceAll('_', ' ').toUpperCase()),
                          selected: _selectedStatus == status,
                          onSelected: (selected) {
                            setState(() => _selectedStatus = status);
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _ordersStream, // Use cached stream
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filter orders containing seller's products
                final allOrders = snapshot.data?.docs ?? [];
                final relevantOrders = allOrders.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final items = data['items'] as List<dynamic>? ?? [];
                  
                  // Check if order contains seller's products
                  bool hasSellersProduct = items.any((item) => item['sellerId'] == widget.user.uid);
                  if (!hasSellersProduct) return false;
                  
                  // Apply status filter
                  if (_selectedStatus != 'All') {
                    final orderStatus = data['status'] ?? 'pending';
                    return orderStatus == _selectedStatus;
                  }
                  return true;
                }).toList();

                if (relevantOrders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _selectedStatus == 'All' ? 'No orders yet' : 'No $_selectedStatus orders',
                          style: const TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: relevantOrders.length,
                  itemBuilder: (context, index) {
                    final orderData = relevantOrders[index].data() as Map<String, dynamic>;
                    final orderId = relevantOrders[index].id;
                    final status = orderData['status'] ?? 'pending';
                    final items = orderData['items'] as List<dynamic>? ?? [];
                    
                    // Filter only seller's items
                    final sellerItems = items.where((item) => item['sellerId'] == widget.user.uid).toList();
                    
                    // Calculate seller's portion
                    double sellerTotal = 0;
                    for (var item in sellerItems) {
                      final price = (item['price'] as num?)?.toDouble() ?? 0;
                      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                      sellerTotal += price * quantity;
                    }

                    Color statusColor;
                    switch (status.toLowerCase()) {
                      case 'delivered':
                        statusColor = Colors.green;
                        break;
                      case 'cancelled':
                        statusColor = Colors.red;
                        break;
                      case 'pending':
                        statusColor = Colors.orange;
                        break;
                      default:
                        statusColor = Colors.blue;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.1),
                          child: Icon(Icons.shopping_bag, color: statusColor),
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Order ID:',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            Text(
                              '#${orderId.substring(0, 8)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${sellerItems.length} Items',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              '₹${sellerTotal.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                        subtitle: null,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Your Items:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ...sellerItems.map((item) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${item['name']} x${item['quantity']}',
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ),
                                          Text(
                                            '₹${((item['price'] as num) * (item['quantity'] as num)).toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '₹${sellerTotal.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Barcode for Scanning
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.qr_code_scanner, size: 18, color: Colors.blue),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Scan for Pickup/Delivery',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: BarcodeWidget(
                                          barcode: Barcode.code128(),
                                          data: orderId,
                                          width: 220,
                                          height: 60,
                                          drawText: true,
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Order ID: $orderId',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Download Shipping Label Button
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.download),
                                    label: const Text('Download Shipping Label'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      side: const BorderSide(color: Colors.blue),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    onPressed: () async {
                                      try {
                                        // Fetch customer name
                                        String? customerName;
                                        final userId = orderData['userId'] as String?;
                                        if (userId != null) {
                                          try {
                                            final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
                                            if (userDoc.exists) {
                                              customerName = userDoc.data()?['name'];
                                            }
                                          } catch (e) {
                                            debugPrint('Error fetching user name: $e');
                                          }
                                        }

                                        // Generate shipping label PDF
                                        final pdfBytes = await ShippingLabelGenerator.generateShippingLabel(
                                          orderData: orderData,
                                          orderId: orderId,
                                          sellerItems: sellerItems,
                                          sellerId: widget.user.uid,
                                          customerName: customerName,
                                        );
                                        
                                        // Download/Print the PDF
                                        await Printing.layoutPdf(
                                          onLayout: (format) async => pdfBytes,
                                        );
                                        
                                        if (context.mounted) {
                                          showToast(context, '✓ Shipping label ready!');
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          showToast(context, 'Error generating label: $e', isError: true);
                                        }
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (status == 'pending' || status == 'confirmed')
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.inventory_2),
                                      label: const Text('Mark as Packed'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () async {
                                        // Open barcode scanner
                                        final result = await Navigator.push<bool>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => BarcodeScannerScreen(
                                              expectedOrderId: orderId,
                                            ),
                                          ),
                                        );

                                        // If barcode scan was successful, mark as packed
                                        if (result == true && context.mounted) {
                                          try {
                                            await FirebaseFirestore.instance
                                                .collection('orders')
                                                .doc(orderId)
                                                .update({
                                              'status': 'packed',
                                              'statusHistory.packed': FieldValue.serverTimestamp(),
                                              'updatedBy': widget.user.uid,
                                            });
                                            if (context.mounted) {
                                              showToast(context, '✓ Order verified and marked as Packed');
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              showToast(context, 'Error: $e', isError: true);
                                            }
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                if (status == 'packed')
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.airport_shuttle),
                                      label: const Text('Ready for Pickup'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () async {
                                        try {
                                          await FirebaseFirestore.instance
                                              .collection('orders')
                                              .doc(orderId)
                                              .update({
                                            'status': 'out_for_delivery', // Or a distinct 'ready_for_pickup' status if preferred, but usually handoff implies out_for_delivery or assignment
                                            'statusHistory.out_for_delivery': FieldValue.serverTimestamp(),
                                            'updatedBy': widget.user.uid,
                                          });
                                          if (context.mounted) {
                                            showToast(context, 'Order marked as Ready/Out for Delivery');
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            showToast(context, 'Error: $e', isError: true);
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                if (status == 'out_for_delivery')
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.check_circle),
                                      label: const Text('Mark as Delivered'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                           context: context,
                                           builder: (c) => AlertDialog(
                                              title: const Text('Confirm Delivery'),
                                              content: const Text('Mark this order as delivered? This will credit the wallet of all sellers in this order.'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                                TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirm')),
                                              ],
                                           ),
                                        );
                                        
                                        if (confirm != true) return;

                                        try {
                                          await FirebaseFirestore.instance
                                              .collection('orders')
                                              .doc(orderId)
                                              .update({
                                            'status': 'delivered',
                                            'statusHistory.delivered': FieldValue.serverTimestamp(),
                                            'updatedBy': widget.user.uid,
                                          });
                                          
                                          // Process Payments for ALL sellers in the order
                                          final Map<String, double> sellerEarnings = {};
                                          for (var item in items) {
                                             final sid = item['sellerId'] as String?;
                                             if (sid != null) {
                                                final price = (item['price'] as num).toDouble();
                                                final qty = (item['quantity'] as num).toInt();
                                                sellerEarnings[sid] = (sellerEarnings[sid] ?? 0) + (price * qty);
                                             }
                                          }

                                          // Create transaction records
                                          for (var entry in sellerEarnings.entries) {
                                             final tx = TransactionModel(
                                                id: '',
                                                userId: entry.key,
                                                amount: entry.value,
                                                type: TransactionType.credit,
                                                status: TransactionStatus.completed,
                                                description: 'Order earnings #${orderId.substring(0,8)}',
                                                referenceId: orderId,
                                                createdAt: DateTime.now(),
                                                metadata: {'orderId': orderId},
                                             );
                                             await TransactionService().recordTransaction(tx);
                                          }

                                          if (context.mounted) {
                                            showToast(context, '✓ Order Delivered & Wallets Credited');
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            showToast(context, 'Error: $e', isError: true);
                                          }
                                        }
                                      },
                                    ),
                                  ),
                              ],
                            ),

                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
