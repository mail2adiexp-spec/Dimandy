import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/currency.dart';
import '../screens/cart_screen.dart';
import '../widgets/more_bottom_sheet.dart';
import '../services/recommendation_service.dart';

class ProductDetailScreen extends StatefulWidget {
  static const routeName = '/product';

  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;
  int _currentNavIndex = 0;
  int _quantity = 1;
  List<Product> _recommendedProducts = [];

  List<String> get _images {
    final imgs = widget.product.imageUrls;
    if (imgs != null && imgs.isNotEmpty) return imgs;
    return [widget.product.imageUrl];
  }

  void _onNavTapped(int index) async {
    if (index == 3) {
      // Show More bottom sheet
      await showMoreBottomSheet(context);
      return;
    }
    // For other tabs, navigate back to home
    if (index != _currentNavIndex) {
      Navigator.pop(context);
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _quantity = widget.product.minimumQuantity > 0 ? widget.product.minimumQuantity : 1;
    _trackView();
    _loadRecommendations();
  }

  void _trackView() {
    context.read<RecommendationService>().trackProductView(widget.product.id);
    // Increment simple view count for Trending logic
    try {
       FirebaseFirestore.instance.collection('products').doc(widget.product.id).update({
         'viewCount': FieldValue.increment(1),
       });
    } catch (e) {
      debugPrint('Error incrementing view count: $e');
    }
  }

  Future<void> _loadRecommendations() async {
    final recommendations = await context.read<RecommendationService>()
        .getSimilarProducts(widget.product, limit: 4);
    if (mounted) {
      setState(() {
        _recommendedProducts = recommendations;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dimandy',
          style: TextStyle(fontWeight: FontWeight.bold),
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 200),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Image Carousel - Smaller
            AspectRatio(
              aspectRatio: 1.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: _images.length,
                      onPageChanged: (i) => setState(() => _currentIndex = i),
                      itemBuilder: (context, index) {
                        return Image.network(
                          _images[index],
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                                child: Icon(Icons.broken_image, size: 40),
                              ),
                        );
                      },
                    ),
                    if (_images.length > 1)
                      Positioned(
                        bottom: 4,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _images.length,
                            (i) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: _currentIndex == i ? 6 : 4,
                              height: _currentIndex == i ? 6 : 4,
                              decoration: BoxDecoration(
                                color: _currentIndex == i
                                    ? Colors.white
                                    : Colors.white70,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Product Name - Smaller
            Text(
              product.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Price & Dropdown Row
            Row(
              children: [
                Text(
                  _formatPriceWithUnit(product),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
                if (_isWeightBased(product)) ...[
                  const SizedBox(width: 12),
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<_WeightVariant>(
                        value: _selectedWeightVariant,
                        isDense: true,
                        hint: const Text('Weight', style: TextStyle(fontSize: 12)),
                        items: _weightVariants.map((variant) {
                          return DropdownMenuItem(
                            value: variant,
                            child: Text(
                              variant.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (variant) {
                          if (variant != null) {
                            setState(() {
                              _selectedWeightVariant = variant;
                              _quantity = 1;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Standard Quantity Counter (Only if NOT weight based)
            if (!_isWeightBased(product)) ...[
              Row(
                children: [
                   Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () {
                            if (_quantity > widget.product.minimumQuantity) {
                              setState(() => _quantity--);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Minimum quantity is ${widget.product.minimumQuantity}'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                        ),
                        Text(
                          '$_quantity',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () {
                            setState(() => _quantity++);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 16),

            // Add to Cart Button (Updated logic)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_isWeightBased(product)) {
                     _addToCartWeightBased();
                  } else {
                     _addToCartStandard();
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_shopping_cart, size: 20),
                label: Text(
                  _isWeightBased(product) 
                      ? 'Add ${_selectedWeightVariant!.label} to Cart - ${formatINR(product.price * _selectedWeightVariant!.multiplier)}'
                      : 'Add to Cart', 
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Description - Very compact
            Row(
              children: [
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Product Description'),
                        content: SingleChildScrollView(
                          child: Text(
                            product.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('View Full', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            Text(
              product.description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Recommended Products - Compact
            if (_recommendedProducts.isNotEmpty) ...[
              Row(
                children: [
                  const Text(
                    'You May Also Like',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recommendedProducts.length,
                  itemBuilder: (ctx, i) {
                    final prod = _recommendedProducts[i];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => ProductDetailScreen(
                              product: prod,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 8),
                        child: Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                  child: (prod.imageUrl.isNotEmpty)
                                      ? Image.network(
                                          prod.imageUrl,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => const Icon(
                                            Icons.broken_image,
                                            size: 24,
                                            color: Colors.grey,
                                          ),
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.image_not_supported,
                                            size: 24,
                                            color: Colors.grey,
                                          ),
                                        ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      prod.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      formatINR(prod.price),
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  String _formatPriceWithUnit(Product p) {
    if (_isWeightBased(p) && _selectedWeightVariant != null) {
      // Show dynamic price for selected variant
      return formatINR(p.price * _selectedWeightVariant!.multiplier); 
    }
    final price = formatINR(p.price);
    if (p.unit == null || p.unit!.isEmpty) return price;
    return '$price / ${p.unit}';
  }

  // --- Weight Variant Logic ---

  bool _isWeightBased(Product p) {
    return p.unit?.trim().toLowerCase() == 'kg' || p.unit?.trim().toLowerCase() == 'kilogram';
  }

  // Define variants
  final List<_WeightVariant> _weightVariants = [
    _WeightVariant('100 g', 0.1, '_100g'),
    _WeightVariant('250 g', 0.25, '_250g'),
    _WeightVariant('500 g', 0.5, '_500g'),
    _WeightVariant('1 Kg', 1.0, '_1kg'),
    _WeightVariant('2 Kg', 2.0, '_2kg'),
    _WeightVariant('5 Kg', 5.0, '_5kg'),
  ];
  
  _WeightVariant? _selectedWeightVariant;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set default variant if not set (e.g. 1 Kg)
    if (_selectedWeightVariant == null && _isWeightBased(widget.product)) {
      _selectedWeightVariant = _weightVariants.firstWhere((v) => v.multiplier == 1.0, orElse: () => _weightVariants.last);
    }
  }

  void _addToCartStandard() {
    if (_quantity < widget.product.minimumQuantity) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Minimum quantity required is ${widget.product.minimumQuantity}'),
           backgroundColor: Colors.red,
         ),
       );
       return;
    }
    final cart = context.read<CartProvider>();
    try {
      for (int i = 0; i < _quantity; i++) {
        cart.addProduct(widget.product);
      }
      _showSuccessMsg('Added $_quantity item(s) to cart');
      setState(() => _quantity = widget.product.minimumQuantity > 0 ? widget.product.minimumQuantity : 1);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addToCartWeightBased() {
    if (_selectedWeightVariant == null) return;
    
    final variant = _selectedWeightVariant!;
    // Create virtual product
    final virtualProduct = Product(
      id: '${widget.product.id}${variant.idSuffix}',
      sellerId: widget.product.sellerId,
      name: '${widget.product.name} (${variant.label})',
      description: widget.product.description,
      price: widget.product.price * variant.multiplier,
      basePrice: widget.product.basePrice * variant.multiplier,
      imageUrl: widget.product.imageUrl,
      imageUrls: widget.product.imageUrls,
      category: widget.product.category,
      unit: 'Pack', // Now it's a pack of that weight
      mrp: widget.product.mrp * variant.multiplier,
      isFeatured: widget.product.isFeatured,
      stock: widget.product.stock, // Warning: Shared stock
      storeIds: widget.product.storeIds,
    );

    final cart = context.read<CartProvider>();
    try {
      cart.addProduct(virtualProduct);
      _showSuccessMsg('Added ${variant.label} pack to cart');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

class _WeightVariant {
  final String label;
  final double multiplier;
  final String idSuffix;

  _WeightVariant(this.label, this.multiplier, this.idSuffix);
}
