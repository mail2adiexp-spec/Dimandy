class Address {
  final String id;
  final String fullName;
  final String phone;
  final String addressLine;
  final String city;
  final String postalCode;
  final bool isDefault;
  final DateTime updatedAt;

  Address({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.addressLine,
    required this.city,
    required this.postalCode,
    this.isDefault = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory Address.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic v) {
      try {
        if (v is DateTime) return v;
        if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
        if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
        if (v is String) return DateTime.parse(v);
        // Firestore Timestamp support without import to avoid dependency
        final type = v.runtimeType.toString();
        if (type == 'Timestamp') {
          // call toDate via dynamic
          return (v as dynamic).toDate();
        }
      } catch (_) {}
      return DateTime.now();
    }

    return Address(
      id: id,
      fullName: map['fullName'] ?? '',
      phone: map['phone'] ?? '',
      addressLine: map['addressLine'] ?? '',
      city: map['city'] ?? '',
      postalCode: map['postalCode'] ?? '',
      isDefault: map['isDefault'] ?? false,
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'phone': phone,
      'addressLine': addressLine,
      'city': city,
      'postalCode': postalCode,
      'isDefault': isDefault,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
