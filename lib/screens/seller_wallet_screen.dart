import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../models/payout_model.dart';
import '../services/payout_service.dart';
import '../models/transaction_model.dart'; // Import TransactionModel
import '../services/transaction_service.dart';

class SellerWalletScreen extends StatefulWidget {
  final AppUser user;

  const SellerWalletScreen({super.key, required this.user});

  @override
  State<SellerWalletScreen> createState() => _SellerWalletScreenState();
}

class _SellerWalletScreenState extends State<SellerWalletScreen> {
  final PayoutService _payoutService = PayoutService();
  final TransactionService _transactionService = TransactionService();
  
  double _balance = 0.0;
  bool _isLoading = true;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchBalance();
  }

  Future<void> _fetchBalance() async {
    setState(() => _isLoading = true);
    try {
      final balance = await _transactionService.getBalance(widget.user.uid);
      if (mounted) setState(() => _balance = balance);
    } catch (e) {
      debugPrint('Error fetching balance: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRequestPayoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Payout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Available Balance: ₹${_balance.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detailsController,
              decoration: const InputDecoration(
                labelText: 'UPI ID / Bank Details',
                border: OutlineInputBorder(),
                hintText: 'e.g., name@upi or Bank Name, A/C No',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(_amountController.text) ?? 0;
              final details = _detailsController.text.trim();
              
              if (amount <= 0 || amount > _balance) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid amount')),
                );
                return;
              }
              if (details.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide payment details')),
                );
                return;
              }

              try {
                await _payoutService.requestPayout(widget.user.uid, amount, details);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payout requested successfully')),
                  );
                  _fetchBalance();
                  _amountController.clear();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Wallet')),
      body: RefreshIndicator(
        onRefresh: _fetchBalance,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[700]!, Colors.blue[500]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Available Balance',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            '₹${NumberFormat('#,##0.00').format(_balance)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue[700],
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: (_balance > 0 && !_isLoading) ? _showRequestPayoutDialog : null,
                      child: const Text('Request Payout', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              const SizedBox(height: 32),
              
              DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: Colors.blue,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.blue,
                      tabs: [
                        Tab(text: 'Payouts'),
                        Tab(text: 'Transactions'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 400, // Fixed height for inner lists
                      child: TabBarView(
                        children: [
                          // Payouts Tab
                           StreamBuilder<List<PayoutModel>>(
                            stream: _payoutService.getPayouts(widget.user.uid),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              
                              final payouts = snapshot.data ?? [];
                              if (payouts.isEmpty) {
                                return const Center(child: Text('No payout history'));
                              }
            
                              return ListView.separated(
                                itemBuilder: (context, index) {
                                  final payout = payouts[index];
                                  Color statusColor;
                                  switch (payout.status) {
                                    case PayoutStatus.approved: statusColor = Colors.green; break;
                                    case PayoutStatus.rejected: statusColor = Colors.red; break;
                                    default: statusColor = Colors.orange;
                                  }
            
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: statusColor.withOpacity(0.1),
                                      child: Icon(
                                        payout.status == PayoutStatus.approved ? Icons.check : Icons.access_time,
                                        color: statusColor,
                                      ),
                                    ),
                                    title: Text('Withdrawal: ₹${payout.amount.toStringAsFixed(2)}'),
                                    subtitle: Text(DateFormat('MMM dd, yyyy • hh:mm a').format(payout.requestDate)),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        payout.status.name.toUpperCase(),
                                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  );
                                },
                                separatorBuilder: (context, index) => const Divider(),
                                itemCount: payouts.length,
                              );
                            },
                          ),

                          // Transactions Tab
                          StreamBuilder<List<TransactionModel>>(
                            stream: _transactionService.getTransactions(widget.user.uid),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              
                              final transactions = snapshot.data ?? [];
                              if (transactions.isEmpty) {
                                return const Center(child: Text('No transactions yet'));
                              }

                              return ListView.separated(
                                itemCount: transactions.length,
                                separatorBuilder: (context, index) => const Divider(),
                                itemBuilder: (context, index) {
                                  final tx = transactions[index];
                                  final isCredit = tx.type == TransactionType.credit;
                                  final isRefund = tx.type == TransactionType.refund;
                                  final color = isCredit ? Colors.green : (isRefund ? Colors.orange : Colors.red);
                                  final prefix = isCredit ? '+' : '-';

                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: color.withOpacity(0.1),
                                      child: Icon(
                                          isCredit ? Icons.arrow_downward : (isRefund ? Icons.assignment_return : Icons.arrow_upward), // arrow_down usually means incoming money
                                          color: color
                                      ),
                                    ),
                                    title: Text(tx.description),
                                    subtitle: Text(DateFormat('MMM dd, yyyy • hh:mm a').format(tx.createdAt)),
                                    trailing: Text(
                                      '$prefix₹${tx.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
