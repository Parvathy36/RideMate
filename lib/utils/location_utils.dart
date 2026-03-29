import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class LocationUtils {
  // Region mapping for Kerala districts
  static const Map<String, String> districtToRegion = {
    // North Kerala
    'Kasaragod': 'North',
    'Kannur': 'North',
    'Wayanad': 'North',
    'Kozhikode': 'North',
    'Malappuram': 'North',

    // Central Kerala
    'Palakkad': 'Central',
    'Thrissur': 'Central',
    'Ernakulam': 'Central',
    'Idukki': 'Central',

    // South Kerala
    'Kottayam': 'South',
    'Pathanamthitta': 'South',
    'Alappuzha': 'South',
    'Kollam': 'South',
    'Thiruvananthapuram': 'South',
  };

  // Approximate center coordinates for Kerala districts
  static const Map<String, Map<String, double>> districtCenters = {
    'Kasaragod': {'lat': 12.5101, 'lng': 74.9852},
    'Kannur': {'lat': 11.8745, 'lng': 75.3704},
    'Wayanad': {'lat': 11.6050, 'lng': 76.0828},
    'Kozhikode': {'lat': 11.2588, 'lng': 75.7804},
    'Malappuram': {'lat': 11.0735, 'lng': 76.0740},
    'Palakkad': {'lat': 10.7867, 'lng': 76.6547},
    'Thrissur': {'lat': 10.5276, 'lng': 76.2144},
    'Ernakulam': {'lat': 9.9816, 'lng': 76.2999},
    'Idukki': {'lat': 9.8500, 'lng': 76.9667},
    'Kottayam': {'lat': 9.5916, 'lng': 76.5221},
    'Pathanamthitta': {'lat': 9.2648, 'lng': 76.7870},
    'Alappuzha': {'lat': 9.4981, 'lng': 76.3329},
    'Kollam': {'lat': 8.8932, 'lng': 76.6141},
    'Thiruvananthapuram': {'lat': 8.5241, 'lng': 76.9366},
  };

  /// Determines the region of a driver based on their latitude and longitude.
  /// Returns 'North', 'Central', 'South', or 'Unknown' if valid coordinates aren't provided.
  static String getRegionFromLatLng(dynamic location) {
    if (location == null) return 'Unknown';

    double lat;
    double lng;

    if (location is GeoPoint) {
      lat = location.latitude;
      lng = location.longitude;
    } else if (location is Map<String, dynamic>) {
      lat = location['latitude'] ?? location['lat'] ?? 0.0;
      lng = location['longitude'] ?? location['lng'] ?? 0.0;
    } else {
      return 'Unknown';
    }

    if (lat == 0.0 && lng == 0.0) return 'Unknown';

    String nearestDistrict = 'Unknown';
    double minDistance = double.infinity;

    districtCenters.forEach((district, coords) {
      final distance = _calculateDistance(
        lat,
        lng,
        coords['lat']!,
        coords['lng']!,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearestDistrict = district;
      }
    });

    return districtToRegion[nearestDistrict] ?? 'Unknown';
  }

  /// Determines the region of a driver based on their district name.
  static String getRegionFromDistrict(String? district) {
    if (district == null) return 'Unknown';
    return districtToRegion[district] ?? 'Unknown';
  }

  /// Helper method to calculate distance between two coordinates (Haversine formula)
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  /// Returns the approximate center coordinate for a Kerala region.
  static LatLng getRegionCenter(String region) {
    switch (region) {
      case 'North':
        return const LatLng(11.2588, 75.7804); // Kozhikode approx center
      case 'Central':
        return const LatLng(9.9816, 76.2999); // Kochi approx center
      case 'South':
        return const LatLng(8.5241, 76.9366); // Trivandrum approx center
      default:
        return const LatLng(10.8505, 76.2711); // Kerala approx center
    }
  }
}
