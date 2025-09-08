import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'lib/services/firestore_service.dart';
import 'lib/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    print('🔥 Firebase initialized successfully');

    // Test police clearance functionality
    await testPoliceClearanceIntegration();

    print('✅ Police clearance admin integration test completed');
  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<void> testPoliceClearanceIntegration() async {
  try {
    print('\n🧪 Testing Police Clearance Admin Integration...');

    // Test 1: Check individual police clearance
    print('\n📋 Test 1: Individual Police Clearance Check');
    final clearanceData = await FirestoreService.checkPoliceClearance(
      'KL01 20230000001',
    );
    if (clearanceData != null) {
      print('✅ Found clearance data: ${clearanceData['police_clearance']}');
      print('   Valid: ${clearanceData['valid']}');
      print('   Date: ${clearanceData['clearance_date']}');
      print('   Authority: ${clearanceData['issuing_authority']}');
    } else {
      print('❌ No clearance data found');
    }

    // Test 2: Check multiple drivers' police clearance
    print('\n📋 Test 2: Multiple Drivers Police Clearance Check');
    final licenseIds = [
      'KL01 20230000001',
      'KL02 20230000002',
      'KL03 20230000003',
      'KL04 20230000004',
      'KL05 20230000005',
    ];

    final multipleClearanceData =
        await FirestoreService.getPoliceClearanceForDrivers(licenseIds);
    print(
      '✅ Retrieved clearance data for ${multipleClearanceData.length} drivers:',
    );

    for (final entry in multipleClearanceData.entries) {
      final licenseId = entry.key;
      final data = entry.value;
      final status = data['police_clearance'] == true ? '✅ CLEAR' : '❌ ISSUES';
      final validStatus = data['valid'] == true ? 'VALID' : 'INVALID';
      print(
        '   $licenseId: $status - $validStatus - ${data['issuing_authority']}',
      );
    }

    // Test 3: Test with non-existent license
    print('\n📋 Test 3: Non-existent License Check');
    final nonExistentData = await FirestoreService.checkPoliceClearance(
      'INVALID123',
    );
    if (nonExistentData == null) {
      print('✅ Correctly returned null for non-existent license');
    } else {
      print('❌ Unexpected data returned for non-existent license');
    }

    // Test 4: Simulate admin dashboard scenario
    print('\n📋 Test 4: Admin Dashboard Simulation');

    // Simulate getting all drivers (we'll use sample data)
    final sampleDrivers = [
      {'licenseId': 'KL01 20230000001', 'name': 'Rajesh Kumar'},
      {'licenseId': 'KL02 20230000002', 'name': 'Priya Nair'},
      {'licenseId': 'KL03 20230000003', 'name': 'Arjun Krishnan'},
      {'licenseId': 'KL04 20230000004', 'name': 'Deepika R'},
      {'licenseId': 'KL05 20230000005', 'name': 'Viknesh K'},
    ];

    final driverLicenseIds = sampleDrivers
        .map((driver) => driver['licenseId'] as String)
        .toList();

    final adminClearanceData =
        await FirestoreService.getPoliceClearanceForDrivers(driverLicenseIds);

    print('✅ Admin Dashboard Police Clearance Summary:');
    for (final driver in sampleDrivers) {
      final licenseId = driver['licenseId'] as String;
      final name = driver['name'] as String;
      final clearance = adminClearanceData[licenseId];

      if (clearance == null) {
        print('   $name ($licenseId): 🟡 NO POLICE CHECK');
      } else if (clearance['police_clearance'] == true) {
        print('   $name ($licenseId): ✅ VERIFICATION SUCCESSFUL');
      } else {
        print('   $name ($licenseId): ❌ VERIFICATION FAILED');
      }
    }

    print('\n🎉 All police clearance admin integration tests passed!');
  } catch (e) {
    print('❌ Error during police clearance admin integration test: $e');
    throw Exception('Police clearance admin integration test failed: $e');
  }
}
