import 'package:cloud_firestore/cloud_firestore.dart';

class StoreModel {
  final String id;
  final String name;
  final String address;
  final List<String> pincodes;
  final bool isActive;
  final Timestamp createdAt;
  
  // Manager Details
  final String? managerId;
  final String? managerName;
  final String? managerEmail;
  final String? managerPhone;

  StoreModel({
    required this.id,
    required this.name,
    required this.address,
    required this.pincodes,
    this.isActive = true,
    required this.createdAt,
    this.managerId,
    this.managerName,
    this.managerEmail,
    this.managerPhone,
  });

  factory StoreModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return StoreModel(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      pincodes: List<String>.from(data['pincodes'] ?? []),
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      managerId: data['managerId'] as String?,
      managerName: data['managerName'] as String?,
      managerEmail: data['managerEmail'] as String?,
      managerPhone: data['managerPhone'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'pincodes': pincodes,
      'isActive': isActive,
      'createdAt': createdAt,
      'managerId': managerId,
      'managerName': managerName,
      'managerEmail': managerEmail,
      'managerPhone': managerPhone,
    };
  }
}
