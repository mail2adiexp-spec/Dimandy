import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().fetchUserOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders'), centerTitle: true),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, child) {
          if (orderProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (orderProvider.orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 100,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Orders',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You haven\'t placed any orders yet',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orderProvider.orders.length,
            itemBuilder: (context, index) {
              final order = orderProvider.orders[index];
              return _buildOrderCard(context, order);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderModel order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderTrackingScreen(order: order),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  _buildStatusChip(order.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('dd MMM yyyy, hh:mm a').format(order.orderDate),
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const Divider(height: 24),
              Text(
                '${order.items.length} items • ₹${order.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (order.trackingNumber != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Tracking Number: ${order.trackingNumber}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (['pending', 'confirmed'].contains(order.status))
                    TextButton.icon(
                      onPressed: () {
                         Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderTrackingScreen(order: order), // Navigate to detail first/or confirm dialog directly?
                            // Better to keep consistent logic. Let's redirect to tracking screen where logic resides or duplicate logic?
                            // Duplicating logic is messy. Let's just let them go to tracking screen OR verify logic.
                            // User said 'button hidden', so let's put it here but maybe just navigate or trigger same dialog.
                            // Since _confirmAction is in State of OrderTrackingScreen (wait, no, it is inside MyOrdersScreenState? No, OrderTrackingScreen is separate stateless widget).
                            // OrderTrackingScreen is Statelss. _confirmAction is inside OrderTrackingScreen.
                            // I cannot call _confirmAction from here easily without refactoring.
                            // For now, I will NOT add logic here to avoid complexity, but I will ensure the button on the next screen is VERY visible.
                            // Wait, OrderTrackingScreen IS visible.
                            // Let's just stick to the SafeArea fix which is robust.
                            // But I can add "Cancel" button here that navigates to tracking screen with auto-popup? Too complex.
                            // I will add a button that simply opens the tracking screen but labeled 'Cancel'.
                           ),
                        );
                      },
                      icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                      label: const Text('Cancel', style: TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              OrderTrackingScreen(order: order),
                        ),
                      );
                    },
                    icon: const Icon(Icons.local_shipping, size: 18),
                    label: const Text('Track Order'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'delivered':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      case 'out_for_delivery':
        color = Colors.orange;
        break;
      case 'shipped':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        OrderModel(
          id: '',
          userId: '',
          items: [],
          totalAmount: 0,
          deliveryAddress: '',
          phoneNumber: '',
          orderDate: DateTime.now(),
          status: status,
        ).getStatusText(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class OrderTrackingScreen extends StatelessWidget {
  final OrderModel order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Tracking'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order #${order.id.substring(0, 8)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          order.getStatusText(),
                          style: TextStyle(
                            color: _getStatusColor(order.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Order Date: ${DateFormat('dd MMM yyyy').format(order.orderDate)}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    if (order.estimatedDelivery != null)
                      Text(
                        'Estimated Delivery: ${DateFormat('dd MMM yyyy').format(order.estimatedDelivery!)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    if (order.trackingNumber != null) ...[
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Icon(Icons.numbers, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Tracking Number: ${order.trackingNumber}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),



            // Tracking Timeline
            const Text(
              'Order Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTrackingTimeline(),

            const SizedBox(height: 24),

            // Delivery Address
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Delivery Address',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(order.deliveryAddress),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 16),
                        const SizedBox(width: 8),
                        Text(order.phoneNumber),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Order Items
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Items',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...order.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${item.productName} x ${item.quantity}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Text(
                              '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '₹${order.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomAction(context),
    );
  }

  Widget? _buildBottomAction(BuildContext context) {
    // 1. Cancel Logic: Allow cancellation if status is pending or confirmed
    if (['pending', 'confirmed'].contains(order.status)) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: () => _confirmAction(context, 'cancelled', 'Cancel Order'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Cancel Order'),
          ),
        ),
      );
    }

    // 2. Return Logic: Allow return if delivered and within 7 days
    if (order.status == 'delivered') {
      final deliveredDate = order.statusHistory?['delivered'];
      if (deliveredDate != null) {
        final difference = DateTime.now().difference(deliveredDate).inDays;
        
        if (difference <= 7) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => _confirmAction(context, 'return_requested', 'Return Order'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Return Order'),
            ),
          );
        }
      }
    }
    
    return null;
  }

  Future<void> _confirmAction(BuildContext context, String newStatus, String label) async {
    Map<String, dynamic>? refundDetails;
    bool confirmed = false;

    if (newStatus == 'return_requested') {
      final upiController = TextEditingController();
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Return Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please provide your Bank Account or UPI ID for refund processing:'),
              const SizedBox(height: 16),
              TextField(
                controller: upiController,
                decoration: const InputDecoration(
                  labelText: 'UPI ID / Bank Details',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 9999999999@upi or Acc No + IFSC',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              const Text(
                'Refund will be processed within 48 hours to this account.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (upiController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter Valid Refund Details')),
                  );
                  return;
                }
                refundDetails = {'paymentInfo': upiController.text.trim()};
                Navigator.pop(context, true);
              },
              child: const Text('Confirm Return'),
            ),
          ],
        ),
      ) ?? false;
    } else {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Confirm $label'),
          content: Text('Are you sure you want to $label?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        ),
      ) ?? false;
    }

    if (confirmed == true && context.mounted) {
      debugPrint('DEBUG: Converting order ${order.id} to status $newStatus');
      try {
        await context.read<OrderProvider>().updateOrderStatus(
          order.id, 
          newStatus, 
          refundDetails: refundDetails
        );
        debugPrint('DEBUG: Order status updated successfully');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Order status updated to $newStatus')),
          );
          Navigator.pop(context); // Go back to refresh list
        }
      } catch (e) {
        debugPrint('DEBUG: Error updating order status: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildTrackingTimeline() {
    final statuses = [
      {'key': 'pending', 'label': 'Order Received'},
      {'key': 'confirmed', 'label': 'Order Confirmed'},
      {'key': 'packed', 'label': 'Packing Complete'},
      {'key': 'shipped', 'label': 'Shipped'},
      {'key': 'out_for_delivery', 'label': 'Out for Delivery'},
      {'key': 'delivered', 'label': 'Delivered'},
      // Return Flow
      if (['return_requested', 'returned', 'refunded'].contains(order.status)) ...[
        {'key': 'return_requested', 'label': 'Return Requested'},
        {'key': 'returned', 'label': 'Returned'},
        {'key': 'refunded', 'label': 'Refunded'},
      ],
    ];

    final currentIndex = statuses.indexWhere((s) => s['key'] == order.status);
    final currentStatusLabel = statuses.firstWhere(
      (s) => s['key'] == order.status, 
      orElse: () => {'label': order.status}
    )['label'];
    final currentColor = _getStatusColor(order.status);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: currentColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.local_shipping_outlined, color: currentColor),
        ),
        title: Text(
          'Status: $currentStatusLabel',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: currentColor,
            fontSize: 16,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Divider(),
          const SizedBox(height: 16),
          Column(
            children: [
              ...List.generate(statuses.length, (index) {
        final status = statuses[index];
        final isCompleted = index <= currentIndex;
        final isCurrent = index == currentIndex;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted ? Colors.green : Colors.grey[300],
                    border: Border.all(
                      color: isCompleted ? Colors.green : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isCompleted ? Icons.check : Icons.circle,
                    size: 16,
                    color: isCompleted ? Colors.white : Colors.grey,
                  ),
                ),
                if (index < statuses.length - 1)
                  Container(
                    width: 2,
                    height: 40,
                    color: isCompleted ? Colors.green : Colors.grey[300],
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status['label']!,
                    style: TextStyle(
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 15,
                      color: isCompleted ? Colors.black : Colors.grey,
                    ),
                  ),
                  if (order.statusHistory != null &&
                      order.statusHistory!.containsKey(status['key']))
                    Text(
                      DateFormat(
                        'dd MMM, hh:mm a',
                      ).format(order.statusHistory![status['key']]!),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  if (index < statuses.length - 1) const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        );

      }),
      if (order.status == 'returned')
        Container(
          margin: const EdgeInsets.only(top: 24, left: 8), // Indent to align with line
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Refund Initiated',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Refund will be processed within 48 hours.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
            ],
          ),
        ], // Close ExpansionTile children
      ), // Close ExpansionTile
    ); // Close Card
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'delivered':
      case 'refunded':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'out_for_delivery':
      case 'return_requested':
        return Colors.orange;
      case 'shipped':
      case 'returned':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
