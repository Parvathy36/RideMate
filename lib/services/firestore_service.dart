import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'license_validation_service.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection names
  static const String usersCollection = 'users';
  static const String driversCollection = 'drivers';
  static const String licensesCollection = 'licenses';
  static const String validLicensesCollection = 'valid_licenses';
  static const String carsCollection = 'cars';
  static const String ridesCollection = 'rides';
  static const String paymentsCollection = 'payments';

  // Get license document without validation (for expiry checking)
  static Future<Map<String, dynamic>?> getLicenseDocument(
    String licenseId,
  ) async {
    try {
      print('🔍 Getting license document: $licenseId');

      // Get license document
      final docSnapshot = await _firestore
          .collection(licensesCollection)
          .doc(licenseId.toUpperCase())
          .get();

      if (!docSnapshot.exists) {
        print('❌ License document not found');
        return null;
      }

      return docSnapshot.data()!;
    } catch (e) {
      print('❌ Error getting license document: $e');
      return null;
    }
  }

  // Create a new ride request in rides collection
  static Future<String?> createRideRequest({
    required String pickupAddress,
    required String destinationAddress,
    String? rideType,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not signed in');
      }

      // Load basic user data for denormalization (fast listing in admin/driver UIs)
      Map<String, dynamic>? userData;
      try {
        userData = await getUserData(user.uid);
      } catch (_) {
        userData = null;
      }

      final rideRef = _firestore.collection(ridesCollection).doc();
      final rideData = <String, dynamic>{
        'rideId': rideRef.id,
        'riderId': user.uid,
        'rider': {
          'name': userData?['name'] ?? user.displayName ?? 'User',
          'email': user.email,
          'phoneNumber': userData?['phoneNumber'],
          'userType': userData?['userType'] ?? 'user',
        },
        'pickupAddress': pickupAddress,
        'destinationAddress': destinationAddress,
        'rideType': rideType ?? 'Solo', // Default to Solo if not specified
        // Coordinates can be filled later when resolved on map screen
        'pickupLocation': null,
        'destinationLocation': null,
        'status':
            'requested', // requested -> matched -> enroute -> completed/cancelled
        'driverId': null,
        'participants': [user.uid],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (extra != null && extra.isNotEmpty) {
        rideData.addAll(extra);
      }

      await rideRef.set(rideData);
      return rideRef.id;
    } catch (e) {
      if (kIsWeb) {
        print('❌ Error creating ride request: $e');
      }
      return null;
    }
  }

  static Future<void> recordPayment({
    required String rideId,
    required double amount,
    required String method,
    required String reference,
    required String issuer,
    required String payerName,
    String? rideType,
    Map<String, dynamic>? driver,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not signed in');
      }

      Map<String, dynamic>? userData;
      try {
        userData = await getUserData(user.uid);
      } catch (_) {
        userData = null;
      }

      final paymentRef = _firestore.collection(paymentsCollection).doc();
      final paymentData = <String, dynamic>{
        'paymentId': paymentRef.id,
        'rideId': rideId,
        'riderId': user.uid,
        'rider': {
          'name': userData?['name'] ?? user.displayName ?? 'User',
          'email': user.email,
          'phoneNumber': userData?['phoneNumber'],
        },
        'method': method,
        'issuer': issuer,
        'reference': reference,
        'payerName': payerName,
        'amount': amount,
        'currency': 'INR',
        'status': 'completed',
        'rideType': rideType,
        'driver': driver,
        'metadata': metadata,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      paymentData.removeWhere((key, value) => value == null);
      await paymentRef.set(paymentData);
    } catch (e) {
      print('❌ Error recording payment: $e');
      rethrow;
    }
  }

  // Get a ride document by ID
  static Future<Map<String, dynamic>?> getRideById(String rideId) async {
    try {
      final doc = await _firestore
          .collection(ridesCollection)
          .doc(rideId)
          .get();
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    } catch (e) {
      print('❌ Error getting ride by id: $e');
      return null;
    }
  }

  // Update ride with resolved locations and optional summary
  static Future<void> updateRideLocations({
    required String rideId,
    required Map<String, double> pickup,
    required Map<String, double> destination,
    Map<String, dynamic>? summary,
  }) async {
    try {
      final update = <String, dynamic>{
        'pickupLocation': GeoPoint(pickup['latitude']!, pickup['longitude']!),
        'destinationLocation': GeoPoint(
          destination['latitude']!,
          destination['longitude']!,
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (summary != null) {
        update['routeSummary'] = summary;
      }
      await _firestore.collection(ridesCollection).doc(rideId).update(update);
    } catch (e) {
      print('❌ Error updating ride locations: $e');
    }
  }

  // Validate license ID and check expiry
  static Future<Map<String, dynamic>?> validateLicense(String licenseId) async {
    try {
      print('🔍 Validating license: $licenseId');

      // Get license document
      final docSnapshot = await _firestore
          .collection(licensesCollection)
          .doc(licenseId.toUpperCase())
          .get();

      if (!docSnapshot.exists) {
        print('❌ License not found');
        return null;
      }

      final licenseData = docSnapshot.data()!;

      // Check if license is active
      if (licenseData['isActive'] != true) {
        print('❌ License is not active');
        return null;
      }

      // Check expiry date
      final expiryDateString = licenseData['expiryDate'] as String;
      final expiryDate = DateTime.parse(expiryDateString);
      final currentDate = DateTime.now();

      if (expiryDate.isBefore(currentDate)) {
        print('❌ License is expired');
        return null;
      }

      print('✅ License is valid');
      return licenseData;
    } catch (e) {
      print('❌ Error validating license: $e');
      return null;
    }
  }

  // Check if license is already registered by another driver
  static Future<bool> isLicenseAlreadyRegistered(String licenseId) async {
    try {
      final querySnapshot = await _firestore
          .collection(usersCollection)
          .where('licenseId', isEqualTo: licenseId.toUpperCase())
          .where('userType', isEqualTo: 'driver')
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking license registration: $e');
      return false;
    }
  }

  // Check if car number is already registered by another driver
  static Future<bool> isCarNumberAlreadyRegistered(String carNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection(usersCollection)
          .where('carNumber', isEqualTo: carNumber.toUpperCase())
          .where('userType', isEqualTo: 'driver')
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking car number registration: $e');
      return false;
    }
  }

  // Get car document from cars collection
  static Future<Map<String, dynamic>?> getCarDocument(String carNumber) async {
    try {
      print('🔍 Getting car document: $carNumber');

      // Get car document using car number as document ID
      final docSnapshot = await _firestore
          .collection(carsCollection)
          .doc(carNumber.toUpperCase())
          .get();

      if (!docSnapshot.exists) {
        print('❌ Car document not found');
        return null;
      }

      return docSnapshot.data()!;
    } catch (e) {
      print('❌ Error getting car document: $e');
      return null;
    }
  }

  // Validate car number against cars collection
  static Future<Map<String, dynamic>?> validateCarNumber(
    String carNumber,
  ) async {
    try {
      print('🔍 Validating car number: $carNumber');

      // Get car document
      final carData = await getCarDocument(carNumber);

      if (carData == null) {
        print('❌ Car not found in database');
        return null;
      }

      // Check if car is valid
      if (carData['isValid'] != true) {
        print('❌ Car is not valid');
        return null;
      }

      print('✅ Car is valid');
      return carData;
    } catch (e) {
      print('❌ Error validating car number: $e');
      return null;
    }
  }

  // Create driver document with all required fields
  static Future<void> createDriverDocument({
    required String userId,
    required String name,
    required String email,
    required String phoneNumber,
    required String licenseId,
    required String carModel,
    required String carNumber,
    Map<String, dynamic>? licenseData,
  }) async {
    try {
      print('📝 Creating driver document for user: $userId');

      final driverData = {
        // Basic user information
        'userId': userId,
        'name': name,
        'email': email,
        'phoneNumber': phoneNumber,
        'userType': 'driver',

        // License information
        'licenseId': licenseId.toUpperCase(),
        'licenseHolderName': licenseData?['name'] ?? name,
        'licenseState': licenseData?['state'] ?? 'Kerala',
        'licenseDistrict': licenseData?['district'] ?? '',
        'licenseIssueDate': licenseData?['issueDate'] ?? '',
        'licenseExpiryDate': licenseData?['expiryDate'] ?? '',
        'vehicleClass': licenseData?['vehicleClass'] ?? 'LMV',

        // Vehicle information
        'carModel': carModel,
        'carNumber': carNumber.toUpperCase(),

        // Driver status
        'isApproved': false,
        'isActive': false,
        'isOnline': false,
        'isAvailable': false,

        // Registration details
        'registrationDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),

        // Additional fields for future use
        'rating': 0.0,
        'totalRides': 0,
        'totalEarnings': 0.0,
        'profileImageUrl': '',
        'licenseImageUrl': '',
        'documents': {
          'licenseVerified': false,
          'carRegistrationVerified': false,
          'insuranceVerified': false,
          'backgroundCheckVerified': false,
        },

        // Location data (will be updated when driver goes online)
        'currentLocation': null,
        'lastLocationUpdate': null,
      };

      // Create driver document in users collection
      await _firestore.collection(usersCollection).doc(userId).set(driverData);

      // Also create a separate document in drivers collection for easier querying
      await _firestore
          .collection(driversCollection)
          .doc(userId)
          .set(driverData);

      print('✅ Driver document created successfully');
    } catch (e) {
      print('❌ Error creating driver document: $e');
      throw Exception('Failed to create driver document: $e');
    }
  }

  // Update driver approval status
  static Future<void> updateDriverApprovalStatus({
    required String userId,
    required bool isApproved,
    String? adminNotes,
  }) async {
    try {
      final updateData = {
        'isApproved': isApproved,
        'isActive': isApproved, // Activate driver when approved
        'approvalDate': isApproved ? FieldValue.serverTimestamp() : null,
        'rejectionDate': !isApproved ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (adminNotes != null) {
        updateData['adminNotes'] = adminNotes;
        // Store rejection message separately for better tracking
        if (!isApproved) {
          updateData['rejectionMessage'] = adminNotes;
        }
      }

      // Update both collections
      await Future.wait([
        _firestore.collection(usersCollection).doc(userId).update(updateData),
        _firestore.collection(driversCollection).doc(userId).update(updateData),
      ]);

      print('✅ Driver approval status updated');
      if (!isApproved && adminNotes != null) {
        print('📝 Rejection message stored: $adminNotes');
      }
    } catch (e) {
      print('❌ Error updating driver approval: $e');
      throw Exception('Failed to update driver approval: $e');
    }
  }

  // Get rides for a specific user (rider)
  static Future<List<Map<String, dynamic>>> getRidesForUser(
    String userId,
  ) async {
    try {
      print('🔍 Fetching rides for user: $userId');

      // Query ONLY by riderId to avoid composite index requirements
      final querySnapshot = await _firestore
          .collection(ridesCollection)
          .where('riderId', isEqualTo: userId)
          .get();

      print('📊 Raw query returned ${querySnapshot.docs.length} documents');

      // Map docs to list and sort in memory to avoid index requirements
      final rides =
          querySnapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList()
            ..sort((a, b) {
              // Sort by createdAt descending in memory
              final aTimestamp = a['createdAt'];
              final bTimestamp = b['createdAt'];
              if (aTimestamp is Timestamp && bTimestamp is Timestamp) {
                return bTimestamp.compareTo(aTimestamp);
              }
              return 0;
            });

      print('📋 Filtered rides count: ${rides.length}');

      // Print details of each ride for debugging
      if (rides.isNotEmpty) {
        print('📋 Detailed ride information:');
        for (var i = 0; i < rides.length; i++) {
          final ride = rides[i];
          print('  Ride $i:');
          print('    ID: ${ride['id']}');
          print('    Status: ${ride['status'] ?? 'N/A'}');
          print('    Rider ID: ${ride['riderId'] ?? 'N/A'}');
          print('    Rider Name: ${ride['rider']?['name'] ?? 'N/A'}');
          print('    Pickup: ${ride['pickupAddress'] ?? 'N/A'}');
          print('    Destination: ${ride['destinationAddress'] ?? 'N/A'}');
          print('    Fare: ${ride['fare'] ?? 'N/A'}');
          print('    Created At: ${ride['createdAt'] ?? 'N/A'}');
        }
      }

      return rides;
    } catch (e, stackTrace) {
      print('❌ Error fetching rides for user $userId: $e');
      print('_STACK TRACE: $stackTrace');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getRidesForDriver(
    String driverId, {
    String? driverEmail,
    List<String>? allowedStatuses,
  }) async {
    try {
      print('🔍 Fetching rides for driver: $driverId');
      if (driverEmail != null) {
        print('📧 Filtering by driver email: $driverEmail');
      }
      if (allowedStatuses != null && allowedStatuses.isNotEmpty) {
        print('📌 Allowed statuses: ${allowedStatuses.join(', ')}');
      }

      // Query ONLY by driverId to avoid composite index requirements
      // We'll do all other filtering in memory
      final querySnapshot = await _firestore
          .collection(ridesCollection)
          .where('driverId', isEqualTo: driverId)
          .get(); // Removed orderBy to avoid any potential index issues

      print('📊 Raw query returned ${querySnapshot.docs.length} documents');

      // Filter in memory to avoid composite index requirements
      final rides =
          querySnapshot.docs
              .map((doc) {
                // Safely extract data from document
                final data = doc.data();
                return {
                  'id': doc.id,
                  ...?data, // Use null-aware spread operator
                };
              })
              .where((ride) {
                try {
                  // Filter by status if provided
                  if (allowedStatuses != null && allowedStatuses.isNotEmpty) {
                    final rideStatus = ride['status'] as String?;
                    if (rideStatus == null ||
                        !allowedStatuses.contains(rideStatus)) {
                      return false;
                    }
                  }

                  // Filter by email if provided
                  if (driverEmail != null) {
                    final rideDriverEmail =
                        ride['driver']?['email'] as String? ??
                        ride['driverEmail'] as String?;
                    if (rideDriverEmail != driverEmail) {
                      return false;
                    }
                  }

                  return true;
                } catch (e) {
                  print('⚠️ Error filtering ride ${ride['id']}: $e');
                  return false; // Exclude rides that cause filtering errors
                }
              })
              // Sort in memory to maintain the same order
              .toList()
            ..sort((a, b) {
              final aTimestamp = a['createdAt'];
              final bTimestamp = b['createdAt'];
              if (aTimestamp is Timestamp && bTimestamp is Timestamp) {
                return bTimestamp.compareTo(aTimestamp);
              }
              return 0;
            });

      print('📋 Filtered rides count: ${rides.length}');

      // Print details of each ride for debugging
      if (rides.isNotEmpty) {
        print('📋 Detailed ride information:');
        for (var i = 0; i < rides.length; i++) {
          final ride = rides[i];
          print('  Ride $i:');
          print('    ID: ${ride['id']}');
          print('    Status: ${ride['status'] ?? 'N/A'}');
          print('    Driver ID: ${ride['driverId'] ?? 'N/A'}');
          print('    Rider Name: ${ride['rider']?['name'] ?? 'N/A'}');
          print('    Pickup: ${ride['pickupAddress'] ?? 'N/A'}');
          print('    Destination: ${ride['destinationAddress'] ?? 'N/A'}');
          print('    Fare: ${ride['fare'] ?? 'N/A'}');
          print('    Created At: ${ride['createdAt'] ?? 'N/A'}');
        }
      } else {
        print('⚠️ No rides found matching the criteria after filtering');
        // Let's also check what rides exist for this driver with any status
        _checkDriverRidesWithAnyStatus(driverId);
      }

      return rides;
    } catch (e, stackTrace) {
      print('❌ Error fetching rides for driver $driverId: $e');
      print('_STACK TRACE: $stackTrace');
      return [];
    }
  }

  // Add this helper method to check rides with any status
  static Future<void> _checkDriverRidesWithAnyStatus(String driverId) async {
    try {
      print('🔍 Checking rides for driver $driverId with ANY status...');
      final allRides = await _firestore
          .collection(ridesCollection)
          .where('driverId', isEqualTo: driverId)
          .get();

      print(
        '📊 Found ${allRides.docs.length} rides for driver $driverId with any status',
      );

      if (allRides.docs.isNotEmpty) {
        final statusMap = <String, int>{};

        print('📋 Rides breakdown by status:');
        for (final doc in allRides.docs) {
          final data = doc.data();
          final status = data['status'] as String? ?? 'unknown';
          statusMap[status] = (statusMap[status] ?? 0) + 1;

          print('  Ride ID: ${doc.id}');
          print('    Status: $status');
          print('    Rider: ${data['rider']?['name'] ?? 'N/A'}');
          print('    Pickup: ${data['pickupAddress'] ?? 'N/A'}');
          print('    Destination: ${data['destinationAddress'] ?? 'N/A'}');
        }

        print('📊 Status summary:');
        statusMap.forEach((status, count) {
          print('  $status: $count rides');
        });
      } else {
        print('⚠️ No rides found for driver $driverId with any status');
      }
    } catch (e) {
      print('❌ Error checking rides with any status: $e');
    }
  }

  // Create shared ride request in shared_rides collection
  static Future<void> createSharedRideRequest({
    required String rideId,
    required String targetRideId,
    required int numberOfMembers,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not signed in');
      }

      // Get current ride details
      final currentRide = await getRideById(rideId);
      final targetRide = await getRideById(targetRideId);

      if (currentRide == null || targetRide == null) {
        throw Exception('Ride not found');
      }

      final sharedRideRef = _firestore.collection('shared_rides').doc();
      final sharedRideData = <String, dynamic>{
        'sharedRideId': sharedRideRef.id,
        'requesterRideId': rideId,
        'requesterUserId': user.uid,
        'requesterDetails': {
          'name': currentRide['rider']?['name'] ?? user.displayName ?? 'User',
          'email': user.email,
        },
        'targetRideId': targetRideId,
        'targetUserId': targetRide['riderId'],
        'targetUserDetails': {
          'name': targetRide['rider']?['name'] ?? 'Unknown User',
          'email': targetRide['rider']?['email'],
        },
        'numberOfMembers': numberOfMembers,
        'pickupAddress': currentRide['pickupAddress'],
        'destinationAddress': currentRide['destinationAddress'],
        'status': 'pending', // pending -> accepted -> rejected
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await sharedRideRef.set(sharedRideData);
    } catch (e) {
      print('❌ Error creating shared ride request: $e');
      throw Exception('Failed to create shared ride request: $e');
    }
  }

  // Update ride with assigned driver details
  static Future<void> updateRideWithDriver({
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
      final updateData = {
        'status': 'requested',
        'driverId': driverId,
        'driver': {
          'id': driverId,
          'name': driverName,
          'carModel': carModel,
          'carNumber': carNumber,
          'rating': rating,
          'distance': distance,
          'email': driverEmail,
          'phoneNumber': driverPhoneNumber,
          'imageUrl': driverImageUrl,
          'fareEstimate': fare,
        },
        'fare': fare,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(ridesCollection)
          .doc(rideId)
          .update(updateData);
    } catch (e) {
      print('❌ Error updating ride with driver: $e');
      rethrow;
    }
  }

  // Cancel ride due to timeout
  static Future<void> cancelRideForTimeout(String rideId) async {
    try {
      final updateData = {
        'status': 'cancelled',
        'cancellationReason': 'Driver did not respond within 5 minutes',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(ridesCollection)
          .doc(rideId)
          .update(updateData);
    } catch (e) {
      print('❌ Error cancelling ride for timeout: $e');
      rethrow;
    }
  }

  // Update ride status (e.g., confirmed, cancelled, completed)
  static Future<void> updateRideStatus(
    String rideId,
    String status, {
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        if (additionalData != null) ...additionalData,
      };

      await _firestore
          .collection(ridesCollection)
          .doc(rideId)
          .update(updateData);
    } catch (e) {
      print('❌ Error updating ride status: $e');
      throw Exception('Failed to update ride status: $e');
    }
  }

  // Update ride with payment information
  static Future<void> updateRideWithPayment({
    required String rideId,
    required bool isPaid,
    String? paymentMethod,
    String? transactionId,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'isPaid': isPaid,
        'paymentMethod': paymentMethod,
        'transactionId': transactionId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Remove null values
      updateData.removeWhere((key, value) => value == null);

      await _firestore
          .collection(ridesCollection)
          .doc(rideId)
          .update(updateData);

      print('✅ Ride payment information updated successfully');
    } catch (e) {
      print('❌ Error updating ride payment information: $e');
      throw Exception('Failed to update ride payment information: $e');
    }
  }

  // Update driver active status (enable/disable)
  static Future<void> updateDriverStatus({
    required String userId,
    required bool isActive,
    String? adminNotes,
  }) async {
    try {
      final updateData = {
        'isActive': isActive,
        'isOnline': isActive ? false : false, // Set offline when disabled
        'isAvailable': isActive
            ? false
            : false, // Set unavailable when disabled
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (adminNotes != null) {
        updateData['adminNotes'] = adminNotes;
      }

      // Update both collections
      await Future.wait([
        _firestore.collection(usersCollection).doc(userId).update(updateData),
        _firestore.collection(driversCollection).doc(userId).update(updateData),
      ]);

      print('✅ Driver status updated: ${isActive ? 'enabled' : 'disabled'}');
    } catch (e) {
      print('❌ Error updating driver status: $e');
      throw Exception('Failed to update driver status: $e');
    }
  }

  // Get all pending drivers for admin approval
  static Future<List<Map<String, dynamic>>> getPendingDrivers() async {
    try {
      final querySnapshot = await _firestore
          .collection(driversCollection)
          .where('isApproved', isEqualTo: false)
          .orderBy('registrationDate', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('❌ Error getting pending drivers: $e');
      return [];
    }
  }

  // Get all approved drivers
  static Future<List<Map<String, dynamic>>> getApprovedDrivers() async {
    try {
      final querySnapshot = await _firestore
          .collection(driversCollection)
          .where('isApproved', isEqualTo: true)
          .orderBy('registrationDate', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('❌ Error getting approved drivers: $e');
      return [];
    }
  }

  // Get all active drivers
  static Future<List<Map<String, dynamic>>> getActiveDrivers() async {
    try {
      final querySnapshot = await _firestore
          .collection(driversCollection)
          .where('isActive', isEqualTo: true)
          .orderBy('registrationDate', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('❌ Error getting active drivers: $e');
      return [];
    }
  }

  // Get available drivers (both isActive: true and isApproved: true)
  static Future<List<Map<String, dynamic>>> getAvailableDrivers() async {
    try {
      print('🔍 Fetching all drivers from collection...');

      // Get all drivers from the collection
      final querySnapshot = await _firestore
          .collection(driversCollection)
          .get();

      print('📋 Total drivers in collection: ${querySnapshot.docs.length}');

      // Filter drivers where both isActive and isApproved are true
      final availableDrivers = <Map<String, dynamic>>[];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final driverName = data['name'] ?? 'Unknown';
        final isActive = data['isActive'];
        final isApproved = data['isApproved'];

        print('👤 Driver: $driverName (ID: ${doc.id})');
        print('   - isActive: $isActive');
        print('   - isApproved: $isApproved');

        // Check if both isActive and isApproved are true
        if (isActive == true && isApproved == true) {
          print('   ✅ Driver is available!');
          availableDrivers.add({'id': doc.id, ...data});
        } else {
          print('   ❌ Driver is not available');
        }
      }

      print(
        '📊 Found ${availableDrivers.length} available drivers out of ${querySnapshot.docs.length} total drivers',
      );
      return availableDrivers;
    } catch (e) {
      print('❌ Error getting available drivers: $e');
      return [];
    }
  }

  // Get nearby available drivers within a specified radius
  static Future<List<Map<String, dynamic>>> getNearbyAvailableDrivers({
    required double pickupLatitude,
    required double pickupLongitude,
    double radiusInKm = 5.0, // Default 5km radius
  }) async {
    try {
      print('🔍 Fetching nearby drivers within ${radiusInKm}km radius...');
      print('📍 Pickup location: ($pickupLatitude, $pickupLongitude)');

      // Get all drivers from the collection
      final querySnapshot = await _firestore
          .collection(driversCollection)
          .get();

      print('📋 Total drivers in collection: ${querySnapshot.docs.length}');

      // Filter drivers where both isActive and isApproved are true AND within radius
      final nearbyDrivers = <Map<String, dynamic>>[];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final driverName = data['name'] ?? 'Unknown';
        final isActive = data['isActive'];
        final isApproved = data['isApproved'];
        final currentLocation = data['currentLocation'];

        print('👤 Driver: $driverName (ID: ${doc.id})');
        print('   - isActive: $isActive');
        print('   - isApproved: $isApproved');
        print('   - Current Location: $currentLocation');

        // Check if both isActive and isApproved are true
        if (isActive == true && isApproved == true) {
          // Check if driver has current location
          if (currentLocation != null && currentLocation is GeoPoint) {
            // Calculate distance between pickup and driver location
            final driverLat = currentLocation.latitude;
            final driverLng = currentLocation.longitude;
            
            // Calculate distance using Haversine formula
            final distanceKm = _calculateDistance(
              pickupLatitude,
              pickupLongitude,
              driverLat,
              driverLng,
            );

            print('   📍 Driver distance: ${distanceKm.toStringAsFixed(2)} km');

            // Check if driver is within the specified radius
            if (distanceKm <= radiusInKm) {
              print('   ✅ Driver is nearby and available!');
              // Add distance to driver data for display
              nearbyDrivers.add({
                'id': doc.id,
                'distanceFromPickup': distanceKm,
                ...data,
              });
            } else {
              print('   ❌ Driver is too far away (${distanceKm.toStringAsFixed(2)} km)');
            }
          } else {
            print('   ⚠️ Driver location not available');
          }
        } else {
          print('   ❌ Driver is not available (inactive or not approved)');
        }
      }

      print(
        '📊 Found ${nearbyDrivers.length} nearby drivers within ${radiusInKm}km radius',
      );
      return nearbyDrivers;
    } catch (e) {
      print('❌ Error getting nearby drivers: $e');
      return [];
    }
  }

  // Helper method to calculate distance between two coordinates (Haversine formula)
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0; // Earth's radius in kilometers

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  // Helper method to convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  // Utility method to update driver location for testing
  static Future<void> updateDriverLocation({
    required String driverId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final locationData = {
        'currentLocation': GeoPoint(latitude, longitude),
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      };

      // Update in both collections
      await Future.wait([
        _firestore.collection(usersCollection).doc(driverId).update(locationData),
        _firestore.collection(driversCollection).doc(driverId).update(locationData),
      ]);

      print('✅ Driver location updated successfully');
    } catch (e) {
      print('❌ Error updating driver location: $e');
      throw Exception('Failed to update driver location: $e');
    }
  }

  // Get all drivers (both pending and approved)
  static Future<List<Map<String, dynamic>>> getAllDrivers() async {
    try {
      final querySnapshot = await _firestore
          .collection(driversCollection)
          .orderBy('registrationDate', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('❌ Error getting all drivers: $e');
      return [];
    }
  }

  // Get all drivers with detailed status information for debugging
  static Future<List<Map<String, dynamic>>> getAllDriversWithStatus() async {
    try {
      print('🔍 Fetching all drivers with status information...');

      final querySnapshot = await _firestore
          .collection(driversCollection)
          .get();

      final allDrivers = <Map<String, dynamic>>[];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final driverInfo = {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'carModel': data['carModel'] ?? 'Unknown',
          'carNumber': data['carNumber'] ?? 'Unknown',
          'isActive': data['isActive'] ?? false,
          'isApproved': data['isApproved'] ?? false,
          'isOnline': data['isOnline'] ?? false,
          'isAvailable': data['isAvailable'] ?? false,
          'rating': data['rating'] ?? 0.0,
          ...data,
        };

        allDrivers.add(driverInfo);

        print('👤 ${driverInfo['name']} (${driverInfo['carModel']})');
        print('   - isActive: ${driverInfo['isActive']}');
        print('   - isApproved: ${driverInfo['isApproved']}');
        print('   - isOnline: ${driverInfo['isOnline']}');
        print('   - isAvailable: ${driverInfo['isAvailable']}');
      }

      print('📊 Total drivers found: ${allDrivers.length}');
      return allDrivers;
    } catch (e) {
      print('❌ Error getting all drivers with status: $e');
      return [];
    }
  }

  // Get driver by ID
  static Future<Map<String, dynamic>?> getDriverById(String userId) async {
    try {
      final docSnapshot = await _firestore
          .collection(driversCollection)
          .doc(userId)
          .get();

      if (docSnapshot.exists) {
        return {'id': docSnapshot.id, ...docSnapshot.data()!};
      }
      return null;
    } catch (e) {
      print('❌ Error getting driver by ID: $e');
      return null;
    }
  }

  // Get driver data by user ID
  static Future<Map<String, dynamic>?> getDriverData(String userId) async {
    try {
      final docSnapshot = await _firestore
          .collection(driversCollection)
          .doc(userId)
          .get();

      if (docSnapshot.exists) {
        return {'id': docSnapshot.id, ...docSnapshot.data()!};
      }
      return null;
    } catch (e) {
      print('❌ Error getting driver data: $e');
      return null;
    }
  }

  // Get user data by user ID from users collection
  static Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      print('🔍 Getting user data for: $userId');

      final docSnapshot = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .get();

      if (docSnapshot.exists) {
        final userData = docSnapshot.data()!;
        print('✅ User data found: ${userData['userType']}');
        return {'id': docSnapshot.id, ...userData};
      }

      print('❌ User data not found');
      return null;
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  // Get users by userType (e.g., 'user', 'admin', 'driver')
  static Future<List<Map<String, dynamic>>> getUsersByType(
    String userType,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(usersCollection)
          .where('userType', isEqualTo: userType)
          // Removed orderBy to avoid composite index requirement; we'll sort client-side
          .get();

      final users = querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      // Sort by createdAt descending if available
      users.sort((a, b) {
        final at = a['createdAt'];
        final bt = b['createdAt'];
        if (at is Timestamp && bt is Timestamp) {
          return bt.compareTo(at);
        }
        return 0;
      });

      print('👥 Loaded users of type "$userType": ${users.length}');
      return users;
    } catch (e) {
      print('❌ Error getting users by type: $e');
      return [];
    }
  }

  // Update driver online status
  static Future<void> updateDriverOnlineStatus({
    required String userId,
    required bool isOnline,
    required bool isAvailable,
    Map<String, double>? location,
  }) async {
    try {
      final updateData = {
        'isOnline': isOnline,
        'isAvailable': isAvailable,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (location != null) {
        updateData['currentLocation'] = GeoPoint(
          location['latitude']!,
          location['longitude']!,
        );
        updateData['lastLocationUpdate'] = FieldValue.serverTimestamp();
      }

      // Update both collections
      await Future.wait([
        _firestore.collection(usersCollection).doc(userId).update(updateData),
        _firestore.collection(driversCollection).doc(userId).update(updateData),
      ]);

      print('✅ Driver online status updated');
    } catch (e) {
      print('❌ Error updating driver online status: $e');
      throw Exception('Failed to update driver online status: $e');
    }
  }

  // Get nearby available drivers
  static Future<List<Map<String, dynamic>>> getNearbyDrivers({
    required double latitude,
    required double longitude,
    double radiusInKm = 10.0,
  }) async {
    try {
      // Note: For production, you should use GeoFlutterFire or similar for proper geospatial queries
      // This is a simplified version
      final querySnapshot = await _firestore
          .collection(driversCollection)
          .where('isApproved', isEqualTo: true)
          .where('isOnline', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('❌ Error getting nearby drivers: $e');
      return [];
    }
  }

  // Test Firestore connection
  static Future<bool> testConnection() async {
    try {
      print('🔄 Testing Firestore connection...');

      // Try to read from a collection
      await _firestore
          .collection('test')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      print('✅ Firestore connection successful');
      return true;
    } catch (e) {
      print('❌ Firestore connection failed: $e');
      return false;
    }
  }

  // Initialize admin user if not exists
  static Future<void> initializeAdminUser() async {
    try {
      print('🔄 Checking for admin user...');

      const adminEmail = 'parvathysuresh36@gmail.com';

      // Check if admin user already exists in users collection
      final adminQuery = await _firestore
          .collection(usersCollection)
          .where('email', isEqualTo: adminEmail)
          .where('userType', isEqualTo: 'admin')
          .limit(1)
          .get();

      if (adminQuery.docs.isEmpty) {
        print('🔄 Creating admin user document...');

        // Create admin user document (this will be used when admin signs in)
        // Note: The actual Firebase Auth user will be created when admin signs in
        final adminDoc = _firestore.collection(usersCollection).doc();
        await adminDoc.set({
          'name': 'Admin',
          'email': adminEmail,
          'userType': 'admin',
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });

        print('✅ Admin user document created');
      } else {
        print('ℹ️ Admin user already exists');
      }
    } catch (e) {
      print('❌ Error initializing admin user: $e');
      // Don't throw error as this is not critical for app functionality
    }
  }

  // Initialize all required collections and data
  static Future<void> initializeFirestore() async {
    try {
      print('🔄 Initializing Firestore...');

      // Test connection first
      final isConnected = await testConnection();
      if (!isConnected) {
        throw Exception('Firestore connection failed');
      }

      // Initialize license data
      await LicenseValidationService.initializeLicensesCollection();

      // Initialize admin user
      await initializeAdminUser();

      print('✅ Firestore initialization completed');
    } catch (e) {
      print('❌ Firestore initialization failed: $e');
      throw Exception('Failed to initialize Firestore: $e');
    }
  }

  // Debug Firestore access and collections
  static Future<void> debugFirestoreAccess() async {
    try {
      print('🔍 Starting Firestore debug...');

      // Test 1: Check connection
      print('📡 Testing Firestore connection...');
      final isConnected = await testConnection();
      if (!isConnected) {
        throw Exception('Firestore connection failed');
      }

      // Test 2: Check licenses collection
      print('📋 Checking licenses collection...');
      final licensesSnapshot = await _firestore
          .collection(licensesCollection)
          .limit(5)
          .get();
      print('📊 Found ${licensesSnapshot.docs.length} license documents');

      // Test 3: List some license IDs
      if (licensesSnapshot.docs.isNotEmpty) {
        print('🔍 Sample license IDs:');
        for (final doc in licensesSnapshot.docs) {
          final data = doc.data();
          print('  - ${doc.id}: ${data['name']} (${data['district']})');
        }
      } else {
        print(
          '⚠️ No licenses found - you may need to initialize the collection',
        );
      }

      // Test 4: Check users collection
      print('👥 Checking users collection...');
      final usersSnapshot = await _firestore
          .collection(usersCollection)
          .limit(3)
          .get();
      print('📊 Found ${usersSnapshot.docs.length} user documents');

      // Test 5: Check drivers collection
      print('🚗 Checking drivers collection...');
      final driversSnapshot = await _firestore
          .collection(driversCollection)
          .limit(3)
          .get();
      print('📊 Found ${driversSnapshot.docs.length} driver documents');

      // Test 6: Check rides collection
      print('🚕 Checking rides collection...');
      final ridesSnapshot = await _firestore
          .collection(ridesCollection)
          .limit(5)
          .get();
      print('📊 Found ${ridesSnapshot.docs.length} ride documents');

      if (ridesSnapshot.docs.isNotEmpty) {
        print('🔍 Sample rides:');
        for (final doc in ridesSnapshot.docs) {
          final data = doc.data();
          print('  - Ride ID: ${doc.id}');
          print('    Status: ${data['status'] ?? 'N/A'}');
          print('    Driver ID: ${data['driverId'] ?? 'N/A'}');
          print('    Rider: ${data['rider']?['name'] ?? 'N/A'}');
          print('    Pickup: ${data['pickupAddress'] ?? 'N/A'}');
          print('    Destination: ${data['destinationAddress'] ?? 'N/A'}');
          print('    Fare: ${data['fare'] ?? 'N/A'}');
          print('    ---');
        }
      }

      print('✅ Firestore debug completed successfully');
    } catch (e) {
      print('❌ Error during Firestore debug: $e');
      rethrow;
    }
  }

  // Test method to fetch all rides (for debugging purposes)
  static Future<List<Map<String, dynamic>>> getAllRides() async {
    try {
      print('🔍 Fetching all rides (no filters)');
      final querySnapshot = await _firestore
          .collection(ridesCollection)
          .orderBy('createdAt', descending: true)
          .get();

      print('📊 Found ${querySnapshot.docs.length} total rides');

      final rides = querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      // Print details of each ride for debugging
      for (var i = 0; i < rides.length && i < 5; i++) {
        final ride = rides[i];
        print(
          'Ride $i: ID=${ride['id']}, Status=${ride['status']}, DriverId=${ride['driverId']}, Rider=${ride['rider']?['name']}',
        );
      }

      return rides;
    } catch (e) {
      print('❌ Error fetching all rides: $e');
      return [];
    }
  }

  // Comprehensive debug method to check rides for a specific driver
  static Future<void> debugRidesForDriver(String driverId) async {
    try {
      print('🔍 Debugging rides for driver: $driverId');

      // 1. Check if driver document exists
      final driverDoc = await _firestore
          .collection(driversCollection)
          .doc(driverId)
          .get();

      if (driverDoc.exists) {
        print('✅ Driver document found');
        final driverData = driverDoc.data()!;
        print('  Name: ${driverData['name']}');
        print('  Email: ${driverData['email']}');
      } else {
        print('❌ Driver document NOT found for ID: $driverId');
        return;
      }

      // 2. Count total rides in collection
      final totalRidesSnapshot = await _firestore
          .collection(ridesCollection)
          .limit(1)
          .get();
      print('📊 Total rides in collection: ${totalRidesSnapshot.size}');

      // 3. Check rides with this driver ID (any status)
      final allDriverRides = await _firestore
          .collection(ridesCollection)
          .where('driverId', isEqualTo: driverId)
          .get();
      print(
        '🚗 Rides with driverId=$driverId (any status): ${allDriverRides.size}',
      );

      // Print details of these rides
      for (final doc in allDriverRides.docs) {
        final data = doc.data();
        print('  Ride ID: ${doc.id}');
        print('    Status: ${data['status']}');
        print('    Rider: ${data['rider']?['name'] ?? 'N/A'}');
        print('    Pickup: ${data['pickupAddress'] ?? 'N/A'}');
        print('    Destination: ${data['destinationAddress'] ?? 'N/A'}');
      }

      // 4. Check rides with this driver ID and status='requested'
      final requestedRides = await _firestore
          .collection(ridesCollection)
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'requested')
          .get();
      print(
        '📬 Rides with driverId=$driverId and status=requested: ${requestedRides.size}',
      );

      // Print details of these rides
      for (final doc in requestedRides.docs) {
        final data = doc.data();
        print('  Ride ID: ${doc.id}');
        print('    Rider: ${data['rider']?['name'] ?? 'N/A'}');
        print('    Pickup: ${data['pickupAddress'] ?? 'N/A'}');
        print('    Destination: ${data['destinationAddress'] ?? 'N/A'}');
      }

      // 5. Check rides with this driver ID and status='accepted'
      final acceptedRides = await _firestore
          .collection(ridesCollection)
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'accepted')
          .get();
      print(
        '👍 Rides with driverId=$driverId and status=accepted: ${acceptedRides.size}',
      );

      print('✅ Debug completed');
    } catch (e) {
      print('❌ Error during driver rides debug: $e');
    }
  }

  // Check police clearance status for a driver by license ID
  static Future<Map<String, dynamic>?> checkPoliceClearance(
    String licenseId,
  ) async {
    try {
      print('🔍 Checking police clearance for license: $licenseId');

      final doc = await _firestore
          .collection('policeclear')
          .doc(licenseId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        print('✅ Police clearance found: ${data['police_clearance']}');
        return data;
      } else {
        print('⚠️ No police clearance record found for license: $licenseId');
        return null;
      }
    } catch (e) {
      print('❌ Error checking police clearance: $e');
      return null;
    }
  }

  // Get police clearance status for multiple drivers
  static Future<Map<String, Map<String, dynamic>>> getPoliceClearanceForDrivers(
    List<String> licenseIds,
  ) async {
    try {
      print('🔍 Checking police clearance for ${licenseIds.length} drivers');

      final Map<String, Map<String, dynamic>> clearanceData = {};

      // Use batch get for better performance
      for (final licenseId in licenseIds) {
        final doc = await _firestore
            .collection('policeclear')
            .doc(licenseId)
            .get();

        if (doc.exists) {
          clearanceData[licenseId] = doc.data() as Map<String, dynamic>;
        }
      }

      print(
        '✅ Found police clearance data for ${clearanceData.length} drivers',
      );
      return clearanceData;
    } catch (e) {
      print('❌ Error getting police clearance data: $e');
      return {};
    }
  }
}
