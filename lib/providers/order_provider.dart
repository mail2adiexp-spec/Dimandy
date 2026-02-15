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
    required String state, // Added state parameter
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

    try {
      // Extract pincode from address
      final pincodeRegex = RegExp(r'\b\d{6}\b');
      final pincodeMatch = pincodeRegex.firstMatch(deliveryAddress);
      final deliveryPincode = pincodeMatch?.group(0);

      // Fetch App Settings for Delivery Fee Calculation
      double deliveryFee = 0.0;
      try {
        final settingsDoc = await _firestore.collection('app_settings').doc('general').get();
        if (settingsDoc.exists) {
          final data = settingsDoc.data();
          if (data != null) {
            final percentage = (data['deliveryFeePercentage'] as num?)?.toDouble() ?? 0.0;
            final maxCap = (data['deliveryFeeMaxCap'] as num?)?.toDouble() ?? 0.0;
            
            if (percentage > 0) {
              final calculatedFee = totalAmount * (percentage / 100);
              deliveryFee = maxCap > 0 && calculatedFee > maxCap ? maxCap : calculatedFee;
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching delivery settings: $e');
      }

      // Extract unique seller IDs for security rules
      final sellerIds = items.map((e) => e.sellerId).toSet().toList();

      final orderData = {
        'userId': userId,
        'items': items.map((item) => item.toMap()).toList(),
        'totalAmount': totalAmount,
        'deliveryAddress': deliveryAddress,
        'phoneNumber': phoneNumber,
        'state': state, // Save state top-level
        'orderDate': DateTime.now().toIso8601String(),
        'status': 'pending',
        'statusHistory': {'pending': DateTime.now().toIso8601String()},
        'deliveryPincode': deliveryPincode,
        'deliveryFee': deliveryFee, // Save calculated fee
        'sellerIds': sellerIds, // Added for security filtering
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
            // In future, can implement round-robin or load balancing.
            final matchedSellerDoc = sellerSnapshot.docs.first;
            final matchedSellerId = matchedSellerDoc.id;
            final matchedSellerName = matchedSellerDoc.data()['name'] ?? 'Local Store'; // Or business name
            
            debugPrint('Routing: Found matching seller $matchedSellerName ($matchedSellerId)');
            
            // Update items belonging to 'admin' to this seller
            final updatedItems = (orderData['items'] as List<dynamic>).map((item) {
              if (item['sellerId'] == 'admin') {
                debugPrint('Routing: Re-assigning item ${item['productName']} from admin to $matchedSellerId');
                final Map<String, dynamic> newItem = Map.from(item);
                newItem['sellerId'] = matchedSellerId;
                // We keep the original productName. 
                // The user will see this item in their order history, 
                // and the sellerId will be this local store.
                return newItem;
              }
              return item;
            }).toList();
            
            orderData['items'] = updatedItems;
          } else {
             debugPrint('Routing: No specific seller found for pincode $deliveryPincode. Keeping as admin.');
          }
        } catch (e) {
          debugPrint('Routing Error: $e');
        }
      }
      // =======================================================================

      final docRef = await _firestore.collection('orders').add(orderData);
      debugPrint('OrderProvider: Order created with ID: ${docRef.id}');

      // Increment orderCount for the user
      await _firestore.collection('users').doc(userId).update({
        'orderCount': FieldValue.increment(1),
      });

      // Increment salesCount for each product and Create Bookings for Services
      for (var item in items) {
        // 1. Increment Sales Count
        try {
          await _firestore.collection('products').doc(item.productId).update({
            'salesCount': FieldValue.increment(item.quantity),
          });
        } catch (e) {
          debugPrint('Error incrementing salesCount for ${item.productId}: $e');
        }

        // 2. Create Booking for Services
        if (item.productId.startsWith('svc_') || (item.metadata != null && item.metadata!.containsKey('bookingDate'))) {
           try {
              debugPrint('OrderProvider: Creating booking for item ${item.productName}');
              
              DateTime bookingDate = DateTime.now();
              String address = deliveryAddress;
              String notes = '';

              if (item.metadata != null) {
                 if (item.metadata!['bookingDate'] != null) {
                    bookingDate = DateTime.parse(item.metadata!['bookingDate']);
                 }
                 if (item.metadata!['bookingTime'] != null) {
                    final parts = item.metadata!['bookingTime'].toString().split(':');
                    if (parts.length == 2) {
                       bookingDate = DateTime(
                         bookingDate.year, bookingDate.month, bookingDate.day, 
                         int.parse(parts[0]), int.parse(parts[1])
                       );
                    }
                 }
                 if (item.metadata!['address'] != null) address = item.metadata!['address'];
                 if (item.metadata!['notes'] != null) notes = item.metadata!['notes'];
              }

              final bookingId = _firestore.collection('bookings').doc().id;
              await _firestore.collection('bookings').doc(bookingId).set({
                 'id': bookingId,
                 'providerId': item.sellerId,
                 'userId': userId,
                 'orderId': docRef.id,
                 'serviceName': item.productName,
                 'customerName': authProvider.currentUser?.name ?? 'Customer',
                 'customerPhone': phoneNumber,
                 'bookingDate': Timestamp.fromDate(bookingDate),
                 'address': address,
                 'notes': notes,
                 'status': 'pending',
                 'totalCost': item.price * item.quantity,
                 'createdAt': FieldValue.serverTimestamp(),
                 'metadata': item.metadata,
              });
              
              // Notify Provider
              final notificationService = NotificationService();
              await notificationService.sendNotification(
                toUserId: item.sellerId,
                title: 'New Service Booking',
                body: 'You have a new booking for ${item.productName}',
                type: 'booking_new',
                relatedId: bookingId,
              );

              debugPrint('OrderProvider: Booking created successfully ($bookingId)');

           } catch (e) {
              debugPrint('Error creating booking for ${item.productId}: $e');
           }
        }
      }

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
