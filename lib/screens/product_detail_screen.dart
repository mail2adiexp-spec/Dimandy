import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/currency.dart';
import '../screens/cart_screen.dart';
import '../screens/checkout_screen.dart';
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
  double _quantity = 1.0;
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
    _quantity = widget.product.minimumQuantity > 0 ? widget.product.minimumQuantity : 1.0;
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
        .getSimilarProducts(widget.product, limit: 18);
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
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                if (product.mrp > product.price) ...[
                  const SizedBox(width: 8),
                  Text(
                    formatINR(product.mrp),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${((product.mrp - product.price) / product.mrp * 100).round()}% OFF',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
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
                          _quantity % 1 == 0 ? _quantity.toInt().toString() : _quantity.toStringAsFixed(2),
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
                            // Enforce Maximum Quantity if set (> 0)
                            if (widget.product.maximumQuantity > 0 && _quantity >= widget.product.maximumQuantity) {
                               ScaffoldMessenger.of(context).hideCurrentSnackBar();
                               ScaffoldMessenger.of(context).showSnackBar(
                                 SnackBar(
                                   content: Text('Maximum quantity is ${widget.product.maximumQuantity}'),
                                   backgroundColor: Colors.orange,
                                   duration: const Duration(seconds: 1),
                                 ),
                               );
                               return;
                            }
                            
                            // If stock is limited, don't allow counter to exceed stock
                            if (_quantity < widget.product.stock) {
                              setState(() => _quantity++);
                            } else {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Only ${widget.product.stock} items available in stock'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            }
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
            // Action Buttons Row
            Row(
              children: [
                // Add to Cart Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.product.stock <= 0 
                      ? null 
                      : () {
                          if (_isWeightBased(product)) {
                             _addToCartWeightBased();
                          } else {
                             _addToCartStandard();
                          }
                        },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: widget.product.stock <= 0 ? Colors.grey : Colors.deepPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: Text(
                      widget.product.stock <= 0 ? 'Out of Stock' : 'To Cart',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Buy Now Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.product.stock <= 0 
                      ? null 
                      : () {
                          if (_isWeightBased(product)) {
                             _buyNowWeightBased();
                          } else {
                             _buyNowStandard();
                          }
                        },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: widget.product.stock <= 0 ? Colors.grey : Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.bolt, size: 18),
                    label: const Text(
                      'Buy Now',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'You May Also Like',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recommendedProducts.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
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
                    child: Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
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
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prod.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatINR(prod.price),
                                  style: const TextStyle(
                                    color: Colors.deepPurple,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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

  Future<void> _addToCartStandard() async {
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
      await cart.addProduct(widget.product, quantityToAdd: _quantity.round());
      if (mounted) {
        _showSuccessMsg('Added ${_quantity % 1 == 0 ? _quantity.toInt() : _quantity} item(s) to cart');
        setState(() => _quantity = widget.product.minimumQuantity > 0 ? widget.product.minimumQuantity : 1.0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addToCartWeightBased() async {
    if (_selectedWeightVariant == null) return;
    
    final variant = _selectedWeightVariant!;
    final virtualProduct = _createVirtualWeightProduct(variant);

    final cart = context.read<CartProvider>();
    try {
      await cart.addProduct(virtualProduct);
      if (mounted) {
        _showSuccessMsg('Added ${variant.label} pack to cart');
      }
    } catch (e) {
      _showErrorMsg(e.toString());
    }
  }

  // --- Buy Now Logic ---

  Future<void> _buyNowStandard() async {
    if (_quantity < widget.product.minimumQuantity) {
       _showErrorMsg('Minimum quantity required is ${widget.product.minimumQuantity}');
       return;
    }
    final cart = context.read<CartProvider>();
    try {
      await cart.addProduct(widget.product, quantityToAdd: _quantity.round());
      if (mounted) {
        Navigator.pushNamed(context, CheckoutScreen.routeName);
      }
    } catch (e) {
      _showErrorMsg(e.toString());
    }
  }

  Future<void> _buyNowWeightBased() async {
    if (_selectedWeightVariant == null) return;
    
    final variant = _selectedWeightVariant!;
    final virtualProduct = _createVirtualWeightProduct(variant);

    final cart = context.read<CartProvider>();
    try {
      await cart.addProduct(virtualProduct);
      if (mounted) {
        Navigator.pushNamed(context, CheckoutScreen.routeName);
      }
    } catch (e) {
      _showErrorMsg(e.toString());
    }
  }

  Product _createVirtualWeightProduct(_WeightVariant variant) {
    return Product(
      id: '${widget.product.id}${variant.idSuffix}',
      sellerId: widget.product.sellerId,
      name: '${widget.product.name} (${variant.label})',
      description: widget.product.description,
      price: double.parse((widget.product.price * variant.multiplier).toStringAsFixed(2)),
      basePrice: double.parse((widget.product.basePrice * variant.multiplier).toStringAsFixed(2)),
      imageUrl: widget.product.imageUrl,
      imageUrls: widget.product.imageUrls,
      category: widget.product.category,
      unit: 'Pack', 
      mrp: double.parse((widget.product.mrp * variant.multiplier).toStringAsFixed(2)),
      isFeatured: widget.product.isFeatured,
      stock: widget.product.stock, 
      storeIds: widget.product.storeIds,
      adminProfitPercentage: widget.product.adminProfitPercentage,
      deliveryFeeOverride: widget.product.deliveryFeeOverride != null ? double.parse((widget.product.deliveryFeeOverride! * variant.multiplier).toStringAsFixed(2)) : null,
      partnerPayoutOverride: widget.product.partnerPayoutOverride != null ? double.parse((widget.product.partnerPayoutOverride! * variant.multiplier).toStringAsFixed(2)) : null,
    );
  }

  void _showErrorMsg(String error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.replaceAll('Exception: ', '')),
        backgroundColor: Colors.red,
      ),
    );
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
