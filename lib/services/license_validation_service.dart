import 'firestore_service.dart';

class LicenseValidationService {
  // Initialize Kerala sample licenses in Firestore
  static Future<void> initializeKeralaSampleLicenses() async {
    try {
      await FirestoreService.initializeLicenseData();
    } catch (e) {
      print('Error initializing Kerala sample licenses: $e');
      rethrow;
    }
  }

  // Initialize licenses collection (alias for initializeKeralaSampleLicenses)
  static Future<void> initializeLicensesCollection() async {
    try {
      await FirestoreService.initializeLicenseData();
    } catch (e) {
      print('Error initializing licenses collection: $e');
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

    // Check if car number is already registered
    final isCarRegistered = await isCarNumberAlreadyRegistered(carNumber);
    if (isCarRegistered) {
      throw Exception('Car number is already registered by another driver');
    }

    // All validations passed
    print('✅ License and car number validation successful');
  }

  // Check if car number format is valid (Kerala format)
  static bool isValidCarNumberFormat(String carNumber) {
    // Kerala car number format: SSDD XX NNNN
    // SS = State code (KL)
    // DD = District code (01-14)
    // XX = Series (AA-ZZ)
    // NNNN = Number (0001-9999)
    final regex = RegExp(r'^KL\d{2} [A-Z]{2} \d{4}$');
    return regex.hasMatch(carNumber.toUpperCase());
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
