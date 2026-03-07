import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'firestore_service.dart';

class RideCancellationService {
  static const Duration cancellationTimeout = Duration(minutes: 5);
  
  /// Check for ride requests that have exceeded the timeout period
  /// and automatically cancel them
  static Future<void> checkAndCancelExpiredRides() async {
    try {
      final now = Timestamp.now();
      final timeoutThreshold = Timestamp.fromDate(
        DateTime.now().subtract(cancellationTimeout),
      );
      
      // Query for rides with 'requested' status that were created before the timeout
      final querySnapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('status', isEqualTo: 'requested')
          .where('createdAt', isLessThan: timeoutThreshold)
          .get();
      
      for (final doc in querySnapshot.docs) {
        final rideData = doc.data();
        
        // Check if the ride was created more than 5 minutes ago
        final createdAt = rideData['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final rideCreatedTime = createdAt.toDate();
          final timeElapsed = DateTime.now().difference(rideCreatedTime);
          
          if (timeElapsed >= cancellationTimeout) {
            // Cancel the ride
            await _cancelRide(doc.id, rideData);
          }
        }
      }
    } catch (e) {
      print('Error checking for expired rides: $e');
    }
  }
  
  /// Cancel a specific ride due to timeout
  static Future<void> _cancelRide(String rideId, Map<String, dynamic> rideData) async {
    try {
      // Update the ride status to cancelled
      await FirestoreService.updateRideStatus(
        rideId,
        'cancelled',
        additionalData: {
          'cancellationReason': 'Driver did not respond within 5 minutes',
          'cancelledAt': FieldValue.serverTimestamp(),
        },
      );
      
      print('Ride $rideId has been cancelled due to timeout');
      
      // Show notification to the user about the cancellation
      // Note: Context is not available in this static method, so notification will be handled
      // by the UI when it detects the status change
    } catch (e) {
      print('Error cancelling ride $rideId: $e');
    }
  }
  
  /// Show notification to the user about the ride cancellation
  static void _showCancellationNotification(Map<String, dynamic> rideData) {
    // This method will be called when the UI is available
    // For now, we'll just print the notification details
    final pickupAddress = rideData['pickupAddress'] as String? ?? 'Unknown';
    final destinationAddress = rideData['destinationAddress'] as String? ?? 'Unknown';
    
    print('Ride cancelled notification:');
    print('  Pickup: $pickupAddress');
    print('  Destination: $destinationAddress');
    print('  Reason: Driver did not respond within 5 minutes');
  }
  
  /// Show cancellation notification with pickup and destination details
  static void showCancellationNotification(BuildContext? context, Map<String, dynamic> rideData) {
    final pickupAddress = rideData['pickupAddress'] as String? ?? 'Unknown';
    final destinationAddress = rideData['destinationAddress'] as String? ?? 'Unknown';
    
    if (context != null) {
      // Show a snackbar notification to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your ride has been cancelled.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('Pickup: $pickupAddress'),
              Text('Destination: $destinationAddress'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      // If no context is available, print the notification
      print('Ride cancelled notification:');
      print('  Pickup: $pickupAddress');
      print('  Destination: $destinationAddress');
      print('  Reason: Driver did not respond within 5 minutes');
    }
  }
  
  /// Start a periodic check for expired rides
  /// This should be called once when the app starts
  static void startPeriodicCheck() {
    // Check every minute for expired rides
    const checkInterval = Duration(minutes: 1);
    
    Timer.periodic(checkInterval, (timer) {
      checkAndCancelExpiredRides();
    });
  }
  
  /// Cancel a specific ride with timeout status immediately
  static Future<void> cancelRideForTimeout(String rideId) async {
    try {
      final ride = await FirestoreService.getRideById(rideId);
      if (ride != null && ride['status'] == 'requested') {
        await FirestoreService.cancelRideForTimeout(rideId);
      }
    } catch (e) {
      print('Error cancelling ride for timeout: $e');
    }
  }
  
  /// Set a timer to cancel a ride after 5 minutes if not accepted
  static void scheduleRideCancellation(String rideId, {Duration timeout = cancellationTimeout}) {
    // Use a delayed future to cancel the ride after the timeout
    Future.delayed(timeout).then((_) async {
      // Check if the ride still has 'requested' status
      final ride = await FirestoreService.getRideById(rideId);
      if (ride != null && ride['status'] == 'requested') {
        await cancelRideForTimeout(rideId);
      }
    });
  }
}