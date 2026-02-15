import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class ProductProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<Product> _products = [];
  bool _isLoading = false;
  bool _isFetchingMore = false;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  String? _currentCategory; // To track if we are viewing specific category

  bool get isLoading => _isLoading;
  bool get isFetchingMore => _isFetchingMore;
  bool get hasMore => _hasMore;
  List<Product> get products => [..._products];

  // Removed startListening since we use manual fetching

  Future<void> fetchProducts({bool refresh = false}) async {
    if (refresh) {
      _lastDocument = null;
      _products.clear();
      _hasMore = true;
      _currentCategory = null; // Reset category filter
    }

    if (!_hasMore) return;
    if (_isLoading || _isFetchingMore) return;

    if (refresh) {
      _isLoading = true;
      notifyListeners();
    } else {
      _isFetchingMore = true;
      notifyListeners(); // Optional: to show bottom loader
    }

    try {
      Query query = _firestore
          .collection('products')
          .orderBy('createdAt', descending: true)
          .limit(10);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        final newProducts = snapshot.docs.map((doc) {
           // Helper to handle data
           final data = doc.data() as Map<String, dynamic>;
           return Product.fromMap(doc.id, data);
        }).toList();

        _products.addAll(newProducts);
        
        if (snapshot.docs.length < 10) {
          _hasMore = false;
        }
      } else {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint('Error fetching products: $e');
    } finally {
      _isLoading = false;
      _isFetchingMore = false;
      notifyListeners();
    }
  }

  Future<void> fetchProductsByCategory(String category, {bool refresh = false}) async {
    if (refresh) {
      _lastDocument = null;
      _products.clear();
      _hasMore = true;
      _currentCategory = category;
    }

    if (_currentCategory != category && !refresh) {
       _lastDocument = null;
       _products.clear();
       _hasMore = true;
       _currentCategory = category;
    }

    if (!_hasMore) return;
    if (_isLoading || _isFetchingMore) return;

    if (refresh) {
      _isLoading = true;
      notifyListeners();
    } else {
      _isFetchingMore = true;
      notifyListeners();
    }

    try {
      Query query = _firestore.collection('products');

      // Handle Special Categories
      if (category == 'Trending') {
        query = query.orderBy('viewCount', descending: true);
      } else if (category == 'Hot Deals') {
        query = query.where('isHotDeal', isEqualTo: true).orderBy('createdAt', descending: true);
      } else if (category == 'Customer Choices') {
        query = query.orderBy('salesCount', descending: true);
      } else {
        // Standard Category
        query = query.where('category', isEqualTo: category).orderBy('createdAt', descending: true);
      }
      
      query = query.limit(10);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        final newProducts = snapshot.docs.map((doc) {
           final data = doc.data() as Map<String, dynamic>;
           return Product.fromMap(doc.id, data);
        }).toList();

        _products.addAll(newProducts);
        
        if (snapshot.docs.length < 10) {
          _hasMore = false;
        }
      } else {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint('Error fetching category products ($category): $e');
      // If error (e.g. missing index), stop fetching to avoid loops
      _hasMore = false;
    } finally {
      _isLoading = false;
      _isFetchingMore = false;
      notifyListeners();
    }
  }
  
  // No changes to CRUD methods
  Future<void> addProduct(Product product) async {
    try {
      await _firestore.collection('products').doc(product.id).set(product.toMap());
      // Optionally add to local list if it matches current view
      if (_currentCategory == null || _currentCategory == product.category) {
         _products.insert(0, product);
         notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProduct(String id, Product updatedProduct) async {
    try {
      final Map<String, dynamic> data = updatedProduct.toMap();
      data.remove('createdAt'); 
      await _firestore.collection('products').doc(id).update(data);
      
      final index = _products.indexWhere((p) => p.id == id);
      if (index >= 0) {
        _products[index] = updatedProduct;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _firestore.collection('products').doc(id).delete();
      _products.removeWhere((p) => p.id == id);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  List<Product> searchProducts(String query) {
    if (query.isEmpty) return products;
    final lowerQuery = query.toLowerCase();
    return _products.where((product) {
      return product.name.toLowerCase().contains(lowerQuery) ||
          product.description.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  // Deprecated/Modified: This now relies on what's currently loaded
  // If specific category view is active, it returns that.
  List<Product> getProductsByCategory(String category) {
    return _products.where((p) => p.category == category).toList();
  }
}
