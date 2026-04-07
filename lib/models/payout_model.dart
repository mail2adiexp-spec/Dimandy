import 'package:cloud_firestore/cloud_firestore.dart';

enum PayoutStatus { pending, approved, rejected }
enum PayoutType { withdrawal, commission_transfer }

class PayoutModel {
  final String id;
  final String userId;
  final String userRole; // Add this: 'delivery_partner', 'store_partner', 'service_provider', etc.
  final double amount;
  final PayoutStatus status;
  final PayoutType type;
  final DateTime requestDate;
  final DateTime? processedDate;
  final String paymentDetails; // Bank info or UPI ID
  final String? adminNote;

  PayoutModel({
    required this.id,
    required this.userId,
    this.userRole = 'general',
    required this.amount,
    required this.status,
    this.type = PayoutType.withdrawal,
    required this.requestDate,
    this.processedDate,
    required this.paymentDetails,
    this.adminNote,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userRole': userRole,
      'amount': amount,
      'status': status.name,
      'type': type.name,
      'requestDate': Timestamp.fromDate(requestDate),
      'processedDate': processedDate != null ? Timestamp.fromDate(processedDate!) : null,
      'paymentDetails': paymentDetails,
      'adminNote': adminNote,
    };
  }

  factory PayoutModel.fromMap(Map<String, dynamic> map, String id) {
    return PayoutModel(
      id: id,
      userId: map['userId'] ?? '',
      userRole: map['userRole'] ?? map['role'] ?? 'general',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      status: PayoutStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PayoutStatus.pending,
      ),
      type: PayoutType.values.firstWhere(
        (e) => e.name == (map['type'] as String?),
        orElse: () => PayoutType.withdrawal,
      ),
      requestDate: (map['requestDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      processedDate: (map['processedDate'] as Timestamp?)?.toDate(),
      paymentDetails: map['paymentDetails'] ?? '',
      adminNote: map['adminNote'],
    );
  }
}
