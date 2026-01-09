import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Record a new transaction
  Future<void> recordTransaction(TransactionModel transaction) async {
    try {
      await _firestore.collection('transactions').add(transaction.toMap());
    } catch (e) {
      print('Error recording transaction: $e');
      rethrow;
    }
  }

  // Get transactions for a user
  Stream<List<TransactionModel>> getTransactions(String userId) {
    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Calculate current balance
  Future<double> getBalance(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .get();

      double balance = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final type = data['type'] as String?;

        if (type == 'credit') {
          balance += amount;
        } else if (type == 'debit' || type == 'refund') {
          balance -= amount;
        }
      }
      return balance;
    } catch (e) {
      print('Error calculating balance: $e');
      return 0.0;
    }
  }
}
