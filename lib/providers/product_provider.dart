import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class ProductProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<Product> _products = [];
  final List<Product> _categoryProducts = []; 
  final Map<String, List<Product>> _sectionProducts = {}; // Improved: Store home screen sections separately
  bool _isLoading = false;
  bool _isFetchingMore = false;
  DocumentSnapshot? _lastDocument;
  DocumentSnapshot? _lastCategoryDocument; 
  bool _hasMore = true;
  bool _hasMoreCategory = true; 
  String? _currentCategory; 

  bool get isLoading => _isLoading;
  bool get isFetchingMore => _isFetchingMore;
  bool get hasMore => _hasMore;
  bool get hasMoreCategory => _hasMoreCategory; 
  List<Product> get products => [..._products];
  List<Product> get categoryProducts => [..._categoryProducts]; 
  
  // Get products for a specific home section
  List<Product> getSectionProducts(String sectionName) {
    final sectionList = _sectionProducts[sectionName] ?? [];
    if (sectionList.isNotEmpty) return [...sectionList];
    
    // Fallback: Filter from main products list if section-specific fetch failed/empty
    // (Crucial while Firestore indexes are building to prevent blank sections)
    if (sectionName == '🔥 Trending Now' || sectionName == 'Trending Now') {
      final trending = _products.where((p) => p.viewCount > 0).toList();
      trending.sort((a, b) => b.viewCount.compareTo(a.viewCount));
      return trending.take(10).toList();
    } else if (sectionName == 'Hot Deals') {
      return _products.where((p) => p.isHotDeal || (p.mrp > p.price && p.mrp > 0)).take(10).toList();
    } else if (sectionName == 'Customer Choices') {
      final choices = _products.where((p) => p.salesCount > 0).toList();
      choices.sort((a, b) => b.salesCount.compareTo(a.salesCount));
      return choices.take(10).toList();
    } else {
      // Standard category (e.g. Daily Needs, Snacks)
      return _products.where((p) => p.category == sectionName).take(10).toList();
    }
  }

  // Removed startListening since we use manual fetching

  Future<void> fetchProducts({bool refresh = false}) async {
    if (refresh) {
      _lastDocument = null;
      _hasMore = true;
      _currentCategory = null; 
    }

    if (!_hasMore) return;
    if (_isLoading || _isFetchingMore) return;

    if (refresh) {
      if (_products.isEmpty) {
        _isLoading = true;
        notifyListeners();
      }
    } else {
      _isFetchingMore = true;
      notifyListeners();
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

      if (refresh && snapshot.docs.isNotEmpty) {
        _products.clear();
      }

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
      _lastCategoryDocument = null;
      _categoryProducts.clear();
      _hasMoreCategory = true;
      _currentCategory = category;
    }

    if (_currentCategory != category && !refresh) {
       _lastCategoryDocument = null;
       _categoryProducts.clear();
       _hasMoreCategory = true;
       _currentCategory = category;
    }

    if (refresh) {
      _isLoading = true;
      notifyListeners();
    } else {
      if (!_hasMoreCategory) return;
      if (_isLoading || _isFetchingMore) return;
      _isFetchingMore = true;
      notifyListeners();
    }

    try {
      Query query = _firestore.collection('products');

      // Handle Special Categories
      // Handle Special Categories
      if (category == '🔥 Trending Now' || category == 'Trending Now' || category == 'Trending') {
        query = query.where('viewCount', isGreaterThan: 0).orderBy('viewCount', descending: true);
      } else if (category == 'Hot Deals') {
        // Query isHotDeal primarily. Local logic uses mrp > price too, 
        // but for Firestore we stick to a flag for performance/indexes.
        query = query.where('isHotDeal', isEqualTo: true).orderBy('createdAt', descending: true);
      } else if (category == 'Customer Choices') {
        query = query.where('salesCount', isGreaterThan: 0).orderBy('salesCount', descending: true);
      } else {
        // Standard Category
        query = query.where('category', isEqualTo: category).orderBy('createdAt', descending: true);
      }
      
      query = query.limit(10);

      if (_lastCategoryDocument != null) {
        query = query.startAfterDocument(_lastCategoryDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastCategoryDocument = snapshot.docs.last;
        final newProducts = snapshot.docs.map((doc) {
           final data = doc.data() as Map<String, dynamic>;
           return Product.fromMap(doc.id, data);
        }).toList();

        _categoryProducts.addAll(newProducts);
        
        if (snapshot.docs.length < 10) {
          _hasMoreCategory = false;
        }
      } else {
        _hasMoreCategory = false;
      }
    } catch (e) {
      debugPrint('Error fetching category products ($category): $e');
      
      // Fallback: If indexing is failing, try to populate from local list
      if (_categoryProducts.isEmpty) {
         final fallbackItems = getSectionProducts(category);
         if (fallbackItems.isNotEmpty) {
           _categoryProducts.addAll(fallbackItems);
           notifyListeners();
         }
      }

      if (e.toString().contains('index')) {
        debugPrint('TIP: This query might require a composite index in Firestore.');
      }
      // If error (e.g. missing index), stop fetching to avoid loops
      _hasMoreCategory = false;
    } finally {
      _isLoading = false;
      _isFetchingMore = false;
      notifyListeners();
    }
  }

  // Specialized fetch for Home Screen sections to avoid overwriting categoryProducts
  Future<void> fetchHomeSection(String sectionName, {int limit = 10}) async {
    try {
      Query query = _firestore.collection('products');
      
      if (sectionName == '🔥 Trending Now' || sectionName == 'Trending Now') {
        query = query.where('viewCount', isGreaterThan: 0).orderBy('viewCount', descending: true);
      } else if (sectionName == 'Hot Deals') {
        query = query.where('isHotDeal', isEqualTo: true).orderBy('createdAt', descending: true);
      } else if (sectionName == 'Customer Choices') {
        query = query.where('salesCount', isGreaterThan: 0).orderBy('salesCount', descending: true);
      } else {
        // Standard category section (e.g. 'Daily Needs', 'Snacks')
        query = query.where('category', isEqualTo: sectionName).orderBy('createdAt', descending: true);
      }

      final snapshot = await query.limit(limit).get();
      
      final sectionItems = snapshot.docs.map((doc) {
        return Product.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();

      _sectionProducts[sectionName] = sectionItems;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching home section ($sectionName): $e');
    }
  }
  
  // No changes to CRUD methods
  Future<void> addProduct(Product product) async {
    try {
      await _firestore.collection('products').doc(product.id).set(product.toMap());
      // Add to local lists if it matches current view
      if (_currentCategory == product.category) {
         _categoryProducts.insert(0, product);
      }
      _products.insert(0, product);
      notifyListeners();
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
      }
      final catIndex = _categoryProducts.indexWhere((p) => p.id == id);
      if (catIndex >= 0) {
        _categoryProducts[catIndex] = updatedProduct;
      }
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _firestore.collection('products').doc(id).delete();
      _products.removeWhere((p) => p.id == id);
      _categoryProducts.removeWhere((p) => p.id == id);
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
