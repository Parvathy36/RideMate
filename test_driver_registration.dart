import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';
import 'lib/services/auth_service.dart';
import 'lib/services/firestore_service.dart';
import 'lib/services/license_validation_service.dart';

/// Test script to verify the driver registration flow
/// This script tests the complete driver registration process
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
    
    // Initialize license data
    await FirestoreService.initializeLicenseData();
    print('✅ License data initialized');
    
    // Test the driver registration flow
    await testDriverRegistrationFlow();
    
  } catch (e) {
    print('❌ Test failed: $e');
  }
}

Future<void> testDriverRegistrationFlow() async {
  print('\n🧪 Testing Driver Registration Flow...\n');
  
  final authService = AuthService();
  
  // Test data
  final testEmail = 'test_driver_${DateTime.now().millisecondsSinceEpoch}@example.com';
  const testPassword = 'TestPassword123!';
  const testName = 'Test Driver';
  const testPhone = '+919876543210';
  const testLicenseId = 'KL01 20230000001'; // This should exist in sample data
  const testCarModel = 'Maruti Swift';
  
  try {
    print('📝 Step 1: Validating license ID...');
    
    // Test license validation
    final licenseData = await LicenseValidationService.validateLicense(testLicenseId);
    if (licenseData == null) {
      print('❌ License validation failed - license not found or expired');
      return;
    }
    print('✅ License validation successful');
    print('   License holder: ${licenseData['name']}');
    print('   Expiry date: ${licenseData['expiryDate']}');
    
    print('\n📝 Step 2: Checking if license is already registered...');
    
    // Check if license is already registered
    final isLicenseRegistered = await FirestoreService.isLicenseAlreadyRegistered(testLicenseId);
    if (isLicenseRegistered) {
      print('⚠️  License is already registered - this is expected for repeated tests');
    } else {
      print('✅ License is available for registration');
    }
    
    print('\n📝 Step 3: Attempting driver registration...');
    
    // Attempt driver registration
    final result = await authService.registerWithEmailAndPassword(
      testEmail,
      testPassword,
      testName,
      isDriver: true,
      phoneNumber: testPhone,
      licenseId: testLicenseId,
      carModel: testCarModel,
    );
    
    if (result != null) {
      print('✅ Driver registration successful!');
      print('   User ID: ${result.user?.uid}');
      print('   Email: ${result.user?.email}');
      
      print('\n📝 Step 4: Verifying driver document creation...');
      
      // Verify driver document was created
      final driverDoc = await FirestoreService.getDriverById(result.user!.uid);
      if (driverDoc != null) {
        print('✅ Driver document created successfully');
        print('   Name: ${driverDoc['name']}');
        print('   License ID: ${driverDoc['licenseId']}');
        print('   Car Model: ${driverDoc['carModel']}');
        print('   Approval Status: ${driverDoc['isApproved']}');
        print('   Active Status: ${driverDoc['isActive']}');
      } else {
        print('❌ Driver document not found');
      }
      
      print('\n📝 Step 5: Cleaning up test data...');
      
      // Clean up - delete the test user
      try {
        await result.user?.delete();
        print('✅ Test user deleted successfully');
      } catch (e) {
        print('⚠️  Could not delete test user: $e');
      }
      
    } else {
      print('❌ Driver registration failed - no result returned');
    }
    
  } catch (e) {
    print('❌ Driver registration failed with error: $e');
    
    // Check if it's a specific validation error
    if (e.toString().contains('already registered')) {
      print('   This is expected if the license is already in use');
    } else if (e.toString().contains('Invalid or expired')) {
      print('   License validation failed - check if sample license data exists');
    }
  }
  
  print('\n🏁 Driver registration flow test completed\n');
}

/// Test the license validation specifically
Future<void> testLicenseValidation() async {
  print('\n🧪 Testing License Validation...\n');
  
  // Test valid license
  const validLicense = 'KL01 20230000001';
  print('Testing valid license: $validLicense');
  
  final validResult = await LicenseValidationService.validateLicense(validLicense);
  if (validResult != null) {
    print('✅ Valid license test passed');
    print('   Holder: ${validResult['name']}');
    print('   Expiry: ${validResult['expiryDate']}');
  } else {
    print('❌ Valid license test failed');
  }
  
  // Test invalid license
  const invalidLicense = 'KL99 99999999999';
  print('\nTesting invalid license: $invalidLicense');
  
  final invalidResult = await LicenseValidationService.validateLicense(invalidLicense);
  if (invalidResult == null) {
    print('✅ Invalid license test passed (correctly rejected)');
  } else {
    print('❌ Invalid license test failed (should have been rejected)');
  }
  
  // Test expired license (if any exists in sample data)
  print('\n🏁 License validation test completed\n');
}

/// Test the format validation
void testLicenseFormatValidation() {
  print('\n🧪 Testing License Format Validation...\n');
  
  final testCases = [
    {'license': 'KL01 20230000001', 'expected': true, 'description': 'Valid Kerala format'},
    {'license': 'KL1 20230000001', 'expected': false, 'description': 'Missing district digit'},
    {'license': 'TN01 20230000001', 'expected': false, 'description': 'Wrong state code'},
    {'license': 'KL01 230000001', 'expected': false, 'description': 'Missing year digit'},
    {'license': 'KL01 202300000001', 'expected': false, 'description': 'Extra digits'},
  ];
  
  for (final testCase in testCases) {
    final license = testCase['license'] as String;
    final expected = testCase['expected'] as bool;
    final description = testCase['description'] as String;
    
    final result = LicenseValidationService.isValidLicenseFormat(license);
    
    if (result == expected) {
      print('✅ $description: $license');
    } else {
      print('❌ $description: $license (expected $expected, got $result)');
    }
  }
  
  print('\n🏁 License format validation test completed\n');
}
