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
                  hintText: 'Search provider or location...',
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
          // Providers List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'service_provider')
                  .where('serviceCategoryId', isEqualTo: widget.category.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading providers',
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  );
                }

                final providers = snapshot.data?.docs ?? [];
                
                // Filter locally
                final filteredProviders = _searchQuery.isEmpty 
                    ? providers 
                    : providers.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['name'] ?? '').toString().toLowerCase();
                        final businessName = (data['businessName'] ?? '').toString().toLowerCase();
                        final district = (data['district'] ?? '').toString().toLowerCase();
                        return name.contains(_searchQuery) ||
                               businessName.contains(_searchQuery) ||
                               district.contains(_searchQuery);
                      }).toList();

                if (filteredProviders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty 
                              ? 'No service providers found'
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
                  itemCount: filteredProviders.length,
                  itemBuilder: (context, index) {
                    final data = filteredProviders[index].data() as Map<String, dynamic>;
                    return _buildProviderCard(context, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(BuildContext context, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Unknown';
    final businessName = data['businessName'] ?? name;
    final minCharge = (data['minCharge'] ?? widget.category.basePrice).toDouble();
    final district = data['district'] ?? '';
    final photoURL = data['photoURL'] as String?;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider Image
            ClipOval(
              child: Container(
                width: 60,
                height: 60,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: photoURL != null && photoURL.isNotEmpty
                    ? Image.network(
                        photoURL,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person,
                          size: 30,
                          color: Theme.of(context).primaryColor,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 30,
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
                  Text(
                    businessName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (district.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          district,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Starts from ₹${minCharge.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Book Button
            Column(
              children: [
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      BookServiceScreen.routeName,
                      arguments: {
                        'serviceName': widget.category.name,
                        'providerName': businessName,
                        'providerImage': photoURL,
                        'minCharge': minCharge >= 50 ? minCharge : 50.0,
                      },
                    );
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
