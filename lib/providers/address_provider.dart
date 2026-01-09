import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/address_model.dart';
import 'auth_provider.dart';

class AddressProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthProvider authProvider;

  AddressProvider(this.authProvider);

  List<Address> _addresses = [];
  bool _loading = false;

  List<Address> get addresses => _addresses;
  bool get isLoading => _loading;

  String get _uid => authProvider.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('users').doc(_uid).collection('addresses');

  Future<void> fetch() async {
    final uid = _uid;
    if (uid.isEmpty) {
      _addresses = [];
      notifyListeners();
      return;
    }
    _loading = true;
    notifyListeners();
    try {
      final snap = await _col.orderBy('updatedAt', descending: true).get();
      _addresses = snap.docs
          .map((d) => Address.fromMap(d.data(), d.id))
          .toList();
    } catch (e) {
      debugPrint('AddressProvider.fetch error: $e');
      _addresses = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> add(Address addr) async {
    final uid = _uid;
    if (uid.isEmpty) return null;
    try {
      final data = addr.toMap();
      if (addr.isDefault) {
        await _unsetAllDefault();
      }
      final doc = await _col.add(data);
      await fetch();
      return doc.id;
    } catch (e) {
      debugPrint('AddressProvider.add error: $e');
      return null;
    }
  }

  Future<void> update(Address addr) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    try {
      if (addr.isDefault) {
        await _unsetAllDefault();
      }
      await _col.doc(addr.id).update(addr.toMap());
      await fetch();
    } catch (e) {
      debugPrint('AddressProvider.update error: $e');
    }
  }

  Future<void> delete(String id) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    try {
      await _col.doc(id).delete();
      await fetch();
    } catch (e) {
      debugPrint('AddressProvider.delete error: $e');
    }
  }

  Future<void> setDefault(String id) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    try {
      await _unsetAllDefault();
      await _col.doc(id).update({
        'isDefault': true,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      await fetch();
    } catch (e) {
      debugPrint('AddressProvider.setDefault error: $e');
    }
  }

  Future<void> _unsetAllDefault() async {
    final snap = await _col.where('isDefault', isEqualTo: true).get();
    for (final d in snap.docs) {
      await d.reference.update({'isDefault': false});
    }
  }

  Address? get defaultAddress {
    for (final a in _addresses) {
      if (a.isDefault) return a;
    }
    return null;
  }
}
