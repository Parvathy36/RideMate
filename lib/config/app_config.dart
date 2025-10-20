class AppConfig {
  // Configuration parameters for the app
  // Google Maps API Key has been removed since we're now using OpenStreetMap

  /// Default coordinates used when the ride document does not provide
  /// a pickup point and geocoding fails. Update these to an area that is
  /// valid for your service region.
  static const Map<String, double> defaultPickupLocation = {
    'latitude': 9.564905,
    'longitude': 76.755649,
  };

  /// Default destination coordinates. You can adjust these values to match
  /// a sensible fallback within your coverage zone.
  static const Map<String, double> defaultDestinationLocation = {
    'latitude': 9.583764,
    'longitude': 76.771374,
  };

  /// Timeout for geocoding requests to OpenStreetMap / Nominatim.
  static const Duration geocodingTimeout = Duration(seconds: 8);
}
