import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';
import 'location_service.dart';

class DriverAssignmentService {
  static const Duration driverAcceptanceTimeout = Duration(minutes: 5);

  /// Assign a driver automatically to a ride and set up 5-minute timeout
  static Future<void> assignDriverToRide({
    required String rideId,
    required String driverId,
    required String driverName,
    required String carModel,
    required double fare,
    required String carNumber,
    required double rating,
    required double distance,
    String? driverEmail,
    String? driverPhoneNumber,
    String? driverImageUrl,
  }) async {
    try {
      // Update ride with driver information and set status to 'request'
      await FirestoreService.updateRideWithDriver(
        rideId: rideId,
        driverId: driverId,
        driverName: driverName,
        carModel: carModel,
        fare: fare,
        carNumber: carNumber,
        rating: rating,
        distance: distance,
        driverEmail: driverEmail,
        driverPhoneNumber: driverPhoneNumber,
        driverImageUrl: driverImageUrl,
      );

      // Schedule timeout to cancel ride if driver doesn't accept within 5 minutes
      scheduleDriverAcceptanceTimeout(rideId);

      print('Driver assigned to ride $rideId. Timeout scheduled for 5 minutes.');
    } catch (e) {
      print('Error assigning driver to ride: $e');
      rethrow;
    }
  }

  /// Schedule a timeout to cancel the ride if driver doesn't accept within 5 minutes
  static void scheduleDriverAcceptanceTimeout(String rideId) {
    Future.delayed(driverAcceptanceTimeout).then((_) async {
      try {
        // Check if the ride still has 'request' status
        final ride = await FirestoreService.getRideById(rideId);
        if (ride != null && ride['status'] == 'request') {
          // Cancel the ride due to timeout using service method which handles notifications
          await FirestoreService.cancelRideForTimeout(rideId);
          print('Ride $rideId cancelled due to driver acceptance timeout');
        }
      } catch (e) {
        print('Error handling driver acceptance timeout for ride $rideId: $e');
      }
    });
  }

  /// Mark ride as completed
  static Future<void> completeRide(String rideId) async {
    try {
      await FirestoreService.updateRideStatus(
        rideId,
        'completed',
        additionalData: {
          'completedAt': FieldValue.serverTimestamp(),
        },
      );
      print('Ride $rideId marked as completed');
    } catch (e) {
      print('Error completing ride $rideId: $e');
      rethrow;
    }
  }

  /// Check if ride is finished (driver has arrived at destination)
  static Future<bool> isRideFinished(String rideId) async {
    try {
      final ride = await FirestoreService.getRideById(rideId);
      if (ride == null) return false;

      final destinationLocation = ride['destinationLocation'] as GeoPoint?;
      final driverLocation = ride['driverLocation'] as GeoPoint?;

      if (destinationLocation == null || driverLocation == null) {
        return false;
      }

      // Calculate distance between driver and destination
      final distance = LocationService().calculateDistance(
        driverLocation.latitude,
        driverLocation.longitude,
        destinationLocation.latitude,
        destinationLocation.longitude,
      );

      // Consider ride finished if driver is within 50 meters of destination
      return distance <= 50;
    } catch (e) {
      print('Error checking if ride is finished: $e');
      return false;
    }
  }

  /// Get available drivers near pickup location
  static Future<List<Map<String, dynamic>>> getAvailableDriversNearPickup({
    required double pickupLat,
    required double pickupLng,
    double radiusKm = 5.0, // Default 5km radius
  }) async {
    try {
      final driversSnapshot = await FirebaseFirestore.instance
          .collection('drivers')
          .where('isAvailable', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .get();

      final availableDrivers = <Map<String, dynamic>>[];

      for (final doc in driversSnapshot.docs) {
        final driverData = doc.data();
        final driverLocation = driverData['currentLocation'] as GeoPoint?;

        if (driverLocation != null) {
          final distance = LocationService().calculateDistance(
            pickupLat,
            pickupLng,
            driverLocation.latitude,
            driverLocation.longitude,
          );

          // Convert distance to kilometers
          final distanceKm = distance / 1000;

          if (distanceKm <= radiusKm) {
            availableDrivers.add({
              'id': doc.id,
              'distance': distanceKm,
              ...driverData,
            });
          }
        }
      }

      // Sort by distance (closest first)
      availableDrivers.sort((a, b) => (a['distance'] as double)
          .compareTo(b['distance'] as double));

      return availableDrivers;
    } catch (e) {
      print('Error fetching available drivers: $e');
      return [];
    }
  }

  /// Assign the closest available driver automatically
  static Future<Map<String, dynamic>?> assignClosestDriver({
    required String rideId,
    required double pickupLat,
    required double pickupLng,
    double radiusKm = 5.0,
  }) async {
    try {
      final availableDrivers = await getAvailableDriversNearPickup(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        radiusKm: radiusKm,
      );

      if (availableDrivers.isEmpty) {
        print('No available drivers found within $radiusKm km');
        return null;
      }

      // Get the closest driver
      final closestDriver = availableDrivers.first;

      // Get ride details to calculate fare
      final ride = await FirestoreService.getRideById(rideId);
      if (ride == null) return null;

      final distanceKm = closestDriver['distance'] as double;
      final baseFare = (closestDriver['baseFare'] as num?)?.toDouble() ?? 50.0;
      final perKmRate = (closestDriver['perKmRate'] as num?)?.toDouble() ?? 15.0;
      final fare = baseFare + (distanceKm * perKmRate);

      // Assign driver to ride
      await assignDriverToRide(
        rideId: rideId,
        driverId: closestDriver['id'] as String,
        driverName: closestDriver['name'] as String,
        carModel: closestDriver['carModel'] as String,
        fare: fare,
        carNumber: closestDriver['carNumber'] as String? ?? '',
        rating: (closestDriver['rating'] as num?)?.toDouble() ?? 0.0,
        distance: distanceKm,
        driverEmail: closestDriver['email'] as String?,
        driverPhoneNumber: closestDriver['phoneNumber'] as String?,
        driverImageUrl: closestDriver['imageUrl'] as String?,
      );

      return {
        'driver': closestDriver,
        'fare': fare,
        'distance': distanceKm,
      };
    } catch (e) {
      print('Error assigning closest driver: $e');
      return null;
    }
  }
}