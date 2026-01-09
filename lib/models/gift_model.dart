import 'package:cloud_firestore/cloud_firestore.dart';

class Gift {
  final String id;
  final String name;
  final String description;
  final double price;
  // Optional primary image URL (first image)
  final String? imageUrl;
  final List<String>? imageUrls;
  // Optional purpose tag like Birthday/Anniversary/Corporate
  final String? purpose;
  final bool isActive;
  final int displayOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Gift({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    this.imageUrls,
    this.purpose,
    this.isActive = true,
    this.displayOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  Gift copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    List<String>? imageUrls,
    String? purpose,
    bool? isActive,
    int? displayOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Gift(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      purpose: purpose ?? this.purpose,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'purpose': purpose,
      'isActive': isActive,
      'displayOrder': displayOrder,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory Gift.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Gift(
      id: doc.id,
      name: (data['name'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      price: (data['price'] is int)
          ? (data['price'] as int).toDouble()
          : (data['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: data['imageUrl'] as String?,
      imageUrls: data['imageUrls'] != null
          ? List<String>.from(data['imageUrls'])
          : null,
      purpose: data['purpose'] as String?,
      isActive: (data['isActive'] as bool?) ?? true,
      displayOrder: (data['displayOrder'] as int?) ?? 0,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: (data['updatedAt'] is Timestamp)
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
