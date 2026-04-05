import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/transaction_service.dart';
import '../models/transaction_model.dart';
import 'seller_wallet_screen.dart';

class DeliveryPartnerEarningsScreen extends StatefulWidget {
  final String deliveryPartnerId;
  const DeliveryPartnerEarningsScreen({super.key, required this.deliveryPartnerId});

  @override
  State<DeliveryPartnerEarningsScreen> createState() => _DeliveryPartnerEarningsScreenState();
}

class _DeliveryPartnerEarningsScreenState extends State<DeliveryPartnerEarningsScreen> {
  bool _isSyncing = false;
  late Stream<QuerySnapshot> _totalEarningsStream;
  late Stream<QuerySnapshot> _completedDeliveriesStream;

  @override
  void initState() {
    super.initState();
    _totalEarningsStream = FirebaseFirestore.instance
        .collection('orders')
        .where('deliveryPartnerId', isEqualTo: widget.deliveryPartnerId)
        .where('deliveryStatus', isEqualTo: 'delivered')
        .snapshots();

    _completedDeliveriesStream = FirebaseFirestore.instance
        .collection('orders')
        .where('deliveryPartnerId', isEqualTo: widget.deliveryPartnerId)
        .where('deliveryStatus', isEqualTo: 'delivered')
        .orderBy('deliveredAt', descending: true)
        .snapshots();
  }

  Future<void> _syncMissingTransactions() async {
    setState(() => _isSyncing = true);
    try {
      final orders = await FirebaseFirestore.instance
          .collection('orders')
          .where('deliveryPartnerId', isEqualTo: widget.deliveryPartnerId)
          .where('deliveryStatus', isEqualTo: 'delivered')
          .get();

      if (orders.docs.isEmpty) return;

      final existingTransactions = await FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: widget.deliveryPartnerId)
          .get();

      final existingOrderIds = existingTransactions.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['referenceId'] as String?)
          .where((id) => id != null)
          .toSet();

      for (var doc in orders.docs) {
        final orderId = doc.id;
        if (existingOrderIds.contains(orderId)) continue;

        final data = doc.data() as Map<String, dynamic>;
        final fee = (data['partnerPayout'] as num?)?.toDouble() ?? (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;

        if (fee > 0) {
          await TransactionService().recordTransaction(
            TransactionModel(
              id: '',
              userId: widget.deliveryPartnerId,
              amount: fee,
              type: TransactionType.credit,
              description: 'Retroactive Delivery Fee: #${orderId.substring(0, 8)}',
              status: TransactionStatus.completed,
              referenceId: orderId,
              metadata: {
                'orderId': orderId,
                'type': 'delivery_earning',
              },
              createdAt: DateTime.now(),
            ),
          );
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync completed!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Earnings History'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isSyncing ? null : _syncMissingTransactions,
            icon: _isSyncing 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.sync),
            tooltip: 'Sync Balance',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row for top summary cards
            Row(
              children: [
                Expanded(
                  child: FutureBuilder<double>(
                    future: TransactionService().getBalance(widget.deliveryPartnerId),
                    builder: (context, snapshot) {
                      final balance = snapshot.data ?? 0.0;
                      return _buildSummaryCard(
                        'Available Balance',
                        '₹${balance.toStringAsFixed(2)}',
                        Icons.account_balance_wallet,
                        Colors.blue,
                        isLoading: snapshot.connectionState == ConnectionState.waiting,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _totalEarningsStream,
                    builder: (context, snapshot) {
                      double total = 0;
                      if (snapshot.hasData) {
                        for (var doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          total += (data['partnerPayout'] as num?)?.toDouble() ?? (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;
                        }
                      }
                      return _buildSummaryCard(
                        'Lifetime Earning',
                        '₹${total.toStringAsFixed(2)}',
                        Icons.trending_up,
                        Colors.green,
                        isLoading: snapshot.connectionState == ConnectionState.waiting,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Wallet Action
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  if (auth.currentUser != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SellerWalletScreen(user: auth.currentUser!)),
                    );
                  }
                },
                icon: const Icon(Icons.payments_outlined), // Payment icon
                label: const Text('WITHDRAW TO BANK / UPI', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 32),

            Text(
              'Completed Deliveries',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            StreamBuilder<QuerySnapshot>(
              stream: _completedDeliveriesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
                }

                final deliveries = snapshot.data?.docs ?? [];
                if (deliveries.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: deliveries.length,
                  itemBuilder: (context, index) {
                    final data = deliveries[index].data() as Map<String, dynamic>;
                    final orderId = deliveries[index].id;
                    final fee = (data['partnerPayout'] as num?)?.toDouble() ?? (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;
                    final customer = data['userName'] ?? 'Customer';
                    final date = (data['deliveredAt'] as Timestamp?)?.toDate();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      elevation: 0,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                          child: const Icon(Icons.check, color: Colors.green, size: 24),
                        ),
                        title: Text('Order #${orderId.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(customer, style: const TextStyle(fontSize: 13)),
                            if (date != null)
                              Text(DateFormat('dd MMM, yyyy • h:mm a').format(date), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ),
                        trailing: Text(
                          '₹${fee.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, {bool isLoading = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 4),
          if (isLoading)
            const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No completed deliveries yet', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
