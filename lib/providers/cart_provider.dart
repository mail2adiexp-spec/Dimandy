import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product_model.dart';

class CartItem {
  final Product product;
  int quantity;
  final Map<String, dynamic>? metadata;

  CartItem({
    required this.product, 
    this.quantity = 1,
    this.metadata,
  });

  double get totalPrice => product.price * quantity;

  Map<String, dynamic> toMap() => {
    'id': product.id,
    'sellerId': product.sellerId,
    'name': product.name,
    'description': product.description,
    'price': product.price,
    'imageUrl': product.imageUrl,
    'quantity': quantity,
    if (metadata != null) 'metadata': metadata,
  };

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      product: Product(
        id: map['id']?.toString() ?? '',
        sellerId: map['sellerId']?.toString() ?? '',
        name: map['name']?.toString() ?? 'Unknown Item',
        description: map['description']?.toString() ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        imageUrl: map['imageUrl']?.toString() ?? '',
      ),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      metadata: map['metadata'] is Map ? (map['metadata'] as Map).cast<String, dynamic>() : null,
    );
  }
}

class CartProvider extends ChangeNotifier {
  static const _storageKey = 'cart_v1';
  final Map<String, CartItem> _items = {};

  CartProvider() {
    // Defer async init to after construction
    Future.microtask(_init);
  }

  List<CartItem> get items => _items.values.toList(growable: false);
  int get itemCount =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);
  double get totalAmount =>
      _items.values.fold(0.0, (sum, item) => sum + item.totalPrice);
  bool get isEmpty => _items.isEmpty;

  void addProduct(Product product, {Map<String, dynamic>? metadata}) {
    debugPrint('CartProvider: addProduct called for ${product.id}');
    final id = product.id;
    
    // Services check: category is 'Services', unit is 'service', or ID starts with 'svc_'
    final isService = product.category == 'Services' || 
                      product.unit?.toLowerCase() == 'service' || 
                      product.id.startsWith('svc_');
    
    // Only check stock for actual products (not services)
    if (!isService && product.stock <= 0) {
      throw Exception('Product is out of stock');
    }
    
    if (_items.containsKey(id)) {
      // Only validate stock for products, not services
      if (!isService && _items[id]!.quantity + 1 > product.stock) {
        throw Exception('Only ${product.stock} items available in stock');
      }
      _items[id]!.quantity += 1;
    } else {
      _items[id] = CartItem(product: product, quantity: 1, metadata: metadata);
    }
    _persistAndNotify();
  }

  void removeOne(String productId) {
    if (!_items.containsKey(productId)) return;
    final item = _items[productId]!;
    if (item.quantity > 1) {
      item.quantity -= 1;
    } else {
      _items.remove(productId);
    }
    _persistAndNotify();
  }

  void removeProduct(String productId) {
    if (_items.remove(productId) != null) {
      _persistAndNotify();
    }
  }

  void clear() {
    _items.clear();
    _persistAndNotify();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data == null || data.isEmpty) return;
      final List list = jsonDecode(data) as List;
      _items
        ..clear()
        ..addEntries(
          list.map((e) {
            final item = CartItem.fromMap(Map<String, dynamic>.from(e as Map));
            return MapEntry(item.product.id, item);
          }),
        );
      notifyListeners();
    } catch (_) {
      // Ignore persistence errors
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _items.values.map((e) => e.toMap()).toList();
      await prefs.setString(_storageKey, jsonEncode(list));
    } catch (_) {
      // Ignore persistence errors
    }
  }

  void _persistAndNotify() {
    // Fire and forget
    _save();
    notifyListeners();
  }
}
