import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import 'logging_service.dart';

class RecommendationService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Product> _recentlyViewed = [];

  List<Product> get recentlyViewed => _recentlyViewed;

  /// Get similar products based on category
  Future<List<Product>> getSimilarProducts(
    Product product, {
    int limit = 6,
  }) async {
    try {
      LoggingService.info('Getting similar products for: ${product.name}');

      final snapshot = await _firestore
          .collection('products')
          .where('category', isEqualTo: product.category)
          .limit(limit + 1) // Get one extra to exclude current product
          .get();

      final products = snapshot.docs
          .map((doc) => Product.fromMap(doc.id, doc.data()))
          .where((p) => p.id != product.id) // Exclude current product
          .take(limit)
          .toList();

      LoggingService.info('Found ${products.length} similar products');
      return products;
    } catch (e, stackTrace) {
      LoggingService.error('Error getting similar products', e, stackTrace);
      return [];
    }
  }

  /// Get recommended products based on category and similar price range
  Future<List<Product>> getRecommendedProducts(
    Product product, {
    int limit = 6,
  }) async {
    try {
      LoggingService.info('Getting recommendations for: ${product.name}');

      final minPrice = product.price * 0.7; // 30% lower
      final maxPrice = product.price * 1.3; // 30% higher

      final snapshot = await _firestore
          .collection('products')
          .where('category', isEqualTo: product.category)
          .get();

      // Filter by price range client-side (Firestore doesn't support multiple range queries)
      final products = snapshot.docs
          .map((doc) => Product.fromMap(doc.id, doc.data()))
          .where((p) =>
              p.id != product.id &&
              p.price >= minPrice &&
              p.price <= maxPrice)
          .take(limit)
          .toList();

      LoggingService.info('Found ${products.length} recommended products');
      return products;
    } catch (e, stackTrace) {
      LoggingService.error('Error getting recommended products', e, stackTrace);
      return [];
    }
  }

  /// Fetch recently viewed products and update state
  Future<void> fetchRecentlyViewed({int limit = 6}) async {
    try {
      LoggingService.info('Fetching recently viewed products');

      final prefs = await SharedPreferences.getInstance();
      final viewedIds = prefs.getStringList('recently_viewed') ?? [];

      if (viewedIds.isEmpty) {
        _recentlyViewed = [];
        notifyListeners();
        return;
      }

      final products = <Product>[];
      for (final id in viewedIds.take(limit)) {
        try {
          final doc = await _firestore.collection('products').doc(id).get();
          if (doc.exists) {
            products.add(Product.fromMap(doc.id, doc.data()!));
          }
        } catch (e) {
          LoggingService.warning('Failed to load recently viewed product: $id');
        }
      }

      _recentlyViewed = products;
      notifyListeners();
      LoggingService.info('Loaded ${products.length} recently viewed products');
    } catch (e, stackTrace) {
      LoggingService.error('Error getting recently viewed', e, stackTrace);
    }
  }

  /// Track product view in local storage and update state
  Future<void> trackProductView(String productId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final viewedIds = prefs.getStringList('recently_viewed') ?? [];

      // Remove if already exists
      viewedIds.remove(productId);

      // Add to front
      viewedIds.insert(0, productId);

      // Keep only last 20
      if (viewedIds.length > 20) {
        viewedIds.removeRange(20, viewedIds.length);
      }

      await prefs.setStringList('recently_viewed', viewedIds);
      LoggingService.info('Product view tracked: $productId');
      
      // Refresh the list
      await fetchRecentlyViewed();
    } catch (e, stackTrace) {
      LoggingService.error('Error tracking product view', e, stackTrace);
    }
  }

  /// Get trending products (newest for now, can be enhanced with view/sales count)
  Future<List<Product>> getTrendingProducts({int limit = 10}) async {
    try {
      LoggingService.info('Getting trending products');

      final snapshot = await _firestore
          .collection('products')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final products = snapshot.docs
          .map((doc) => Product.fromMap(doc.id, doc.data()))
          .toList();

      LoggingService.info('Found ${products.length} trending products');
      return products;
    } catch (e, stackTrace) {
      LoggingService.error('Error getting trending products', e, stackTrace);
      return [];
    }
  }

  /// Clear recently viewed history
  Future<void> clearRecentlyViewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('recently_viewed');
      _recentlyViewed = [];
      notifyListeners();
      LoggingService.info('Recently viewed history cleared');
    } catch (e, stackTrace) {
      LoggingService.error('Error clearing recently viewed', e, stackTrace);
    }
  }

  // Backward compatibility method if needed, but better to use fetchRecentlyViewed + getter
  Future<List<Product>> getRecentlyViewed({int limit = 6}) async {
    await fetchRecentlyViewed(limit: limit);
    return _recentlyViewed;
  }
}
