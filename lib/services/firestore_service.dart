import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection names
  static const String usersCollection = 'users';
  static const String driversCollection = 'drivers';
  static const String licensesCollection = 'licenses';
  static const String validLicensesCollection = 'valid_licenses';

  // Initialize Firestore with sample license data
  static Future<void> initializeLicenseData() async {
    try {
      print('🔄 Initializing license data in Firestore...');

      // Sample Kerala license data
      final sampleLicenses = [
        {
          "licenseId": "KL01 20230000001",
          "name": "Rajesh Kumar",
          "state": "Kerala",
          "district": "Thiruvananthapuram",
          "issueDate": "2023-01-15",
          "expiryDate": "2043-01-15",
          "vehicleClass": "LMV",
          "isActive": true,
          "createdAt": FieldValue.serverTimestamp(),
        },
        {
          "licenseId": "KL02 20230000002",
          "name": "Priya Nair",
          "state": "Kerala",
          "district": "Kochi",
          "issueDate": "2023-02-20",
          "expiryDate": "2043-02-20",
          "vehicleClass": "LMV",
          "isActive": true,
          "createdAt": FieldValue.serverTimestamp(),
        },
        {
          "licenseId": "KL03 20230000003",
          "name": "Arjun Krishnan",
          "state": "Kerala",
          "district": "Pathanamthitta",
          "issueDate": "2023-03-10",
          "expiryDate": "2043-03-10",
          "vehicleClass": "LMV",
          "isActive": true,
          "createdAt": FieldValue.serverTimestamp(),
        },
        {
          "licenseId": "KL04 20230000004",
          "name": "Deepika R",
          "state": "Kerala",
          "district": "Ernakulam",
          "issueDate": "2023-04-05",
          "expiryDate": "2043-04-05",
          "vehicleClass": "LMV",
          "isActive": true,
          "createdAt": FieldValue.serverTimestamp(),
        },
        {
          "licenseId": "KL05 20230000005",
          "name": "Viknesh K",
          "state": "Kerala",
          "district": "Kozhikode",
          "issueDate": "2023-05-12",
          "expiryDate": "2043-05-12",
          "vehicleClass": "LMV",
          "isActive": true,
          "createdAt": FieldValue.serverTimestamp(),
        },
        {
          "licenseId": "KL06 20230000006",
          "name": "Neha M",
          "state": "Kerala",
          "district": "Kollam",
          "issueDate": "2023-06-18",
          "expiryDate": "2043-06-18",
          "vehicleClass": "LMV",
          "isActive": true,
          "createdAt": FieldValue.serverTimestamp(),
        },
        {
          "licenseId": "KL07 20230000007",
          "name": "Amit S",
          "state": "Kerala",
          "district": "Pathanamthitta",
          "issueDate": "2023-07-25",
          "expiryDate": "2043-07-25",
          "vehicleClass": "LMV",
          "isActive": true,
          "createdAt": FieldValue.serverTimestamp(),
        },
        {
          "licenseId": "KL08 20230000008",
          "name": "Rajeev M",
          "state": "Kerala",
          "district": "Thiruvananthapuram",
          "issueDate": "2023-08-30",
          "expiryDate": "2043-08-30",
          "vehicleClass": "LMV",
          "isActive": true,
          "createdAt": FieldValue.serverTimestamp(),
        },
        {
          "licenseId": "KL09 20230000009",
          "name": "Sunita Mohan",
          "state": "Kerala",
          "district": "Kollam",
          "issueDate": "2023-09-14",
          "expiryDate": "2043-09-14",
          "vehicleClass": "LMV",
          "isActive": true,
          "createdAt": FieldValue.serverTimestamp(),
        },
        {
          "licenseId": "KL10 20230000010",
          "name": "Harpreet S",
          "state": "Kerala",
          "district": "Kottayam",
          "issueDate": "2023-10-08",
          "expiryDate": "2043-10-08",
          "vehicleClass": "LMV",
          "isActive": true,
          "createdAt": FieldValue.serverTimestamp(),
        },
        {
          "licenseId": "KL11 20230000011",
          "name": "Sourav S",
          "state": "Kerala",
          "district": "Kottayam",
          "issueDate": "2023-11-22",
          "expiryDate": "2043-11-22",
          "vehicleClass": "LMV",
          "isActive": true,
          "createdAt": FieldValue.serverTimestamp(),
        },
        {
          "licenseId": "KL12 20230000012",
          "name": "Lakshmi R",
          "state": "Kerala",
          "district": "Pathanamthitta",
          "issueDate": "2023-12-03",
          "expiryDate": "2043-12-03",
          "vehicleClass": "LMV",
          "isActive": true,
          "createdAt": FieldValue.serverTimestamp(),
        },
        {
          "licenseId": "KL13 20240000013",
          "name": "Kiran Kumar",
          "state": "Kerala",
          "district": "Kozhikode",
          "issueDate": "2024-01-16",
          "expiryDate": "2044-01-16",
          "vehicleClass": "LMV",
          "isActive": true,
          "createdAt": FieldValue.serverTimestamp(),
        },
        {
          "licenseId": "KL14 20240000014",
          "name": "Bijay Mohan",
          "state": "Kerala",
          "district": "Thrissur",
          "issueDate": "2024-02-28",
          "expiryDate": "2044-02-28",
          "vehicleClass": "LMV",
          "isActive": true,
          "createdAt": FieldValue.serverTimestamp(),
        },
        {
          "licenseId": "KL15 20240000015",
          "name": "Rahul Mohan",
          "state": "Kerala",
          "district": "Ernakulam",
          "issueDate": "2024-03-11",
          "expiryDate": "2044-03-11",
          "vehicleClass": "LMV",
          "isActive": true,
          "createdAt": FieldValue.serverTimestamp(),
        },
      ];

      // Check if licenses already exist
      final existingLicenses = await _firestore
          .collection(licensesCollection)
          .limit(1)
          .get();

      if (existingLicenses.docs.isEmpty) {
        // Use batch to add all licenses
        final batch = _firestore.batch();

        for (final license in sampleLicenses) {
          final docRef = _firestore
              .collection(licensesCollection)
              .doc(license['licenseId'] as String);
          batch.set(docRef, license);
        }

        await batch.commit();
        print('✅ License data initialized successfully');
      } else {
        print('ℹ️ License data already exists');
      }
    } catch (e) {
      print('❌ Error initializing license data: $e');
      throw Exception('Failed to initialize license data: $e');
    }
  }

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
      await initializeLicenseData();

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
}
