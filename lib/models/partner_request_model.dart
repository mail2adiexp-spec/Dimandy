class PartnerRequest {
  final String id;
  final String role; // 'Seller' or 'Service Provider'
  final String gender;
  final String name;
  final String phone;
  final String email;
  final String district;
  final String pincode;
  final String businessName;
  final String panNumber;
  final String aadhaarNumber;
  final double minCharge;
  final String? profilePicUrl;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;

  PartnerRequest({
    required this.id,
    required this.role,
    required this.gender,
    required this.name,
    required this.phone,
    required this.email,
    required this.district,
    required this.pincode,
    required this.businessName,
    required this.panNumber,
    required this.aadhaarNumber,
    required this.minCharge,
    this.profilePicUrl,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role,
      'gender': gender,
      'name': name,
      'phone': phone,
      'email': email,
      'district': district,
      'pincode': pincode,
      'businessName': businessName,
      'panNumber': panNumber,
      'aadhaarNumber': aadhaarNumber,
      'minCharge': minCharge,
      'profilePicUrl': profilePicUrl,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PartnerRequest.fromMap(Map<String, dynamic> map) {
    // Helper to safely parse minCharge from various formats
    double parseMinCharge(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }

    return PartnerRequest(
      id: map['id'] ?? '',
      role: map['role'] ?? 'Seller',
      gender: map['gender'] ?? 'Male',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      district: map['district'] ?? '',
      pincode: map['pincode'] ?? '',
      businessName: map['businessName'] ?? '',
      panNumber: map['panNumber'] ?? '',
      aadhaarNumber: map['aadhaarNumber'] ?? '',
      minCharge: parseMinCharge(map['minCharge']),
      profilePicUrl: map['profilePicUrl'],
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }
}
