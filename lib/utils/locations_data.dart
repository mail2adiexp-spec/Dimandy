import 'dart:math' show cos, sqrt, asin;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';

class City {
  final String name;
  final String state;
  final double lat;
  final double lng;

  const City({
    required this.name,
    required this.state,
    required this.lat,
    required this.lng,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      name: json['name'] ?? '',
      state: json['state'] ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'state': state,
      'lat': lat,
      'lng': lng,
    };
  }

  @override
  String toString() => '$name, $state';
}

class LocationsData {
  static List<City> cities = [
    // Fallback cities
    const City(name: 'Kolkata', state: 'West Bengal', lat: 22.5726, lng: 88.3639),
    const City(name: 'Siliguri', state: 'West Bengal', lat: 26.7271, lng: 88.3953),
    const City(name: 'Durgapur', state: 'West Bengal', lat: 23.5204, lng: 87.3119),
    const City(name: 'Asansol', state: 'West Bengal', lat: 23.6739, lng: 86.9524),
    const City(name: 'Patna', state: 'Bihar', lat: 25.5941, lng: 85.1376),
    const City(name: 'New Delhi', state: 'Delhi', lat: 28.6139, lng: 77.2090),
    const City(name: 'Mumbai', state: 'Maharashtra', lat: 19.0760, lng: 72.8777),
    const City(name: 'Bangalore', state: 'Karnataka', lat: 12.9716, lng: 77.5946),
  ];

  static bool _isLoading = false;
  static bool _isLoaded = false;

  static Future<void> loadCities() async {
    if (_isLoaded || _isLoading) return;
    
    try {
      _isLoading = true;
      
      // 1. Load from JSON asset (primary source)
      final String jsonString = await rootBundle.loadString('assets/locations/wb_places.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      final List<City> assetCities = jsonList.map((json) => City.fromJson(json)).toList();
      
      if (assetCities.isNotEmpty) {
        cities = assetCities;
      }
      
      // 2. Load custom locations from Firestore
      // This allows user-added locations to be available globally
      try {
        final snapshot = await FirebaseFirestore.instance.collection('locations').get();
        if (snapshot.docs.isNotEmpty) {
          final firestoreCities = snapshot.docs.map((doc) => City.fromJson(doc.data())).toList();
          
          // Merge lists, avoiding duplicates if names match
          final existingNames = cities.map((c) => c.name.toLowerCase()).toSet();
          for (final city in firestoreCities) {
            if (!existingNames.contains(city.name.toLowerCase())) {
              cities.add(city);
            }
          }
        }
      } catch (e) {
        // debugPrint('Firestore locations load error: $e'); // Silent fail for offline
      }

      _isLoaded = true;
    } catch (e) {
      // debugPrint('Error loading locations: $e');
    } finally {
      _isLoading = false;
    }
  }

  // Add a new custom location to Firestore
  static Future<void> addCustomLocation(String name) async {
    try {
      // Check for duplicates first locally
      final lowerName = name.toLowerCase();
      if (cities.any((c) => c.name.toLowerCase() == lowerName)) return;

      final newCity = City(
        name: name,
        state: 'Custom Location', // Default state for user inputs
        lat: 0.0, // No coords available from manual entry
        lng: 0.0,
      );

      // Add to local list immediately for UI responsiveness
      cities.add(newCity);

      // Persist to Firestore
      await FirebaseFirestore.instance.collection('locations').add(newCity.toJson());
    } catch (e) {
      // debugPrint('Error adding location: $e');
    }
  }

  static List<City> searchCities(String query) {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return cities.where((city) {
      return city.name.toLowerCase().contains(lowerQuery) || 
             city.state.toLowerCase().contains(lowerQuery);
    }).take(20).toList();
  }

  
  // Calculate distance between two points in Kilometers using Haversine formula
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    
    // 12742 is diameter of earth in km
    final distance = 12742 * asin(sqrt(a));
    
    // Add 20% to account for road curvature vs straight line air distance
    return double.parse((distance * 1.2).toStringAsFixed(1));
  }
}

