import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'test_police_clearance.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    print('🔥 Firebase initialized successfully');

    // Add sample police clearance data
    await TestPoliceClearance.addSamplePoliceClearanceData();

    // Check the data
    await TestPoliceClearance.checkPoliceClearanceData();

    print('✅ Police clearance data initialization completed');
  } catch (e) {
    print('❌ Error: $e');
  }
}
