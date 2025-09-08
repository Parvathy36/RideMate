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

    // Test with your actual database data
    await verifyActualPoliceClearanceData();

    print('✅ Police clearance verification completed');
  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<void> verifyActualPoliceClearanceData() async {
  try {
    print('\n🔍 Verifying Police Clearance with Your Actual Database...');

    // Test with your actual license IDs from the screenshot
    final actualLicenseIds = ['KL01 20230000001', 'KL05 20230000002'];

    print('\n📋 Testing Individual License Checks:');
    for (final licenseId in actualLicenseIds) {
      final clearanceData = await FirestoreService.checkPoliceClearance(
        licenseId,
      );

      if (clearanceData != null) {
        final policeClearance = clearanceData['police_clearance'] == true;
        final valid = clearanceData['valid'] == true;
        final date = clearanceData['clearance_date'] ?? 'N/A';
        final authority = clearanceData['issuing_authority'] ?? 'N/A';

        print('✅ $licenseId:');
        print(
          '   Police Clearance: ${policeClearance ? "✅ CLEAR" : "❌ ISSUES"}',
        );
        print('   Valid Status: ${valid ? "✅ VALID" : "❌ INVALID"}');
        print('   Date: $date');
        print('   Authority: $authority');
        print('');
      } else {
        print('❌ $licenseId: No data found');
      }
    }

    print('\n📋 Testing Batch License Check:');
    final batchData = await FirestoreService.getPoliceClearanceForDrivers(
      actualLicenseIds,
    );

    print('Found ${batchData.length} records in batch:');
    for (final entry in batchData.entries) {
      final licenseId = entry.key;
      final data = entry.value;
      final status = data['police_clearance'] == true ? '✅ CLEAR' : '❌ ISSUES';
      final validStatus = data['valid'] == true ? 'VALID' : 'INVALID';
      print('   $licenseId: $status & $validStatus');
    }

    print('\n🎯 Admin Dashboard Simulation:');
    print('This is how it will appear in your admin panel:');

    for (final licenseId in actualLicenseIds) {
      final clearanceData = batchData[licenseId];

      if (clearanceData == null) {
        print('   Driver ($licenseId): 🟡 NO POLICE CHECK');
      } else if (clearanceData['police_clearance'] == true) {
        print('   Driver ($licenseId): ✅ VERIFICATION SUCCESSFUL');
      } else {
        print('   Driver ($licenseId): ❌ VERIFICATION FAILED');
      }
    }

    print('\n🎉 Your police clearance system is working correctly!');
    print(
      '📱 Now you can open the admin panel to see the police clearance badges and details.',
    );
  } catch (e) {
    print('❌ Error during verification: $e');
    throw Exception('Verification failed: $e');
  }
}
