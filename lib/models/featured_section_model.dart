class FeaturedSection {
  final String id;
  final String title; // e.g., "HOTS DEALS", "Daily Needs", "Customer Choices"
  final String categoryName; // The product category to filter
  final int displayOrder; // Order of appearance (1, 2, 3...)
  final bool isActive; // Whether to show this section
  final String? bannerColor1; // For gradient (optional)
  final String? bannerColor2; // For gradient (optional)
  final String? iconName; // Icon identifier (optional)

  FeaturedSection({
    required this.id,
    required this.title,
    required this.categoryName,
    required this.displayOrder,
    required this.isActive,
    this.bannerColor1,
    this.bannerColor2,
    this.iconName,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'categoryName': categoryName,
      'displayOrder': displayOrder,
      'isActive': isActive,
      'bannerColor1': bannerColor1,
      'bannerColor2': bannerColor2,
      'iconName': iconName,
    };
  }

  // Create from Firestore Map
  factory FeaturedSection.fromMap(String id, Map<String, dynamic> map) {
    return FeaturedSection(
      id: id,
      title: map['title'] ?? '',
      categoryName: map['categoryName'] ?? '',
      displayOrder: map['displayOrder'] ?? 0,
      isActive: map['isActive'] ?? true,
      bannerColor1: map['bannerColor1'],
      bannerColor2: map['bannerColor2'],
      iconName: map['iconName'],
    );
  }

  FeaturedSection copyWith({
    String? id,
    String? title,
    String? categoryName,
    int? displayOrder,
    bool? isActive,
    String? bannerColor1,
    String? bannerColor2,
    String? iconName,
  }) {
    return FeaturedSection(
      id: id ?? this.id,
      title: title ?? this.title,
      categoryName: categoryName ?? this.categoryName,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      bannerColor1: bannerColor1 ?? this.bannerColor1,
      bannerColor2: bannerColor2 ?? this.bannerColor2,
      iconName: iconName ?? this.iconName,
    );
  }
}
