import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String sellerId;
  final String name;
  final String description;
  final double price;
  final double basePrice; // Added basePrice (Buying Price)
  final String imageUrl; // Primary image
  final List<String>? imageUrls; // Multiple images (minimum 4)
  final String? category; // Product category
  final String? unit; // Unit: Kg, Ltr, Pic, Pkt, Grm
  final double mrp; // Maximum Retail Price (for strikethrough)
  final bool isFeatured;
  final bool isHotDeal;
  final bool isCustomerChoice;
  int salesCount;
  int viewCount;
  int stock;
  final int minimumQuantity; // Added minimum quantity field
  final List<String> storeIds; // Added storeIds for availability
  final String? state; // Added state field
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.description,
    required this.price,
    this.basePrice = 0.0, // Default to 0 if not provided
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
    this.stock = 0, // Added to constructor
    this.minimumQuantity = 1, // Default to 1
    this.storeIds = const [], // Default empty
    this.state, // Added to constructor
    this.createdAt,
    this.updatedAt, // Added to constructor
  });

  // Convert Product to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sellerId': sellerId,
      'name': name,
      'description': description,
      'price': price,
      'basePrice': basePrice,
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
      'storeIds': storeIds,
      'state': state, // Added to map
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
      basePrice: (map['basePrice'] as num?)?.toDouble() ?? 0.0,
      imageUrl: map['imageUrl'] ?? '',
      imageUrls: (map['imageUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList() 
          ?? (map['images'] as List<dynamic>?)?.map((e) => e.toString()).toList(), // Fallback to 'images'
      category: map['category'],
      unit: map['unit'],
      mrp: (map['mrp'] as num?)?.toDouble() ?? 0.0,
      isFeatured: map['isFeatured'] ?? false,
      isHotDeal: map['isHotDeal'] ?? false,
      isCustomerChoice: map['isCustomerChoice'] ?? false,
      salesCount: (map['salesCount'] as num?)?.toInt() ?? 0,
      viewCount: (map['viewCount'] as num?)?.toInt() ?? 0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      minimumQuantity: (map['minimumQuantity'] as num?)?.toInt() ?? 1,
      storeIds: (map['storeIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      state: map['state'] as String?, // Added from map
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
