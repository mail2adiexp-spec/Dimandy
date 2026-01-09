import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/gift_model.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../screens/gift_detail_screen.dart';

class GiftCard extends StatelessWidget {
  final Gift gift;
  const GiftCard({super.key, required this.gift});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GiftDetailScreen(gift: gift),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.2,
              child: gift.imageUrl != null && gift.imageUrl!.isNotEmpty
                  ? Image.network(
                      gift.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.card_giftcard, size: 40),
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            gift.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '₹${gift.price.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final cart = Provider.of<CartProvider>(
                            context,
                            listen: false,
                          );
                          final productToAdd = Product(
                            id: gift.id,
                            name: gift.name,
                            description: gift.description,
                            price: gift.price,
                            imageUrl: gift.imageUrl ?? '',
                            sellerId: '',
                          );
                          cart.addProduct(productToAdd);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${gift.name} added to cart!'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                        label: const Text('Order'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
