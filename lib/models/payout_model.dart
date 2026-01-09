import 'package:cloud_firestore/cloud_firestore.dart';

enum PayoutStatus { pending, approved, rejected }

class PayoutModel {
  final String id;
  final String userId;
  final double amount;
  final PayoutStatus status;
  final DateTime requestDate;
  final DateTime? processedDate;
  final String paymentDetails; // Bank info or UPI ID
  final String? adminNote;

  PayoutModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.status,
    required this.requestDate,
    this.processedDate,
    required this.paymentDetails,
    this.adminNote,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'status': status.name,
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
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      status: PayoutStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PayoutStatus.pending,
      ),
      requestDate: (map['requestDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      processedDate: (map['processedDate'] as Timestamp?)?.toDate(),
      paymentDetails: map['paymentDetails'] ?? '',
      adminNote: map['adminNote'],
    );
  }
}
