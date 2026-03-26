  Widget _buildFinancialOverview() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final todayStartTs = Timestamp.fromDate(todayStart);
    final todayEndTs = Timestamp.fromDate(todayEnd);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.today, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text(
                      "Today's Summary",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Flex(
                  direction: isMobile ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // 1. Today's Booked Services
                    Expanded(
                      flex: isMobile ? 0 : 1,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('bookings')
                            .where('createdAt', isGreaterThanOrEqualTo: todayStartTs)
                            .where('createdAt', isLessThanOrEqualTo: todayEndTs)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                          return _buildStatItem(
                            "Today's Services Booked",
                            '$count',
                            Icons.design_services,
                            Colors.blue,
                          );
                        },
                      ),
                    ),
                    if (isMobile) const SizedBox(height: 16),

                    // 2. Today's Completed Orders
                    Expanded(
                      flex: isMobile ? 0 : 1,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('orders')
                            .where('orderDate', isGreaterThanOrEqualTo: todayStartTs)
                            .where('orderDate', isLessThanOrEqualTo: todayEndTs)
                            .where('status', isEqualTo: 'delivered')
                            .snapshots(),
                        builder: (context, snapshot) {
                          final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                          return _buildStatItem(
                            "Today's Completed Orders",
                            '$count',
                            Icons.check_circle_outline,
                            Colors.green,
                          );
                        },
                      ),
                    ),
                    if (isMobile) const SizedBox(height: 16),

                    // 3. Today's Total Revenue
                    Expanded(
                      flex: isMobile ? 0 : 1,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('orders')
                            .where('orderDate', isGreaterThanOrEqualTo: todayStartTs)
                            .where('orderDate', isLessThanOrEqualTo: todayEndTs)
                            .where('status', isEqualTo: 'delivered')
                            .snapshots(),
                        builder: (context, orderSnap) {
                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('bookings')
                                .where('createdAt', isGreaterThanOrEqualTo: todayStartTs)
                                .where('createdAt', isLessThanOrEqualTo: todayEndTs)
                                .where('status', isEqualTo: 'completed')
                                .snapshots(),
                            builder: (context, bookingSnap) {
                              double revenue = 0;
                              if (orderSnap.hasData) {
                                for (var doc in orderSnap.data!.docs) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  revenue += (data['totalAmount'] as num?)?.toDouble() ?? 0;
                                }
                              }
                              if (bookingSnap.hasData) {
                                for (var doc in bookingSnap.data!.docs) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  revenue += (data['totalCost'] as num?)?.toDouble() ?? 0;
                                }
                              }
                              return _buildStatItem(
                                "Today's Revenue",
                                '₹${revenue.toStringAsFixed(0)}',
                                Icons.currency_rupee,
                                Colors.orange,
                              );
                            },
                          );
                        },
                      ),
                    ),

                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
