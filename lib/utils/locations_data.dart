import 'dart:math' show cos, sqrt, asin;

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

  @override
  String toString() => '$name, $state';
}

class LocationsData {
  // Common cities in India - Add more as needed
  static const List<City> cities = [
    // Bihar
    City(name: 'Patna', state: 'Bihar', lat: 25.5941, lng: 85.1376),
    City(name: 'Gaya', state: 'Bihar', lat: 24.7914, lng: 85.0002),
    City(name: 'Muzaffarpur', state: 'Bihar', lat: 26.1209, lng: 85.3647),
    City(name: 'Bhagalpur', state: 'Bihar', lat: 25.2425, lng: 87.0117),
    
    // West Bengal
    City(name: 'Kolkata', state: 'West Bengal', lat: 22.5726, lng: 88.3639),
    City(name: 'Siliguri', state: 'West Bengal', lat: 26.7271, lng: 88.3953),
    City(name: 'Durgapur', state: 'West Bengal', lat: 23.5204, lng: 87.3119),
    City(name: 'Asansol', state: 'West Bengal', lat: 23.6739, lng: 86.9524),
    City(name: 'Farakka', state: 'West Bengal', lat: 24.8159, lng: 87.8960),

    // Delhi NCR
    City(name: 'New Delhi', state: 'Delhi', lat: 28.6139, lng: 77.2090),
    City(name: 'Gurgaon', state: 'Haryana', lat: 28.4595, lng: 77.0266),
    City(name: 'Noida', state: 'Uttar Pradesh', lat: 28.5355, lng: 77.3910),

    // Maharashtra
    City(name: 'Mumbai', state: 'Maharashtra', lat: 19.0760, lng: 72.8777),
    City(name: 'Pune', state: 'Maharashtra', lat: 18.5204, lng: 73.8567),
    City(name: 'Nagpur', state: 'Maharashtra', lat: 21.1458, lng: 79.0882),

    // Karnataka
    City(name: 'Bangalore', state: 'Karnataka', lat: 12.9716, lng: 77.5946),
    City(name: 'Mysore', state: 'Karnataka', lat: 12.2958, lng: 76.6394),

    // Tamil Nadu
    City(name: 'Chennai', state: 'Tamil Nadu', lat: 13.0827, lng: 80.2707),
    City(name: 'Coimbatore', state: 'Tamil Nadu', lat: 11.0168, lng: 76.9558),

    // Telangana / Andhra
    City(name: 'Hyderabad', state: 'Telangana', lat: 17.3850, lng: 78.4867),
    City(name: 'Visakhapatnam', state: 'Andhra Pradesh', lat: 17.6868, lng: 83.2185),

    // Uttar Pradesh
    City(name: 'Lucknow', state: 'Uttar Pradesh', lat: 26.8467, lng: 80.9461),
    City(name: 'Varanasi', state: 'Uttar Pradesh', lat: 25.3176, lng: 82.9739),
    City(name: 'Kanpur', state: 'Uttar Pradesh', lat: 26.4499, lng: 80.3319),

    // Gujarat
    City(name: 'Ahmedabad', state: 'Gujarat', lat: 23.0225, lng: 72.5714),
    City(name: 'Surat', state: 'Gujarat', lat: 21.1702, lng: 72.8311),

    // Rajasthan
    City(name: 'Jaipur', state: 'Rajasthan', lat: 26.9124, lng: 75.7873),
    City(name: 'Udaipur', state: 'Rajasthan', lat: 24.5854, lng: 73.7125),

    // Others
    City(name: 'Chandigarh', state: 'Chandigarh', lat: 30.7333, lng: 76.7794),
    City(name: 'Bhubaneswar', state: 'Odisha', lat: 20.2961, lng: 85.8245),
    City(name: 'Guwahati', state: 'Assam', lat: 26.1445, lng: 91.7362),
  ];

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
