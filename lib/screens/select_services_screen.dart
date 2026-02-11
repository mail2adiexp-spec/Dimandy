import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/service_item_model.dart';
import '../providers/auth_provider.dart';
import '../utils/category_helpers.dart';
import 'book_service_screen.dart';

class SelectServicesScreen extends StatefulWidget {
  static const routeName = '/select-services';

  const SelectServicesScreen({super.key});

  @override
  State<SelectServicesScreen> createState() => _SelectServicesScreenState();
}

class _SelectServicesScreenState extends State<SelectServicesScreen> {
  List<ServiceItem> _services = [];
  List<ServiceItem> get _selectedServices =>
      _services.where((s) => s.isSelected).toList();
  double get _totalPrice =>
      _selectedServices.fold(0.0, (sum, service) => sum + service.price);

  @override
  Widget build(BuildContext context) {
    final args =
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ?? {};
    final providerId = args['providerId'] as String? ?? '';
    final providerName = args['providerName'] as String? ?? '';
    final providerImage = args['providerImage'] as String?;
    final category = args['category'] as String? ?? '';

    if (providerId.isEmpty) {
       return const Scaffold(body: Center(child: Text("Error: Provider ID missing")));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('services')
          .doc(providerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('Services not found')),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final servicesList = (data['servicesList'] as List<dynamic>?)
                ?.where((item) => item is Map<String, dynamic>)
                .map((item) =>
                    ServiceItem.fromMap(item as Map<String, dynamic>))
                .toList() ??
            [];

        // Initialize services list if empty - defer state update
        if (_services.isEmpty && servicesList.isNotEmpty) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted) {
               setState(() {
                 _services = servicesList;
               });
             }
           });
        }
        
        // Minimum Booking Amount Logic
        final minBookingAmount = (data['price'] as num?)?.toDouble() ?? 0.0;
        final preBookingAmount = (data['preBookingAmount'] as num?)?.toDouble() ?? 0.0;
        final effectiveAmount = _totalPrice > minBookingAmount ? _totalPrice : minBookingAmount;
        final bool isBelowMinimum = _totalPrice > 0 && _totalPrice < minBookingAmount;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Select Services'),
            elevation: 2,
          ),
          body: Column(
            children: [
              // Header Info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      providerName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select one or more services',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Services List
              Expanded(
                child: _services.isEmpty
                    ? const Center(
                        child: Text(
                          'No services available',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : (category.toLowerCase().contains('blood') || category.toLowerCase().contains('technician') || category.toLowerCase().contains('napit') || category.toLowerCase().contains('barber') || category.toLowerCase().contains('salon') || category.toLowerCase().contains('beautician') || category.toLowerCase().contains('beauty') || category.toLowerCase().contains('parlour'))
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButtonFormField<ServiceItem>(
                                  decoration: const InputDecoration(
                                    labelText: 'Select Test',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.search),
                                  ),
                                  items: _services
                                      .where((s) => !s.isSelected)
                                      .map((s) => DropdownMenuItem(
                                            value: s,
                                            child: Text('${s.name} - ₹${s.price.toStringAsFixed(0)}'),
                                          ))
                                      .toList(),
                                  onChanged: (service) {
                                    if (service != null && mounted) {
                                      setState(() {
                                        final index =
                                            _services.indexWhere((s) => s.id == service.id);
                                        if (index != -1) {
                                          _services[index] =
                                              service.copyWith(isSelected: true);
                                        }
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 20),
                                if (_selectedServices.isNotEmpty) ...[
                                  const Text(
                                    'Selected Tests:',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 10),
                                  ListView.separated(
                                    physics: const NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    itemCount: _selectedServices.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final service = _selectedServices[index];
                                      return Card(
                                        elevation: 2,
                                        child: ListTile(
                                          title: Text(service.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          subtitle: Text(
                                              '₹${service.price.toStringAsFixed(0)} • ${service.duration} mins'),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.close,
                                                color: Colors.red),
                                            onPressed: () {
                                              setState(() {
                                                final idx = _services.indexWhere(
                                                    (s) => s.id == service.id);
                                                if (idx != -1) {
                                                  _services[idx] = service.copyWith(
                                                      isSelected: false);
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _services.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final service = _services[index];
                              return Card(
                                elevation: service.isSelected ? 4 : 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: service.isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: CheckboxListTile(
                                  value: service.isSelected,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      _services[index] = service.copyWith(
                                        isSelected: value ?? false,
                                      );
                                    });
                                  },
                                  title: Text(
                                    service.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: service.isSelected
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.black,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (service.description.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          service.description,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 14,
                                            color: Colors.grey[500],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${service.duration} mins',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Icon(
                                            Icons.currency_rupee,
                                            size: 14,
                                            color: Colors.green,
                                          ),
                                          Text(
                                            service.price.toStringAsFixed(0),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  activeColor:
                                      Theme.of(context).colorScheme.primary,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                              );
                            },
                          ),
              ),

              // Price Summary Bar
              if (_selectedServices.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    border: Border(
                      top: BorderSide(
                        color: Colors.green.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Expanded(
                        child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(
                             '${_selectedServices.length} service${_selectedServices.length > 1 ? 's' : ''} selected',
                             style: const TextStyle(
                               fontSize: 14,
                               color: Colors.grey,
                             ),
                           ),
                           const SizedBox(height: 4),
                           Text(
                             'Total: ₹${_totalPrice.toStringAsFixed(0)}',
                             style: const TextStyle(
                               fontSize: 20,
                               fontWeight: FontWeight.bold,
                               color: Colors.green,
                             ),
                           ),
                           if (isBelowMinimum)
                              Text(
                                '(Minimum Booking Amount ₹${minBookingAmount.toStringAsFixed(0)} applies)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                         ],
                       ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isBelowMinimum)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Minimum bill of ₹${minBookingAmount.toStringAsFixed(0)} will be charged.",
                                style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _selectedServices.isEmpty
                          ? null
                          : () {
                              // Navigate to booking screen with selected services
                              Navigator.pushNamed(
                                context,
                                BookServiceScreen.routeName,
                                arguments: {
                                  'serviceName': _selectedServices
                                      .map((s) => s.name)
                                      .join(', '),
                                  'providerName': providerName,
                                  'providerId': providerId,
                                  'providerImage': providerImage,
                                  'ratePerKm': 0.0,
                                  'minBookingAmount': effectiveAmount, // Pass the enforced minimum
                                  'preBookingAmount': preBookingAmount,
                                  'selectedServices': _selectedServices
                                      .map((s) => s.toMap())
                                      .toList(),
                                },
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black, // Dark background for contrast
                        foregroundColor: Colors.white, // White text
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                        'Book Now (₹${effectiveAmount.toStringAsFixed(0)})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
         ),
        );
      },
    );
  }
}
