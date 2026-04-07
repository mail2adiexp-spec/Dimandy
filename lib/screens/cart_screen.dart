import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/currency.dart';
import 'checkout_screen.dart';
import 'auth_screen.dart';

class CartScreen extends StatelessWidget {
  static const routeName = '/cart';

  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) => Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Your Cart', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          actions: [
            if (!cart.isEmpty)
              TextButton(
                onPressed: () => _showClearDialog(context, cart),
                child: const Text('Clear', style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
        body: (cart.isEmpty && !cart.hasSavedItems)
            ? _buildEmptyState(context)
            : CustomScrollView(
                slivers: [
                  // Cart Items Section
                  if (!cart.items.isEmpty) ...[
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _CartItemTile(item: cart.items[i], isSaved: false),
                        childCount: cart.items.length,
                      ),
                    ),
                  ],

                  // Saved for Later Section
                  if (cart.hasSavedItems) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Text('Saved for Later', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _CartItemTile(item: cart.savedItems[i], isSaved: true),
                        childCount: cart.savedItems.length,
                      ),
                    ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 120)), // Space for bottom bar
                ],
              ),
        bottomNavigationBar: cart.isEmpty ? null : _buildBottomBar(context, cart),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('Your cart is empty', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Start Shopping'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, CartProvider cart) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('Total Amount', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                   Text(
                    formatINR(cart.totalAmount),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 50,
              width: 180,
              child: ElevatedButton(
                onPressed: () => _handleCheckout(context, cart),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Checkout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCheckout(BuildContext context, CartProvider cart) {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const AuthScreen(redirectRouteName: CheckoutScreen.routeName),
        ),
      );
    } else {
      Navigator.pushNamed(context, CheckoutScreen.routeName);
    }
  }

  void _showClearDialog(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Cart?'),
        content: const Text('This will remove all items from your cart.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              cart.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final bool isSaved;

  const _CartItemTile({required this.item, required this.isSaved});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final p = item.product;
    final isService = p.category == 'Services' || p.unit == 'service';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), // Slightly reduced from 20
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  p.imageUrl,
                  width: 90, // Slightly bigger image
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80, height: 80, color: Colors.grey[100],
                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), // Increased from 13
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatINR(p.price),
                      style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 15), // Increased from 13
                    ),
                    const SizedBox(height: 12),
                    if (!isSaved && !isService)
                      Center(child: _QuantityCounter(item: item, cart: cart, isService: isService)),
                  ],
                ),
              ),
              // Price (Total)
              if (!isSaved)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  formatINR(item.totalPrice),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17), // Increased from 14
                ),
              ),
            ],
          ),
          if (isService) ...[
            const SizedBox(height: 8),
            const Center(child: Text('Service Booking', style: TextStyle(fontSize: 13, color: Colors.grey))),
          ],
          const Divider(height: 20, thickness: 0.8), // Reduced from 24
          // Action Buttons
          Row(
            children: [
              if (!isSaved)
                _ActionButton(
                  icon: Icons.bookmark_border,
                  label: 'Save for later',
                  onTap: () => cart.saveForLater(p.id),
                ),
              if (isSaved)
                _ActionButton(
                  icon: Icons.shopping_cart_outlined,
                  label: 'Move to cart',
                  color: Colors.deepPurple,
                  onTap: () => cart.moveToCart(p.id),
                ),
              const Spacer(),
              _ActionButton(
                icon: Icons.delete_outline,
                label: 'Remove',
                color: Colors.red,
                onTap: () => isSaved ? cart.removeSaved(p.id) : cart.removeProduct(p.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityCounter extends StatelessWidget {
  final CartItem item;
  final CartProvider cart;
  final bool isService;

  const _QuantityCounter({required this.item, required this.cart, required this.isService});

  @override
  Widget build(BuildContext context) {
    if (isService) return const Text('Service Booking', style: TextStyle(fontSize: 12, color: Colors.grey));

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CountBtn(
            icon: Icons.remove,
            onTap: () {
              if (item.quantity > item.product.minimumQuantity) {
                cart.removeOne(item.product.id);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Minimum order: ${item.product.minimumQuantity}'))
                );
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16), // A bit more room
            child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), // Increased from default
          ),
          _CountBtn(
            icon: Icons.add,
            onTap: () async {
              try {
                await cart.addProduct(item.product);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red)
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _CountBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CountBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: Colors.black87),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.black54,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color), // Increased from 16
            const SizedBox(width: 6), // Increased from 4
            Text(label, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w500)), // Increased from 12
          ],
        ),
      ),
    );
  }
}
