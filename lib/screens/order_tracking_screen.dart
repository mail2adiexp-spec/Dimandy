import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import '../providers/auth_provider.dart';
import '../services/invoice_service.dart';
import '../services/notification_service.dart';
import '../widgets/modify_order_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderTrackingScreen extends StatelessWidget {
  final OrderModel order;
  final bool isAdminOrPartner;

  const OrderTrackingScreen({
    super.key, 
    required this.order, 
    this.isAdminOrPartner = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Order Tracking #${order.id.substring(0, 8)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isAdminOrPartner) _buildAdminActions(context),
        ],
      ),
      body: isDesktop 
          ? _buildDesktopView(context, theme)
          : _buildMobileView(context, theme),
      bottomNavigationBar: !isAdminOrPartner ? _buildCustomerActions(context) : null,
    );
  }

  Widget _buildAdminActions(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.print),
      onSelected: (value) async {
        try {
          String? customerName = 'Customer'; // In a real app, fetch name or phone
          if (value == 'invoice') {
            await InvoiceService.generateInvoice(order, customerName: customerName);
          } else if (value == 'label') {
            await InvoiceService.generateShippingLabel(order, customerName: customerName);
          }
        } catch (e) {
          debugPrint('Error generating PDF: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to generate PDF: $e')),
            );
          }
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'invoice',
          child: Row(
            children: [
              Icon(Icons.description, color: Colors.blue),
              SizedBox(width: 8),
              Text('Customer Invoice'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'label',
          child: Row(
            children: [
              Icon(Icons.local_shipping, color: Colors.orange),
              SizedBox(width: 8),
              Text('Shipping Label'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopView(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side: Order Info & Items
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildOrderInfoCard(theme),
                  const SizedBox(height: 24),
                  _buildItemsCard(theme),
                  const SizedBox(height: 24),
                  _buildDeliveryInfoCard(theme),
                ],
              ),
            ),
          ),
          const SizedBox(width: 32),
          // Right Side: Tracking Timeline
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildTrackingTimelineCard(theme),
                  if (isAdminOrPartner) ...[
                    const SizedBox(height: 24),
                    _buildAdminControlCard(context, theme),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileView(BuildContext context, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildOrderInfoCard(theme),
          const SizedBox(height: 16),
          _buildTrackingTimelineCard(theme),
          const SizedBox(height: 16),
          _buildItemsCard(theme),
          const SizedBox(height: 16),
          _buildDeliveryInfoCard(theme),
          if (isAdminOrPartner) ...[
            const SizedBox(height: 16),
            _buildAdminControlCard(context, theme),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grand Total',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(order.status),
              ],
            ),
            const Divider(height: 48),
            Row(
              children: [
                _buildInfoBit('Placed On', DateFormat('dd MMM yyyy, hh:mm a').format(order.orderDate)),
                const Spacer(),
                if (order.estimatedDelivery != null)
                  _buildInfoBit('Exp. Delivery', DateFormat('dd MMM yyyy').format(order.estimatedDelivery!)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBit(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        order.getStatusText().toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTrackingTimelineCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tracking Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildTimeline(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    final statuses = [
      {'key': 'pending', 'label': 'Order Received'},
      {'key': 'confirmed', 'label': 'Order Confirmed'},
      {'key': 'packed', 'label': 'Packing Complete'},
      {'key': 'shipped', 'label': 'Shipped'},
      {'key': 'out_for_delivery', 'label': 'Out for Delivery'},
      {'key': 'delivered', 'label': 'Delivered'},
      if (['return_requested', 'returned', 'refunded'].contains(order.status)) ...[
        {'key': 'return_requested', 'label': 'Return Requested'},
        {'key': 'returned', 'label': 'Returned'},
        {'key': 'refunded', 'label': 'Refunded'},
      ],
      if (order.status == 'cancelled') {'key': 'cancelled', 'label': 'Cancelled'},
    ];

    final currentIndex = statuses.indexWhere((s) => s['key'] == order.status);

    return Column(
      children: List.generate(statuses.length, (index) {
        final status = statuses[index];
        final isCompleted = index <= currentIndex;
        final isCurrent = index == currentIndex;
        final hasLink = index < statuses.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted ? Colors.green : Colors.grey[300],
                    ),
                    child: Icon(
                      isCompleted ? Icons.check : Icons.circle,
                      size: 14,
                      color: isCompleted ? Colors.white : Colors.grey[300],
                    ),
                  ),
                  if (hasLink)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isCompleted ? Colors.green : Colors.grey[300],
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status['label']!,
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCompleted ? Colors.black : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      if (order.statusHistory != null && order.statusHistory!.containsKey(status['key']))
                        Text(
                          DateFormat('dd MMM, hh:mm a').format(order.statusHistory![status['key']]!),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildItemsCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Order Items',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${order.items.length} Items',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...order.items.map((item) => _buildOrderItem(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              image: item.imageUrl != null 
                  ? DecorationImage(image: NetworkImage(item.imageUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: item.imageUrl == null ? const Icon(Icons.shopping_bag_outlined, color: Colors.grey) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Qty: ${item.quantity}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '₹${(item.price * item.quantity).toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryInfoCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Address',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, color: Colors.red, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.deliveryAddress,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(order.phoneNumber, style: const TextStyle(fontWeight: FontWeight.w500)),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.call, color: Colors.green, size: 20),
                                onPressed: () => _makePhoneCall(order.phoneNumber),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminControlCard(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Controls',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => ModifyOrderDialog(
                      orderId: order.id, 
                      orderData: order.toMap()..['id'] = order.id, 
                      isCustomer: false
                    ),
                  ).then((updated) {
                    if (updated == true) {
                       context.read<OrderProvider>().fetchUserOrders();
                    }
                  });
                },
                icon: const Icon(Icons.edit_note),
                label: const Text('Modify Order Items'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildCustomerActions(BuildContext context) {
    if (['pending', 'confirmed'].contains(order.status)) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _confirmAction(context, 'cancelled', 'Cancel Order'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancel Order'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => ModifyOrderDialog(
                        orderId: order.id, 
                        orderData: order.toMap()..['id'] = order.id, 
                        isCustomer: true
                      ),
                    ).then((updated) {
                      if (updated == true) {
                        context.read<OrderProvider>().fetchUserOrders();
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Modify Order'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (order.status == 'delivered') {
      final deliveredDate = order.statusHistory?['delivered'];
      if (deliveredDate != null) {
        final difference = DateTime.now().difference(deliveredDate).inDays;
        if (difference <= 7) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: () => _confirmAction(context, 'return_requested', 'Return Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Return Order'),
              ),
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
            children: [
              const Text('Please provide your Bank Account or UPI ID for refund processing:'),
              const SizedBox(height: 16),
              TextField(
                controller: upiController,
                decoration: const InputDecoration(
                  labelText: 'UPI ID / Bank Details',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 9999999999@upi',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (upiController.text.trim().isEmpty) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Valid Refund Details')));
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
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
          ],
        ),
      ) ?? false;
    }

    if (confirmed == true && context.mounted) {
      try {
        await context.read<OrderProvider>().updateOrderStatus(
          order.id, 
          newStatus, 
          refundDetails: refundDetails
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Order status updated to $newStatus')),
          );
          Navigator.pop(context); 
        }
        
        // Notification Logic
        _notifySellers(order, newStatus);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _notifySellers(OrderModel order, String newStatus) async {
    try {
      final Set<String> sellerIds = {};
      for (var item in order.items) {
         if (item.sellerId.isNotEmpty) sellerIds.add(item.sellerId);
      }

      final notificationService = NotificationService();
      for (var sellerId in sellerIds) {
         String title = 'Order Update';
         String body = 'Order #${order.id.substring(0,8)} has been updated.';
         String type = 'order_update';

         if (newStatus == 'cancelled') {
           title = 'Order Cancelled';
           body = 'Order #${order.id.substring(0,8)} has been cancelled by the user.';
           type = 'order_cancelled';
         } else if (newStatus == 'return_requested') {
           title = 'Return Requested';
           body = 'Return requested for Order #${order.id.substring(0,8)}.';
           type = 'return_requested';
         }

         await notificationService.sendNotification(
           toUserId: sellerId,
           title: title,
           body: body,
           type: type,
           relatedId: order.id,
         );
      }
    } catch (e) {
      debugPrint('Error sending notifications: $e');
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      debugPrint('Could not launch $launchUri');
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'out_for_delivery': return Colors.orange;
      case 'shipped': return Colors.blue;
      case 'confirmed': return Colors.indigo;
      case 'packed': return Colors.teal;
      default: return Colors.grey;
    }
  }
}
