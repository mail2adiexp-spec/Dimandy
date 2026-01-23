import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/service_category_provider.dart';
import '../models/service_category_model.dart';
import 'account_screen.dart';
import 'cart_screen.dart';
import 'book_service_screen.dart';
import 'category_service_providers_screen.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  ServiceCategory? _selectedCategory; // Keeping this for now if strictly needed, though we navigate away
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
        // Left: User icon
        leading: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            final user = auth.currentUser;
            return IconButton(
              tooltip: user != null ? 'Account (${user.name})' : 'Sign In',
              onPressed: () =>
                  Navigator.pushNamed(context, AccountScreen.routeName),
              icon: user?.photoURL != null
                  ? CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(user!.photoURL!),
                      key: ValueKey(user.photoURL),
                      backgroundColor: Colors.grey[200],
                    )
                  : const Icon(Icons.person),
            );
          },
        ),
        // Center: App name
        title: const Text(
          'Dimandy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        // Right: Theme toggle + Cart
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return IconButton(
                tooltip: themeProvider.isDarkMode ? 'Light Mode' : 'Dark Mode',
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
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for services...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
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
          // Scrollable content
          Expanded(
            child: Consumer<ServiceCategoryProvider>(
              builder: (context, serviceCategoryProvider, _) {
                final serviceCategories =
                    serviceCategoryProvider.serviceCategories;
                final isLoading = serviceCategoryProvider.isLoading;
                final error = serviceCategoryProvider.errorMessage;

                if (isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (error != null) {
                  final isPermission =
                      error.toLowerCase().contains('permission') ||
                      error.toLowerCase().contains('insufficient');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 64,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.6),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isPermission
                                ? 'Permission denied reading services'
                                : 'Error loading services',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isPermission
                                ? 'Please update Firestore rules to allow reads on service_categories, or sign in as admin.'
                                : error,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (serviceCategories.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.construction, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No services available yet',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Check back soon!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Filter categories based on search query
                final filteredCategories = _searchQuery.isEmpty
                    ? serviceCategories
                    : serviceCategories.where((category) {
                        return category.name.toLowerCase().contains(
                              _searchQuery,
                            ) ||
                            category.description.toLowerCase().contains(
                              _searchQuery,
                            );
                      }).toList();

                if (filteredCategories.isEmpty && _searchQuery.isNotEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No services found for "$_searchQuery"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                            },
                            child: const Text('Clear search'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => Provider.of<ServiceCategoryProvider>(
                    context,
                    listen: false,
                  ).refresh(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // Service Categories Grid
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 0.85,
                                    ),
                                itemCount: filteredCategories.length,
                                itemBuilder: (context, index) {
                                  final category = filteredCategories[index];
                                  final isSelected =
                                      _selectedCategory?.id == category.id;
                                  return _buildServiceCategoryCard(
                                    category: category,
                                    isSelected: isSelected,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCategoryCard({
    required ServiceCategory category,
    required bool isSelected,
  }) {
    final color = Color(int.parse(category.colorHex.replaceFirst('#', '0xFF')));
    final hasImage = category.imageUrl != null && category.imageUrl!.isNotEmpty;

    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          CategoryServiceProvidersScreen.routeName,
          arguments: category,
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.transparent,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: hasImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          category.imageUrl!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.broken_image, size: 40, color: color);
                          },
                        ),
                      )
                    : Icon(
                        Icons.design_services, 
                        size: 40, 
                        color: color
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            category.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
