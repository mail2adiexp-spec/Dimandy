import 'package:ecommerce_app/screens/main_navigation_screen.dart';
import 'package:ecommerce_app/widgets/more_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../models/gift_model.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../providers/theme_provider.dart';
import 'cart_screen.dart';

class GiftDetailScreen extends StatefulWidget {
  final Gift gift;

  const GiftDetailScreen({super.key, required this.gift});

  @override
  State<GiftDetailScreen> createState() => _GiftDetailScreenState();
}

class _GiftDetailScreenState extends State<GiftDetailScreen> {
  late PageController _pageController;
  int _currentIndex = 0; // For BottomNavigationBar

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    // Update the index to reflect the tap, even if we navigate away.
    // This prevents a potential state issue with the BottomNavigationBar.
    setState(() {
      _currentIndex = index;
    });

    if (index == 3) {
      // "More" tab
      showMoreBottomSheet(context);
      return;
    }
    
    // For other tabs, navigate to the main screen with the selected index.
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => MainNavigationScreen(initialIndex: index),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gift.name),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.gift.imageUrls != null &&
                widget.gift.imageUrls!.isNotEmpty)
              Column(
                children: [
                  SizedBox(
                    height: 250, // Fixed height for the image carousel
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: widget.gift.imageUrls!.length,
                      itemBuilder: (context, index) {
                        return Image.network(
                          widget.gift.imageUrls![index],
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            color: Colors.grey[200],
                            child:
                                const Icon(Icons.image_not_supported, size: 50),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: widget.gift.imageUrls!.length,
                    effect: const ExpandingDotsEffect(
                      activeDotColor: Colors.blue,
                      dotColor: Colors.grey,
                      dotHeight: 8,
                      dotWidth: 8,
                      spacing: 4,
                    ),
                  ),
                ],
              )
            else if (widget.gift.imageUrl != null &&
                widget.gift.imageUrl!.isNotEmpty)
              Center(
                child: Image.network(
                  widget.gift.imageUrl!,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported, size: 50),
                  ),
                ),
              )
            else
              Container(
                height: 200,
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.card_giftcard, size: 50),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              widget.gift.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Price: ₹${widget.gift.price.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 18, color: Colors.green),
            ),
            const SizedBox(height: 16),
            if (widget.gift.description != null &&
                widget.gift.description!.isNotEmpty)
              Text(
                widget.gift.description!,
                style: const TextStyle(fontSize: 16),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final cart =
                      Provider.of<CartProvider>(context, listen: false);
                  final productToAdd = Product(
                    id: widget.gift.id,
                    name: widget.gift.name,
                    description: widget.gift.description,
                    price: widget.gift.price,
                    imageUrl: widget.gift.imageUrl ?? '',
                    sellerId: '',
                  );
                  cart.addProduct(productToAdd);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${widget.gift.name} added to cart!'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Order Now'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
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
}