import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../utils/currency.dart';

class BookingTrackingScreen extends StatelessWidget {
  static const routeName = '/booking-tracking';
  
  final String bookingId;

  const BookingTrackingScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Booking'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Booking not found'));
          }

          final booking = snapshot.data!.data() as Map<String, dynamic>;
          final status = booking['status'] as String? ?? 'pending';
          final serviceName = booking['serviceName'] as String? ?? 'Service';
          
          DateTime? bookingDate;
          if (booking['bookingDate'] != null) {
              if (booking['bookingDate'] is Timestamp) {
                  bookingDate = (booking['bookingDate'] as Timestamp).toDate();
              }
          }
           
          final providerName = booking['providerName'] as String? ?? 'Provider';


          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service Info Card
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviceName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                         Row(
                          children: [
                            const Icon(Icons.person, size: 20, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text('Provider: $providerName', style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (bookingDate != null)
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('MMM dd, yyyy  hh:mm a').format(bookingDate),
                               style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold)),
                             Text(
                               formatINR((booking['serviceAmount'] as num?)?.toDouble() ?? 0),
                               style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                             ),
                           ],
                        ),
                        if ((booking['remainingAmount'] as num?)?.toDouble() != null && (booking['remainingAmount'] as num).toDouble() > 0)
                           Padding(
                             padding: const EdgeInsets.only(top: 8),
                             child: Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                 const Text('Pending Amount:', style: TextStyle(color: Colors.orange)),
                                 Text(
                                   formatINR((booking['remainingAmount'] as num?)?.toDouble() ?? 0),
                                   style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                                 ),
                               ],
                             ),
                           ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                if (['on_way', 'in_progress'].contains(status)) ...[
                   Center(
                     child: Container(
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(
                         color: Colors.white,
                         borderRadius: BorderRadius.circular(16),
                         border: Border.all(color: Colors.grey.withOpacity(0.2)),
                         boxShadow: [
                           BoxShadow(
                             color: Colors.black.withOpacity(0.05),
                             blurRadius: 10,
                             offset: const Offset(0, 4),
                           ),
                         ],
                       ),
                       child: Column(
                         children: [
                           BarcodeWidget(
                             barcode: Barcode.qrCode(),
                             data: bookingId,
                             width: 200,
                             height: 200,
                             color: Colors.black,
                           ),
                           const SizedBox(height: 16),
                           Text(
                             'Scan to Complete Service',
                             style: TextStyle(
                               fontSize: 16,
                               fontWeight: FontWeight.bold,
                               color: Colors.grey[800],
                             ),
                           ),
                           Text(
                             'Show this QR code to the provider',
                             style: TextStyle(
                               fontSize: 12,
                               color: Colors.grey[600],
                             ),
                           ),
                         ],
                       ),
                     ),
                   ),
                   const SizedBox(height: 32),
                ],

                const Text(
                   'Booking Status',
                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                _buildTimeline(status),
                
                 const SizedBox(height: 32),
                 
                 // Cancel Button (Only if pending or confirmed)
                 if (['pending', 'confirmed'].contains(status))
                   SizedBox(
                     width: double.infinity,
                     child: OutlinedButton.icon(
                       onPressed: () => _confirmCancel(context, bookingId),
                       icon: const Icon(Icons.cancel_outlined),
                       label: const Text('Cancel Booking'),
                       style: OutlinedButton.styleFrom(
                         foregroundColor: Colors.red,
                         side: const BorderSide(color: Colors.red),
                         padding: const EdgeInsets.symmetric(vertical: 16),
                       ),
                     ),
                   ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeline(String currentStatus) {
     final steps = [
       {'status': 'pending', 'label': 'Booking Received', 'icon': Icons.assignment_turned_in},
       {'status': 'confirmed', 'label': 'Booking Confirmed', 'icon': Icons.check_circle_outline},
       {'status': 'on_way', 'label': 'Provider on the Way', 'icon': Icons.directions_bike},
       {'status': 'in_progress', 'label': 'Service In Progress', 'icon': Icons.handyman},
       {'status': 'completed', 'label': 'Service Completed', 'icon': Icons.thumb_up},
     ];
     
     // Determine current step index
     int currentIndex = 0;
     if (currentStatus == 'cancelled') {
        return Center(
           child: Container(
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               color: Colors.red.withOpacity(0.1),
               borderRadius: BorderRadius.circular(12),
               border: Border.all(color: Colors.red),
             ),
             child: const Column(
               children: [
                 Icon(Icons.cancel, color: Colors.red, size: 48),
                 SizedBox(height: 8),
                 Text(
                   'Booking Cancelled',
                   style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
                 ),
               ],
             ),
           ),
        );
     }
     
     final foundIndex = steps.indexWhere((s) => s['status'] == currentStatus);
     if (foundIndex != -1) {
       currentIndex = foundIndex;
     } else {
        // Handle custom statuses if any, default to 0
     }

     return ListView.builder(
       shrinkWrap: true,
       physics: const NeverScrollableScrollPhysics(),
       itemCount: steps.length,
       itemBuilder: (context, index) {
         final step = steps[index];
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
                     color: isCompleted ? (isCurrent ? Colors.blue : Colors.green) : Colors.grey[300],
                     shape: BoxShape.circle,
                   ),
                   child: Icon(
                     step['icon'] as IconData,
                     color: Colors.white,
                     size: 16,
                   ),
                 ),
                 if (index < steps.length - 1)
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
                     step['label'] as String,
                     style: TextStyle(
                       fontSize: 16,
                       fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                       color: isCompleted ? Colors.black : Colors.grey,
                     ),
                   ),
                   const SizedBox(height: 32),
                 ],
               ),
             ),
           ],
         );
       },
     );
  }

  Future<void> _confirmCancel(BuildContext context, String bookingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
             style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': 'user',
        });
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking cancelled successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
           );
        }
      }
    }
  }
}
