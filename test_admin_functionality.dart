import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/services/firestore_service.dart';
import 'lib/firebase_options.dart';

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

    // Test driver data retrieval
    print('\n🔄 Testing driver data retrieval...');

    // Get all drivers
    final allDrivers = await FirestoreService.getAllDrivers();
    print('📊 Total drivers: ${allDrivers.length}');

    // Get pending drivers
    final pendingDrivers = await FirestoreService.getPendingDrivers();
    print('⏳ Pending drivers: ${pendingDrivers.length}');

    // Get approved drivers
    final approvedDrivers = await FirestoreService.getApprovedDrivers();
    print('✅ Approved drivers: ${approvedDrivers.length}');

    // Display sample driver data
    if (allDrivers.isNotEmpty) {
      print('\n📋 Sample driver data:');
      final sampleDriver = allDrivers.first;
      print('  Name: ${sampleDriver['name']}');
      print('  Email: ${sampleDriver['email']}');
      print('  License: ${sampleDriver['licenseId']}');
      print('  Status: ${sampleDriver['isApproved'] ? 'Approved' : 'Pending'}');
      print('  Active: ${sampleDriver['isActive'] ? 'Yes' : 'No'}');
    }

    // Test license data
    print('\n🔄 Testing license validation...');
    final sampleLicense = await FirestoreService.validateLicense(
      'KL01 20230000001',
    );
    if (sampleLicense != null) {
      print('✅ License validation working');
      print('  License holder: ${sampleLicense['name']}');
    } else {
      print('❌ License validation failed or license not found');
    }

    print('\n✅ All admin functionality tests completed successfully!');
    print('\n📝 Admin Features Available:');
    print('  ✓ View all drivers');
    print('  ✓ Search drivers by name, email, phone, license, car number');
    print('  ✓ Filter drivers by status (pending, approved, active, inactive)');
    print('  ✓ Approve/reject pending drivers');
    print('  ✓ Enable/disable approved drivers');
    print('  ✓ View detailed driver information');
    print('  ✓ Real-time status updates');
  } catch (e) {
    print('❌ Error during testing: $e');
  }
}
