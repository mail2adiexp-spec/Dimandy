import 'package:flutter_test/flutter_test.dart';
import 'package:ecommerce_app/models/transaction_model.dart';
import 'package:ecommerce_app/models/payout_model.dart';

void main() {
  group('TransactionModel Tests', () {
    test('should create TransactionModel from map', () {
      final date = DateTime.now();
      final map = {
        'userId': 'user123',
        'amount': 500.0,
        'type': 'credit',
        'description': 'Test Credit',
        'status': 'completed',
        'referenceId': 'order123',
        'createdAt': date.toIso8601String(),
      };

      final transaction = TransactionModel.fromMap(map, 'trans123');

      expect(transaction.id, 'trans123');
      expect(transaction.userId, 'user123');
      expect(transaction.amount, 500.0);
      expect(transaction.type, TransactionType.credit);
      expect(transaction.status, TransactionStatus.completed);
    });

    test('should convert TransactionModel to map', () {
      final transaction = TransactionModel(
        id: 'trans123',
        userId: 'user123',
        amount: 500.0,
        type: TransactionType.debit,
        description: 'Test Debit',
        status: TransactionStatus.pending,
        referenceId: 'payout123',
        createdAt: DateTime.now(),
      );

      final map = transaction.toMap();

      expect(map['userId'], 'user123');
      expect(map['amount'], 500.0);
      expect(map['type'], 'debit');
      expect(map['status'], 'pending');
    });
  });

  group('PayoutModel Tests', () {
    test('should create PayoutModel from map', () {
      final date = DateTime.now();
      final map = {
        'userId': 'user123',
        'amount': 1000.0,
        'status': 'pending',
        'requestDate': date.toIso8601String(),
        'paymentDetails': 'UPI: test@upi',
        'adminNote': 'Processing',
      };

      final payout = PayoutModel.fromMap(map, 'payout123');

      expect(payout.id, 'payout123');
      expect(payout.userId, 'user123');
      expect(payout.amount, 1000.0);
      expect(payout.status, PayoutStatus.pending);
      expect(payout.paymentDetails, 'UPI: test@upi'); // Assuming paymentDetails maps to paymentMethod in simple case
    });
  });
}
