class ServiceItem {
  final String id;
  final String name;
  final double price;
  final String description;
  final String category;
  final int duration; // in minutes
  bool isSelected; // for multi-selection

  ServiceItem({
    required this.id,
    required this.name,
    required this.price,
    this.description = '',
    this.category = '',
    this.duration = 30,
    this.isSelected = false,
  });

  // Convert ServiceItem to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'description': description,
      'category': category,
      'duration': duration,
    };
  }

  // Create ServiceItem from Firestore Map
  factory ServiceItem.fromMap(Map<String, dynamic> map) {
    return ServiceItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      duration: (map['duration'] as num?)?.toInt() ?? 30,
    );
  }

  // Copy with method for updating selection state
  ServiceItem copyWith({
    String? id,
    String? name,
    double? price,
    String? description,
    String? category,
    int? duration,
    bool? isSelected,
  }) {
    return ServiceItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      category: category ?? this.category,
      duration: duration ?? this.duration,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
