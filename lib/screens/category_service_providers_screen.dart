import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_category_model.dart';
import '../providers/theme_provider.dart';
import '../providers/cart_provider.dart';
import '../screens/cart_screen.dart';
import '../screens/book_service_screen.dart';

class CategoryServiceProvidersScreen extends StatefulWidget {
  static const routeName = '/category-service-providers';

  final ServiceCategory category;

  const CategoryServiceProvidersScreen({super.key, required this.category});

  @override
  State<CategoryServiceProvidersScreen> createState() => _CategoryServiceProvidersScreenState();
}

class _CategoryServiceProvidersScreenState extends State<CategoryServiceProvidersScreen> {
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(() {
        if (mounted) {
          setState(() {
            _searchQuery = _searchController.text.toLowerCase().trim();
          });
        }
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.category.name} Services',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return IconButton(
                onPressed: () => themeProvider.toggleTheme(),
                icon: Icon(
                  themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
              );
            },
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  Navigator.pushNamed(context, CartScreen.routeName);
                },
              ),
              Positioned(
                right: 8,
                top: 10,
                child: Consumer<CartProvider>(
                  builder: (_, cart, __) => cart.itemCount == 0
                      ? const SizedBox.shrink()
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            cart.itemCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search service or provider...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          // Services List (Querying 'services' collection instead of 'users')
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('services')
                  .where('category', isEqualTo: widget.category.name)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: SelectableText(
                      'Error loading services: ${snapshot.error}',
                      style: TextStyle(color: Colors.red[700]),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final services = snapshot.data?.docs ?? [];
                
                // Filter locally
                final filteredServices = _searchQuery.isEmpty 
                    ? services 
                    : services.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['name'] ?? '').toString().toLowerCase();
                        final providerName = (data['providerName'] ?? '').toString().toLowerCase();
                        final description = (data['description'] ?? '').toString().toLowerCase();
                        return name.contains(_searchQuery) ||
                               providerName.contains(_searchQuery) ||
                               description.contains(_searchQuery);
                      }).toList();

                if (filteredServices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.design_services_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty 
                              ? 'No services found in ${widget.category.name}'
                              : 'No matches found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  itemCount: filteredServices.length,
                  itemBuilder: (context, index) {
                    final data = filteredServices[index].data() as Map<String, dynamic>;
                    final serviceId = filteredServices[index].id;
                    return _buildServiceCard(context, data, serviceId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, Map<String, dynamic> data, String serviceId) {
    final serviceName = data['name'] ?? 'Unknown Service';
    final providerName = data['providerBusinessName'] ?? data['providerName'] ?? 'Service Provider';
    final price = (data['price'] ?? 0.0).toDouble();
    final description = data['description'] ?? '';
    final imageUrl = data['imageUrl'] as String?;
    final providerImage = data['providerImage'] as String?;
    final providerId = data['providerId'] ?? '';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 80,
                height: 80,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.build_circle,
                          size: 40,
                          color: Theme.of(context).primaryColor,
                        ),
                      )
                    : Icon(
                        Icons.build_circle,
                        size: 40,
                        color: Theme.of(context).primaryColor,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Service Name (Hide if redundant or specific 'vehical' typo)
                  if (!widget.category.name.toLowerCase().contains(serviceName.toLowerCase()) && 
                      !serviceName.toLowerCase().contains(widget.category.name.toLowerCase()) &&
                      serviceName.toLowerCase() != 'vehical' &&
                      serviceName.toLowerCase() != 'vehicle')
                    Text(
                      serviceName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  
                  const SizedBox(height: 4),
                  
                  // 2. Provider Name
                  ProviderNameWidget(
                    providerId: providerId,
                    cachedName: providerName,
                    providerImage: providerImage,
                  ),
                  
                  const SizedBox(height: 6),
                  
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                         description,
                         maxLines: 2,
                         overflow: TextOverflow.ellipsis,
                         style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  
                  // 3. Pre-booking Amount (Green text only, no box)
                  Row(
                    children: [
                      const Text(
                        'Pre-booking: ', 
                        style: TextStyle(
                          fontSize: 12, 
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '₹${((data['preBookingAmount'] ?? 0).toDouble()).toStringAsFixed(0)}', 
                        style: const TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 14, 
                          color: Colors.green,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            // Book Button
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      BookServiceScreen.routeName,
                      arguments: {
                        'serviceName': serviceName,
                        'providerName': providerName,
                        'providerId': providerId,
                        'providerImage': providerImage,
                        'ratePerKm': (data['ratePerKm'] ?? 0).toDouble(),
                        'minBookingAmount': (data['price'] ?? 0).toDouble(), // Use customer billable price
                        'preBookingAmount': (data['preBookingAmount'] ?? 0).toDouble(),
                      },
                    );
                    print('DEBUG BOOK: ratePerKm=${data['ratePerKm']}, minBooking=${data['price']}, prebook=${data['preBookingAmount']}');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Book'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProviderNameWidget extends StatelessWidget {
  final String providerId;
  final String? cachedName;
  final String? providerImage;

  const ProviderNameWidget({
    super.key,
    required this.providerId,
    this.cachedName,
    this.providerImage,
  });

  @override
  Widget build(BuildContext context) {
    // If we have a good cached name, show it (filtering out generic/empty)
    if (cachedName != null && 
        cachedName != 'Service Provider' && 
        cachedName != 'Unknown Service' && 
        cachedName!.isNotEmpty) {
       return _buildContent(cachedName!, providerImage);
    }

    // If no providerId, fallback
    if (providerId.isEmpty) return _buildContent('Service Provider', providerImage);

    // Otherwise, fetch it from Firestore
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(providerId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const SizedBox(width: 80, height: 16, child: LinearProgressIndicator(color: Colors.grey, minHeight: 2));
        }
        
        String name = 'Service Provider';
        String? image = providerImage;

        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
           final data = snapshot.data!.data() as Map<String, dynamic>;
           name = data['businessName'] ?? data['name'] ?? 'Service Provider';
           image = data['photoURL'] ?? image;
        }

        return _buildContent(name, image);
      },
    );
  }

  Widget _buildContent(String name, String? image) {
    return Row(
      children: [
        if (image != null && image.isNotEmpty)
            Container(
              width: 20, height: 20,
              margin: const EdgeInsets.only(right: 6),
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: ClipOval(child: Image.network(image, fit: BoxFit.cover, errorBuilder: (_,__,___)=> const Icon(Icons.store, size: 18, color: Colors.blueGrey)))
            )
        else  
            const Icon(Icons.store, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              color: Colors.grey[900],
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
