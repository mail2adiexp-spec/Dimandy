import 'package:cloud_firestore/cloud_firestore.dart';

class AppSettingsModel {
  final String id;
  final String? upiQRCodeUrl;
  final String? upiId;
  final double deliveryFeePercentage;
  final double deliveryFeeMaxCap;
  final double sellerPlatformFeePercentage;
  final double servicePlatformFeePercentage;
  final String? announcementText;
  final bool isAnnouncementEnabled;
  final DateTime updatedAt;
  final String? updatedBy;

  AppSettingsModel({
    required this.id,
    this.upiQRCodeUrl,
    this.upiId,
    this.deliveryFeePercentage = 0.0,
    this.deliveryFeeMaxCap = 0.0,
    this.sellerPlatformFeePercentage = 0.0,
    this.servicePlatformFeePercentage = 0.0,
    this.announcementText,
    this.isAnnouncementEnabled = false,
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
      sellerPlatformFeePercentage: (map['sellerPlatformFeePercentage'] as num?)?.toDouble() ?? 0.0,
      servicePlatformFeePercentage: (map['servicePlatformFeePercentage'] as num?)?.toDouble() ?? 0.0,
      announcementText: map['announcementText'] as String?,
      isAnnouncementEnabled: map['isAnnouncementEnabled'] as bool? ?? false,
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
      'sellerPlatformFeePercentage': sellerPlatformFeePercentage,
      'servicePlatformFeePercentage': servicePlatformFeePercentage,
      'announcementText': announcementText,
      'isAnnouncementEnabled': isAnnouncementEnabled,
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
    double? sellerPlatformFeePercentage,
    double? servicePlatformFeePercentage,
    String? announcementText,
    bool? isAnnouncementEnabled,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return AppSettingsModel(
      id: id ?? this.id,
      upiQRCodeUrl: upiQRCodeUrl ?? this.upiQRCodeUrl,
      upiId: upiId ?? this.upiId,
      deliveryFeePercentage: deliveryFeePercentage ?? this.deliveryFeePercentage,
      deliveryFeeMaxCap: deliveryFeeMaxCap ?? this.deliveryFeeMaxCap,
      sellerPlatformFeePercentage: sellerPlatformFeePercentage ?? this.sellerPlatformFeePercentage,
      servicePlatformFeePercentage: servicePlatformFeePercentage ?? this.servicePlatformFeePercentage,
      announcementText: announcementText ?? this.announcementText,
      isAnnouncementEnabled: isAnnouncementEnabled ?? this.isAnnouncementEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
