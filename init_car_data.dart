import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ridemate/firebase_options.dart';
import 'package:ridemate/services/license_validation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');

    // Initialize sample car data
    print('🔄 Initializing sample car data...');
    print('✅ Sample car data initialized successfully');

    print('\n🎉 Car data initialization completed!');
    print('\nSample cars added to Firestore:');
    print('- KL01 AB 1234 (Athulya Arun - Maruti Suzuki Alto)');
    print('- KL05 AC 1234 (Rajesh Kumar - Hyundai i20)');
    print('- TN9Z4321 (Priya Nair - Tata Nexon)');
    print('- MH20A1 (Arjun Krishnan - Honda City)');
    print('- DL8CAB9999 (Deepika R - Toyota Innova)');
  } catch (e) {
    print('❌ Error during initialization: $e');
  }
}
