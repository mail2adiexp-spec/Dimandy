import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationsDialog extends StatefulWidget {
  final String userId;

  const NotificationsDialog({super.key, required this.userId});

  @override
  State<NotificationsDialog> createState() => _NotificationsDialogState();
}

class _NotificationsDialogState extends State<NotificationsDialog> {
  @override
  void initState() {
    super.initState();
    // Automatically mark all notifications as read when dialog opens
    _markAllAsRead();
  }

  Future<void> _markAllAsRead() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('toUserId', isEqualTo: widget.userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('toUserId', isEqualTo: widget.userId)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text('No notifications', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final title = data['title'] ?? 'Notification';
                      final body = data['body'] ?? '';
                      final isRead = data['isRead'] ?? false;
                      final type = data['type'] ?? 'info';
                      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

                      IconData icon;
                      Color color;
                      switch (type) {
                        case 'order_new':
                          icon = Icons.shopping_bag;
                          color = Colors.blue;
                          break;
                        case 'order_cancelled':
                          icon = Icons.cancel;
                          color = Colors.red;
                          break;
                        case 'order_delivered':
                          icon = Icons.check_circle;
                          color = Colors.green;
                        default:
                          icon = Icons.notifications;
                          color = Colors.grey;
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.1),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(body),
                            if (createdAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  DateFormat('MMM dd, hh:mm a').format(createdAt),
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                              ),
                          ],
                        ),
                        tileColor: isRead ? null : Colors.blue.withOpacity(0.05),
                        onTap: () async {
                          if (!isRead) {
                            await FirebaseFirestore.instance
                                .collection('notifications')
                                .doc(docs[index].id)
                                .update({'isRead': true});
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
