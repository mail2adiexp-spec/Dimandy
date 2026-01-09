  Widget _buildFinancialOverview() {
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
                const Text(
                  'Financial Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Flex(
                  direction: isMobile ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total Revenue (Orders + Bookings)
                    Expanded(
                      flex: isMobile ? 0 : 1,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _ordersStream,
                        builder: (context, orderSnapshot) {
                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('bookings').where('status', isEqualTo: 'completed').snapshots(),
                            builder: (context, bookingSnapshot) {
                              double totalRevenue = 0;
                              
                              // Calculate from Orders
                              if (orderSnapshot.hasData) {
                                for (var doc in orderSnapshot.data!.docs) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  if (data['status'] == 'delivered' || data['status'] == 'completed') {
                                     totalRevenue += (data['totalAmount'] as num?)?.toDouble() ?? 0;
                                  }
                                }
                              }

                              // Calculate from Bookings
                              if (bookingSnapshot.hasData) {
                                for (var doc in bookingSnapshot.data!.docs) {
                                   final data = doc.data() as Map<String, dynamic>;
                                   totalRevenue += (data['totalCost'] as num?)?.toDouble() ?? 0;
                                }
                              }

                              return _buildStatItem(
                                'Total Revenue (GMV)',
                                '₹${totalRevenue.toStringAsFixed(0)}',
                                Icons.currency_rupee,
                                Colors.green,
                              );
                            }
                          );
                        }
                      ),
                    ),
                    if (isMobile) const SizedBox(height: 16),
                    
                    // Platform Revenue (Assume 10% commission for demo)
                     Expanded(
                      flex: isMobile ? 0 : 1,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _ordersStream,
                        builder: (context, orderSnapshot) {
                           return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('bookings').where('status', isEqualTo: 'completed').snapshots(),
                            builder: (context, bookingSnapshot) {
                              double totalRevenue = 0;
                              if (orderSnapshot.hasData) {
                                for (var doc in orderSnapshot.data!.docs) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  if (data['status'] == 'delivered' || data['status'] == 'completed') {
                                     totalRevenue += (data['totalAmount'] as num?)?.toDouble() ?? 0;
                                  }
                                }
                              }
                              if (bookingSnapshot.hasData) {
                                for (var doc in bookingSnapshot.data!.docs) {
                                   final data = doc.data() as Map<String, dynamic>;
                                   totalRevenue += (data['totalCost'] as num?)?.toDouble() ?? 0;
                                }
                              }
                              // Assuming 10% commission
                              final platformRevenue = totalRevenue * 0.10;

                              return _buildStatItem(
                                'Est. Platform Revenue (10%)',
                                '₹${platformRevenue.toStringAsFixed(0)}',
                                Icons.account_balance_wallet,
                                Colors.blue,
                              );
                            }
                           );
                        }
                      ),
                    ),
                    if (isMobile) const SizedBox(height: 16),
                    
                    // Active Users
                    Expanded(
                      flex: isMobile ? 0 : 1,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _usersStream,
                         builder: (context, snapshot) {
                            int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                            return _buildStatItem(
                              'Total Users',
                              '$count',
                              Icons.people,
                              Colors.purple,
                            );
                         }
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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
