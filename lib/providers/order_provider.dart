import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

class OrderProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthProvider authProvider;

  List<OrderModel> _orders = [];
  bool _isLoading = false;

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;

  OrderProvider(this.authProvider);

  Future<void> fetchUserOrders() async {
    final userId = authProvider.currentUser?.uid;
    if (userId == null) {
      debugPrint('OrderProvider: No user logged in');
      _orders = [];
      notifyListeners();
      return;
    }

    debugPrint('OrderProvider: Fetching orders for user $userId');
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .get();

      debugPrint('OrderProvider: Found ${snapshot.docs.length} orders');
      _orders = snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
          .where((order) {
            // Filter out orders that contain ONLY service items
            // A service item is identified by 'svc_' prefix OR having 'bookingDate' in metadata
            final isServiceOrder = order.items.every((item) {
              final isService = item.productId.startsWith('svc_') || 
                               (item.metadata != null && item.metadata!.containsKey('bookingDate'));
              return isService;
            });
            return !isServiceOrder;
          })
          .toList();

      // Sort orders by date in memory (temporary until Firebase index is created)
      _orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      _orders = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> createOrder({
    required List<OrderItem> items,
    required double totalAmount,
    required String deliveryAddress,
    required String phoneNumber,
    required String state,
    required String paymentMethod,
    double? deliveryFee, 
    double? partnerPayout, // New: Accept explicit partner payout
    String? userName, // Added
  }) async {
    final userId = authProvider.currentUser?.uid;
    if (userId == null) {
      debugPrint('OrderProvider: Cannot create order - no user logged in');
      return null;
    }

    debugPrint('OrderProvider: Creating order for user $userId');
    debugPrint('OrderProvider: Items count: ${items.length}');
    debugPrint('OrderProvider: Total amount: $totalAmount');
    debugPrint('OrderProvider: State: $state');
    debugPrint('OrderProvider: Payment Method: $paymentMethod');

    try {
      // Extract pincode from address
      final pincodeRegex = RegExp(r'\b\d{6}\b');
      final pincodeMatch = pincodeRegex.firstMatch(deliveryAddress);
      final deliveryPincode = pincodeMatch?.group(0);

      // Fetch App Settings for Delivery Fee Calculation (if not explicitly provided)
      double calculatedDeliveryFee = deliveryFee ?? 0.0;
      double calculatedPartnerPayout = partnerPayout ?? 0.0; // Capturing payout
      
      if (deliveryFee == null) {
        try {
          final settingsDoc = await _firestore.collection('app_settings').doc('general').get();
          if (settingsDoc.exists) {
            final data = settingsDoc.data();
            if (data != null) {
              final percentage = (data['deliveryFeePercentage'] as num?)?.toDouble() ?? 0.0;
              final maxCap = (data['deliveryFeeMaxCap'] as num?)?.toDouble() ?? 0.0;
              calculatedPartnerPayout = (data['partnerDeliveryRate'] as num?)?.toDouble() ?? 0.0; // Fallback
              
              if (percentage > 0) {
                final calculatedFee = totalAmount * (percentage / 100);
                calculatedDeliveryFee = maxCap > 0 && calculatedFee > maxCap ? maxCap : calculatedFee;
              }
            }
          }
        } catch (e) {
          debugPrint('Error fetching delivery settings: $e');
        }
      }


      final orderData = {
        'userId': userId,
        'userName': userName ?? authProvider.currentUser?.name, // Use passed name or profile name
        'items': items.map((item) => item.toMap()).toList(),
        'totalAmount': totalAmount,
        'deliveryAddress': deliveryAddress,
        'phoneNumber': phoneNumber,
        'state': state, // Save state top-level
        'paymentMethod': paymentMethod,
        'orderDate': FieldValue.serverTimestamp(),
        'status': 'pending',
        'statusHistory': {'pending': DateTime.now().toIso8601String()},
        'deliveryPincode': deliveryPincode,
        'deliveryFee': calculatedDeliveryFee, 
        'partnerPayout': calculatedPartnerPayout, // Saving partner payout
      };
      
      // =======================================================================
      // PINCODE-BASED ROUTING LOGIC
      // =======================================================================
      if (deliveryPincode != null) {
        debugPrint('Routing: Checking sellers for pincode $deliveryPincode');
        try {
          // Find sellers who service this pincode
          final sellerSnapshot = await _firestore.collection('users')
              .where('role', isEqualTo: 'seller')
              .where('servicePincodes', arrayContains: deliveryPincode)
              .get();
              
          if (sellerSnapshot.docs.isNotEmpty) {
            // Found matching seller(s). For now, pick the first one.
            final matchedSellerDoc = sellerSnapshot.docs.first;
            final matchedSellerId = matchedSellerDoc.id;
            
            debugPrint('Routing: Found matching seller ${matchedSellerDoc.data()['name'] ?? 'Local Store'} ($matchedSellerId)');
            
            // Update items belonging to 'admin' to this seller
            final updatedItems = (orderData['items'] as List<dynamic>).map((item) {
              if (item['sellerId'] == 'admin') {
                final Map<String, dynamic> newItem = Map.from(item);
                newItem['sellerId'] = matchedSellerId;
                return newItem;
              }
              return item;
            }).toList();
            
            orderData['items'] = updatedItems;
          }
        } catch (e) {
          debugPrint('Routing Error: $e');
        }
      }
      
      // Recalculate unique seller IDs AFTER routing for accurate dashboard filtering
      final finalItems = orderData['items'] as List<dynamic>;
      final finalSellerIds = finalItems
          .map((item) => item['sellerId'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .toList();
      orderData['sellerIds'] = finalSellerIds;
      // =======================================================================

      final docRef = await _firestore.collection('orders').add(orderData);
      debugPrint('OrderProvider: Order created with ID: ${docRef.id}');

      // Increment orderCount for the user
      await _firestore.collection('users').doc(userId).update({
        'orderCount': FieldValue.increment(1),
      });

      // NOTE: salesCount increment and stock decrement are handled by 
      // the Cloud Function 'onOrderCreate' to avoid Permission Denied errors 
      // for customers and ensure atomicity.
      
      // Refresh user's order list

      await fetchUserOrders(); // Refresh orders
      debugPrint('OrderProvider: Orders refreshed, count: ${_orders.length}');

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating order: $e');
      return null;
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus, {Map<String, dynamic>? refundDetails}) async {
    try {
      // Fetch current status to prevent updating cancelled orders
      final currentOrderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (currentOrderDoc.exists) {
        final currentStatus = currentOrderDoc.data()?['status'];
        if (currentStatus == 'cancelled') {
          debugPrint('OrderProvider: Cannot update status of a cancelled order ($orderId)');
          throw Exception('This order is cancelled and cannot be updated.');
        }
      }

      final Map<String, dynamic> updates = {
        'status': newStatus,
        'statusHistory.$newStatus': DateTime.now().toIso8601String(),
      };
      
      if (refundDetails != null) {
        updates['refundDetails'] = refundDetails;
      }

      await _firestore.collection('orders').doc(orderId).update(updates);



      if (newStatus == 'return_requested') {
        debugPrint('DEBUG: Processing return request for order $orderId');
        // Fetch order details for notification
        final orderDoc = await _firestore.collection('orders').doc(orderId).get();
        if (orderDoc.exists) {
           final orderData = orderDoc.data()!;
           final notificationService = NotificationService();

           // 1. Notify Admin
           await notificationService.notifyAdmins(
             title: 'Return Requested', 
             body: 'Return requested for Order #$orderId', 
             type: 'return_request',
             relatedId: orderId,
           );

           // 2. Notify Delivery Partners (Broadcast for Pickup)
           await notificationService.notifyDeliveryPartners(
             title: 'New Return Pickup', 
             body: 'Return pickup available for Order #$orderId', 
             type: 'return_pickup',
             relatedId: orderId,
           );

           // 3. Notify Sellers
           final items = (orderData['items'] as List<dynamic>?) ?? [];
           final Set<String> notifiedSellers = {};
           
           for (var item in items) {
             final sellerId = item['sellerId'] as String?;
             if (sellerId != null && !notifiedSellers.contains(sellerId)) {
               await notificationService.sendNotification(
                 toUserId: sellerId,
                 title: 'Return Requested',
                 body: 'A customer requested return for an item in Order #$orderId',
                 type: 'return_request',
                 relatedId: orderId,
               );
               notifiedSellers.add(sellerId);
             }
           }
        }
      } else if (newStatus == 'returned') {
        // Notify Admin for Refund
        final notificationService = NotificationService();
        await notificationService.notifyAdmins(
          title: 'Return Received', 
          body: 'Order #$orderId has been returned. Please process refund.', 
          type: 'refund_request',
          relatedId: orderId,
        );
      }



      await fetchUserOrders();
    } catch (e) {
      debugPrint('Error updating order status: $e');
      rethrow; // Rethrow error so UI knows it failed
    }
  }

  Future<OrderModel?> getOrderById(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      if (doc.exists) {
        return OrderModel.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      debugPrint('Error fetching order: $e');
    }
    return null;
  }



  void clear() {
    _orders = [];
    notifyListeners();
  }
}
