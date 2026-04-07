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
      final trending = [..._products];
      trending.sort((a, b) => b.viewCount == a.viewCount 
        ? (b.createdAt?.compareTo(a.createdAt ?? DateTime.now()) ?? 0)
        : b.viewCount.compareTo(a.viewCount));
      return trending.take(10).toList();
    } else if (sectionName == 'Hot Deals') {
      return _products.where((p) => p.isHotDeal || (p.mrp > p.price && p.mrp > 0)).take(10).toList();
    } else if (sectionName == 'Customer Choices') {
      // Favor manually marked then sales
      final choices = _products.where((p) => p.isCustomerChoice).toList();
      if (choices.isEmpty) {
        final topSales = [..._products];
        topSales.sort((a, b) => b.salesCount.compareTo(a.salesCount));
        return topSales.take(10).toList();
      }
      return choices.take(10).toList();
    } else {
      // Standard category (e.g. Daily Needs, Snacks)
      return _products.where((p) => p.category == sectionName).take(10).toList();
    }
  }

  // Removed startListening since we use manual fetching

  Future<void> fetchProducts({bool refresh = false, String? userPincode}) async {
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
          .orderBy('createdAt', descending: true);

      if (userPincode != null && userPincode.isNotEmpty) {
        query = query.where('servicePincodes', arrayContains: userPincode);
      }

      query = query.limit(10);

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

  Future<void> fetchProductsByCategory(String category, {bool refresh = false, String? userPincode}) async {
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
      
      if (userPincode != null && userPincode.isNotEmpty) {
        query = query.where('servicePincodes', arrayContains: userPincode);
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
  Future<void> fetchHomeSection(String sectionName, {int limit = 10, String? userPincode}) async {
    try {
      Query query = _firestore.collection('products');
      
      if (sectionName == '🔥 Trending Now' || sectionName == 'Trending Now') {
        // Show all products sorted by view count, then newest
        query = query.orderBy('viewCount', descending: true).orderBy('createdAt', descending: true);
      } else if (sectionName == 'Hot Deals') {
        query = query.where('isHotDeal', isEqualTo: true).orderBy('createdAt', descending: true);
      } else if (sectionName == 'Customer Choices') {
        // Show manually marked products primarily
        query = query.where('isCustomerChoice', isEqualTo: true).orderBy('createdAt', descending: true);
      } else {
        // Standard category section (e.g. 'Daily Needs', 'Snacks')
        query = query.where('category', isEqualTo: sectionName).orderBy('createdAt', descending: true);
      }

      if (userPincode != null && userPincode.isNotEmpty) {
        query = query.where('servicePincodes', arrayContains: userPincode);
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

  // Generate keywords for search (lowercase, word-based + prefixes)
  List<String> _generateSearchKeywords(String name) {
    final List<String> keywords = [];
    final String lowerName = name.toLowerCase();
    
    // Add full name
    keywords.add(lowerName);
    
    // Split by spaces and special characters
    // Split by non-alphanumeric characters for better word extraction
    final List<String> words = lowerName.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();
    
    for (final word in words) {
      // Add each word
      if (!keywords.contains(word)) keywords.add(word);
      
      // Add prefixes of each word (for instant search)
      for (int i = 1; i <= word.length; i++) {
        final prefix = word.substring(0, i);
        if (!keywords.contains(prefix)) keywords.add(prefix);
      }
    }
    
    return keywords;
  }

  // Global search using Firestore array-contains
  Future<List<Product>> searchProductsGlobal(String query) async {
    if (query.trim().isEmpty) return [];
    
    final String lowerQuery = query.trim().toLowerCase();
    
    try {
      Query q = _firestore
          .collection('products')
          .where('searchKeywords', arrayContains: lowerQuery)
          .limit(100);
          
      final snapshot = await q.get();
          
      return snapshot.docs.map((doc) {
        return Product.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      debugPrint('Error in global search: $e');
      // If error (like missing index), fallback to local search
      return searchProducts(query);
    }
  }
  
  // No changes to CRUD methods
  Future<void> addProduct(Product product) async {
    try {
      // Generate keywords before saving
      final productWithKeywords = Product(
        id: product.id,
        sellerId: product.sellerId,
        name: product.name,
        description: product.description,
        price: product.price,
        basePrice: product.basePrice,
        imageUrl: product.imageUrl,
        imageUrls: product.imageUrls,
        category: product.category,
        unit: product.unit,
        mrp: product.mrp,
        isFeatured: product.isFeatured,
        isHotDeal: product.isHotDeal,
        isCustomerChoice: product.isCustomerChoice,
        salesCount: product.salesCount,
        viewCount: product.viewCount,
        stock: product.stock,
        minimumQuantity: product.minimumQuantity,
        storeIds: product.storeIds,
        state: product.state,
        deliveryFeeOverride: product.deliveryFeeOverride,
        partnerPayoutOverride: product.partnerPayoutOverride,
        searchKeywords: _generateSearchKeywords(product.name),
        createdAt: product.createdAt,
        updatedAt: product.updatedAt,
      );

      await _firestore.collection('products').doc(product.id).set(productWithKeywords.toMap());
      // Add to local lists if it matches current view
      if (_currentCategory == product.category) {
         _categoryProducts.insert(0, productWithKeywords);
      }
      _products.insert(0, productWithKeywords);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProduct(String id, Product updatedProduct) async {
    try {
      final productWithKeywords = Product(
        id: updatedProduct.id,
        sellerId: updatedProduct.sellerId,
        name: updatedProduct.name,
        description: updatedProduct.description,
        price: updatedProduct.price,
        basePrice: updatedProduct.basePrice,
        imageUrl: updatedProduct.imageUrl,
        imageUrls: updatedProduct.imageUrls,
        category: updatedProduct.category,
        unit: updatedProduct.unit,
        mrp: updatedProduct.mrp,
        isFeatured: updatedProduct.isFeatured,
        isHotDeal: updatedProduct.isHotDeal,
        isCustomerChoice: updatedProduct.isCustomerChoice,
        salesCount: updatedProduct.salesCount,
        viewCount: updatedProduct.viewCount,
        stock: updatedProduct.stock,
        minimumQuantity: updatedProduct.minimumQuantity,
        storeIds: updatedProduct.storeIds,
        state: updatedProduct.state,
        deliveryFeeOverride: updatedProduct.deliveryFeeOverride,
        partnerPayoutOverride: updatedProduct.partnerPayoutOverride,
        searchKeywords: _generateSearchKeywords(updatedProduct.name),
        createdAt: updatedProduct.createdAt,
        updatedAt: updatedProduct.updatedAt,
      );

      final Map<String, dynamic> data = productWithKeywords.toMap();
      data.remove('createdAt'); 
      await _firestore.collection('products').doc(id).update(data);
      
      final index = _products.indexWhere((p) => p.id == id);
      if (index >= 0) {
        _products[index] = productWithKeywords;
      }
      final catIndex = _categoryProducts.indexWhere((p) => p.id == id);
      if (catIndex >= 0) {
        _categoryProducts[catIndex] = productWithKeywords;
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
