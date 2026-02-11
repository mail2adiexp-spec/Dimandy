import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_category_model.dart';
import '../providers/theme_provider.dart';
import '../providers/cart_provider.dart';
import '../screens/cart_screen.dart';
import '../screens/book_service_screen.dart';
import '../utils/category_helpers.dart';
import '../providers/address_provider.dart';

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
    // Fetch addresses to get pincode for filtering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AddressProvider>(context, listen: false).fetch();
    });

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
          // Services List with Pincode Filtering
          Expanded(
            child: Consumer<AddressProvider>(
              builder: (context, addressProvider, _) {
                final profilePincode = addressProvider.authProvider.currentUser?.pincode;
                final userPincode = addressProvider.defaultAddress?.postalCode ?? profilePincode;

                if (userPincode == null || userPincode.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'No address or pincode found.\nPlease set a default address or update your profile pincode.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Go to Profile > Addresses to set a default address')),
                            );
                          },
                          child: const Text('Set Address'),
                        ),
                      ],
                    ),
                  );
                }

                // 1. Fetch Providers who serve this Pincode
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('role', isEqualTo: 'service_provider')
                      .where('servicePincodes', arrayContains: userPincode)
                      .snapshots(),
                  builder: (context, providerSnapshot) {
                    if (providerSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Providers serving this area
                    final validProviderIds = providerSnapshot.data?.docs
                            .map((doc) => doc.id)
                            .toSet() ??
                        {};

                    if (validProviderIds.isEmpty) {
                      return Center(
                        child: Text(
                          'No service providers found for pincode $userPincode',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    // 2. Fetch Services and Filter by Valid Provider IDs
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('services')
                          .where('category', isEqualTo: widget.category.name)
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, serviceSnapshot) {
                        if (serviceSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final services = serviceSnapshot.data?.docs ?? [];
                        
                        // Filter services: Provider ID must be in validProviderIds
                        final filteredServices = services.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final providerId = data['providerId'];
                          
                          // Core filtering logic
                          if (providerId == null || !validProviderIds.contains(providerId)) {
                            return false;
                          }

                          // Also apply local search query
                          if (_searchQuery.isNotEmpty) {
                            final name = (data['name'] ?? '').toString().toLowerCase();
                            final providerName = (data['providerName'] ?? '').toString().toLowerCase();
                            final description = (data['description'] ?? '').toString().toLowerCase();
                            return name.contains(_searchQuery) ||
                                   providerName.contains(_searchQuery) ||
                                   description.contains(_searchQuery);
                          }
                          return true;
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
                                  'No services found in your area ($userPincode)',
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

                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filteredServices.length,
                          itemBuilder: (context, index) {
                            final data = filteredServices[index].data() as Map<String, dynamic>;
                            final serviceId = filteredServices[index].id;
                            return _buildServiceCard(context, data, serviceId);
                          },
                        );
                      },
                    );
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
    final preBookingAmount = (data['preBookingAmount'] ?? 0).toDouble();
    final rating = (data['rating'] ?? 4.0).toDouble(); // Default 4.0 if no rating

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Navigate to provider details screen
          Navigator.pushNamed(
            context,
            '/provider-details',
            arguments: {
              'providerId': serviceId,
              'providerName': providerName,
              'providerImage': providerImage,
              'category': widget.category.name,
            },
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Provider Image
            Expanded(
              flex: 4, // Increased from 3 for larger image
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Container(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: providerImage != null && providerImage.isNotEmpty
                      ? Image.network(
                          providerImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.person,
                            size: 48,
                            color: Theme.of(context).primaryColor,
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: 48,
                          color: Theme.of(context).primaryColor,
                        ),
                ),
              ),
            ),
            
            // Provider Info
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // Minimize vertical space
                children: [
                  // Provider Name
                  Text(
                    providerName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 2), // Minimal spacing
                  
                  // Rating Stars
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < rating.floor() ? Icons.star : Icons.star_border,
                        size: 14,
                        color: Colors.amber,
                      );
                    }),
                  ),
                ],
              ),
            ),
            
            // Book Button
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: ElevatedButton(
                onPressed: () {
                  // For multi-service categories, navigate to Select Services
                  if (CategoryHelpers.isMultiServiceCategory(widget.category.name)) {
                    Navigator.pushNamed(
                      context,
                      '/select-services',
                      arguments: {
                        'providerId': serviceId,
                        'providerName': providerName,
                        'providerImage': providerImage,
                        'category': widget.category.name,
                      },
                    );
                  } else {
                    // For other categories, use direct booking
                    Navigator.pushNamed(
                      context,
                      BookServiceScreen.routeName,
                      arguments: {
                        'serviceName': serviceName,
                        'providerName': providerName,
                        'providerId': providerId,
                        'providerImage': providerImage,
                        'ratePerKm': (data['ratePerKm'] ?? 0).toDouble(),
                        'minBookingAmount': (data['price'] ?? 0).toDouble(),
                        'preBookingAmount': (data['preBookingAmount'] ?? 0).toDouble(),
                      },
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // Green background
                  foregroundColor: Colors.white, // White text
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Book Now'),
              ),
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
