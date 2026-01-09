import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceCategory {
  final String id;
  final String name;
  final String iconName;
  final String colorHex;
  final String description;
  final double basePrice;
  final String? imageUrl; // New field for avatar image
  final DateTime createdAt;

  ServiceCategory({
    required this.id,
    required this.name,
    required this.iconName,
    required this.colorHex,
    required this.description,
    required this.basePrice,
    this.imageUrl,
    required this.createdAt,
  });

  factory ServiceCategory.fromMap(Map<String, dynamic> map, String id) {
    return ServiceCategory(
      id: id,
      name: map['name'] ?? '',
      iconName: map['iconName'] ?? 'miscellaneous_services',
      colorHex: map['colorHex'] ?? '#2196F3',
      description: map['description'] ?? '',
      basePrice: (map['basePrice'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'iconName': iconName,
      'colorHex': colorHex,
      'description': description,
      'basePrice': basePrice,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ServiceCategory copyWith({
    String? id,
    String? name,
    String? iconName,
    String? colorHex,
    String? description,
    double? basePrice,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return ServiceCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      description: description ?? this.description,
      basePrice: basePrice ?? this.basePrice,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
