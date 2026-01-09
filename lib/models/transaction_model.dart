import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { credit, debit, refund }
enum TransactionStatus { pending, completed, failed }

class TransactionModel {
  final String id;
  final String userId;
  final double amount;
  final TransactionType type;
  final String description;
  final TransactionStatus status;
  final String referenceId; // Order ID or Payout ID
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;


  TransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.description,
    required this.status,
    required this.referenceId,
    this.metadata,
    required this.createdAt,

  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'type': type.name,
      'description': description,
      'status': status.name,
      'referenceId': referenceId,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),

    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return TransactionModel(
      id: id,
      userId: map['userId'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.credit,
      ),
      description: map['description'] ?? '',
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TransactionStatus.completed,
      ),
      referenceId: map['referenceId'] ?? '',
      metadata: map['metadata'] as Map<String, dynamic>?,

      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
