import 'package:ecommerce_app/widgets/search_results.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:ecommerce_app/screens/category_products_screen.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../providers/category_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/product_card.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import 'cart_screen.dart';
import 'account_screen.dart';
import '../services/recommendation_service.dart';
import '../widgets/marquee_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _searchController;
  String _searchQuery = '';
  String _sortBy = 'newest'; // newest, price_low, price_high
  List<Product> _trendingProducts = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(() {
        if (mounted) {
          setState(() {
            _searchQuery = _searchController.text.trim().toLowerCase();
          });
        }
      });
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    // Fetch recently viewed via provider
    context.read<RecommendationService>().fetchRecentlyViewed(limit: 6);
    
    // Trending still local for now, or could be moved to provider too
    final trending = await context.read<RecommendationService>().getTrendingProducts(limit: 8);
    if (mounted) {
      setState(() {
        _trendingProducts = trending;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Selected category filter (null = All)
  String? _selectedCategory;

  Future<void> _openCameraSearch() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analyzing image... 🔍'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final inputImage = InputImage.fromFilePath(photo.path);
      final options = ImageLabelerOptions(confidenceThreshold: 0.5);
      final imageLabeler = ImageLabeler(options: options);

      final labels = await imageLabeler.processImage(inputImage);
      imageLabeler.close();

      if (labels.isNotEmpty && mounted) {
        final topLabel = labels.first.label;
        setState(() {
          _searchController.text = topLabel;
          _searchQuery = topLabel.toLowerCase();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found: $topLabel')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not identify object. Try closer.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    List<Product> source = productProvider.products;
    // Apply category filter
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      source = source.where((p) => p.category == _selectedCategory).toList();
    }
    // Apply search filter
    var filteredProducts = _searchQuery.isEmpty
        ? source
        : source.where((p) {
            return p.name.toLowerCase().contains(_searchQuery) ||
                p.description.toLowerCase().contains(_searchQuery) ||
                (p.category?.toLowerCase().contains(_searchQuery) ?? false);
          }).toList();
    
    // Apply sorting
    if (_sortBy == 'price_low') {
      filteredProducts.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortBy == 'price_high') {
      filteredProducts.sort((a, b) => b.price.compareTo(a.price));
    } else {
      // newest (default) - already sorted by Firestore
    }

    final bool isSearching = _searchQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        toolbarHeight: 51,
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
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
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
                // remove tooltip to avoid hover popup on web
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
      body: productProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Fixed Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Container(
                    height: 38,
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
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        hintStyle: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withOpacity(0.6),
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => _searchController.clear(),
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            IconButton(
                              icon: const Icon(Icons.camera_alt, size: 18),
                              onPressed: _openCameraSearch,
                              tooltip: 'Search by image',
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 38,
                        ),
                      ),
                    ),
                  ),
                ),
                // Scrollable content
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      if (isSearching)
                        SearchResults(
                          products: filteredProducts,
                          onClear: () => _searchController.clear(),
                        )
                      else ...[

                        // Free Delivery Marquee
                        // Dynamic Free Delivery Marquee
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('app_settings').doc('general').snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || !snapshot.data!.exists) {
                              return const SliverToBoxAdapter(child: SizedBox.shrink());
                            }

                            final data = snapshot.data!.data() as Map<String, dynamic>?;
                            final isEnabled = data?['isAnnouncementEnabled'] as bool? ?? false;
                            final message = data?['announcementText'] as String? ?? '';

                            if (!isEnabled || message.isEmpty) {
                              return const SliverToBoxAdapter(child: SizedBox.shrink());
                            }

                            return SliverToBoxAdapter(
                            child: Container(
                              margin: EdgeInsets.zero,
                              height: 22,
                              color: Colors.transparent,
                              child: MarqueeWidget(
                                stepSize: 1.0,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 50),
                                  child: Row(
                                    children: [
                                      Text(
                                        message,
                                        style: const TextStyle(
                                          color: Color(0xFFE65100),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                          },
                        ),
                        // Recently Viewed Section
                        SliverToBoxAdapter(
                          child: Consumer<RecommendationService>(
                            builder: (context, recommendationService, _) {
                              return _buildProductCarousel(
                                context,
                                '👁️ Recently Viewed',
                                recommendationService.recentlyViewed,
                                sectionHeight: 180,
                                cardWidth: 140,
                              );
                            },
                          ),
                        ),

                        // Category grid
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: Builder(
                              builder: (context) {
                                if (categoryProvider.isLoading) {
                                  return const SizedBox(
                                    height: 100,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                if (categoryProvider.categories.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'No categories found. Add categories from Admin Panel.',
                                      style: TextStyle(color: Colors.grey[600]),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                }

                                // Show only first 9 categories
                                final displayCategories =
                                    categoryProvider.categories.length > 9
                                    ? categoryProvider.categories
                                          .take(9)
                                          .toList()
                                    : categoryProvider.categories;
                                final hasMore =
                                    categoryProvider.categories.length > 9;

                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GridView.count(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      crossAxisCount: 3,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 4,
                                      childAspectRatio: 0.95,
                                      children: [
                                        ...displayCategories.map(
                                          (cat) => _buildCategoryCard(
                                            cat.name,
                                            cat.name,
                                            cat.imageUrl,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (hasMore) ...[
                                      const SizedBox(height: 16),
                                      Center(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                  'All Categories',
                                                ),
                                                content: SizedBox(
                                                  width: double.maxFinite,
                                                  child: GridView.count(
                                                    shrinkWrap: true,
                                                    crossAxisCount: 3,
                                                    mainAxisSpacing: 12,
                                                    crossAxisSpacing: 8,
                                                    childAspectRatio: 0.85,
                                                    children: [
                                                      ...categoryProvider
                                                          .categories
                                                          .map(
                                                            (cat) =>
                                                                _buildCategoryCard(
                                                                  cat.name,
                                                                  cat.name,
                                                                  cat.imageUrl,
                                                                ),
                                                          ),
                                                    ],
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: const Text('Close'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.grid_view),
                                          label: const Text(
                                            'View All Categories',
                                          ),
                                        ),
                                      ),
                                    ],

                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        // Trending Products Section (Logic: Most Viewed)
                        if (productProvider.products.any((p) => p.viewCount > 0))
                          SliverToBoxAdapter(
                            child: _buildProductCarousel(
                              context,
                              '🔥 Trending Now',
                              (productProvider.products.where((p) => p.viewCount > 0).toList()
                                ..sort((a, b) => b.viewCount.compareTo(a.viewCount)))
                                .take(10)
                                .toList(),
                            ),
                          ),
                          
                        // Daily Needs horizontal carousel
                        if (productProvider.products.any((p) => p.category == 'Daily Needs'))
                          SliverToBoxAdapter(
                            child: _buildProductCarousel(
                              context,
                              'Daily Needs',
                              productProvider.products
                                  .where((p) => p.category == 'Daily Needs')
                                  .toList(),
                            ),
                          ),
                          
                        // Customer Choices (Logic: Top selling products)
                        // Sort by salesCount descending and take top 10
                         if (productProvider.products.any((p) => p.salesCount > 0)) ...[
                           SliverToBoxAdapter(
                            child: _buildProductCarousel(
                              context,
                              'Customer Choices',
                              (productProvider.products.where((p) => p.salesCount > 0).toList()
                                ..sort((a, b) => b.salesCount.compareTo(a.salesCount)))
                                .take(10)
                                .toList(),
                            ),
                          ),
                         ],
                          
                        // Hot Deals Banner & Section (Logic: isHotDeal == true OR mrp > price)
                        if (productProvider.products.any((p) => p.isHotDeal || (p.mrp > p.price && p.mrp > 0))) ...[
                           SliverToBoxAdapter(child: const SizedBox(height: 16)),
                           SliverToBoxAdapter(
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.pushNamed(
                                            context,
                                            CategoryProductsScreen.routeName,
                                            arguments: ProductCategory.hotDeals,
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 20,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFFFF7043),
                                                  Color(0xFFE53935),
                                                ],
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: const [
                                                    Icon(Icons.local_fire_department, color: Colors.white, size: 24),
                                                    SizedBox(width: 8),
                                                    Text('HOT DEALS', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                                                    SizedBox(width: 8),
                                                    Icon(Icons.local_fire_department, color: Colors.white, size: 24),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                const Text('Grab amazing offers today!', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                           ),
                           SliverToBoxAdapter(
                              child: _buildProductCarousel(
                                context,
                                'Hot Deals',
                                productProvider.products
                                    .where((p) => p.isHotDeal || (p.mrp > p.price && p.mrp > 0))
                                    .toList(),
                              ),
                           ),
                        ],
                        // Gift Finder Banner
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            child: InkWell(
                              onTap: () {
                                // Navigate to gifts category page
                                Navigator.pushNamed(
                                  context,
                                  CategoryProductsScreen.routeName,
                                  arguments: ProductCategory.gifts,
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 24,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFE91E63), // pink
                                      Color(0xFF9C27B0), // purple
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.card_giftcard,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Text(
                                            'Gift Finder',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Find the perfect gift for your loved ones',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Snacks Carousel
                        SliverToBoxAdapter(
                          child: _buildProductCarousel(
                            context,
                            'Snacks',
                            productProvider.products
                                .where((p) => p.category == 'Snacks')
                                .toList(),
                          ),
                        ),
                        // Products grid
                        filteredProducts.isEmpty
                            ? SliverFillRemaining(
                                child: Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.travel_explore,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                       _selectedCategory == null &&
                                                _searchQuery.isEmpty
                                            ? 'No products yet'
                                            : 'No matching products found',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[800],
                                        letterSpacing: 0.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try checking your spelling or use different keywords.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        height: 1.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 32),
                                    if (_searchQuery.isNotEmpty)
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _searchController.clear(),
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Clear Search'),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            side: BorderSide(color: Colors.grey[300]!),
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
                              )
                            : SliverPadding(
                                padding: const EdgeInsets.all(10.0),
                                sliver: SliverGrid(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        childAspectRatio: 0.75, // Ajusted to prevent cropping/overflow
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                      ),
                                  delegate: SliverChildBuilderDelegate(
                                    (ctx, i) => ProductCard(
                                      product: filteredProducts[i],
                                    ),
                                    childCount: filteredProducts.length,
                                  ),
                                ),
                              ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCategoryCard(
    String label,
    String? categoryValue,
    String imagePathOrUrl,
  ) {
    final isSelected = _selectedCategory == categoryValue;
    final isNetworkImage = imagePathOrUrl.startsWith('http');

    return Column(
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              // Navigate to category products screen
              Navigator.pushNamed(
                context,
                CategoryProductsScreen.routeName,
                arguments: categoryValue,
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(0.0),
                child: isNetworkImage
                    ? Image.network(
                        imagePathOrUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.category,
                            size: 32,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          );
                        },
                      )
                    : Image.asset(
                        imagePathOrUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.category,
                            size: 32,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          );
                        },
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildProductCarousel(
    BuildContext context,
    String title,
    List<Product> products, {
    double sectionHeight = 240,
    double cardWidth = 160,
  }) {
    if (products.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    letterSpacing: 0.5,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      CategoryProductsScreen.routeName,
                      arguments: title,
                    );
                  },
                  child: const Text('View All', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
          height: sectionHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: products.length > 10 ? 10 : products.length,
              itemBuilder: (context, index) {
                return Container(
                  width: cardWidth,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: ProductCard(
                    product: products[index],
                    heroTagPrefix: '${title.replaceAll(' ', '-')}-',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
