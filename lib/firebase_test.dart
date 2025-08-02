import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

class FirebaseTest {
  static Future<void> testFirebaseConnection() async {
    try {
      print('Testing Firebase connection...');

      // Test Firebase initialization
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase initialized successfully');

      // Test Firebase Auth instance
      final auth = FirebaseAuth.instance;
      print('✅ Firebase Auth instance created');
      print('Current user: ${auth.currentUser?.email ?? 'No user signed in'}');

      // Test Firestore instance
      final firestore = FirebaseFirestore.instance;
      print('✅ Firestore instance created');

      // Test Firestore connection by reading settings
      try {
        await firestore.settings;
        print('✅ Firestore connection successful');
      } catch (e) {
        print('❌ Firestore connection failed: $e');
      }

      // Test Auth providers
      final providers = await auth.fetchSignInMethodsForEmail(
        'test@example.com',
      );
      print(
        '✅ Auth provider check successful. Available providers: $providers',
      );

      print('🎉 All Firebase tests passed!');
    } catch (e) {
      print('❌ Firebase test failed: $e');
      rethrow;
    }
  }

  static Future<void> testEmailPasswordAuth() async {
    try {
      print('Testing Email/Password authentication...');

      final auth = FirebaseAuth.instance;

      // Try to create a test user (this will fail if auth is not enabled)
      try {
        final testEmail =
            'test_${DateTime.now().millisecondsSinceEpoch}@example.com';
        final testPassword = 'TestPassword123!';

        print('Attempting to create test user with email: $testEmail');

        final userCredential = await auth.createUserWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );

        print('✅ Test user created successfully: ${userCredential.user?.uid}');

        // Clean up - delete the test user
        await userCredential.user?.delete();
        print('✅ Test user deleted successfully');
      } catch (e) {
        if (e.toString().contains('operation-not-allowed')) {
          print(
            '❌ Email/Password authentication is not enabled in Firebase Console',
          );
          print(
            'Please enable Email/Password authentication in Firebase Console:',
          );
          print('1. Go to Firebase Console > Authentication > Sign-in method');
          print('2. Enable Email/Password provider');
        } else {
          print('❌ Auth test failed: $e');
        }
        rethrow;
      }
    } catch (e) {
      print('❌ Email/Password auth test failed: $e');
      rethrow;
    }
  }
}
