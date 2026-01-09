import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/gift_provider.dart';
import '../widgets/gift_card.dart';
import '../providers/theme_provider.dart';
import '../providers/cart_provider.dart';
import '../screens/cart_screen.dart';
import '../widgets/product_card.dart';
import '../widgets/more_bottom_sheet.dart';
import '../models/product_model.dart';
import '../services/recommendation_service.dart';
import '../utils/currency.dart';
import '../screens/product_detail_screen.dart';

class CategoryProductsScreen extends StatefulWidget {
  static const routeName = '/category-products';

  const CategoryProductsScreen({super.key});

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  String? _selectedGiftFilter;
  final int _currentNavIndex = 0;

  // Gift filters
  final List<Map<String, dynamic>> _giftFilters = [
    {'label': 'All Gifts', 'value': null, 'icon': Icons.card_giftcard},
    {'label': 'Birthday', 'value': 'Birthday', 'icon': Icons.cake},
    {'label': 'Anniversary', 'value': 'Anniversary', 'icon': Icons.favorite},
    {'label': 'Wedding', 'value': 'Wedding', 'icon': Icons.celebration},
    {'label': 'Kids', 'value': 'Kids', 'icon': Icons.child_care},
    {'label': 'Corporate', 'value': 'Corporate', 'icon': Icons.business_center},
  ];

  void _onNavTapped(int index) async {
    if (index == 3) {
      // Show More bottom sheet
      await showMoreBottomSheet(context);
      return;
    }
    // For other tabs, just navigate back to home and switch tab
    if (index != _currentNavIndex) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the category name from route arguments
    final categoryName = ModalRoute.of(context)!.settings.arguments as String;
    final isGiftCategory = categoryName == 'Gifts';

    return Scaffold(
      appBar: AppBar(
        // Left: Back button (default)
        // Center: Category name
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
                onPressed: () => themeProvider.toggleTheme(),
                icon: Icon(
                  themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                splashColor: Colors.transparent,
                style: IconButton.styleFrom(overlayColor: Colors.transparent),
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
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                splashColor: Colors.transparent,
                style: IconButton.styleFrom(overlayColor: Colors.transparent),
              ),
              Positioned(
                right: 8,
                top: 10,
                child: Consumer<CartProvider>(
                  builder: (context, cart, _) {
                    final count = cart.itemCount;
                    return count > 0
                        ? Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          // Gift filters (only for Gifts category)
          if (isGiftCategory)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2.8,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _giftFilters.length,
                itemBuilder: (ctx, index) {
                  final filter = _giftFilters[index];
                  final isSelected = _selectedGiftFilter == filter['value'];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedGiftFilter = filter['value'] as String?;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            filter['icon'] as IconData,
                            size: 20,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            filter['label'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          // Products grid
          Expanded(
            child: isGiftCategory
                ? Consumer<GiftProvider>(
                    builder: (context, giftProvider, _) {
                      var gifts = giftProvider.gifts
                          .where((g) => g.isActive)
                          .toList();
                      if (_selectedGiftFilter != null) {
                        gifts = gifts
                            .where(
                              (g) =>
                                  (g.purpose ?? '').toLowerCase() ==
                                      _selectedGiftFilter!.toLowerCase() ||
                                  g.name.toLowerCase().contains(
                                    _selectedGiftFilter!.toLowerCase(),
                                  ) ||
                                  g.description.toLowerCase().contains(
                                    _selectedGiftFilter!.toLowerCase(),
                                  ),
                            )
                            .toList();
                      }
                      if (giftProvider.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (gifts.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.card_giftcard,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No gifts found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try another purpose filter',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.65,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemCount: gifts.length,
                        itemBuilder: (c, i) => GiftCard(gift: gifts[i]),
                      );
                    },
                  )
                : Consumer<ProductProvider>(
                    builder: (context, productProvider, _) {
                      print('DEBUG: checking against "${ProductCategory.hotDeals}"');
                      print('DEBUG: Total products in provider: ${productProvider.products.length}');
                      productProvider.products.take(5).forEach((p) {
                         print('DEBUG PROD: ${p.name} | isHotDeal: ${p.isHotDeal} | mrp: ${p.mrp} | price: ${p.price} | mrp>price: ${p.mrp > p.price}');
                      });

                      List<Product> categoryProducts;
                      if (categoryName.contains('Trending')) {
                        categoryProducts = List.from(productProvider.products)
                          ..sort((a, b) => (b.viewCount).compareTo(a.viewCount));
                      } else if (categoryName.trim() == ProductCategory.hotDeals) {
                        categoryProducts = productProvider.products
                            .where((p) => p.isHotDeal || (p.mrp > p.price))
                            .toList();
                        print('DEBUG: Hot Deals found: ${categoryProducts.length}');
                      } else if (categoryName == 'Customer Choices') {
                        categoryProducts = List.from(productProvider.products)
                            ..sort((a, b) => b.salesCount.compareTo(a.salesCount));
                      } else if (categoryName == '👁️ Recently Viewed') {
                        // Use RecommendationService for recently viewed
                        final recommendationService = Provider.of<RecommendationService>(context, listen: false);
                        // Ensure we have the list (it should be loaded by home, but good to check)
                        categoryProducts = recommendationService.recentlyViewed;
                        print('DEBUG: Recently Viewed products: ${categoryProducts.length}');
                      } else {
                        categoryProducts = productProvider.products
                            .where((product) => product.category == categoryName)
                            .toList();
                      }
                      if (productProvider.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (categoryProducts.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No products in this category',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Check back later!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.62, // Taller to accommodate text below image
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 16,
                            ),
                        itemCount: categoryProducts.length,
                        itemBuilder: (ctx, index) =>
                            _buildProductGridItem(categoryProducts[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: _onNavTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'HOME',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.design_services_outlined),
            activeIcon: Icon(Icons.design_services),
            label: 'SERVICES',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contact_page_outlined),
            activeIcon: Icon(Icons.contact_page),
            label: 'CONTACT',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            activeIcon: Icon(Icons.menu),
            label: 'MORE',
          ),
        ],
      ),
    );
  }
  Widget _buildProductGridItem(Product product) {
    // Logic copied from ProductCard but with different layout
    final hasDiscount = product.mrp > product.price;
    final discountPercent = hasDiscount 
        ? ((product.mrp - product.price) / product.mrp * 100).round() 
        : 0;

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          ProductDetailScreen.routeName,
          arguments: product,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image in Card
          Expanded(
            child: Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              margin: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10.0),
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.white,
                      child: Hero(
                        tag: 'cat-product-image-${product.id}',
                        child: Image.network(
                          (product.imageUrls != null && product.imageUrls!.isNotEmpty)
                              ? product.imageUrls!.first
                              : product.imageUrl,
                          fit: BoxFit.contain, // Contain to show full product
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                        ),
                      ),
                    ),
                    if (hasDiscount)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$discountPercent% OFF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Name
          Text(
            product.name,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Price and Cart below
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasDiscount)
                      Text(
                        formatINR(product.mrp),
                        style: const TextStyle(
                          fontSize: 9.0,
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    Text(
                      formatINR(product.price),
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                   context.read<CartProvider>().addProduct(product);
                   ScaffoldMessenger.of(context).hideCurrentSnackBar();
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(
                       content: Text('${product.name} added to cart'),
                       duration: const Duration(seconds: 1),
                     ),
                   );
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.add_shopping_cart,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
