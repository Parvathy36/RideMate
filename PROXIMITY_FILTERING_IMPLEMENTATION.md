# Proximity-Based Driver Filtering Implementation

## Overview
This implementation adds proximity-based filtering to the Available Drivers section in map_screen.dart. Only drivers within a 5km radius of the user's pickup location will be displayed.

## Changes Made

### 1. Updated FirestoreService (lib/services/firestore_service.dart)

Added new method:
```dart
static Future<List<Map<String, dynamic>>> getNearbyAvailableDrivers({
  required double pickupLatitude,
  required double pickupLongitude,
  double radiusInKm = 5.0,
})
```

Features:
- Fetches all drivers from Firestore
- Filters for drivers where `isActive: true` and `isApproved: true`
- Calculates distance between pickup location and each driver's current location
- Returns only drivers within the specified radius
- Adds `distanceFromPickup` field to each driver's data

Added helper methods:
```dart
static double _calculateDistance(double lat1, double lon1, double lat2, double lon2)
static double _degreesToRadians(double degrees)
```

### 2. Updated MapScreen (lib/map_screen.dart)

Modified `_getAvailableDrivers()` method:
- Now uses `getNearbyAvailableDrivers()` instead of `getAvailableDrivers()`
- Passes pickup location coordinates to the proximity filter
- Sets default radius to 5km

Enhanced Driver model:
- Modified `fromFirestore()` factory to use `distanceFromPickup` when available
- Falls back to rating-based distance estimation if proximity data unavailable
- Added debug logging to show which distance calculation method is used

UI improvements:
- Changed "Distance" label to "Distance from pickup" for clarity

## How It Works

1. When a user views the map screen with a ride request:
   - The pickup location is resolved (either from stored coordinates or geocoded)
   - `_getAvailableDrivers()` is called to fetch nearby drivers

2. The proximity filtering process:
   - Fetches all drivers from Firestore
   - For each driver, checks if they are active and approved
   - If driver has location data, calculates distance to pickup
   - Only includes drivers within 5km radius
   - Adds calculated distance to driver data

3. Display:
   - Only nearby drivers are shown in the Available Drivers list
   - Each driver card shows their distance from the pickup location
   - Distance is used for fare calculation

## Requirements

For this feature to work properly, drivers must:
1. Have `isActive: true` and `isApproved: true` in their Firestore document
2. Have `currentLocation` field populated with GeoPoint data
3. Be within the specified radius (default 5km) of the pickup location

## Testing

To test this implementation:
1. Ensure driver documents have `currentLocation` GeoPoint fields
2. Set different pickup locations to verify radius filtering
3. Check that only nearby drivers appear in the list
4. Verify distance calculations are accurate

## Customization

The radius can be adjusted by modifying the `radiusInKm` parameter in `_getAvailableDrivers()`:
```dart
final driversData = await FirestoreService.getNearbyAvailableDrivers(
  pickupLatitude: _pickup!.latitude,
  pickupLongitude: _pickup!.longitude,
  radiusInKm: 10.0, // Change this value as needed
);
```

## Performance Notes

- The implementation fetches all drivers then filters client-side
- For production apps with many drivers, consider using GeoFlutterFire or similar geospatial indexing solutions
- Distance calculations use the Haversine formula for accuracy