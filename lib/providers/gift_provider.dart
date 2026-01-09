import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gift_model.dart';

class GiftProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<Gift> _gifts = [];
  bool _isLoading = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  bool get isLoading => _isLoading;
  List<Gift> get gifts => [..._gifts];

  void startListening() {
    _isLoading = true;
    notifyListeners();
    _sub?.cancel();
    debugPrint('🎁 Starting realtime listener for gifts...');
    _sub = _firestore
        .collection('gifts')
        .orderBy('displayOrder')
        .snapshots()
        .listen(
          (snapshot) {
            _gifts
              ..clear()
              ..addAll(snapshot.docs.map((doc) => Gift.fromDoc(doc)));
            _isLoading = false;
            notifyListeners();
            debugPrint('🎁 Realtime update: ${_gifts.length} gifts');
          },
          onError: (e) {
            _isLoading = false;
            notifyListeners();
            debugPrint('🔴 Gift realtime listener error: $e');
          },
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> addGift(Gift gift) async {
    try {
      debugPrint('🎁 Adding gift ${gift.name}');
      await _firestore.collection('gifts').doc(gift.id).set(gift.toMap());
      debugPrint('✅ Gift added successfully');
    } catch (e) {
      debugPrint('🔴 Error adding gift: $e');
      rethrow;
    }
  }

  Future<void> updateGift(String id, Gift updated) async {
    try {
      debugPrint('🎁 Updating gift $id');
      final data = updated.toMap();
      data.remove('createdAt'); // Don't overwrite original createdAt
      await _firestore.collection('gifts').doc(id).update(data);
      debugPrint('✅ Gift updated successfully');
    } catch (e) {
      debugPrint('🔴 Error updating gift: $e');
      rethrow;
    }
  }

  Future<void> deleteGift(String id) async {
    try {
      debugPrint('🎁 Deleting gift $id');
      await _firestore.collection('gifts').doc(id).delete();
      debugPrint('✅ Gift deleted successfully');
    } catch (e) {
      debugPrint('🔴 Error deleting gift: $e');
      rethrow;
    }
  }

  Gift? findById(String id) {
    try {
      return _gifts.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }
}
