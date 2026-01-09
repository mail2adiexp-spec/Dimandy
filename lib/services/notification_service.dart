import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send a notification to a specific user (or role-based logic if needed later)
  Future<void> sendNotification({
    required String toUserId,
    required String title,
    required String body,
    required String type, // 'order_update', 'return_request', 'system'
    String? relatedId, // e.g., Order ID
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'toUserId': toUserId,
        'title': title,
        'body': body,
        'type': type,
        'relatedId': relatedId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Notification sent to $toUserId: $title');
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  /// Send notification to all admins (Assuming we don't have a rigid admin list, 
  /// we might need to query users with role='admin' or just send to a known admin ID for now.
  /// For this MVP, we might skip this or implement if we have admin IDs).
  Future<void> notifyAdmins({
    required String title, 
    required String body, 
    required String type, 
    String? relatedId
  }) async {
    try {
      // Query users where role is admin
      final adminSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (var doc in adminSnapshot.docs) {
        await sendNotification(
          toUserId: doc.id,
          title: title,
          body: body,
          type: type,
          relatedId: relatedId,
        );
      }
    } catch (e) {
      debugPrint('Error notifying admins: $e');
    }
  }

  /// Broadcast notification to all delivery partners (e.g. for new available returns)
  Future<void> notifyDeliveryPartners({
    required String title,
    required String body,
    required String type,
    String? relatedId,
    String? pincode, // Optional: Filter by pincode if needed later
  }) async {
    try {
      // In a real app, you'd filter by status='available' and verified=true
      // For now, let's just query users with role='delivery_partner'
      Query query = _firestore.collection('users').where('role', isEqualTo: 'delivery_partner');
      
      // Note: Filtering by pincode here requires the delivery partner user doc to have 'pincode' field
      // which we might not have standardized yet. Skipping pincode filter for MVP broadcast.
      
      final snapshot = await query.get();

      for (var doc in snapshot.docs) {
         await sendNotification(
          toUserId: doc.id,
          title: title,
          body: body,
          type: type,
          relatedId: relatedId,
        );
      }
    } catch (e) {
       debugPrint('Error notifying delivery partners: $e');
    }
  }
}
