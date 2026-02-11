import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String? state; // Added State field

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
    this.state,
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
      'state': state,
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

    // Handle createdAt being String or Timestamp
    DateTime parseCreatedAt(dynamic value) {
       if (value is Timestamp) return value.toDate();
       if (value is String) return DateTime.parse(value);
       return DateTime.now();
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
      createdAt: parseCreatedAt(map['createdAt']),
      state: map['state'],
    );
  }
}
