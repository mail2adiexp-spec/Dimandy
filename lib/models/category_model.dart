class Category {
  final String id;
  final String name;
  final String imageUrl;
  final int order;

  Category({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.order,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'imageUrl': imageUrl, 'order': order};
  }

  factory Category.fromMap(String id, Map<String, dynamic> map) {
    return Category(
      id: id,
      name: map['name'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      order: map['order'] ?? 0,
    );
  }
}
