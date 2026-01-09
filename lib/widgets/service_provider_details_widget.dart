import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceProviderDetailsWidget extends StatefulWidget {
  final String providerId;

  const ServiceProviderDetailsWidget({Key? key, required this.providerId}) : super(key: key);

  @override
  State<ServiceProviderDetailsWidget> createState() => _ServiceProviderDetailsWidgetState();
}

class _ServiceProviderDetailsWidgetState extends State<ServiceProviderDetailsWidget> {
  late Stream<QuerySnapshot> _servicesStream;
  late Stream<QuerySnapshot> _requestsStream;

  @override
  void initState() {
    super.initState();
    _servicesStream = FirebaseFirestore.instance
        .collection('services')
        .where('providerId', isEqualTo: widget.providerId)
        .snapshots();
    
    _requestsStream = FirebaseFirestore.instance
        .collection('service_requests')
        .where('providerId', isEqualTo: widget.providerId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: StreamBuilder<QuerySnapshot>(
        stream: _servicesStream,
        builder: (context, serviceSnapshot) {
          final serviceCount = serviceSnapshot.data?.docs.length ?? 0;

          return StreamBuilder<QuerySnapshot>(
            stream: _requestsStream,
            builder: (context, requestSnapshot) {
              final requestCount = requestSnapshot.data?.docs.length ?? 0;
              final requests = requestSnapshot.data?.docs ?? [];

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatCard(
                    'Total Services',
                    serviceCount.toString(),
                    Icons.handyman,
                    Colors.orange,
                  ),
                  _buildStatCard(
                    'Total Requests',
                    requestCount.toString(),
                    Icons.assignment,
                    Colors.blue,
                  ),
                  _buildStatCard(
                    'Pending',
                    requests.where((r) {
                      final d = r.data() as Map<String, dynamic>;
                      return d['status'] == 'pending';
                    }).length.toString(),
                    Icons.pending_actions,
                    Colors.red,
                  ),
                  _buildStatCard(
                    'Completed',
                    requests.where((r) {
                      final d = r.data() as Map<String, dynamic>;
                      return d['status'] == 'completed';
                    }).length.toString(),
                    Icons.task_alt,
                    Colors.green,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
