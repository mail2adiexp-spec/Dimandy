import 'package:cloud_firestore/cloud_firestore.dart';

class AppSettingsModel {
  final String id;
  final String? upiQRCodeUrl;
  final String? upiId;
  final double deliveryFeePercentage;
  final double deliveryFeeMaxCap;
  final double freeDeliveryThreshold; // New: Above this amount, delivery is free
  final double partnerDeliveryRate; // New: What Admin pays the partner per delivery
  final Map<String, double> pincodeOverrides; // New: Specific fees for pincodes
  final double sellerPlatformFeePercentage;
  final double servicePlatformFeePercentage;
  final String? announcementText;
  final bool isAnnouncementEnabled;
  final String? contactPhoneNumber; // New Field
  final DateTime updatedAt;
  final String? updatedBy;

  AppSettingsModel({
    required this.id,
    this.upiQRCodeUrl,
    this.upiId,
    this.deliveryFeePercentage = 0.0,
    this.deliveryFeeMaxCap = 0.0,
    this.freeDeliveryThreshold = 0.0,
    this.partnerDeliveryRate = 0.0,
    this.pincodeOverrides = const {},
    this.sellerPlatformFeePercentage = 0.0,
    this.servicePlatformFeePercentage = 0.0,
    this.announcementText,
    this.isAnnouncementEnabled = false,
    this.contactPhoneNumber, // New Field
    required this.updatedAt,
    this.updatedBy,
  });

  factory AppSettingsModel.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      // ... parse string
      return DateTime.now();
    }

    return AppSettingsModel(
      id: documentId,
      upiQRCodeUrl: map['upiQRCodeUrl'] as String?,
      upiId: map['upiId'] as String?,
      deliveryFeePercentage: (map['deliveryFeePercentage'] as num?)?.toDouble() ?? 0.0,
      deliveryFeeMaxCap: (map['deliveryFeeMaxCap'] as num?)?.toDouble() ?? 0.0,
      freeDeliveryThreshold: (map['freeDeliveryThreshold'] as num?)?.toDouble() ?? 0.0,
      partnerDeliveryRate: (map['partnerDeliveryRate'] as num?)?.toDouble() ?? 0.0,
      pincodeOverrides: (map['pincodeOverrides'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, (value as num).toDouble())
      ) ?? {},
      sellerPlatformFeePercentage: (map['sellerPlatformFeePercentage'] as num?)?.toDouble() ?? 0.0,
      servicePlatformFeePercentage: (map['servicePlatformFeePercentage'] as num?)?.toDouble() ?? 0.0,
      announcementText: map['announcementText'] as String?,
      isAnnouncementEnabled: map['isAnnouncementEnabled'] as bool? ?? false,
      contactPhoneNumber: map['contactPhoneNumber'] as String?, // New Field
      updatedAt: parseDate(map['updatedAt']),
      updatedBy: map['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'upiQRCodeUrl': upiQRCodeUrl,
      'upiId': upiId,
      'deliveryFeePercentage': deliveryFeePercentage,
      'deliveryFeeMaxCap': deliveryFeeMaxCap,
      'freeDeliveryThreshold': freeDeliveryThreshold,
      'partnerDeliveryRate': partnerDeliveryRate,
      'pincodeOverrides': pincodeOverrides,
      'sellerPlatformFeePercentage': sellerPlatformFeePercentage,
      'servicePlatformFeePercentage': servicePlatformFeePercentage,
      'announcementText': announcementText,
      'isAnnouncementEnabled': isAnnouncementEnabled,
      'contactPhoneNumber': contactPhoneNumber, // New Field
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
  }

  AppSettingsModel copyWith({
    String? id,
    String? upiQRCodeUrl,
    String? upiId,
    double? deliveryFeePercentage,
    double? deliveryFeeMaxCap,
    double? freeDeliveryThreshold,
    double? partnerDeliveryRate,
    Map<String, double>? pincodeOverrides,
    double? sellerPlatformFeePercentage,
    double? servicePlatformFeePercentage,
    String? announcementText,
    bool? isAnnouncementEnabled,
    String? contactPhoneNumber, // New Field
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return AppSettingsModel(
      id: id ?? this.id,
      upiQRCodeUrl: upiQRCodeUrl ?? this.upiQRCodeUrl,
      upiId: upiId ?? this.upiId,
      deliveryFeePercentage: deliveryFeePercentage ?? this.deliveryFeePercentage,
      deliveryFeeMaxCap: deliveryFeeMaxCap ?? this.deliveryFeeMaxCap,
      freeDeliveryThreshold: freeDeliveryThreshold ?? this.freeDeliveryThreshold,
      partnerDeliveryRate: partnerDeliveryRate ?? this.partnerDeliveryRate,
      pincodeOverrides: pincodeOverrides ?? this.pincodeOverrides,
      sellerPlatformFeePercentage: sellerPlatformFeePercentage ?? this.sellerPlatformFeePercentage,
      servicePlatformFeePercentage: servicePlatformFeePercentage ?? this.servicePlatformFeePercentage,
      announcementText: announcementText ?? this.announcementText,
      isAnnouncementEnabled: isAnnouncementEnabled ?? this.isAnnouncementEnabled,
      contactPhoneNumber: contactPhoneNumber ?? this.contactPhoneNumber, // New Field
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
