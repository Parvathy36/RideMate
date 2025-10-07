import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/firestore_service.dart';

// Test script to add sample driver data to Firestore
class TestDriverData {
  static Future<void> addSampleDrivers() async {
    try {
      print('🔄 Adding sample driver data...');

      final drivers = [
        {
          'name': 'Rajesh Kumar',
          'email': 'rajesh.kumar@example.com',
          'phoneNumber': '+91 9876543210',
          'carModel': 'Maruti Swift',
          'carNumber': 'KL-01-AB-1234',
          'rating': 4.8,
          'isActive': true,
          'isApproved': true,
          'isOnline': true,
          'isAvailable': true,
          'userType': 'driver',
          'registrationDate': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'name': 'Priya Nair',
          'email': 'priya.nair@example.com',
          'phoneNumber': '+91 9876543211',
          'carModel': 'Honda City',
          'carNumber': 'KL-02-CD-5678',
          'rating': 4.9,
          'isActive': true,
          'isApproved': true,
          'isOnline': true,
          'isAvailable': true,
          'userType': 'driver',
          'registrationDate': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'name': 'Suresh Menon',
          'email': 'suresh.menon@example.com',
          'phoneNumber': '+91 9876543212',
          'carModel': 'Toyota Innova',
          'carNumber': 'KL-03-EF-9012',
          'rating': 4.7,
          'isActive': true,
          'isApproved': true,
          'isOnline': true,
          'isAvailable': true,
          'userType': 'driver',
          'registrationDate': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'name': 'Anita Das',
          'email': 'anita.das@example.com',
          'phoneNumber': '+91 9876543213',
          'carModel': 'Hyundai Creta',
          'carNumber': 'KL-04-GH-3456',
          'rating': 4.9,
          'isActive': true,
          'isApproved': true,
          'isOnline': true,
          'isAvailable': true,
          'userType': 'driver',
          'registrationDate': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      ];

      final firestore = FirebaseFirestore.instance;

      for (int i = 0; i < drivers.length; i++) {
        final driverId = 'test_driver_${i + 1}';

        // Add to drivers collection
        await firestore.collection('drivers').doc(driverId).set({
          ...drivers[i],
          'id': driverId,
        });

        print('✅ Added driver: ${drivers[i]['name']}');
      }

      print('✅ Sample driver data added successfully!');
    } catch (e) {
      print('❌ Error adding sample driver data: $e');
    }
  }

  static Future<void> testGetAvailableDrivers() async {
    try {
      print('🔄 Testing getAvailableDrivers...');

      final drivers = await FirestoreService.getAvailableDrivers();
      print('📊 Found ${drivers.length} available drivers');

      for (final driver in drivers) {
        print(
          '  - ${driver['name']}: ${driver['carModel']} (${driver['carNumber']})',
        );
      }
    } catch (e) {
      print('❌ Error testing getAvailableDrivers: $e');
    }
  }

  static Future<void> testAllDriversStatus() async {
    try {
      print('🔄 Testing getAllDriversWithStatus...');

      final drivers = await FirestoreService.getAllDriversWithStatus();
      print('📊 Found ${drivers.length} total drivers');

      int availableCount = 0;
      for (final driver in drivers) {
        final isAvailable =
            driver['isActive'] == true && driver['isApproved'] == true;
        if (isAvailable) availableCount++;

        print('👤 ${driver['name']} (${driver['carModel']})');
        print('   - isActive: ${driver['isActive']}');
        print('   - isApproved: ${driver['isApproved']}');
        print(
          '   - Status: ${isAvailable ? "✅ Available" : "❌ Not Available"}',
        );
        print('');
      }

      print(
        '📊 Summary: $availableCount out of ${drivers.length} drivers are available',
      );
    } catch (e) {
      print('❌ Error testing getAllDriversWithStatus: $e');
    }
  }
}
