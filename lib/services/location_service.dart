import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for real-time driver location tracking
/// Handles GPS location updates, permission management, and Firestore synchronization
class LocationService {
  static const double distanceFilter = 10.0; // meters
  static const int updateInterval = 5000; // milliseconds

  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _locationUpdateTimer;

  /// Request location permissions
  Future<bool> requestLocationPermission() async {
    // Request permission
    final status = await Permission.location.request();

    // Handle the permission status
    switch (status) {
      case PermissionStatus.granted:
        return true;
      case PermissionStatus.denied:
      case PermissionStatus.restricted:
      case PermissionStatus.permanentlyDenied:
      case PermissionStatus.limited:
      case PermissionStatus.provisional:
        return false;
    }
  }

  /// Check if location service is enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Start tracking driver location
  Future<void> startTrackingDriverLocation() async {
    bool serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    bool permissionGranted = await requestLocationPermission();
    if (!permissionGranted) {
      throw Exception('Location permissions are denied.');
    }

    // Start listening to position updates
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update when moved 10 meters
      ),
    ).listen(_onLocationUpdate);
  }

  /// Stop tracking driver location
  Future<void> stopTrackingDriverLocation() async {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  /// Update driver location in Firestore
  Future<void> _onLocationUpdate(Position position) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Update driver's location in both collections
      final locationData = {
        'currentLocation': GeoPoint(position.latitude, position.longitude),
        'lastLocationUpdate': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Update in users collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(locationData);

      // Update in drivers collection
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(user.uid)
          .update(locationData);

      // Also update the ride document if the driver is on an active ride
      await _updateRideLocation(user.uid, position);
    } catch (e) {
      print('Error updating driver location: $e');
    }
  }

  /// Update ride document with driver's current location
  Future<void> _updateRideLocation(String driverId, Position position) async {
    try {
      // Find active ride for this driver
      final rideSnapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: driverId)
          .where(
            'status',
            whereIn: [
              'accepted',
              'confirmed',
              'enroute',
              'arrived',
              'in_progress',
            ],
          )
          .limit(1)
          .get();

      if (rideSnapshot.docs.isNotEmpty) {
        final rideDoc = rideSnapshot.docs.first;
        await FirebaseFirestore.instance
            .collection('rides')
            .doc(rideDoc.id)
            .update({
              'driverLocation': GeoPoint(position.latitude, position.longitude),
              'driverLastLocationUpdate': FieldValue.serverTimestamp(),
            });
      }
    } catch (e) {
      print('Error updating ride location: $e');
    }
  }

  /// Get driver's current location
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    bool permissionGranted = await requestLocationPermission();
    if (!permissionGranted) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Calculate distance between two points
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Get driver's location stream
  Stream<Position> get locationStream => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  );
}
