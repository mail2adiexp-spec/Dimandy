import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';

class ModifyOrderDialog extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;
  final bool isCustomer;

  const ModifyOrderDialog({
    super.key,
    required this.orderId,
    required this.orderData,
    this.isCustomer = false,
  });

  @override
  State<ModifyOrderDialog> createState() => _ModifyOrderDialogState();
}

class _ModifyOrderDialogState extends State<ModifyOrderDialog> {
  late List<dynamic> _items;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Clone items
    _items = List.from(widget.orderData['items'] ?? []);
  }

  double get _totalAmount {
    double total = (widget.orderData['deliveryFee'] as num?)?.toDouble() ?? 0.0;
    for (var item in _items) {
      final qty = item['quantity'] as int? ?? 1;
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      total += (price * qty);
    }
    return total;
  }

  Future<void> _saveChanges() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order must have at least one item. Cancel order instead.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final newSellerIds = _items
          .map((e) => e['sellerId']?.toString())
          .where((id) => id != null)
          .toSet()
          .toList();

      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
        'items': _items,
        'totalAmount': _totalAmount,
        'sellerIds': newSellerIds,
        'modifiedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order modified successfully')));
        
        // Notify respective party
        try {
          final notificationService = NotificationService();
          if (widget.isCustomer) {
            // Customer modified -> Notify Sellers/Partners
            final sellers = widget.orderData['sellerIds'] as List<dynamic>? ?? [];
            for (var sellerId in sellers) {
              await notificationService.sendNotification(
                toUserId: sellerId.toString(),
                title: 'Order Modified by Customer',
                body: 'Order #${widget.orderId.substring(0, 8)} has been modified by the customer.',
                type: 'order_update',
                relatedId: widget.orderId,
              );
            }
          } else {
            // Partner modified -> Notify Customer
            final customerId = widget.orderData['userId'] as String?;
            if (customerId != null) {
              await notificationService.sendNotification(
                toUserId: customerId,
                title: 'Order Modified by Store',
                body: 'Your Order #${widget.orderId.substring(0, 8)} items have been updated by the store.',
                type: 'order_update',
                relatedId: widget.orderId,
              );
            }
          }
        } catch (e) {
          debugPrint('Error notifying party: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modify Order Items'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Adjust quantities or remove items before packing.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final name = item['productName'] ?? item['name'] ?? 'Item';
                  final qty = item['quantity'] as int? ?? 1;
                  final price = (item['price'] as num?)?.toDouble() ?? 0.0;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: Text('₹${price.toStringAsFixed(2)} each'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: qty > 1 ? () {
                            setState(() {
                              _items[index]['quantity'] = qty - 1;
                            });
                          } : null,
                        ),
                        Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                          onPressed: () {
                            setState(() {
                              _items[index]['quantity'] = qty + 1;
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            setState(() {
                              _items.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('New Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('₹${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveChanges,
          child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Changes'),
        ),
      ],
    );
  }
}
