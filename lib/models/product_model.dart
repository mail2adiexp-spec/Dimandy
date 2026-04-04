import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String sellerId;
  final String name;
  final String description;
  final double price;
  final double? sellerPrice; // The price intended by the seller (before platform fee)
  final double basePrice; // Added basePrice (Buying Price)
  final double? adminProfitPercentage; // Custom profit sharing percentage (Admin only)
  final String imageUrl; // Primary image
  final List<String>? imageUrls; // Multiple images (minimum 4)
  final String? category; // Product category
  final String? unit; // Unit: Kg, Ltr, Pic, Pkt, Grm
  final double mrp; // Maximum Retail Price (for strikethrough)
  final bool isFeatured;
  final bool isHotDeal;
  final bool isCustomerChoice;
  final int salesCount;
  final int viewCount;
  int stock;
  final int minimumQuantity; // Added minimum quantity field
  final int maximumQuantity; // Added maximum quantity field
  final List<String> storeIds; // Added storeIds for availability
  final String? state; // Added state field
  final List<String> searchKeywords; // Added for global search
  final double? deliveryFeeOverride; // Optional: Custom delivery fee for this product
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.description,
    required this.price,
    this.sellerPrice,
    this.basePrice = 0.0,
    this.adminProfitPercentage,
    required this.imageUrl,
    this.imageUrls,
    this.category,
    this.unit,
    this.mrp = 0.0,
    this.isFeatured = false,
    this.isHotDeal = false,
    this.isCustomerChoice = false,
    this.salesCount = 0,
    this.viewCount = 0,
    this.stock = 0,
    this.minimumQuantity = 1,
    this.maximumQuantity = 0,
    this.storeIds = const [],
    this.state,
    this.deliveryFeeOverride,
    this.searchKeywords = const [],
    this.createdAt,
    this.updatedAt,
  });

  // Convert Product to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sellerId': sellerId,
      'name': name,
      'description': description,
      'price': price,
      'sellerPrice': sellerPrice,
      'basePrice': basePrice,
      'adminProfitPercentage': adminProfitPercentage,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'category': category,
      'unit': unit,
      'mrp': mrp,
      'isFeatured': isFeatured,
      'isHotDeal': isHotDeal,
      'isCustomerChoice': isCustomerChoice,
      'salesCount': salesCount,
      'viewCount': viewCount,
      'stock': stock,
      'minimumQuantity': minimumQuantity,
      'maximumQuantity': maximumQuantity,
      'storeIds': storeIds,
      'state': state,
      'deliveryFeeOverride': deliveryFeeOverride,
      'searchKeywords': searchKeywords,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Create Product from Firestore Map
  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      sellerId: map['sellerId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      sellerPrice: (map['sellerPrice'] as num?)?.toDouble(),
      basePrice: (map['basePrice'] as num?)?.toDouble() ?? 0.0,
      adminProfitPercentage: (map['adminProfitPercentage'] as num?)?.toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      imageUrls: (map['imageUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList() 
          ?? (map['images'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      category: map['category'],
      unit: map['unit'],
      mrp: (map['mrp'] as num?)?.toDouble() ?? 0.0,
      isFeatured: map['isFeatured'] ?? false,
      isHotDeal: map['isHotDeal'] ?? false,
      isCustomerChoice: map['isCustomerChoice'] ?? false,
      salesCount: (map['salesCount'] as num?)?.toInt() ?? 0,
      viewCount: (map['viewCount'] as num?)?.toInt() ?? 0,
      stock: (map['stock'] as num?)?.toInt()?.clamp(0, 9999999) ?? 0,
      minimumQuantity: (map['minimumQuantity'] as num?)?.toInt() ?? 1,
      maximumQuantity: (map['maximumQuantity'] as num?)?.toInt() ?? 0,
      storeIds: (map['storeIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      state: map['state'] as String?,
      deliveryFeeOverride: (map['deliveryFeeOverride'] as num?)?.toDouble(),
      searchKeywords: (map['searchKeywords'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: map['createdAt'] is Timestamp 
          ? (map['createdAt'] as Timestamp).toDate() 
          : null,
      updatedAt: map['updatedAt'] is Timestamp 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }
}

// Product Categories
class ProductCategory {
  static const String snacks = 'Snacks';
  static const String dailyNeeds = 'Daily Needs';
  static const String customerChoice = 'Customer Choice';
  static const String hotDeals = 'Hot Deals';
  static const String gifts = 'Gifts';
  static const String riceAta = 'Rice & Ata';
  static const String cookingOils = 'Cooking Oils';
  static const String fastFood = 'Fast Food';
  static const String coldDrinks = 'Cold Drinks';

  static const List<String> all = [
    snacks,
    dailyNeeds,
    gifts,
    riceAta,
    cookingOils,
    fastFood,
    coldDrinks,
  ];
}
