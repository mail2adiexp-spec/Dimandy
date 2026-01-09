import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../services/invoice_service.dart';

class OrderDetailsDialog extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const OrderDetailsDialog({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primaryContainer,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Details',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Order #${orderId.substring(0, orderId.length >= 12 ? 12 : orderId.length)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Print Actions
                  PopupMenuButton<String>(
                    icon: Icon(Icons.print, color: Theme.of(context).colorScheme.onPrimary),
                    tooltip: 'Print Documents',
                    onSelected: (value) async {
                      try {
                        // Create a temporary OrderModel object to pass to the service
                        final order = OrderModel.fromMap(orderData, orderId);
                        
                        // Fetch user data for name
                        String? customerName;
                        final userId = orderData['userId'] as String?;
                        if (userId != null) {
                          try {
                            final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
                            if (userDoc.exists) {
                              customerName = userDoc.data()?['name'];
                            }
                          } catch (e) {
                            debugPrint('Error fetching user name for invoice: $e');
                          }
                        }

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
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _fetchCompleteOrderData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Error loading order details: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  }

                  final completeData = snapshot.data!;
                  final userData = completeData['user'] as Map<String, dynamic>?;
                  
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer Information
                        _buildSection(
                          context,
                          'Customer Information',
                          Icons.person,
                          _buildCustomerInfo(userData),
                        ),
                        const SizedBox(height: 20),
                        
                        // Delivery Information
                        _buildSection(
                          context,
                          'Delivery Information',
                          Icons.location_on,
                          _buildDeliveryInfo(),
                        ),
                        const SizedBox(height: 20),

                        // Payment Information
                        if (orderData['paymentMethod'] == 'qr_code') ...[
                          _buildSection(
                            context,
                            'Payment Information',
                            Icons.payment,
                            PaymentVerificationSection(
                              orderId: orderId,
                              orderData: orderData,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        
                        // Order Items
                        _buildSection(
                          context,
                          'Order Items',
                          Icons.shopping_bag,
                          _buildOrderItems(),
                        ),
                        const SizedBox(height: 20),
                        
                        // Order Summary
                        _buildSection(
                          context,
                          'Order Summary',
                          Icons.receipt,
                          _buildOrderSummary(),
                        ),
                        const SizedBox(height: 20),
                        
                        // Status Timeline
                        _buildSection(
                          context,
                          'Order Timeline',
                          Icons.timeline,
                          _buildStatusTimeline(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchCompleteOrderData() async {
    final userId = orderData['userId'] as String?;
    Map<String, dynamic>? userData;
    
    if (userId != null && userId.isNotEmpty) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        
        if (userDoc.exists) {
          userData = userDoc.data();
        }
      } catch (e) {
        debugPrint('Error fetching user data: $e');
      }
    }
    
    return {
      'user': userData,
    };
  }

  Widget _buildSection(BuildContext context, String title, IconData icon, Widget content) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          content,
        ],
      ),
    );
  }

  Widget _buildCustomerInfo(Map<String, dynamic>? userData) {
    final userId = orderData['userId'] as String? ?? 'N/A';
    final userName = userData?['name'] as String? ?? 'N/A';
    final userEmail = userData?['email'] as String? ?? 'N/A';
    final phoneNumber = orderData['phoneNumber'] as String? ?? userData?['phone'] as String? ?? 'N/A';
    
    return Column(
      children: [
        _buildInfoRow('Customer Name', userName),

        _buildInfoRow('Email', userEmail),
        _buildInfoRow('Phone Number', phoneNumber),
      ],
    );
  }

  Widget _buildDeliveryInfo() {
    final address = orderData['deliveryAddress'] as String? ?? 'N/A';
    final pincode = orderData['deliveryPincode'] as String? ?? 'N/A';
    final partnerName = orderData['deliveryPartnerName'] as String?;
    final partnerId = orderData['deliveryPartnerId'] as String?;
    
    return Column(
      children: [
        _buildInfoRow('Delivery Address', address),
        _buildInfoRow('Pincode', pincode),
        if (partnerName != null)
          _buildInfoRow('Delivery Partner', partnerName),
        if (partnerId != null && partnerName == null)
          _buildInfoRow('Delivery Partner ID', partnerId),
      ],
    );
  }

  Widget _buildOrderItems() {
    final items = orderData['items'] as List<dynamic>? ?? [];
    
    if (items.isEmpty) {
      return const Text('No items in this order');
    }
    
    return Column(
      children: items.map((item) {
        final itemMap = item as Map<String, dynamic>;
        final productName = itemMap['productName'] as String? ?? 'Unknown Product';
        final quantity = itemMap['quantity'] as int? ?? 1;
        final price = (itemMap['price'] as num?)?.toDouble() ?? 0.0;
        final imageUrl = itemMap['imageUrl'] as String?;
        final sellerId = itemMap['sellerId'] as String? ?? 'N/A';
        final total = price * quantity;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    image: imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: imageUrl == null
                      ? const Icon(Icons.image, size: 40, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 12),
                // Product Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Seller ID: $sellerId', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('Quantity: $quantity', style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        'Price: ${NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(price)} each',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                // Total for this item
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(total),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOrderSummary() {
    final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final orderDateStr = orderData['orderDate'] as String?;
    DateTime? orderDate;
    try {
      if (orderDateStr != null) {
        orderDate = DateTime.tryParse(orderDateStr);
      }
    } catch (_) {}
    
    final status = orderData['status'] as String? ?? 'pending';
    
    return Column(
      children: [
        _buildInfoRow('Order Date', orderDate != null 
            ? DateFormat('dd MMM yyyy, hh:mm a').format(orderDate) 
            : 'N/A'),
        _buildInfoRow('Order Status', status.toUpperCase().replaceAll('_', ' ')),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Grand Total',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(totalAmount),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusTimeline() {
    final statusHistory = orderData['statusHistory'] as Map<String, dynamic>?;
    
    if (statusHistory == null || statusHistory.isEmpty) {
      return const Text('No status history available');
    }
    
    final sortedStatuses = statusHistory.entries.toList()
      ..sort((a, b) {
        try {
          final dateA = _parseTimestamp(a.value);
          final dateB = _parseTimestamp(b.value);
          return dateA.compareTo(dateB);
        } catch (_) {
          return 0;
        }
      });
    
    return Column(
      children: sortedStatuses.map((entry) {
        final status = entry.key;
        final timestamp = entry.value;
        DateTime? date;
        
        try {
          date = _parseTimestamp(timestamp);
        } catch (_) {}
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.toUpperCase().replaceAll('_', ' '),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (date != null)
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is String) {
      return DateTime.parse(timestamp);
    } else if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return DateTime.now();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.blue;
      case 'packed': return Colors.indigo;
      case 'shipped': return Colors.purple;
      case 'out_for_delivery': return Colors.teal;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentVerificationSection extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const PaymentVerificationSection({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<PaymentVerificationSection> createState() => _PaymentVerificationSectionState();
}

class _PaymentVerificationSectionState extends State<PaymentVerificationSection> {
  bool _isLoading = false;
  late bool _isVerified;

  @override
  void initState() {
    super.initState();
    _isVerified = widget.orderData['paymentVerified'] ?? false;
  }

  Future<void> _verifyPayment(bool verify) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'paymentVerified': verify,
        'paymentVerifiedAt': verify ? FieldValue.serverTimestamp() : null,
        // In a real app, you'd want to store the admin's ID who verified it
        // 'paymentVerifiedBy': currentAdminId, 
      });

      if (mounted) {
        setState(() {
          _isVerified = verify;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(verify ? 'Payment verified successfully' : 'Payment verification revoked'),
            backgroundColor: verify ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _viewProof(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                url,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const CircularProgressIndicator(color: Colors.white);
                },
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final proofUrl = widget.orderData['paymentProofUrl'] as String?;
    final uploadedAt = widget.orderData['paymentProofUploadedAt'];
    DateTime? uploadTime;
    
    if (uploadedAt != null) {
      if (uploadedAt is Timestamp) uploadTime = uploadedAt.toDate();
      else if (uploadedAt is String) uploadTime = DateTime.tryParse(uploadedAt);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
              ),
              child: const Text(
                'UPI QR Code',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (_isVerified)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      'Verified',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (proofUrl != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _viewProof(proofUrl),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      proofUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Proof',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    if (uploadTime != null)
                      Text(
                        'Uploaded: ${DateFormat('MMM d, h:mm a').format(uploadTime)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (!_isVerified)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : () => _verifyPayment(true),
                          icon: _isLoading 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                            : const Icon(Icons.check),
                          label: Text(_isLoading ? 'Verifying...' : 'Verify Payment'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : () => _verifyPayment(false),
                        icon: const Icon(Icons.undo, size: 16),
                        label: const Text('Revoke Verification'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ] else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.orange),
                const SizedBox(width: 12),
                const Text(
                  'No payment proof uploaded yet',
                  style: TextStyle(color: Colors.orange),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
