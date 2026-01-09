class User {
  final String id;
  final String email;
  final String name;
  final String? phoneNumber;
  final String? photoURL;
  final String role; // 'customer', 'seller', 'admin'
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.phoneNumber,
    this.photoURL,
    this.role = 'customer',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phoneNumber': phoneNumber,
      'photoURL': photoURL,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'],
      photoURL: map['photoURL'],
      role: map['role'] ?? 'customer',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? phoneNumber,
    String? photoURL,
    String? role,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoURL: photoURL ?? this.photoURL,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class UserRole {
  static const String customer = 'customer';
  static const String seller = 'seller';
  static const String admin = 'admin';

  static const List<String> all = [customer, seller, admin];
}
