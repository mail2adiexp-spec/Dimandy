import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import '../services/payout_service.dart';
import '../models/payout_model.dart';
import '../providers/auth_provider.dart';

class ServiceProviderDashboardScreen extends StatefulWidget {
  static const routeName = '/service-provider-dashboard';

  const ServiceProviderDashboardScreen({super.key});

  @override
  State<ServiceProviderDashboardScreen> createState() => _ServiceProviderDashboardScreenState();
}

class _ServiceProviderDashboardScreenState extends State<ServiceProviderDashboardScreen> {
  Stream<QuerySnapshot>? _partnerRequestsStream;
  Stream<QuerySnapshot>? _servicesStream;
  Stream<QuerySnapshot>? _bookingsCountStream; // Unordered for count
  Stream<QuerySnapshot>? _revenueStream;
  Stream<QuerySnapshot>? _recentActivityStream;
  Stream<QuerySnapshot>? _allBookingsStream; // Ordered for list

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    if (user != null) {
      // Partner requests (depends on email)
      _partnerRequestsStream ??= FirebaseFirestore.instance
          .collection('partner_requests')
          .where('email', isEqualTo: user.email)
          .snapshots();

      // Services (depends on uid)
      _servicesStream ??= FirebaseFirestore.instance
          .collection('services')
          .where('providerId', isEqualTo: user.uid)
          .snapshots();

      // Bookings Count
      _bookingsCountStream ??= FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: user.uid)
          .snapshots();

      // Revenue
      _revenueStream ??= FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .snapshots();

      // Recent Activity
      _recentActivityStream ??= FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots();

      // All Bookings (Transactions Tab)
      _allBookingsStream ??= FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Dashboard')),
        body: const Center(child: Text('Please login to continue')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('My Dashboard'),
          elevation: 2,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Transactions'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOverviewTab(context, user),
            _buildTransactionsTab(user.uid),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, dynamic user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Welcome Header
          _buildWelcomeHeader(user),
          const SizedBox(height: 24),

          // 2. Business Stats
          const Text('Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          _buildStatsGrid(context),
          const SizedBox(height: 24),

          // 3. Quick Actions
          const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          _buildQuickActionsGrid(context, user),
          const SizedBox(height: 24),

          // 4. Partner Request Status
          StreamBuilder<QuerySnapshot>(
             stream: _partnerRequestsStream,
             builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
                
                // Filter out approved requests
                final pendingRequests = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['status'] ?? '').toString().toLowerCase() != 'approved';
                }).toList();

                if (pendingRequests.isEmpty) return const SizedBox();

                return Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                      const Text('Service Provider Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 12),
                      ...pendingRequests.map((doc) => _buildRequestCard(context, doc.data() as Map<String, dynamic>, doc.id)),
                      const SizedBox(height: 24),
                   ],
                );
             }
          ),

          // 5. Recent Activity
          Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
                const Text('Recent Bookings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                TextButton(
                   onPressed: () => _showViewBookingsDialog(context, user),
                   child: const Text('View All'),
                ),
             ],
          ),
          const SizedBox(height: 8),
          _buildRecentActivityList(user),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildLimitedAccessView(BuildContext context, AuthProvider auth) {
    final role = auth.currentUser?.role ?? 'user';
    final isApproved = role == 'seller' || role == 'service_provider';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Service Provider Status',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isApproved
                        ? 'Approved via account role (${role}). You can receive bookings.'
                        : 'We cannot access your request details due to permissions. If you recently applied, your status may be pending.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isApproved ? Icons.check_circle : Icons.lock_outline,
                        color: isApproved ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isApproved ? 'Approved' : 'Limited Access',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isApproved
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isApproved
                        ? 'Your account role indicates approval. Full request details may be restricted by current Firestore rules.'
                        : 'Ask admin to confirm your request status. Optionally, update Firestore rules to let you read your own request.',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> data, String docId) {
    final status = data['status'] ?? 'pending';
    final role = data['role'] ?? 'N/A';
    final name = data['fullName'] ?? 'N/A';
    final phone = data['phoneNumber'] ?? 'N/A';
    final email = data['email'] ?? 'N/A';
    final experience = data['experience'] ?? 'N/A';
    final minCharge = data['minCharge'] ?? 0;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status.toLowerCase()) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Approved';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Rejected';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'Pending';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    role,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                        onPressed: () => _showEditRequestDialog(context, docId, data),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor),
                      ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
              ],
            ),
            const Divider(height: 24),

            // Details
            _buildDetailRow(Icons.person, 'Name', name),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.phone, 'Phone', phone),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.email, 'Email', email),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.work, 'Experience', experience),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.currency_rupee,
              'Min Charge',
              '₹${minCharge.toString()}/hour',
            ),

            // Status-specific message
            if (status.toLowerCase() == 'approved') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.celebration, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Congratulations! Your request has been approved. You can now receive service bookings.',
                        style: TextStyle(
                          color: Colors.green[800],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (status.toLowerCase() == 'rejected') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your request was not approved. Please contact support for more details.',
                        style: TextStyle(color: Colors.red[800], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (status.toLowerCase() == 'pending') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your request is under review. We will notify you once it\'s processed.',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsTab(String userId) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transaction History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showRequestPayoutDialog(userId),
                icon: const Icon(Icons.payments),
                label: const Text('Request Payout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<TransactionModel>>(
            stream: TransactionService().getTransactions(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final transactions = snapshot.data ?? [];

              if (transactions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No transactions yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  final isCredit = transaction.type == TransactionType.credit;
                  final color = isCredit ? Colors.green : Colors.red;
                  final icon = isCredit ? Icons.arrow_downward : Icons.arrow_upward;
                  final prefix = isCredit ? '+' : '-';

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withOpacity(0.1),
                        child: Icon(icon, color: color),
                      ),
                      title: Text(
                        transaction.description,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        DateFormat('MMM d, yyyy • h:mm a').format(transaction.createdAt),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$prefix₹${transaction.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            transaction.status.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              color: transaction.status == TransactionStatus.completed
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showRequestPayoutDialog(String userId) async {
    final amountController = TextEditingController();
    final detailsController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Request Payout'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter amount';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Enter valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: detailsController,
                  decoration: const InputDecoration(
                    labelText: 'Payment Details (UPI/Bank)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., upi@id or Bank Account Details',
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter payment details';
                    }
                    return null;
                  },
                ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setState(() => isLoading = true);
                        try {
                          final amount = double.parse(amountController.text);
                          await PayoutService().requestPayout(
                            userId,
                            amount,
                            detailsController.text,
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Payout requested successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => isLoading = false);
                          }
                        }
                      }
                    },
              child: const Text('Request'),
            ),
          ],
        ),
      ),
    );
  }

  // Manage Services Dialog
  void _showManageServicesDialog(BuildContext context, dynamic user) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: 900,
          height: 700,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: const Text(
                      'My Services',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showAddServiceDialog(context, user),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Service'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('services').where('providerId', isEqualTo: user.uid).orderBy('createdAt', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: SelectableText('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    final services = snapshot.data?.docs ?? [];
                    if (services.isEmpty) {
                      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.build_outlined, size: 80, color: Colors.grey[400]), const SizedBox(height: 16), const Text('No services yet', style: TextStyle(fontSize: 18, color: Colors.grey)), const SizedBox(height: 8), ElevatedButton.icon(onPressed: () { Navigator.pop(ctx); _showAddServiceDialog(context, user); }, icon: const Icon(Icons.add), label: const Text('Add Your First Service'))]));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: services.length,
                      itemBuilder: (context, index) {
                        final serviceData = services[index].data() as Map<String, dynamic>;
                        final serviceId = services[index].id;
                        final name = serviceData['name'] ?? 'Unknown';
                        final basePrice = (serviceData['basePrice'] as num?)?.toDouble() ?? 0;
                        final imageUrl = serviceData['imageUrl'] as String?;
                        final category = serviceData['category'] ?? 'General';
                        final ratePerKm = (serviceData['ratePerKm'] as num?)?.toDouble() ?? 0;
                        final preBookingAmount = (serviceData['preBookingAmount'] as num?)?.toDouble() ?? 0;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Image (smaller)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[200],
                                    child: imageUrl != null
                                        ? Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 24),
                                          )
                                        : const Icon(Icons.build, size: 24),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        category,
                                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.currency_rupee, size: 14, color: Colors.green),
                                                Flexible(
                                                  child: Text(
                                                    '${basePrice.toStringAsFixed(0)}/hr',
                                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (ratePerKm > 0) ...[
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                '₹${ratePerKm.toStringAsFixed(0)}/km',
                                                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // 3-dot menu
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      _showEditServiceDialog(context, serviceId, serviceData);
                                    } else if (value == 'delete') {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (dialogCtx) => AlertDialog(
                                          title: const Text('Delete Service'),
                                          content: Text('Delete "$name"?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(dialogCtx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(dialogCtx, true),
                                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      
                                      if (confirm == true) {
                                        try {
                                          await FirebaseFirestore.instance
                                              .collection('services')
                                              .doc(serviceId)
                                              .delete();
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Service deleted'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Error: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 20),
                                          SizedBox(width: 12),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 20, color: Colors.red),
                                          SizedBox(width: 12),
                                          Text('Delete', style: TextStyle(color: Colors.red)),
                                        ],
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
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Edit Service Dialog
  void _showEditServiceDialog(BuildContext context, String serviceId, Map<String, dynamic> data) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: data['name']);
    final descriptionController = TextEditingController(text: data['description']);
    final basePriceController = TextEditingController(text: (data['price'] ?? 0).toString());
    
    // Platform fee (use stored or default)
    final double platformFeePercentage = (data['platformFeePercentage'] as num?)?.toDouble() ?? 10.0;
    
    // Existing images
    List<String> existingImages = List<String>.from(data['imageUrls'] ?? [data['imageUrl'] ?? '']);
    existingImages.removeWhere((url) => url.isEmpty);

    // New images
    List<Uint8List> newImagesData = [];
    final ImagePicker picker = ImagePicker();
    
    double listingPrice = double.tryParse(basePriceController.text) ?? 0.0;
    
    // Helper to calculate earnings
    double calculateEarnings(double inputPrice) {
      return inputPrice / (1 + platformFeePercentage / 100);
    }
    double earnings = calculateEarnings(listingPrice);
    
    final ratePerKmController = TextEditingController(text: (data['ratePerKm'] ?? 0).toString());
    final preBookingAmountController = TextEditingController(text: (data['preBookingAmount'] ?? 0).toString());

    String? selectedCategory = data['category'];
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) {
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setState) {

          Future<void> pickNewImages() async {
             try {
               final List<XFile> pickedFiles = await picker.pickMultiImage();
               if (pickedFiles.isNotEmpty) {
                 final currentCount = existingImages.length + newImagesData.length;
                 if (currentCount + pickedFiles.length > 6) {
                   setState(() => errorMessage = 'Max 6 images allowed');
                   return;
                 }
                 
                 for (var file in pickedFiles) {
                   var bytes = await file.readAsBytes();
                   if (mounted) setState(() => newImagesData.add(bytes));
                 }
                 setState(() => errorMessage = null);
               }
             } catch (e) {
               setState(() => errorMessage = 'Error picking images: $e');
             }
          }

          Future<List<String>> uploadNewImages() async {
            List<String> urls = [];
            for (int i = 0; i < newImagesData.length; i++) {
               final ref = FirebaseStorage.instance.ref().child('service_images').child(serviceId).child('new_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
               await ref.putData(newImagesData[i], SettableMetadata(contentType: 'image/jpeg'));
               urls.add(await ref.getDownloadURL());
            }
            return urls;
          }

          return AlertDialog(
            title: const Text('Edit Service'),
            content: SizedBox(
               width: double.maxFinite,
               child: SingleChildScrollView(
                 child: Form(
                   key: formKey,
                   child: ConstrainedBox(
                     constraints: const BoxConstraints(maxWidth: 500),
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                          if (errorMessage != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.only(bottom: 12),
                              color: Colors.red[100],
                              child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                            ),
                          
                          // Image Preview (Existing + New)
                          SizedBox(
                            height: 120,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                // Existing
                                ...existingImages.asMap().entries.map((entry) {
                                   return Padding(
                                     padding: const EdgeInsets.only(right: 8),
                                     child: Stack(
                                       children: [
                                         ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(entry.value, width: 100, height: 100, fit: BoxFit.cover)),
                                         Positioned(
                                           top: 0, right: 0,
                                           child: IconButton(
                                             icon: const Icon(Icons.close, color: Colors.red),
                                             onPressed: () => setState(() => existingImages.removeAt(entry.key))
                                           )
                                         )
                                       ]
                                     )
                                   );
                                }),
                                // New
                                ...newImagesData.asMap().entries.map((entry) {
                                   return Padding(
                                     padding: const EdgeInsets.only(right: 8),
                                     child: Stack(
                                       children: [
                                         ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(entry.value, width: 100, height: 100, fit: BoxFit.cover)),
                                         Positioned(
                                           top: 0, right: 0,
                                           child: IconButton(
                                             icon: const Icon(Icons.close, color: Colors.red),
                                             onPressed: () => setState(() => newImagesData.removeAt(entry.key))
                                           )
                                         )
                                       ]
                                     )
                                   );
                                }),
                                // Add Button
                                if ((existingImages.length + newImagesData.length) < 6)
                                  InkWell(
                                    onTap: pickNewImages,
                                    child: Container(
                                      width: 100, height: 100,
                                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.add_a_photo, size: 30, color: Colors.grey),
                                    )
                                  )
                              ]
                            )
                          ),
                          const SizedBox(height: 16),
                          
                          TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(labelText: 'Service Name', border: OutlineInputBorder()),
                            validator: (v) => v?.isEmpty == true ? 'Required' : null
                          ),
                          const SizedBox(height: 16),
                          
                          TextFormField(
                            controller: descriptionController,
                            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                            maxLines: 3,
                            validator: (v) {
                               if (v == null || v.isEmpty) return 'Required';
                               if (v.trim() == '\u2022') return 'Required';
                               return null;
                            }
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: basePriceController,
                                  decoration: const InputDecoration(labelText: 'Minimum Price', border: OutlineInputBorder(), prefixText: '₹'),
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) {
                                    final price = double.tryParse(val) ?? 0.0;
                                    setState(() {
                                       listingPrice = price;
                                       earnings = calculateEarnings(price);
                                    });
                                  },
                                  validator: (v) {
                                     final p = double.tryParse(v ?? '');
                                     if (p == null || p <= 0) return 'Invalid';
                                     return null;
                                  }
                                )
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance.collection('service_categories').orderBy('name').snapshots(),
                                  builder: (context, snapshot) {
                                    List<String> categories = ['General'];
                                    if (snapshot.hasData) {
                                      categories = snapshot.data!.docs.map((d) => (d.data() as Map<String,dynamic>)['name'] as String).toSet().toList();
                                    }
                                    return DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      value: categories.contains(selectedCategory) ? selectedCategory : null,
                                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                      onChanged: (v) => setState(() => selectedCategory = v!)
                                    );
                                  }
                                )
                              )
                            ]
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: ratePerKmController,
                            decoration: const InputDecoration(labelText: 'Rate per Km (₹/km)', border: OutlineInputBorder(), helperText: 'Set 0 for fixed price services'),
                            keyboardType: TextInputType.number,
                            validator: (v) => v?.isEmpty == true ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: preBookingAmountController,
                            decoration: const InputDecoration(labelText: 'Pre-booking Amount (₹)', border: OutlineInputBorder(), helperText: 'Amount to pay in advance (set 0 if not required)'),
                            keyboardType: TextInputType.number,
                            validator: (v) => v?.isEmpty == true ? 'Required' : null,
                          ),
                          
                          const SizedBox(height: 12),
                          Container(
                             width: double.maxFinite,
                             padding: const EdgeInsets.all(12),
                             decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                             child: Text('Your Earnings: ₹${earnings.toStringAsFixed(2)}', style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold), textAlign: TextAlign.center)
                          )
                       ]
                     )
                   )
                 )
               )
            ),
            actions: [
               TextButton(onPressed: isLoading ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
               ElevatedButton(
                 onPressed: isLoading ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    if (existingImages.isEmpty && newImagesData.isEmpty) {
                       setState(() => errorMessage = 'At least 1 image required');
                       return;
                    }

                    setState(() => isLoading = true);
                    try {
                       List<String> newUrls = await uploadNewImages();
                       List<String> finalImages = [...existingImages, ...newUrls];
                       
                       double price = double.parse(basePriceController.text);
                       
                       await FirebaseFirestore.instance.collection('services').doc(serviceId).update({
                          'name': nameController.text.trim(),
                          'description': descriptionController.text.trim(),
                          'price': price,
                          'ratePerKm': double.tryParse(ratePerKmController.text) ?? 0,
                          'preBookingAmount': double.tryParse(preBookingAmountController.text) ?? 0,
                          'basePrice': price / (1 + platformFeePercentage / 100),
                          'category': selectedCategory,
                          'imageUrl': finalImages.first,
                          'imageUrls': finalImages,
                          'updatedAt': FieldValue.serverTimestamp()
                       });
                       
                       if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service updated!'), backgroundColor: Colors.green));
                       }
                    } catch (e) {
                       setState(() => errorMessage = e.toString());
                    } finally {
                       if (mounted) setState(() => isLoading = false);
                    }
                 },
                 child: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Update')
               )
            ]
          );
        });
      }
    );
  }

  // Add Service Dialog
  Future<void> _showAddServiceDialog(BuildContext context, dynamic user) async {
    // Fetch Platform Fee
    double platformFeePercentage = 0.0;
    try {
      final doc = await FirebaseFirestore.instance.collection('app_settings').doc('general').get();
      if (doc.exists) {
        platformFeePercentage = (doc.data()?['servicePlatformFeePercentage'] as num?)?.toDouble() ?? 
                                (doc.data()?['platformFeePercentage'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      debugPrint('Error fetching platform fee: $e');
    }

    if (!context.mounted) return;

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController(text: '\u2022 '); // Auto-bullet start
    final basePriceController = TextEditingController();
    final ratePerKmController = TextEditingController(text: '0');
    final preBookingAmountController = TextEditingController(text: '0');
    String selectedCategory = 'General';
    bool isLoading = false;
    List<Uint8List> selectedImages = [];
    final ImagePicker picker = ImagePicker();
    
    double listingPrice = 0.0;

    Future<void> pickImages(StateSetter setState) async {
      try {
        final List<XFile> images = await picker.pickMultiImage();
        if (images.isNotEmpty) {
          final List<Uint8List> imageBytes = [];
          for (var image in images.take(6)) { imageBytes.add(await image.readAsBytes()); }
          setState(() => selectedImages = imageBytes);
        }
      } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
    }

    Future<List<String>> uploadImages(String serviceId) async {
      final List<String> imageUrls = [];
      for (int i = 0; i < selectedImages.length; i++) {
        try {
          final ref = FirebaseStorage.instance.ref().child('service_images').child(serviceId).child('image_$i.jpg');
          await ref.putData(selectedImages[i], SettableMetadata(contentType: 'image/jpeg'));
          imageUrls.add(await ref.getDownloadURL());
        } catch (e) { print('Error uploading image $i: $e'); }
      }
      return imageUrls;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        String? errorMessage;
        return StatefulBuilder(
        builder: (context, setState) {
          
          // Helper to update listing price
          void updateListingPrice(String val) {
             final price = double.tryParse(val) ?? 0.0;
             final earnings = price / (1 + platformFeePercentage / 100);
          }

          return AlertDialog(
          title: const Text('Add New Service'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.red[100],
                        child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                      ),
                    InkWell(
                      onTap: () async {
                         try {
                            await pickImages(setState);
                            setState(() => errorMessage = null);
                         } catch (e) {
                            setState(() => errorMessage = e.toString());
                         }
                      },
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[400]!)
                        ),
                        child: selectedImages.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Tap to add images (max 6)', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.all(8),
                              itemCount: selectedImages.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.memory(
                                      selectedImages[index],
                                      width: 100, // Fixed width for horizontal list items
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              },
                            ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Service Name *', border: OutlineInputBorder()),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Description *', border: OutlineInputBorder()),
                      maxLines: 3,
                      onChanged: (value) {
                          if (value.endsWith('\n')) {
                            // User pressed enter, add bullet
                            descriptionController.text = '$value\u2022 ';
                            descriptionController.selection = TextSelection.fromPosition(TextPosition(offset: descriptionController.text.length));
                          } else if (value.isEmpty) {
                            // User cleared everything, add bullet back
                            descriptionController.text = '\u2022 ';
                            descriptionController.selection = TextSelection.fromPosition(TextPosition(offset: descriptionController.text.length));
                          }
                      },
                      validator: (v) {
                         if (v == null || v.isEmpty) return 'Required';
                         if (v.trim() == '\u2022') return 'Required'; // Don't allow just a bullet
                         return null;
                      }
                    ),
                    const SizedBox(height: 16),


                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: basePriceController,
                            decoration: const InputDecoration(labelText: 'Minimum Price *', border: OutlineInputBorder(), prefixText: '₹'),
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              final price = double.tryParse(val) ?? 0.0;
                              final earnings = price / (1 + platformFeePercentage / 100);
                              setState(() => listingPrice = earnings); 
                            },
                            validator: (v) {
                              if (v?.isEmpty == true) return 'Required';
                              final price = double.tryParse(v!);
                              if (price == null || price <= 0) return 'Invalid';
                              return null;
                            }
                          )
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('service_categories').orderBy('name').snapshots(),
                            builder: (context, snapshot) {
                              List<String> categories = ['General'];
                              if (snapshot.hasData) {
                                categories = snapshot.data!.docs
                                    .map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String? ?? '')
                                    .where((name) => name.isNotEmpty)
                                    .toSet() // Remove duplicates
                                    .toList();
                                if (categories.isEmpty) categories = ['General'];
                              }
                              
                              // Ensure selectedCategory is in the list
                              if (!categories.contains(selectedCategory) && categories.isNotEmpty) {
                                // Defer update to avoid build conflict? Or just select first.
                                // simpler: selectedCategory = categories.first;
                                // But we can't update state during build easily without potential loops.
                                // Instead, use logic:
                                // value: categories.contains(selectedCategory) ? selectedCategory : categories.first
                              }

                              return DropdownButtonFormField<String>(
                                isExpanded: true,
                                menuMaxHeight: 300, // Enable scrolling for long lists
                                value: categories.contains(selectedCategory) ? selectedCategory : categories.firstOrNull,
                                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                                items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => selectedCategory = val);
                                }
                              );
                            }
                          )
                        )
                      ]
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: ratePerKmController,
                      decoration: const InputDecoration(labelText: 'Rate per Km (₹/km)', border: OutlineInputBorder(), helperText: 'Set 0 for fixed price services'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: preBookingAmountController,
                      decoration: const InputDecoration(labelText: 'Pre-booking Amount (₹)', border: OutlineInputBorder(), helperText: 'Amount to pay in advance (set 0 if not required)'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    if (basePriceController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Container(
                          width: double.maxFinite,
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withOpacity(0.3))
                          ),
                          child: Text(
                            'Your Earnings: ₹${listingPrice.toStringAsFixed(2)}  (After $platformFeePercentage% platform fee)',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green[800]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          ), // Close SizedBox
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel')
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (!formKey.currentState!.validate()) return;
                if (selectedImages.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least 1 image')));
                  return;
                }
                
                setState(() => isLoading = true);
                
                try {
                  final serviceId = FirebaseFirestore.instance.collection('services').doc().id;
                  final imageUrls = await uploadImages(serviceId);
                  
                  if (imageUrls.isEmpty) throw Exception('Upload failed');
                  
                  // Fetch updated user details from Firestore to get Business Name
                  final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                  final userData = userDoc.data() ?? {};
                  final providerName = userData['name'] ?? user.displayName ?? 'Unknown';
                  final providerBusinessName = userData['businessName'] ?? providerName;
                  final providerImage = userData['photoURL'] ?? user.photoURL;

                  final inputPrice = double.parse(basePriceController.text); // Listing Price
                  final earnings = inputPrice / (1 + platformFeePercentage / 100); // Base Price

                  await FirebaseFirestore.instance.collection('services').doc(serviceId).set({
                    'id': serviceId,
                    'providerId': user.uid,
                    'providerName': providerName,
                    'providerBusinessName': providerBusinessName,
                    'providerImage': providerImage,
                    'name': nameController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'basePrice': earnings,
                    'platformFeePercentage': platformFeePercentage,
                    'price': inputPrice,
                    'ratePerKm': double.tryParse(ratePerKmController.text) ?? 0,
                    'preBookingAmount': double.tryParse(preBookingAmountController.text) ?? 0,
                    'category': selectedCategory,
                    'imageUrl': imageUrls.first,
                    'imageUrls': imageUrls,
                    'createdAt': FieldValue.serverTimestamp(),
                    'rating': 0.0,
                    'reviewCount': 0
                  });
                  
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Service added! Earnings: ₹${earnings.toStringAsFixed(2)} (Fee: $platformFeePercentage%)'), 
                        backgroundColor: Colors.green
                      )
                    );
                  }
                } catch (e) {
                  setState(() => errorMessage = e.toString());
                } finally {
                  if (mounted) setState(() => isLoading = false);
                }
              },
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add Service')
            )
          ]
        );
      }
      );
    }
    );
  }

  // View Bookings Dialog
  void _showViewBookingsDialog(BuildContext context, dynamic user) {
    showDialog(
      context: context,
      builder: (ctx) {
        String selectedStatus = 'All';
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: StatefulBuilder(
            builder: (context, setState) {
            return Container(
              width: 900,
              height: 700,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('My Bookings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Status Filter Chips
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ['All', 'pending', 'confirmed', 'in_progress', 'completed', 'cancelled'].map((status) {
                        final isSelected = selectedStatus == status;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(status == 'All' ? 'All' : status.toUpperCase()),
                            selected: isSelected,
                            onSelected: (selected) => setState(() => selectedStatus = status),
                            backgroundColor: Colors.grey[200],
                            selectedColor: Colors.blue[100],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Bookings List
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _allBookingsStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: SelectableText(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        
                        var bookings = snapshot.data?.docs ?? [];
                        if (selectedStatus != 'All') {
                          bookings = bookings.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return (data['status'] ?? 'pending').toLowerCase() == selectedStatus.toLowerCase();
                          }).toList();
                        }
                        
                        if (bookings.isEmpty) {
                          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]), const SizedBox(height: 16), Text(selectedStatus == 'All' ? 'No bookings yet' : 'No $selectedStatus bookings', style: const TextStyle(fontSize: 18, color: Colors.grey))]));
                        }
                        
                        return ListView.builder(
                          itemCount: bookings.length,
                          itemBuilder: (context, index) {
                            final bookingData = bookings[index].data() as Map<String, dynamic>;
                            final bookingId = bookings[index].id;
                            final serviceName = bookingData['serviceName'] ?? 'Service';
                            final customerName = bookingData['customerName'] ?? 'Customer';
                            final customerPhone = bookingData['customerPhone'] ?? 'N/A';
                            final status = bookingData['status'] ?? 'pending';
                            final totalCost = (bookingData['totalCost'] as num?)?.toDouble() ?? 0;
                            final bookingDate = (bookingData['bookingDate'] as Timestamp?)?.toDate();
                            final address = bookingData['address'] ?? 'N/A';
                            
                            Color statusColor;
                            switch (status.toLowerCase()) {
                              case 'completed': statusColor = Colors.green; break;
                              case 'cancelled': statusColor = Colors.red; break;
                              case 'in_progress': statusColor = Colors.blue; break;
                              case 'confirmed': statusColor = Colors.teal; break;
                              default: statusColor = Colors.orange;
                            }
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ExpansionTile(
                                leading: CircleAvatar(backgroundColor: statusColor.withOpacity(0.1), child: Icon(Icons.work, color: statusColor, size: 20)),
                                title: Text('Booking #${bookingId.substring(0, 8)}...', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('$serviceName • $customerName'),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('₹${totalCost.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                        child: status != 'completed' && status != 'cancelled' 
                                            ? PopupMenuButton<String>(
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(status.toUpperCase(), style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                                                    Icon(Icons.arrow_drop_down, color: statusColor, size: 16),
                                                  ],
                                                ),
                                                onSelected: (newValue) async {
                                                  // Confirm change
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (c) => AlertDialog(
                                                      title: const Text('Update Status'),
                                                      content: Text('Set status to ${newValue.toUpperCase()}?'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirm')),
                                                      ],
                                                    ),
                                                  );

                                                  if (confirm == true) {
                                                     try {
                                                        await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({'status': newValue});
                                                        
                                                        // Record Transaction if Completed
                                                        if (newValue == 'completed') {
                                                           final auth = Provider.of<AuthProvider>(context, listen: false);
                                                           final user = auth.currentUser;
                                                           if (user != null) {
                                                              final tx = TransactionModel(
                                                                 id: '', // Auto-gen
                                                                 userId: user.uid,
                                                                 amount: totalCost,
                                                              type: TransactionType.credit,
                                                              status: TransactionStatus.completed,
                                                              description: 'Booking payment: $serviceName',
                                                              createdAt: DateTime.now(),
                                                              referenceId: bookingId,
                                                              metadata: {'bookingId': bookingId},
                                                           );
                                                           await TransactionService().recordTransaction(tx);
                                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Credited to Wallet'), backgroundColor: Colors.green));
                                                        }
                                                        }

                                                        if (context.mounted) setState(() {}); 
                                                     } catch(e) {
                                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                                     }
                                                  }
                                                },
                                                itemBuilder: (context) => [
                                                  if (status == 'pending') const PopupMenuItem(value: 'confirmed', child: Text('Confirm')),
                                                  if (status == 'confirmed') const PopupMenuItem(value: 'in_progress', child: Text('In Progress')),
                                                  if (status == 'in_progress') const PopupMenuItem(value: 'completed', child: Text('Complete')),
                                                  const PopupMenuItem(value: 'cancelled', child: Text('Cancel')),
                                                ],
                                              )
                                            : Text(status.toUpperCase(), style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildBookingDetailRow(Icons.person, 'Customer', customerName),
                                        const SizedBox(height: 8),
                                        _buildBookingDetailRow(Icons.phone, 'Phone', customerPhone),
                                        const SizedBox(height: 8),
                                        _buildBookingDetailRow(Icons.build, 'Service', serviceName),
                                        const SizedBox(height: 8),
                                        if (bookingDate != null) _buildBookingDetailRow(Icons.calendar_today, 'Date', DateFormat('MMM d, yyyy').format(bookingDate)),
                                        const SizedBox(height: 8),
                                        _buildBookingDetailRow(Icons.location_on, 'Address', address),
                                        const SizedBox(height: 8),
                                        _buildBookingDetailRow(Icons.currency_rupee, 'Total Cost', '₹${totalCost.toStringAsFixed(2)}'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
      },
    );
  }

  Widget _buildBookingDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeHeader(dynamic user) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade800, Colors.teal.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'S',
                    style: TextStyle(
                      fontSize: 28,
                      color: Colors.teal[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: TextStyle(color: Colors.teal[100], fontSize: 14),
                      ),
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  tooltip: 'Edit Profile',
                  onPressed: () => _showEditProfileDialog(context, user),
                ),
                const Icon(Icons.verified, color: Colors.white, size: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
     return Column(
        children: [
           Row(
              children: [
                 Expanded(
                    child: FutureBuilder<double>(
                       future: TransactionService().getBalance(Provider.of<AuthProvider>(context).currentUser!.uid),
                       builder: (context, snapshot) {
                          return _buildModernStatCard('Wallet Balance', '₹${(snapshot.data ?? 0.0).toStringAsFixed(2)}', Icons.account_balance_wallet, Colors.blue, Colors.blue[50]!);
                       }
                    ),
                 ),
                 const SizedBox(width: 12),
                 Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                       stream: _bookingsCountStream,
                       builder: (context, snapshot) {
                          return _buildModernStatCard('Bookings', '${snapshot.data?.docs.length ?? 0}', Icons.calendar_today, Colors.orange, Colors.orange[50]!);
                       }
                    ),
                 ),
              ],

           ),
           const SizedBox(height: 12),
           Row(
              children: [
                 Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                       stream: _servicesStream,
                       builder: (context, snapshot) {
                          return _buildModernStatCard('Services', '${snapshot.data?.docs.length ?? 0}', Icons.build_circle, Colors.purple, Colors.purple[50]!);
                       }
                    ),
                 ),
                 const SizedBox(width: 12),
                 Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                       stream: _servicesStream,
                       builder: (context, snapshot) {
                          double totalRating = 0;
                          int ratedCount = 0;
                          for (var doc in snapshot.data?.docs ?? []) {
                             final data = doc.data() as Map<String, dynamic>;
                             final rating = (data['rating'] as num?)?.toDouble();
                             if (rating != null && rating > 0) { totalRating += rating; ratedCount++; }
                          }
                          final avg = ratedCount > 0 ? (totalRating / ratedCount) : 0.0;
                          return _buildModernStatCard('Rating', avg.toStringAsFixed(1), Icons.star, Colors.amber, Colors.amber[50]!);
                       }
                    ),
                 ),
              ],
           ),
        ],
     );
  }

  Widget _buildModernStatCard(String title, String value, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, dynamic user) {
     final actions = [
        {'title': 'My Services', 'icon': Icons.build, 'color': Colors.purple, 'onTap': () {
            if (user.hasPermission('can_manage_services')) _showManageServicesDialog(context, user);
            else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Access Denied')));
        }},
        {'title': 'My Bookings', 'icon': Icons.calendar_month, 'color': Colors.blue, 'onTap': () {
            if (user.hasPermission('can_view_bookings')) _showViewBookingsDialog(context, user);
            else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Access Denied')));
        }},
        {'title': 'Add Service', 'icon': Icons.add_circle, 'color': Colors.green, 'onTap': () {
            if (user.hasPermission('can_manage_services')) _showAddServiceDialog(context, user);
            else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Access Denied')));
        }},
     ];

     return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
           crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.0, 
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) {
           final action = actions[index];
           return InkWell(
              onTap: action['onTap'] as VoidCallback,
              child: Container(
                 decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
                 ),
                 child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: (action['color'] as Color).withOpacity(0.1)),
                          child: Icon(action['icon'] as IconData, color: action['color'] as Color, size: 28),
                       ),
                       const SizedBox(height: 8),
                       Text(action['title'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                 ),
              ),
           );
        },
     );
  }

  Widget _buildRecentActivityList(dynamic user) {
     return StreamBuilder<QuerySnapshot>(
        stream: _recentActivityStream,
        builder: (context, snapshot) {
           if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(16),
                color: Colors.red[50],
                child: SelectableText(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }
           if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                  width: double.infinity, padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('No recent activity', style: TextStyle(color: Colors.grey))),
              );
           }
           final bookings = snapshot.data!.docs;
           return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bookings.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                 final data = bookings[index].data() as Map<String, dynamic>;
                 final serviceName = data['serviceName'] ?? 'Service';
                 final customerName = data['customerName'] ?? 'Customer';
                 final status = data['status'] ?? 'pending';
                 final cost = (data['totalCost'] as num?)?.toDouble() ?? 0;
                 
                 Color statusColor = Colors.orange;
                 if (status == 'completed') statusColor = Colors.green;
                 if (status == 'cancelled') statusColor = Colors.red;
                 if (status == 'in_progress') statusColor = Colors.blue;

                 return Container(
                    decoration: BoxDecoration(
                       color: Colors.white,
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(color: Colors.grey.withOpacity(0.3)),
                       boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: IntrinsicHeight(
                      child: Row(
                         crossAxisAlignment: CrossAxisAlignment.stretch,
                         children: [
                            Container(width: 4, color: statusColor),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                   children: [
                                      Expanded(
                                         child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                               Text(serviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                               const SizedBox(height: 4),
                                               Text('$customerName • ₹${cost.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                            ],
                                         ),
                                      ),
                                      Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                         decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                         child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                   ],
                                ),
                              ),
                            ),
                         ],
                      ),
                    ),
                 );
              },
           );
        },
     );
  }
  Future<void> _showEditRequestDialog(BuildContext context, String docId, Map<String, dynamic> data) async {
    final nameCtrl = TextEditingController(text: data['fullName']);
    final phoneCtrl = TextEditingController(text: data['phoneNumber']);
    final experienceCtrl = TextEditingController(text: data['experience']);
    final minChargeCtrl = TextEditingController(text: (data['minCharge'] ?? 0).toString());
    
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Details'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   TextFormField(
                     controller: nameCtrl,
                     decoration: const InputDecoration(labelText: 'Full Name'),
                     validator: (v) => v!.isEmpty ? 'Enter Name' : null,
                   ),
                   const SizedBox(height: 12),
                   TextFormField(
                     controller: phoneCtrl,
                     decoration: const InputDecoration(labelText: 'Phone Number', prefixText: '+91 '),
                     keyboardType: TextInputType.phone,
                     maxLength: 10,
                     validator: (v) => v!.length != 10 ? 'Enter valid 10-digit phone' : null,
                   ),
                   const SizedBox(height: 12),
                   TextFormField(
                     controller: experienceCtrl,
                     decoration: const InputDecoration(labelText: 'Experience (e.g. 2 Years)'),
                   ),

                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setState(() => isLoading = true);
                try {
                  final updates = {
                    'fullName': nameCtrl.text.trim(),
                    'phoneNumber': phoneCtrl.text.trim(),
                    'experience': experienceCtrl.text.trim(),
                    'minCharge': double.tryParse(minChargeCtrl.text.trim()) ?? 0,
                  };

                  // Update Partner Request
                  await FirebaseFirestore.instance.collection('partner_requests').doc(docId).update(updates);

                  // Also try to update User Profile if it matches current user
                  final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
                  if (user != null && data['email'] == user.email) {
                      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                        'name': nameCtrl.text.trim(),
                        'phoneNumber': phoneCtrl.text.trim(),
                        'experience': experienceCtrl.text.trim(),
                        'minCharge': updates['minCharge'],
                      });
                  }

                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated successfully!')));
                  }
                } catch (e) {
                  if (mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                } finally {
                  if (mounted) setState(() => isLoading = false);
                }
              }, 
              child: isLoading ? const CircularProgressIndicator() : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _showEditProfileDialog(BuildContext context, dynamic userModel) async {
    // 1. Fetch latest data from Firestore to get extended fields (experience, minCharge)
    Map<String, dynamic> userData = {};
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userModel.uid).get();
      if (doc.exists) {
        userData = doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }

    final nameCtrl = TextEditingController(text: userData['name'] ?? userModel.name);
    final phoneCtrl = TextEditingController(text: userData['phoneNumber'] ?? userModel.phoneNumber ?? '');
    final experienceCtrl = TextEditingController(text: userData['experience'] ?? '');
    final minChargeCtrl = TextEditingController(text: (userData['minCharge'] ?? 0).toString());
    
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   TextFormField(
                     controller: nameCtrl,
                     decoration: const InputDecoration(labelText: 'Display Name / Business Name'),
                     validator: (v) => v!.isEmpty ? 'Enter Name' : null,
                   ),
                   const SizedBox(height: 12),
                   TextFormField(
                     controller: phoneCtrl,
                     decoration: const InputDecoration(labelText: 'Phone Number', prefixText: '+91 '),
                     keyboardType: TextInputType.phone,
                     maxLength: 10,
                     validator: (v) => v!.length != 10 ? 'Enter valid 10-digit phone' : null,
                   ),
                   const SizedBox(height: 12),
                   TextFormField(
                     controller: experienceCtrl,
                     decoration: const InputDecoration(labelText: 'Experience (e.g. 5 Years)'),
                   ),

                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setState(() => isLoading = true);
                try {
                  final updates = {
                    'name': nameCtrl.text.trim(),
                    'phoneNumber': phoneCtrl.text.trim(),
                    'experience': experienceCtrl.text.trim(),
                    'minCharge': double.tryParse(minChargeCtrl.text.trim()) ?? 0,
                  };

                  await FirebaseFirestore.instance.collection('users').doc(userModel.uid).update(updates);
                  
                   if (context.mounted) {
                      try {
                        await Provider.of<AuthProvider>(context, listen: false).refreshUser();
                      } catch (e) {
                        // ignore if method doesn't exist
                      }
                   }

                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
                  }
                } catch (e) {
                  if (mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                } finally {
                  if (mounted) setState(() => isLoading = false);
                }
              }, 
              child: isLoading ? const CircularProgressIndicator() : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
