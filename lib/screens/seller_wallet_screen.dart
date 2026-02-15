import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _isSavingBankDetails = false;
  bool _bankDetailsLoaded = false;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _ifscController = TextEditingController();
  final TextEditingController _upiController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchBalance();
    _loadBankDetails();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _upiController.dispose();
    super.dispose();
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

  Future<void> _loadBankDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        setState(() {
          _accountNumberController.text = data['bankAccountNumber'] ?? '';
          _ifscController.text = data['bankIfscCode'] ?? '';
          _upiController.text = data['upiId'] ?? '';
          _bankDetailsLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading bank details: $e');
    }
  }

  Future<void> _saveBankDetails() async {
    final accountNo = _accountNumberController.text.trim();
    final ifsc = _ifscController.text.trim();
    final upi = _upiController.text.trim();

    // Validate: at least bank (account+ifsc) or UPI must be provided
    if (accountNo.isEmpty && ifsc.isEmpty && upi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Bank Details or UPI ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (accountNo.isNotEmpty && ifsc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter IFSC Code with Account Number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (ifsc.isNotEmpty && accountNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Account Number with IFSC Code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSavingBankDetails = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .set({
        'bankAccountNumber': accountNo,
        'bankIfscCode': ifsc.toUpperCase(),
        'upiId': upi,
        'bankDetailsUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bank details saved successfully! ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving bank details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingBankDetails = false);
    }
  }

  void _showRequestPayoutDialog() {
    String? errorMessage;
    // Pre-fill from saved bank details
    final payoutAccountCtrl = TextEditingController(text: _accountNumberController.text);
    final payoutIfscCtrl = TextEditingController(text: _ifscController.text);
    final payoutUpiCtrl = TextEditingController(text: _upiController.text);
    final payoutAmountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Request Payout'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Available Balance: ₹${_balance.toStringAsFixed(2)}'),
                  const SizedBox(height: 16),
                  if (errorMessage != null) ...[
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: payoutAmountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      if (errorMessage != null) {
                        setStateDialog(() => errorMessage = null);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Bank Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: payoutAccountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Account Number',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., 1234567890',
                      prefixIcon: Icon(Icons.account_balance),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: payoutIfscCtrl,
                    decoration: const InputDecoration(
                      labelText: 'IFSC Code',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., SBIN0001234',
                      prefixIcon: Icon(Icons.code),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('OR UPI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: payoutUpiCtrl,
                    decoration: const InputDecoration(
                      labelText: 'UPI ID',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., name@upi',
                      prefixIcon: Icon(Icons.payment),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  payoutAccountCtrl.dispose();
                  payoutIfscCtrl.dispose();
                  payoutUpiCtrl.dispose();
                  payoutAmountCtrl.dispose();
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  setStateDialog(() => errorMessage = null);
                  
                  final amount = double.tryParse(payoutAmountCtrl.text) ?? 0;
                  final accountNo = payoutAccountCtrl.text.trim();
                  final ifsc = payoutIfscCtrl.text.trim();
                  final upi = payoutUpiCtrl.text.trim();
                  
                  if (amount <= 0 || amount > _balance) {
                    setStateDialog(() => errorMessage = 'Invalid amount');
                    return;
                  }
                  if (amount < 1000) {
                     setStateDialog(() => errorMessage = 'Minimum withdrawal amount is ₹1000');
                    return;
                  }
                  
                  // Validate: at least bank (account+ifsc) or UPI must be provided
                  final hasBankDetails = accountNo.isNotEmpty && ifsc.isNotEmpty;
                  final hasUpi = upi.isNotEmpty;
                  
                  if (!hasBankDetails && !hasUpi) {
                    setStateDialog(() => errorMessage = 'Please provide Bank Details (Account + IFSC) or UPI ID');
                    return;
                  }
                  
                  if (accountNo.isNotEmpty && ifsc.isEmpty) {
                    setStateDialog(() => errorMessage = 'Please provide IFSC Code with Account Number');
                    return;
                  }
                  if (ifsc.isNotEmpty && accountNo.isEmpty) {
                    setStateDialog(() => errorMessage = 'Please provide Account Number with IFSC Code');
                    return;
                  }
                  
                  // Build payment details string
                  final List<String> parts = [];
                  if (hasBankDetails) {
                    parts.add('Account: $accountNo');
                    parts.add('IFSC: ${ifsc.toUpperCase()}');
                  }
                  if (hasUpi) {
                    parts.add('UPI: $upi');
                  }
                  final details = parts.join(' | ');

                  try {
                    await _payoutService.requestPayout(widget.user.uid, amount, details);
                    if (context.mounted) {
                      payoutAccountCtrl.dispose();
                      payoutIfscCtrl.dispose();
                      payoutUpiCtrl.dispose();
                      payoutAmountCtrl.dispose();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Payout requested successfully')),
                      );
                      _fetchBalance();
                    }
                  } catch (e) {
                     String msg = e.toString();
                     if (msg.contains('Exception: ')) {
                       msg = msg.replaceAll('Exception: ', '');
                     }
                     setStateDialog(() => errorMessage = msg);
                  }
                },
                child: const Text('Request'),
              ),
            ],
          );
        }
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
              const SizedBox(height: 24),

              // Bank Details Section
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance, color: Colors.blue[700], size: 28),
                          const SizedBox(width: 12),
                          const Text(
                            'Bank Details & UPI',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (_bankDetailsLoaded && 
                              (_accountNumberController.text.isNotEmpty || _upiController.text.isNotEmpty))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                                  SizedBox(width: 4),
                                  Text('Saved', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your bank details for payout withdrawals',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const Divider(height: 24),

                      // Account Number
                      TextField(
                        controller: _accountNumberController,
                        decoration: InputDecoration(
                          labelText: 'Account Number',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          hintText: 'e.g., 1234567890',
                          prefixIcon: const Icon(Icons.account_balance),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      // IFSC Code
                      TextField(
                        controller: _ifscController,
                        decoration: InputDecoration(
                          labelText: 'IFSC Code',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          hintText: 'e.g., SBIN0001234',
                          prefixIcon: const Icon(Icons.code),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 20),

                      // Divider with "OR"
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // UPI ID
                      TextField(
                        controller: _upiController,
                        decoration: InputDecoration(
                          labelText: 'UPI ID',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          hintText: 'e.g., name@upi',
                          prefixIcon: const Icon(Icons.payment),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSavingBankDetails ? null : _saveBankDetails,
                          icon: _isSavingBankDetails
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save),
                          label: Text(_isSavingBankDetails ? 'Saving...' : 'Save Bank Details'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
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
