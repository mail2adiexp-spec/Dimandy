import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../utils/currency.dart';
import 'booking_tracking_screen.dart';

class MyBookingsScreen extends StatelessWidget {
  static const routeName = '/my-bookings';

  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('customerId', isEqualTo: auth.currentUser?.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No bookings yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final bookings = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index].data() as Map<String, dynamic>;
              final status = booking['status'] as String? ?? 'pending';
              final serviceName = booking['serviceName'] as String? ?? 'Service';
              final providerName = booking['providerName'] as String? ?? 'Provider';
              
              // Helper to parse date
              String dateStr = '';
              String timeStr = '';
              
              if (booking['bookingDate'] != null) {
                 // Try to parse if string or Timestamp
                 if (booking['bookingDate'] is Timestamp) {
                   dateStr = DateFormat('MMM dd, yyyy').format((booking['bookingDate'] as Timestamp).toDate());
                 } else {
                   dateStr = booking['bookingDate'].toString();
                 }
              }
              
              if (booking['bookingTime'] != null) {
                timeStr = booking['bookingTime'].toString();
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () {
                     Navigator.pushNamed(
                        context, 
                        BookingTrackingScreen.routeName, 
                        arguments: booking['id']
                     );
                  },
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  serviceName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              _buildStatusChip(status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.person, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text('Provider: $providerName'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (dateStr.isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.calendar_month, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('$dateStr $timeStr'),
                              ],
                            ),
                          const SizedBox(height: 12),
                           const Divider(),
                           const SizedBox(height: 8),
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   const Text('Total Amount', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                   Text(
                                     formatINR((booking['serviceAmount'] as num?)?.toDouble() ?? 0),
                                     style: const TextStyle(fontWeight: FontWeight.bold),
                                   ),
                                 ],
                               ),
                                Column(
                                 crossAxisAlignment: CrossAxisAlignment.end,
                                 children: [
                                   const Text('Paid', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                   Text(
                                     formatINR((booking['customerPayment'] as num?)?.toDouble() ?? 0),
                                     style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                   ),
                                 ],
                               ),
                             ],
                           )
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'confirmed':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'completed':
        color = Colors.blue;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
