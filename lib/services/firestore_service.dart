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

      print('✅ Driver approval status updated');
    } catch (e) {
      print('❌ Error updating driver approval: $e');
      throw Exception('Failed to update driver approval: $e');
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

      print('✅ Firestore debug completed successfully');
    } catch (e) {
      print('❌ Error during Firestore debug: $e');
      rethrow;
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
