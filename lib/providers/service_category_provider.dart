import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_category_model.dart';

class ServiceCategoryProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<ServiceCategory> _serviceCategories = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  List<ServiceCategory> get serviceCategories => [..._serviceCategories];
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void startListening() {
    _isLoading = true;
    notifyListeners();
    _sub?.cancel();

    debugPrint('🔧 Starting realtime listener for service_categories...');

    _sub = _firestore
        .collection('service_categories')
        .snapshots()
        .listen(
          (snapshot) {
            _errorMessage = null;
            _serviceCategories = snapshot.docs
                .map((doc) => ServiceCategory.fromMap(doc.data(), doc.id))
                .toList();
            _serviceCategories.sort((a, b) => a.name.compareTo(b.name));
            _isLoading = false;
            notifyListeners();
            debugPrint(
              '🔧 Realtime update: ${_serviceCategories.length} service categories',
            );
          },
          onError: (error) {
            debugPrint('🔴 Service categories listener error: $error');
            _isLoading = false;
            _errorMessage = error.toString();
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> addServiceCategory(ServiceCategory category) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('service_categories').add(category.toMap());

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateServiceCategory(ServiceCategory category) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore
          .collection('service_categories')
          .doc(category.id)
          .update(category.toMap());

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteServiceCategory(String id) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('service_categories').doc(id).delete();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  ServiceCategory? getCategoryById(String id) {
    try {
      return _serviceCategories.firstWhere((cat) => cat.id == id);
    } catch (e) {
      return null;
    }
  }
}
