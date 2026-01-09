import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/featured_section_model.dart';

class FeaturedSectionProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<FeaturedSection> _sections = [];
  bool _isLoading = false;

  List<FeaturedSection> get sections => [..._sections];
  bool get isLoading => _isLoading;

  // Get active sections sorted by displayOrder
  List<FeaturedSection> get activeSections {
    return _sections.where((section) => section.isActive).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  // Fetch all featured sections from Firestore
  Future<void> fetchSections() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('featured_sections')
          .orderBy('displayOrder')
          .get();

      _sections = snapshot.docs
          .map((doc) => FeaturedSection.fromMap(doc.id, doc.data()))
          .toList();

      print('✅ Fetched ${_sections.length} featured sections');
    } catch (e) {
      print('❌ Error fetching featured sections: $e');
      _sections = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add a new featured section
  Future<void> addSection(FeaturedSection section) async {
    try {
      final docRef = await _firestore
          .collection('featured_sections')
          .add(section.toMap());

      final newSection = section.copyWith(id: docRef.id);
      _sections.add(newSection);
      notifyListeners();

      print('✅ Added featured section: ${section.title}');
    } catch (e) {
      print('❌ Error adding featured section: $e');
      rethrow;
    }
  }

  // Update an existing featured section
  Future<void> updateSection(FeaturedSection section) async {
    try {
      await _firestore
          .collection('featured_sections')
          .doc(section.id)
          .update(section.toMap());

      final index = _sections.indexWhere((s) => s.id == section.id);
      if (index != -1) {
        _sections[index] = section;
        notifyListeners();
      }

      print('✅ Updated featured section: ${section.title}');
    } catch (e) {
      print('❌ Error updating featured section: $e');
      rethrow;
    }
  }

  // Delete a featured section
  Future<void> deleteSection(String id) async {
    try {
      await _firestore.collection('featured_sections').doc(id).delete();

      _sections.removeWhere((s) => s.id == id);
      notifyListeners();

      print('✅ Deleted featured section');
    } catch (e) {
      print('❌ Error deleting featured section: $e');
      rethrow;
    }
  }

  // Toggle active status
  Future<void> toggleActive(String id) async {
    final section = _sections.firstWhere((s) => s.id == id);
    final updated = section.copyWith(isActive: !section.isActive);
    await updateSection(updated);
  }
}
