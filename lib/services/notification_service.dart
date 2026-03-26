import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final Logger _logger = Logger();

  Future<void> initPushNotifications() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true, badge: true, sound: true,
    );
    _logger.i('User granted permission: ${settings.authorizationStatus}');

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true);

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onSelectNotification,
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', 
      'High Importance Notifications', 
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });
  }

  void _onSelectNotification(NotificationResponse response) {
    if (response.payload != null) {
      _logger.i('Notification payload: ${response.payload}');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      await _localNotificationsPlugin.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications.',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  Future<void> subscribeToAdminOrders() async {
    await _fcm.subscribeToTopic('admin_new_orders');
    _logger.i('Subscribed to admin_new_orders topic');
  }

  Future<void> unsubscribeFromAdminOrders() async {
    await _fcm.unsubscribeFromTopic('admin_new_orders');
    _logger.i('Unsubscribed from admin_new_orders topic');
  }

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
