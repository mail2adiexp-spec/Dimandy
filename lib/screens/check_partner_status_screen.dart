import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CheckPartnerStatusScreen extends StatefulWidget {
  static const routeName = '/check-partner-status';

  const CheckPartnerStatusScreen({super.key});

  @override
  State<CheckPartnerStatusScreen> createState() =>
      _CheckPartnerStatusScreenState();
}

class _CheckPartnerStatusScreenState extends State<CheckPartnerStatusScreen> {
  final _phoneController = TextEditingController();
  bool _isSearching = false;
  Map<String, dynamic>? _requestData;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    if (_phoneController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your phone number';
        _requestData = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _requestData = null;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('partner_requests')
          .where('phone', isEqualTo: _phoneController.text.trim())
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _errorMessage = 'No request found with this phone number';
          _isSearching = false;
        });
        return;
      }

      final doc = querySnapshot.docs.first;
      setState(() {
        _requestData = doc.data();
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isSearching = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.pending;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
      default:
        return 'Pending Review';
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check Partner Status'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100, left: 16, right: 16, top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Illustration
            Container(
              padding: const EdgeInsets.all(32),
              child: Icon(
                Icons.person_search,
                size: 100,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Check Your Request Status',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your registered phone number to check your partner request status',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Phone Input
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter your phone number',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onSubmitted: (_) => _checkStatus(),
            ),
            const SizedBox(height: 16),

            // Check Status Button
            ElevatedButton.icon(
              onPressed: _isSearching ? null : _checkStatus,
              icon: _isSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search),
              label: Text(_isSearching ? 'Checking...' : 'Check Status'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Error Message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Request Details
            if (_requestData != null) ...[
              // Status Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getStatusColor(_requestData!['status'] ?? 'pending'),
                      _getStatusColor(
                        _requestData!['status'] ?? 'pending',
                      ).withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _getStatusColor(
                        _requestData!['status'] ?? 'pending',
                      ).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      _getStatusIcon(_requestData!['status'] ?? 'pending'),
                      size: 60,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getStatusText(_requestData!['status'] ?? 'pending'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_requestData!['notificationMessage'] != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _requestData!['notificationMessage'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Details Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Request Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 24),
                      _buildDetailRow('Name', _requestData!['name'] ?? 'N/A'),
                      _buildDetailRow('Role', _requestData!['role'] ?? 'N/A'),
                      _buildDetailRow('Phone', _requestData!['phone'] ?? 'N/A'),
                      _buildDetailRow('Email', _requestData!['email'] ?? 'N/A'),
                      _buildDetailRow(
                        'Business Name',
                        _requestData!['businessName'] ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'District',
                        _requestData!['district'] ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Submitted On',
                        _formatDate(_requestData!['createdAt']),
                      ),
                      if (_requestData!['updatedAt'] != null)
                        _buildDetailRow(
                          'Last Updated',
                          _formatDate(_requestData!['updatedAt']),
                        ),
                    ],
                  ),
                ),
              ),

              // Contact Support Button
              if (_requestData!['status'] == 'rejected')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Add contact support logic
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Contact support feature coming soon'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.support_agent),
                    label: const Text('Contact Support'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
