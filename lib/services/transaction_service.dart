import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Record a new transaction
  Future<void> recordTransaction(TransactionModel transaction) async {
    try {
      await _firestore.collection('transactions').add(transaction.toMap());
    } catch (e) {
      debugPrint('Error recording transaction: $e');
      rethrow;
    }
  }

  // Get transactions for a user
  Stream<List<TransactionModel>> getTransactions(String userId, {String? role}) {
    Query query = _firestore.collection('transactions');

    // If role is seller, we want transactions where they are either the primary userId (payouts)
    // or the sellerId in metadata (revenue).
    // Note: Firestore doesn't support logical OR across different fields in a single query easily 
    // without composite indexes or complex filters. 
    // For now, we fetch by userId and client-side filter or use a more specific query if role is provided.
    
    if (role == 'seller') {
      // For sellers, we often want to prioritize their revenue (metadata.sellerId)
      // but also show their payouts (userId).
      // We'll return a stream that combines these or just focuses on the relevant ones.
      return _firestore
          .collection('transactions')
          .where('metadata.sellerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .asyncMap((revenueSnapshot) async {
            // Also fetch payout transactions where they are the primary userId
            final payoutSnapshot = await _firestore
                .collection('transactions')
                .where('userId', isEqualTo: userId)
                .where('type', isEqualTo: 'debit')
                .get();

            List<TransactionModel> txns = revenueSnapshot.docs
                .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
                .toList();

            for (var doc in payoutSnapshot.docs) {
              final tx = TransactionModel.fromMap(doc.data(), doc.id);
              // avoid duplicates if any
              if (!txns.any((t) => t.id == tx.id)) {
                txns.add(tx);
              }
            }
            
            // Sort by date descending
            txns.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return txns;
          });
    }

    return query
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  // Calculate current balance
  Future<double> getBalance(String userId, {String? role}) async {
    try {
      double balance = 0.0;

      // 1. Get Revenue (where they are the seller)
      final revenueSnapshot = await _firestore
          .collection('transactions')
          .where('metadata.sellerId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .get();

      for (var doc in revenueSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final type = data['type'] as String?;
        if (type == 'credit') {
          balance += amount;
        } else if (type == 'refund' || type == 'debit') {
          balance -= amount;
        }
      }

      // 2. Get Payouts/Adjustments (where they are the primary userId and NOT already counted as revenue)
      final internalSnapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .get();

      for (var doc in internalSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
        
        // Skip if already counted in revenue query to avoid double counting
        if (metadata['sellerId'] == userId) continue;

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
      debugPrint('Error calculating balance: $e');
      return 0.0;
    }
  }
}
