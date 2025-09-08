import 'package:cloud_firestore/cloud_firestore.dart';

class TestPoliceClearance {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add sample police clearance data for testing
  static Future<void> addSamplePoliceClearanceData() async {
    try {
      print('🔄 Adding sample police clearance data...');

      // Sample police clearance data
      final sampleClearances = [
        {
          "licenseId": "KL01 20230000001",
          "police_clearance": true,
          "clearance_date": "2024-01-15",
          "issuing_authority": "Kerala Police",
          "remarks": "Clear background check",
          "created_at": FieldValue.serverTimestamp(),
        },
        {
          "licenseId": "KL02 20230000002",
          "police_clearance": true,
          "clearance_date": "2024-01-20",
          "issuing_authority": "Kerala Police",
          "remarks": "Verified clean record",
          "created_at": FieldValue.serverTimestamp(),
        },
        {
          "licenseId": "KL03 20230000003",
          "police_clearance": false,
          "clearance_date": "2024-01-25",
          "issuing_authority": "Kerala Police",
          "remarks": "Minor traffic violations found",
          "created_at": FieldValue.serverTimestamp(),
        },
        {
          "licenseId": "KL04 20230000004",
          "police_clearance": true,
          "clearance_date": "2024-02-01",
          "issuing_authority": "Kerala Police",
          "remarks": "Background verification successful",
          "created_at": FieldValue.serverTimestamp(),
        },
        {
          "licenseId": "KL05 20230000005",
          "police_clearance": true,
          "clearance_date": "2024-02-05",
          "issuing_authority": "Kerala Police",
          "remarks": "Clean criminal record",
          "created_at": FieldValue.serverTimestamp(),
        },
      ];

      // Use batch to add all clearance records
      final batch = _firestore.batch();

      for (final clearance in sampleClearances) {
        final docRef = _firestore
            .collection('policeclear')
            .doc(clearance['licenseId'] as String);
        batch.set(docRef, clearance);
      }

      await batch.commit();
      print('✅ Sample police clearance data added successfully');
    } catch (e) {
      print('❌ Error adding sample police clearance data: $e');
      throw Exception('Failed to add sample police clearance data: $e');
    }
  }

  // Check if police clearance data exists
  static Future<void> checkPoliceClearanceData() async {
    try {
      print('🔍 Checking existing police clearance data...');

      final snapshot = await _firestore
          .collection('policeclear')
          .limit(10)
          .get();

      print('📊 Found ${snapshot.docs.length} police clearance records');

      for (final doc in snapshot.docs) {
        final data = doc.data();
        print(
          '  - ${doc.id}: ${data['police_clearance']} (${data['remarks']})',
        );
      }
    } catch (e) {
      print('❌ Error checking police clearance data: $e');
    }
  }
}
