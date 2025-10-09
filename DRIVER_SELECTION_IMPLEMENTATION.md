# Driver Selection Implementation

## Overview
This document describes the implementation of the driver selection feature where users can select a driver from the "Available Drivers" list, and all driver details are stored in the Firestore `rides` collection.

## Changes Made

### 1. Updated FirestoreService (`lib/services/firestore_service.dart`)

Enhanced the `updateRideWithDriver` method to store comprehensive driver information:

**Previous Implementation:**
- Only stored: `driverId`, `driverName`, `carModel`, `fare`

**New Implementation:**
Now stores all driver details in a structured format:

```dart
{
  'driverId': String,
  'driver': {
    'id': String,
    'name': String,
    'email': String?,
    'phoneNumber': String?,
    'rating': double,
    'imageUrl': String?,
  },
  'vehicle': {
    'carModel': String,
    'carNumber': String?,
  },
  'fare': double,
  'distance': double?,
  'status': 'matched',
  'matchedAt': Timestamp,
  'updatedAt': Timestamp,
}
```

**New Parameters Added:**
- `carNumber` - Vehicle registration number
- `rating` - Driver's rating
- `distance` - Distance for the ride in kilometers
- `driverEmail` - Driver's email address
- `driverPhoneNumber` - Driver's phone number
- `driverImageUrl` - Driver's profile image URL

### 2. Updated MapScreen (`lib/map_screen.dart`)

Modified the "Select Driver" button handler to pass all driver details:

**Changes:**
- Now passes all available driver information when calling `updateRideWithDriver`
- Includes: car number, rating, distance, email, phone number, and image URL
- Uses the calculated `distanceKm` from the route for accurate distance tracking

## Data Structure in Firestore

When a driver is selected, the following data is stored in the `rides` collection:

```json
{
  "rideId": "unique_ride_id",
  "riderId": "user_id",
  "rider": {
    "name": "User Name",
    "email": "user@example.com",
    "phoneNumber": "+1234567890",
    "userType": "user"
  },
  "pickupAddress": "Pickup Location Address",
  "destinationAddress": "Destination Address",
  "pickupLocation": GeoPoint(lat, lng),
  "destinationLocation": GeoPoint(lat, lng),
  "routeSummary": {
    "distanceKm": 26.6,
    "durationMin": 24
  },
  "driverId": "driver_user_id",
  "driver": {
    "id": "driver_user_id",
    "name": "Athulya Arun",
    "email": "driver@example.com",
    "phoneNumber": "+1234567890",
    "rating": 4.5,
    "imageUrl": "https://..."
  },
  "vehicle": {
    "carModel": "Maruti Suzuki Alto",
    "carNumber": "KL-01-AB-1234"
  },
  "fare": 433,
  "distance": 26.6,
  "status": "matched",
  "matchedAt": Timestamp,
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

## Features

### Driver Information Stored:
1. **Driver Details:**
   - Driver ID (userId)
   - Driver Name
   - Email Address
   - Phone Number
   - Rating (star rating)
   - Profile Image URL

2. **Vehicle Details:**
   - Car Model (e.g., "Maruti Suzuki Alto")
   - Car Number (registration number)

3. **Ride Details:**
   - Calculated Fare (based on distance and car model rates)
   - Distance (in kilometers)
   - Status (automatically set to "matched")
   - Timestamp when driver was matched

### Status Flow:
- `requested` → Initial ride request
- `matched` → Driver selected (current implementation)
- `enroute` → Driver on the way (future implementation)
- `completed` → Ride completed (future implementation)
- `cancelled` → Ride cancelled (future implementation)

## User Experience

1. User creates a ride request with pickup and destination addresses
2. System displays available drivers with:
   - Driver name and rating
   - Car model
   - Distance
   - Calculated fare
3. User clicks "Select Driver" button
4. System stores all driver and ride details in Firestore
5. User sees success message: "Driver [Name] selected successfully!"
6. Ride status changes to "matched"

## Error Handling

- If driver selection fails, user sees error message
- All errors are logged to console for debugging
- Transaction is atomic - either all data is saved or none

## Future Enhancements

Potential improvements:
1. Real-time driver location tracking
2. Driver acceptance/rejection of ride requests
3. In-app messaging between rider and driver
4. Live ride tracking
5. Payment integration
6. Ride history and receipts
7. Driver availability status updates

## Testing

To test the implementation:
1. Create a ride request from the home page
2. Navigate to the map screen
3. View available drivers in the right panel
4. Click "Select Driver" on any driver card
5. Check Firestore console to verify all data is stored correctly in the `rides` collection

## Notes

- The fare calculation is based on car model rates (base fare + per km rate)
- Distance is calculated using OSRM routing service
- All timestamps use Firestore server timestamps for consistency
- Driver data is denormalized for faster queries and better performance