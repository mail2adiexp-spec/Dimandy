import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    'basePrice': product.basePrice,
    'imageUrl': product.imageUrl,
    'quantity': quantity,
    'stock': product.stock, // Added stock
    'storeIds': product.storeIds,
    'adminProfitPercentage': product.adminProfitPercentage,
    'deliveryFeeOverride': product.deliveryFeeOverride,
    if (metadata != null) 'metadata': metadata,
  };

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      product: Product(
        id: map['id']?.toString() ?? '',
        sellerId: map['sellerId']?.toString() ?? '',
        name: map['name']?.toString() ?? 'Unknown Item',
        description: map['description']?.toString() ?? '',
        price: double.parse(((map['price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)),
        basePrice: double.parse(((map['basePrice'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)),
        imageUrl: map['imageUrl']?.toString() ?? '',
        stock: (map['stock'] as num?)?.toInt() ?? 0, // Restore stock
        storeIds: List<String>.from(map['storeIds'] ?? []),
        adminProfitPercentage: (map['adminProfitPercentage'] as num?)?.toDouble(),
        deliveryFeeOverride: (map['deliveryFeeOverride'] as num?)?.toDouble(),
      ),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      metadata: map['metadata'] is Map ? (map['metadata'] as Map).cast<String, dynamic>() : null,
    );
  }
}

class CartProvider extends ChangeNotifier {
  static const _storageKey = 'cart_v1';
  final Map<String, CartItem> _items = {};
  final Map<String, CartItem> _savedItems = {};
  final Map<String, bool> _addingMutex = {};

  CartProvider() {
    // Defer async init to after construction
    Future.microtask(_init);
  }

  List<CartItem> get items => _items.values.toList(growable: false);
  List<CartItem> get savedItems => _savedItems.values.toList(growable: false);
  int get itemCount =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);
  double get totalAmount =>
      _items.values.fold(0.0, (sum, item) => sum + item.totalPrice);
  bool get isEmpty => _items.isEmpty;
  bool get hasSavedItems => _savedItems.isNotEmpty;

  Future<void> addProduct(Product product, {int quantityToAdd = 1, Map<String, dynamic>? metadata}) async {
    debugPrint('CartProvider: addProduct called for ${product.id}');
    final id = product.id;
    String getBaseProductId(String productId) {
      final suffixes = ['_100g', '_250g', '_500g', '_1kg', '_2kg', '_5kg'];
      for (final suffix in suffixes) {
        if (productId.endsWith(suffix)) {
          return productId.substring(0, productId.length - suffix.length);
        }
      }
      return productId;
    }
    final baseProductId = getBaseProductId(id);
    
    // Services check: category is 'Services', unit is 'service', or ID starts with 'svc_'
    final isService = product.category == 'Services' || 
                      product.unit?.toLowerCase() == 'service' || 
                      product.id.startsWith('svc_');
    
    // Only check stock for actual products (not services)
    if (!isService) {
      // Mutex lock to prevent race conditions on rapid taps
      while (_addingMutex[baseProductId] == true) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      _addingMutex[baseProductId] = true;

      try {
        DocumentSnapshot? doc;
        // Try fetching base product first
        doc = await FirebaseFirestore.instance.collection('products').doc(baseProductId).get();
        
        // If base not found and it's different from full ID, try fetching full ID
        if (!doc.exists && baseProductId != id) {
           doc = await FirebaseFirestore.instance.collection('products').doc(id).get();
        }

        int remoteStock = product.stock; // Fallback to passed stock

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null) {
            remoteStock = (data['stock'] as num?)?.toInt() ?? 0;
          }
        }
        
        if (remoteStock <= 0) {
          throw Exception('Product is out of stock');
        }

        // --- ENFORCE MAXIMUM QUANTITY ---
        if (product.maximumQuantity > 0) {
           // Calculate total quantity of THIS BASE PRODUCT already in cart (including variants)
           int totalBaseQtyInCart = 0;
           for (var item in _items.values) {
              final itemBaseId = getBaseProductId(item.product.id);
              if (itemBaseId == baseProductId) {
                 totalBaseQtyInCart += item.quantity;
              }
           }
           
           if (totalBaseQtyInCart + quantityToAdd > product.maximumQuantity) {
              throw Exception('You can only purchase a maximum of ${product.maximumQuantity} units of this item');
           }
        }
        // --------------------------------
        
        // Calculate total quantity for STOCK check
        int totalBaseQtyInCart = 0;
        for (var item in _items.values) {
           final itemBaseId = getBaseProductId(item.product.id);
           if (itemBaseId == baseProductId) {
              totalBaseQtyInCart += item.quantity;
           }
        }

        if (totalBaseQtyInCart + quantityToAdd > remoteStock) {
          throw Exception('Only $remoteStock items available in stock');
        }
        
        _addingMutex[baseProductId] = false;
      } catch (e) {
         _addingMutex[baseProductId] = false;
         if (e.toString().contains('stock') || e.toString().contains('maximum')) {
           throw Exception(e.toString().replaceAll('Exception: ', ''));
         }
         // If it's just a 'not found' or network error, we might still want to allow adding if local stock > 0
         // but user explicitly complained about Stock check, so we should be careful.
         // Given the "Product not found" error was annoying, I'll let it use product.stock as fallback.
         debugPrint('Stock check failed: $e. Using local stock: ${product.stock}');
         if (product.stock <= 0) {
            throw Exception('Product is out of stock');
         }
      }
    }
    
    if (_items.containsKey(id)) {
      _items[id]!.quantity += quantityToAdd;
    } else {
      _items[id] = CartItem(product: product, quantity: quantityToAdd, metadata: metadata);
    }
    
    if (!isService) {
      _addingMutex[baseProductId] = false;
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
    _savedItems.clear();
    _persistAndNotify();
  }

  void saveForLater(String productId) {
    if (!_items.containsKey(productId)) return;
    _savedItems[productId] = _items.remove(productId)!;
    _persistAndNotify();
  }

  void moveToCart(String productId) {
    if (!_savedItems.containsKey(productId)) return;
    _items[productId] = _savedItems.remove(productId)!;
    _persistAndNotify();
  }

  void removeSaved(String productId) {
    if (_savedItems.remove(productId) != null) {
      _persistAndNotify();
    }
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load Cart Items
      final cartData = prefs.getString(_storageKey);
      if (cartData != null && cartData.isNotEmpty) {
        final List list = jsonDecode(cartData) as List;
        _items.clear();
        for (var e in list) {
          final item = CartItem.fromMap(Map<String, dynamic>.from(e as Map));
          _items[item.product.id] = item;
        }
      }

      // Load Saved Items
      final savedData = prefs.getString('${_storageKey}_saved');
      if (savedData != null && savedData.isNotEmpty) {
        final List list = jsonDecode(savedData) as List;
        _savedItems.clear();
        for (var e in list) {
          final item = CartItem.fromMap(Map<String, dynamic>.from(e as Map));
          _savedItems[item.product.id] = item;
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('CartProvider: Error loading cart from storage: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final cartList = _items.values.map((e) => e.toMap()).toList();
      await prefs.setString(_storageKey, jsonEncode(cartList));

      final savedList = _savedItems.values.map((e) => e.toMap()).toList();
      await prefs.setString('${_storageKey}_saved', jsonEncode(savedList));
    } catch (e) {
      debugPrint('CartProvider: Error saving cart to storage: $e');
    }
  }

  void _persistAndNotify() {
    // Fire and forget
    _save();
    notifyListeners();
  }
}
