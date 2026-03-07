// Test script to demonstrate proximity filtering
// Run this in your Flutter app to test the new functionality

import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/services/firestore_service.dart';

void testProximityFiltering() async {
  print('🚀 Testing Proximity-Based Driver Filtering');
  
  // Example: Test with Bangalore coordinates
  final pickupLat = 12.9716;
  final pickupLng = 77.5946;
  
  print('📍 Pickup location: ($pickupLat, $pickupLng)');
  
  try {
    // Test the new proximity filtering method
    final nearbyDrivers = await FirestoreService.getNearbyAvailableDrivers(
      pickupLatitude: pickupLat,
      pickupLongitude: pickupLng,
      radiusInKm: 5.0,
    );
    
    print('📊 Found ${nearbyDrivers.length} nearby drivers:');
    
    if (nearbyDrivers.isNotEmpty) {
      for (var i = 0; i < nearbyDrivers.length; i++) {
        final driver = nearbyDrivers[i];
        final name = driver['name'] ?? 'Unknown Driver';
        final carModel = driver['carModel'] ?? 'Unknown Car';
        final distance = driver['distanceFromPickup']?.toStringAsFixed(2) ?? 'N/A';
        
        print('${i + 1}. $name - $carModel (${distance} km from pickup)');
      }
    } else {
      print('⚠️ No nearby drivers found within 5km radius');
      print('💡 Make sure drivers have:');
      print('   - isActive: true');
      print('   - isApproved: true'); 
      print('   - currentLocation: GeoPoint with valid coordinates');
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
}

// Example usage to update a driver's location for testing
void updateTestDriverLocation() async {
  // Replace with actual driver ID from your database
  final driverId = 'DRIVER_DOCUMENT_ID_HERE';
  
  // Set driver location near Bangalore
  await FirestoreService.updateDriverLocation(
    driverId: driverId,
    latitude: 12.9750,
    longitude: 77.6000,
  );
  
  print('✅ Driver location updated for testing');
}