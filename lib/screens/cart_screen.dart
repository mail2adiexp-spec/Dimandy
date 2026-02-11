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
      builder: (_, cart, __) => Scaffold(
        appBar: AppBar(title: const Text('Your Cart')),
        body: cart.isEmpty
            ? const Center(child: Text('Your shopping cart is empty.'))
            : ListView.separated(
                padding: const EdgeInsets.only(
                  bottom: 100,
                  left: 12,
                  right: 12,
                  top: 12,
                ),
                itemCount: cart.items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final item = cart.items[i];
                  final p = item.product;
                  final isService = p.category == 'Services' || p.unit == 'service';
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        p.imageUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.image_not_supported),
                      ),
                    ),
                    title: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${formatINR(p.price)} x ${item.quantity} = ${formatINR(item.totalPrice)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isService)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              if (item.quantity > item.product.minimumQuantity) {
                                cart.removeOne(p.id);
                              } else {
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Minimum quantity is ${item.product.minimumQuantity}. Use delete to remove.'),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                        Text(item.quantity.toString()),
                        if (!isService)
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => cart.addProduct(p),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => cart.removeProduct(p.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        formatINR(cart.totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: cart.isEmpty
                      ? null
                      : () {
                          final auth = context.read<AuthProvider>();
                          if (!auth.isLoggedIn) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AuthScreen(
                                  redirectRouteName: CheckoutScreen.routeName,
                                ),
                              ),
                            );
                          } else {
                            Navigator.pushNamed(
                              context,
                              CheckoutScreen.routeName,
                            );
                          }
                        },
                  child: const Text('Proceed to Checkout'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
