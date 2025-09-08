import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class LicenseValidationService {
  // Initialize Kerala sample licenses collection (creates dummy data if not exists)
  static Future<void> initializeKeralaSampleLicenses() async {
    try {
      print('🔄 Initializing Kerala sample licenses...');

      // Access the Firestore instance directly
      final firestore = FirebaseFirestore.instance;

      // Check if licenses collection already has data
      final existingLicenses = await firestore
          .collection(FirestoreService.licensesCollection)
          .limit(1)
          .get();

      if (existingLicenses.docs.isNotEmpty) {
        print('ℹ️ Licenses collection already has data');
        return;
      }

      // Sample license data matching the screenshot
      final sampleLicenses = [
        {
          'name': 'Maruti Suzuki Alto',
          'district': 'Thiruvananthapuram',
          'state': 'Kerala',
          'issueDate': '2023-01-15',
          'expiryDate': '2043-01-14',
          'vehicleClass': 'LMV',
          'isActive': true,
          'ownerName': 'Abhijya Arun',
        },
        {
          'name': 'Honda City',
          'district': 'Kochi',
          'state': 'Kerala',
          'issueDate': '2022-03-10',
          'expiryDate': '2042-03-09',
          'vehicleClass': 'LMV',
          'isActive': true,
          'ownerName': 'Rajesh Kumar',
        },
        {
          'name': 'Hyundai i20',
          'district': 'Chennai',
          'state': 'Tamil Nadu',
          'issueDate': '2021-06-20',
          'expiryDate': '2041-06-19',
          'vehicleClass': 'LMV',
          'isActive': true,
          'ownerName': 'Priya Sharma',
        },
        {
          'name': 'Tata Nexon',
          'district': 'Mumbai',
          'state': 'Maharashtra',
          'issueDate': '2020-12-05',
          'expiryDate': '2040-12-04',
          'vehicleClass': 'LMV',
          'isActive': true,
          'ownerName': 'Amit Patel',
        },
        {
          'name': 'Toyota Innova',
          'district': 'Delhi',
          'state': 'Delhi',
          'issueDate': '2019-09-15',
          'expiryDate': '2039-09-14',
          'vehicleClass': 'LMV',
          'isActive': true,
          'ownerName': 'Suresh Singh',
        },
      ];

      // License IDs to match the screenshot
      final licenseIds = [
        'KL01 AB1234',
        'KL05 AC1234',
        'TN9Z4321',
        'MH20A1',
        'DL8CAB9999',
      ];

      // Add sample licenses to Firestore
      for (int i = 0; i < sampleLicenses.length; i++) {
        await firestore
            .collection(FirestoreService.licensesCollection)
            .doc(licenseIds[i])
            .set(sampleLicenses[i]);
      }

      print('✅ Kerala sample licenses initialized successfully');
    } catch (e) {
      print('❌ Error initializing Kerala sample licenses: $e');
      rethrow;
    }
  }

  // Initialize sample cars collection (creates dummy data if not exists)
  static Future<void> initializeSampleCars() async {
    try {
      print('🔄 Initializing sample cars...');

      // Access the Firestore instance directly
      final firestore = FirebaseFirestore.instance;

      // Check if cars collection already has data
      final existingCars = await firestore
          .collection(FirestoreService.carsCollection)
          .limit(1)
          .get();

      if (existingCars.docs.isNotEmpty) {
        print('ℹ️ Cars collection already has data');
        return;
      }

      // Sample car data matching the screenshot
      final sampleCars = [
        {
          'carModel': 'Maruti Suzuki Alto',
          'ownerName': 'Abhijya Arun',
          'district': 'Thiruvananthapuram',
          'state': 'Kerala',
          'isValid': true,
        },
        {
          'carModel': 'Honda City',
          'ownerName': 'Rajesh Kumar',
          'district': 'Kochi',
          'state': 'Kerala',
          'isValid': true,
        },
        {
          'carModel': 'Hyundai i20',
          'ownerName': 'Priya Sharma',
          'district': 'Chennai',
          'state': 'Tamil Nadu',
          'isValid': true,
        },
        {
          'carModel': 'Tata Nexon',
          'ownerName': 'Amit Patel',
          'district': 'Mumbai',
          'state': 'Maharashtra',
          'isValid': true,
        },
        {
          'carModel': 'Toyota Innova',
          'ownerName': 'Suresh Singh',
          'district': 'Delhi',
          'state': 'Delhi',
          'isValid': true,
        },
      ];

      // Car numbers to match the screenshot
      final carNumbers = [
        'KL01 AB1234',
        'KL05 AC1234',
        'TN9Z4321',
        'MH20A1',
        'DL8CAB9999',
      ];

      // Add sample cars to Firestore
      for (int i = 0; i < sampleCars.length; i++) {
        await firestore
            .collection(FirestoreService.carsCollection)
            .doc(carNumbers[i])
            .set(sampleCars[i]);
      }

      print('✅ Sample cars initialized successfully');
    } catch (e) {
      print('❌ Error initializing sample cars: $e');
      rethrow;
    }
  }

  // Initialize licenses collection (validates existing data or creates if empty)
  static Future<void> initializeLicensesCollection() async {
    try {
      print('🔄 Initializing licenses collection...');

      // Access the Firestore instance directly
      final firestore = FirebaseFirestore.instance;

      // Get count of existing licenses
      final licensesSnapshot = await firestore
          .collection(FirestoreService.licensesCollection)
          .get();

      final licensesCount = licensesSnapshot.docs.length;
      print('📊 Found $licensesCount licenses in collection');

      // Get count of existing cars
      final carsSnapshot = await firestore
          .collection(FirestoreService.carsCollection)
          .get();

      final carsCount = carsSnapshot.docs.length;
      print('📊 Found $carsCount cars in collection');

      // Get count of police clearances
      final policeClearSnapshot = await firestore
          .collection('policeclear')
          .get();

      final policeClearCount = policeClearSnapshot.docs.length;
      print('📊 Found $policeClearCount police clearance records');

      if (licensesCount == 0) {
        print('⚠️ No licenses found, initializing sample data...');
        await initializeKeralaSampleLicenses();
      }

      if (carsCount == 0) {
        print('⚠️ No cars found, initializing sample data...');
        await initializeSampleCars();
      }

      // After initialization, get final counts
      final finalLicensesSnapshot = await firestore
          .collection(FirestoreService.licensesCollection)
          .get();

      final finalCarsSnapshot = await firestore
          .collection(FirestoreService.carsCollection)
          .get();

      final finalLicensesCount = finalLicensesSnapshot.docs.length;
      final finalCarsCount = finalCarsSnapshot.docs.length;

      print('✅ Licenses collection initialization completed');
      print('📋 Collection summary:');
      print('  • Licenses: $finalLicensesCount documents');
      print('  • Cars: $finalCarsCount documents');
      print('  • Police Clearances: $policeClearCount documents');
    } catch (e) {
      print('❌ Error initializing licenses collection: $e');
      rethrow;
    }
  }

  // Debug Firestore access and connectivity
  static Future<void> debugFirestoreAccess() async {
    try {
      await FirestoreService.debugFirestoreAccess();
    } catch (e) {
      print('Error during Firestore debug: $e');
      rethrow;
    }
  }

  // Check if license ID exists and is valid (includes expiry check)
  static Future<Map<String, dynamic>?> validateLicense(String licenseId) async {
    try {
      // Validate from Firestore only (includes expiry date validation)
      final firestoreResult = await FirestoreService.validateLicense(licenseId);
      return firestoreResult;
    } catch (e) {
      print('Error validating license: $e');
      return null;
    }
  }

  // Check if license exists but is expired
  static Future<Map<String, String>?> checkLicenseExpiry(
    String licenseId,
  ) async {
    try {
      print('🔍 Checking license expiry: $licenseId');

      // Get license document directly without expiry validation
      final docSnapshot = await FirestoreService.getLicenseDocument(licenseId);

      if (docSnapshot == null) {
        return {
          'status': 'not_found',
          'message': 'License ID not found in database',
        };
      }

      final licenseData = docSnapshot;

      // Check if license is active
      if (licenseData['isActive'] != true) {
        return {'status': 'inactive', 'message': 'License is not active'};
      }

      // Parse and check expiry date
      final expiryDateString = licenseData['expiryDate'] as String;
      final expiryDate = DateTime.parse(expiryDateString);
      final currentDate = DateTime.now();

      if (expiryDate.isBefore(currentDate)) {
        final daysDifference = currentDate.difference(expiryDate).inDays;
        return {
          'status': 'expired',
          'message': 'License expired on $expiryDateString',
          'expiryDate': expiryDateString,
          'daysExpired': daysDifference.toString(),
        };
      } else {
        final daysUntilExpiry = expiryDate.difference(currentDate).inDays;
        return {
          'status': 'valid',
          'message': 'License is valid',
          'expiryDate': expiryDateString,
          'daysUntilExpiry': daysUntilExpiry.toString(),
        };
      }
    } catch (e) {
      print('❌ Error checking license expiry: $e');
      return {
        'status': 'error',
        'message': 'Error checking license expiry: $e',
      };
    }
  }

  // Get detailed license validation result with expiry information
  static Future<Map<String, dynamic>> validateLicenseDetailed(
    String licenseId,
  ) async {
    try {
      // First check format
      if (!isValidLicenseFormat(licenseId)) {
        return {
          'isValid': false,
          'status': 'invalid_format',
          'message':
              'Invalid license format. Use Kerala format: KLDD YYYYNNNNNNN',
        };
      }

      // Check expiry status
      final expiryResult = await checkLicenseExpiry(licenseId);

      if (expiryResult == null) {
        return {
          'isValid': false,
          'status': 'error',
          'message': 'Error checking license',
        };
      }

      final status = expiryResult['status']!;

      if (status == 'not_found') {
        return {
          'isValid': false,
          'status': 'not_found',
          'message': 'License ID not found in database',
        };
      }

      if (status == 'inactive') {
        return {
          'isValid': false,
          'status': 'inactive',
          'message': 'License is not active',
        };
      }

      if (status == 'expired') {
        return {
          'isValid': false,
          'status': 'expired',
          'message': expiryResult['message']!,
          'expiryDate': expiryResult['expiryDate'],
          'daysExpired': expiryResult['daysExpired'],
        };
      }

      if (status == 'valid') {
        // Get full license data
        final licenseData = await validateLicense(licenseId);
        return {
          'isValid': true,
          'status': 'valid',
          'message': 'License is valid',
          'licenseData': licenseData,
          'expiryDate': expiryResult['expiryDate'],
          'daysUntilExpiry': expiryResult['daysUntilExpiry'],
        };
      }

      return {
        'isValid': false,
        'status': 'error',
        'message': expiryResult['message'] ?? 'Unknown error',
      };
    } catch (e) {
      print('❌ Error in detailed license validation: $e');
      return {
        'isValid': false,
        'status': 'error',
        'message': 'Error validating license: $e',
      };
    }
  }

  // Check if license is already registered by another driver
  static Future<bool> isLicenseAlreadyRegistered(String licenseId) async {
    return await FirestoreService.isLicenseAlreadyRegistered(licenseId);
  }

  // Check if car number is already registered by another driver
  static Future<bool> isCarNumberAlreadyRegistered(String carNumber) async {
    return await FirestoreService.isCarNumberAlreadyRegistered(carNumber);
  }

  // Validate car number against cars collection in Firestore
  static Future<Map<String, dynamic>?> validateCarNumber(
    String carNumber,
  ) async {
    try {
      // Validate from Firestore cars collection
      final carData = await FirestoreService.validateCarNumber(carNumber);
      return carData;
    } catch (e) {
      print('Error validating car number: $e');
      return null;
    }
  }

  // Get detailed car validation result
  static Future<Map<String, dynamic>> validateCarNumberDetailed(
    String carNumber,
  ) async {
    try {
      // First check format
      if (!isValidCarNumberFormat(carNumber)) {
        return {
          'isValid': false,
          'status': 'invalid_format',
          'message': 'Invalid car number format. Use Indian format: SSRRXXNNNN',
        };
      }

      // Check if car exists and is valid in database
      final carData = await validateCarNumber(carNumber);

      if (carData == null) {
        return {
          'isValid': false,
          'status': 'not_found',
          'message': 'Car number not found in database',
        };
      }

      if (carData['isValid'] != true) {
        return {
          'isValid': false,
          'status': 'invalid',
          'message': 'Car is not valid for registration',
        };
      }

      return {
        'isValid': true,
        'status': 'valid',
        'message': 'Car is valid for registration',
        'carData': carData,
      };
    } catch (e) {
      print('❌ Error in detailed car validation: $e');
      return {
        'isValid': false,
        'status': 'error',
        'message': 'Error validating car number: $e',
      };
    }
  }

  // Get car owner name by car number
  static Future<String?> getCarOwnerName(String carNumber) async {
    try {
      final carData = await validateCarNumber(carNumber);
      return carData?['ownerName'];
    } catch (e) {
      print('Error getting car owner name: $e');
      return null;
    }
  }

  // Validate license and car number together
  static Future<void> validateLicenseAndCarNumber(
    String licenseId,
    String carNumber,
  ) async {
    // Check if license is valid
    final licenseData = await validateLicense(licenseId);
    if (licenseData == null) {
      throw Exception('Invalid or expired license ID');
    }

    // Check if car number format is valid
    if (!isValidCarNumberFormat(carNumber)) {
      throw Exception('Invalid car number format');
    }

    // Check if car number exists and is valid in database
    final carData = await validateCarNumber(carNumber);
    if (carData == null) {
      throw Exception('Car number not found in database');
    }

    if (carData['isValid'] != true) {
      throw Exception('Car is not valid for registration');
    }

    // Check if car number is already registered
    final isCarRegistered = await isCarNumberAlreadyRegistered(carNumber);
    if (isCarRegistered) {
      throw Exception('Car number is already registered by another driver');
    }

    // All validations passed
    print('✅ License and car number validation successful');
  }

  // Check if car number format is valid (Indian format)
  static bool isValidCarNumberFormat(String carNumber) {
    // Indian car number format: SS RR XX NNNN or SSRRXXNNNN (without spaces)
    // SS = State code (2 letters: KL, TN, MH, etc.)
    // RR = RTO code (1-2 digits: 01, 9, 20, etc.)
    // XX = Series (1-2 letters: A, AB, Z, etc.) - optional depending on registration batch
    // NNNN = Vehicle number (1-4 digits: 1, 1234, 9999, etc.)

    // Remove all spaces and convert to uppercase
    String cleanNumber = carNumber.replaceAll(' ', '').toUpperCase();

    // Pattern: 2 letters + 1-2 digits + 1-2 letters + 1-4 digits
    // Examples: KL01AB1234, TN9Z4321, MH20A1, DL8CAB9999
    final regex = RegExp(r'^[A-Z]{2}\d{1,2}[A-Z]{1,2}\d{1,4}$');

    if (!regex.hasMatch(cleanNumber)) {
      return false;
    }

    // Additional validation: ensure it's not malformed
    // Should start with 2 letters (state code)
    if (!RegExp(r'^[A-Z]{2}').hasMatch(cleanNumber)) {
      return false;
    }

    // Should not be all letters or all numbers
    if (RegExp(r'^[A-Z]+$').hasMatch(cleanNumber) ||
        RegExp(r'^\d+$').hasMatch(cleanNumber)) {
      return false;
    }

    // Should have proper structure: letters-digits-letters-digits
    if (!RegExp(r'^[A-Z]{2}\d+[A-Z]+\d+$').hasMatch(cleanNumber)) {
      return false;
    }

    return true;
  }

  // Format car number to standard format
  static String formatCarNumber(String carNumber) {
    return carNumber.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // Get license holder name by license ID
  static Future<String?> getLicenseHolderName(String licenseId) async {
    try {
      final licenseData = await validateLicense(licenseId);
      return licenseData?['name'];
    } catch (e) {
      print('Error getting license holder name: $e');
      return null;
    }
  }

  // Check if license ID format is valid (Kerala format)
  static bool isValidLicenseFormat(String licenseId) {
    // Kerala license format: SSDD YYYYNNNNNNN
    // SS = State code (KL)
    // DD = District code (27, etc.)
    // YYYY = Year (2020, 2023)
    // NNNNNNN = Unique 7-digit number
    final regex = RegExp(r'^KL\d{2} \d{4}\d{7}$');
    return regex.hasMatch(licenseId.toUpperCase());
  }

  // Validate license format and extract information
  static Map<String, String>? parseLicenseId(String licenseId) {
    if (!isValidLicenseFormat(licenseId)) {
      return null;
    }

    final upperLicenseId = licenseId.toUpperCase();

    // Format: SSDD YYYYNNNNNNN
    // Example: KL27 20231234567
    final parts = upperLicenseId.split(' ');
    if (parts.length != 2) return null;

    final firstPart = parts[0]; // SSDD (KL27)
    final secondPart = parts[1]; // YYYYNNNNNNN (20231234567)

    if (firstPart.length != 4 || secondPart.length != 11) return null;

    final stateCode = firstPart.substring(0, 2); // KL
    final districtCode = firstPart.substring(2, 4); // 27
    final year = secondPart.substring(0, 4); // 2023
    final uniqueNumber = secondPart.substring(4); // 1234567

    return {
      'stateCode': stateCode,
      'districtCode': districtCode,
      'year': year,
      'uniqueNumber': uniqueNumber,
      'fullLicenseId': upperLicenseId,
    };
  }
}
