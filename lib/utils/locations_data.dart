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
    return {'name': name, 'state': state, 'lat': lat, 'lng': lng};
  }

  @override
  String toString() => '$name, $state';
}

class LocationsData {
  static List<City> cities = [
    // Complete fallback list of Indian States and UTs (with a prominent city for each to fulfill the City model)
    const City(
      name: 'Port Blair',
      state: 'Andaman and Nicobar Islands',
      lat: 11.6234,
      lng: 92.7265,
    ),
    const City(
      name: 'Visakhapatnam',
      state: 'Andhra Pradesh',
      lat: 17.6868,
      lng: 83.2185,
    ),
    const City(
      name: 'Itanagar',
      state: 'Arunachal Pradesh',
      lat: 27.0844,
      lng: 93.6053,
    ),
    const City(name: 'Guwahati', state: 'Assam', lat: 26.1445, lng: 91.7362),
    const City(name: 'Patna', state: 'Bihar', lat: 25.5941, lng: 85.1376),
    const City(
      name: 'Chandigarh',
      state: 'Chandigarh',
      lat: 30.7333,
      lng: 76.7794,
    ),
    const City(
      name: 'Raipur',
      state: 'Chhattisgarh',
      lat: 21.2514,
      lng: 81.6296,
    ),
    const City(
      name: 'Daman',
      state: 'Dadra and Nagar Haveli and Daman and Diu',
      lat: 20.3974,
      lng: 72.8328,
    ),
    const City(name: 'New Delhi', state: 'Delhi', lat: 28.6139, lng: 77.2090),
    const City(name: 'Panaji', state: 'Goa', lat: 15.4909, lng: 73.8278),
    const City(name: 'Ahmedabad', state: 'Gujarat', lat: 23.0225, lng: 72.5714),
    const City(name: 'Gurgaon', state: 'Haryana', lat: 28.4595, lng: 77.0266),
    const City(
      name: 'Shimla',
      state: 'Himachal Pradesh',
      lat: 31.1048,
      lng: 77.1734,
    ),
    const City(
      name: 'Srinagar',
      state: 'Jammu and Kashmir',
      lat: 34.0837,
      lng: 74.7973,
    ),
    const City(name: 'Ranchi', state: 'Jharkhand', lat: 23.3441, lng: 85.3096),
    const City(
      name: 'Bangalore',
      state: 'Karnataka',
      lat: 12.9716,
      lng: 77.5946,
    ),
    const City(name: 'Kochi', state: 'Kerala', lat: 9.9312, lng: 76.2673),
    const City(
      name: 'Kavaratti',
      state: 'Lakshadweep',
      lat: 10.5667,
      lng: 72.6417,
    ),
    const City(
      name: 'Indore',
      state: 'Madhya Pradesh',
      lat: 22.7196,
      lng: 75.8577,
    ),
    const City(
      name: 'Mumbai',
      state: 'Maharashtra',
      lat: 19.0760,
      lng: 72.8777,
    ),
    const City(name: 'Imphal', state: 'Manipur', lat: 24.8170, lng: 93.9368),
    const City(
      name: 'Shillong',
      state: 'Meghalaya',
      lat: 25.5788,
      lng: 91.8933,
    ),
    const City(name: 'Aizawl', state: 'Mizoram', lat: 23.7271, lng: 92.7176),
    const City(name: 'Dimapur', state: 'Nagaland', lat: 25.8640, lng: 93.7289),
    const City(
      name: 'Bhubaneswar',
      state: 'Odisha',
      lat: 20.2961,
      lng: 85.8245,
    ),
    const City(
      name: 'Puducherry',
      state: 'Puducherry',
      lat: 11.9416,
      lng: 79.8083,
    ),
    const City(name: 'Ludhiana', state: 'Punjab', lat: 30.9010, lng: 75.8573),
    const City(name: 'Jaipur', state: 'Rajasthan', lat: 26.9124, lng: 75.7873),
    const City(name: 'Gangtok', state: 'Sikkim', lat: 27.3314, lng: 88.6138),
    const City(
      name: 'Chennai',
      state: 'Tamil Nadu',
      lat: 13.0827,
      lng: 80.2707,
    ),
    const City(
      name: 'Hyderabad',
      state: 'Telangana',
      lat: 17.3850,
      lng: 78.4867,
    ),
    const City(name: 'Agartala', state: 'Tripura', lat: 23.8315, lng: 91.2868),
    const City(
      name: 'Lucknow',
      state: 'Uttar Pradesh',
      lat: 26.8467,
      lng: 80.9462,
    ),
    const City(
      name: 'Dehradun',
      state: 'Uttarakhand',
      lat: 30.3165,
      lng: 78.0322,
    ),
    const City(
      name: 'Kolkata',
      state: 'West Bengal',
      lat: 22.5726,
      lng: 88.3639,
    ),
    const City(name: 'Ladakh', state: 'Ladakh', lat: 34.1526, lng: 77.5771),
  ];

  static bool _isLoading = false;
  static bool _isLoaded = false;

  static Future<void> loadCities() async {
    if (_isLoaded || _isLoading) return;

    try {
      _isLoading = true;

      // 1. Load from JSON asset (primary source)
      final String jsonString = await rootBundle.loadString(
        'assets/locations/wb_places.json',
      );
      final List<dynamic> jsonList = json.decode(jsonString);
      final List<City> assetCities = jsonList
          .map((json) => City.fromJson(json))
          .toList();

      if (assetCities.isNotEmpty) {
        cities = assetCities;
      }

      // 2. Load custom locations from Firestore
      // This allows user-added locations to be available globally
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('locations')
            .get();
        if (snapshot.docs.isNotEmpty) {
          final firestoreCities = snapshot.docs
              .map((doc) => City.fromJson(doc.data()))
              .toList();

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
      await FirebaseFirestore.instance
          .collection('locations')
          .add(newCity.toJson());
    } catch (e) {
      // debugPrint('Error adding location: $e');
    }
  }

  static List<City> searchCities(String query) {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return cities
        .where((city) {
          return city.name.toLowerCase().contains(lowerQuery) ||
              city.state.toLowerCase().contains(lowerQuery);
        })
        .take(20)
        .toList();
  }

  // Calculate distance between two points in Kilometers using Haversine formula
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;

    // 12742 is diameter of earth in km
    final distance = 12742 * asin(sqrt(a));

    // Add 20% to account for road curvature vs straight line air distance
    return double.parse((distance * 1.2).toStringAsFixed(1));
  }
}
