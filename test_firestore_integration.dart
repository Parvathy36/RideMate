import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';
import 'lib/services/firestore_service.dart';
import 'lib/services/license_validation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');

    // Test Firestore connection
    print('\n🔄 Testing Firestore connection...');
    final isConnected = await FirestoreService.testConnection();
    if (!isConnected) {
      print('❌ Firestore connection failed');
      return;
    }

    // Initialize Firestore with license data
    print('\n🔄 Initializing Firestore with license data...');
    await FirestoreService.initializeFirestore();

    // Test license validation
    print('\n🔄 Testing license validation...');
    await testLicenseValidation();

    // Test driver registration flow
    print('\n🔄 Testing driver registration flow...');
    await testDriverRegistrationFlow();

    print('\n✅ All tests completed successfully!');
  } catch (e) {
    print('❌ Test failed: $e');
  }
}

Future<void> testLicenseValidation() async {
  try {
    // Test valid license
    print('Testing valid license: KL01 20230000001');
    final validLicense = await LicenseValidationService.validateLicense(
      'KL01 20230000001',
    );
    if (validLicense != null) {
      print('✅ Valid license found: ${validLicense['name']}');
      print('   State: ${validLicense['state']}');
      print('   District: ${validLicense['district']}');
      print('   Expiry: ${validLicense['expiryDate']}');
    } else {
      print('❌ Valid license not found');
    }

    // Test invalid license
    print('\nTesting invalid license: KL99 99999999999');
    final invalidLicense = await LicenseValidationService.validateLicense(
      'KL99 99999999999',
    );
    if (invalidLicense == null) {
      print('✅ Invalid license correctly rejected');
    } else {
      print('❌ Invalid license incorrectly accepted');
    }

    // Test license format validation
    print('\nTesting license format validation...');
    final validFormats = ['KL01 20230000001', 'KL14 20240000015'];

    final invalidFormats = [
      'KL1 20230000001', // Missing digit
      'KL01 2023000001', // Wrong format
      'TN01 20230000001', // Wrong state
      'KL01-20230000001', // Wrong separator
    ];

    for (final format in validFormats) {
      final isValid = LicenseValidationService.isValidLicenseFormat(format);
      print('${isValid ? '✅' : '❌'} $format: ${isValid ? 'Valid' : 'Invalid'}');
    }

    for (final format in invalidFormats) {
      final isValid = LicenseValidationService.isValidLicenseFormat(format);
      print(
        '${!isValid ? '✅' : '❌'} $format: ${isValid ? 'Valid' : 'Invalid'} (should be invalid)',
      );
    }
  } catch (e) {
    print('❌ License validation test failed: $e');
  }
}

Future<void> testDriverRegistrationFlow() async {
  try {
    // Test car number format validation
    print('Testing car number format validation...');
    final validCarNumbers = ['KL01 AB 1234', 'KL14 XY 9999'];

    final invalidCarNumbers = [
      'KL1 AB 1234', // Missing digit
      'KL01 A 1234', // Single letter
      'KL01 AB 123', // Missing digit
      'TN01 AB 1234', // Wrong state
    ];

    for (final carNumber in validCarNumbers) {
      final isValid = LicenseValidationService.isValidCarNumberFormat(
        carNumber,
      );
      print(
        '${isValid ? '✅' : '❌'} $carNumber: ${isValid ? 'Valid' : 'Invalid'}',
      );
    }

    for (final carNumber in invalidCarNumbers) {
      final isValid = LicenseValidationService.isValidCarNumberFormat(
        carNumber,
      );
      print(
        '${!isValid ? '✅' : '❌'} $carNumber: ${isValid ? 'Valid' : 'Invalid'} (should be invalid)',
      );
    }

    // Test license already registered check
    print('\nTesting license registration check...');
    final isRegistered =
        await LicenseValidationService.isLicenseAlreadyRegistered(
          'KL01 20230000001',
        );
    print('License KL01 20230000001 already registered: $isRegistered');

    // Test car number already registered check
    print('\nTesting car number registration check...');
    final isCarRegistered =
        await LicenseValidationService.isCarNumberAlreadyRegistered(
          'KL01 AB 1234',
        );
    print('Car number KL01 AB 1234 already registered: $isCarRegistered');
  } catch (e) {
    print('❌ Driver registration flow test failed: $e');
  }
}
