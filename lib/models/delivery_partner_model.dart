import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryPartnerModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String vehicleType;
  final String? vehicleNumber;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? rejectionReason;

  DeliveryPartnerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.vehicleType,
    this.vehicleNumber,
    required this.status,
    required this.createdAt,
    this.approvedAt,
    this.rejectionReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'vehicleType': vehicleType,
      'vehicleNumber': vehicleNumber,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectionReason': rejectionReason,
    };
  }

  factory DeliveryPartnerModel.fromMap(Map<String, dynamic> map) {
    return DeliveryPartnerModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      vehicleType: map['vehicleType'] ?? '',
      vehicleNumber: map['vehicleNumber'],
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedAt: (map['approvedAt'] as Timestamp?)?.toDate(),
      rejectionReason: map['rejectionReason'],
    );
  }
}
