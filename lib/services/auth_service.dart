import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';
import 'license_validation_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '975273579439-tv90tipl383kcekt025g730vgv56bjf4.apps.googleusercontent.com'
        : null,
    scopes: ['email', 'profile'], // Minimal scopes to avoid People API
  );

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if current user is admin
  bool isAdmin() {
    final user = currentUser;
    if (user == null) return false;

    // Admin email check
    const adminEmail = 'parvathysuresh36@gmail.com';
    return user.email?.toLowerCase() == adminEmail.toLowerCase();
  }

  // Get user type from Firestore
  Future<String?> getUserType() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      print('🔍 Getting user type for: ${user.uid}');

      final userData = await FirestoreService.getUserData(user.uid);
      if (userData != null) {
        final userType = userData['userType'] as String?;
        print('✅ User type found: $userType');
        return userType;
      }

      print('❌ User data not found in Firestore');
      return null;
    } catch (e) {
      print('❌ Error getting user type: $e');
      return null;
    }
  }

  // Ensure user document exists in Firestore
  Future<void> _ensureUserDocumentExists(User user, String email) async {
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        print('🔄 Creating user document for: ${user.email}');

        // Determine user type
        String userType = 'user'; // default
        const adminEmail = 'parvathysuresh36@gmail.com';

        if (email.toLowerCase() == adminEmail.toLowerCase()) {
          userType = 'admin';
          print('👑 Creating admin user document');
        }

        // Create user document
        await _firestore.collection('users').doc(user.uid).set({
          'name': user.displayName ?? 'User',
          'email': email,
          'userType': userType,
          'createdAt': FieldValue.serverTimestamp(),
          'signInMethod': 'email',
        });

        print('✅ User document created with userType: $userType');
      } else {
        print('ℹ️ User document already exists');
      }
    } catch (e) {
      print('❌ Error ensuring user document exists: $e');
      // Don't throw error as this shouldn't prevent sign-in
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if user document exists in Firestore, create if not
      await _ensureUserDocumentExists(result.user!, email);

      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('Starting Google Sign-In...');

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('User canceled Google Sign-In');
        return null;
      }

      print('Google user obtained: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      print('Google auth tokens obtained');

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('Firebase credential created');

      // Sign in to Firebase with the Google credential
      UserCredential result = await _auth.signInWithCredential(credential);

      print('Firebase sign-in successful: ${result.user?.email}');

      // Ensure user document exists in Firestore
      await _ensureUserDocumentExists(result.user!, result.user!.email!);

      if (result.additionalUserInfo?.isNewUser == true) {
        print('New user signed in with Google');
      } else {
        print('Existing user signed in with Google');
      }

      print('Google Sign-In completed successfully. Returning result...');
      return result;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Exception: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('Google sign-in error: $e');
      // Check if it's a People API error
      if (e.toString().contains('People API') || e.toString().contains('403')) {
        throw Exception(
          'Google Sign-In requires People API to be enabled. Please enable it in Google Cloud Console.',
        );
      }
      throw Exception('Google sign-in failed: $e');
    }
  }

  // Register with email and password
  Future<UserCredential?> registerWithEmailAndPassword(
    String email,
    String password,
    String name, {
    bool isDriver = false,
    String? licenseId,
    String? carModel,
    String? carNumber,
    String? phoneNumber,
  }) async {
    try {
      print('Starting registration for email: $email');

      // Add timeout to prevent hanging
      UserCredential result = await _auth
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'Registration timed out. Please check your internet connection and try again.',
              );
            },
          );

      print('User created successfully: ${result.user?.uid}');

      // Update display name
      await result.user
          ?.updateDisplayName(name)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('Display name update timed out, but continuing...');
            },
          );
      print('Display name updated');

      // Send email verification
      if (result.user != null && !result.user!.emailVerified) {
        try {
          await result.user!.sendEmailVerification();
          print('Email verification sent to: $email');
        } catch (e) {
          print('Failed to send email verification: $e');
        }
      }

      // Create user document in Firestore
      try {
        if (isDriver) {
          if (licenseId == null || licenseId.isEmpty) {
            throw Exception('License ID is required for driver registration');
          }
          if (carModel == null || carModel.isEmpty) {
            throw Exception('Car model is required for driver registration');
          }
          if (phoneNumber == null || phoneNumber.isEmpty) {
            throw Exception('Phone number is required for driver registration');
          }

          final licenseData = await LicenseValidationService.validateLicense(
            licenseId,
          );
          if (licenseData == null) {
            throw Exception(
              'Invalid or expired license ID. Please check and try again.',
            );
          }

          final isLicenseRegistered =
              await FirestoreService.isLicenseAlreadyRegistered(licenseId);
          if (isLicenseRegistered) {
            throw Exception(
              'This license ID is already registered with another driver account.',
            );
          }

          await FirestoreService.createDriverDocument(
            userId: result.user!.uid,
            name: name,
            email: email,
            phoneNumber: phoneNumber,
            licenseId: licenseId,
            carModel: carModel,
            carNumber: carNumber ?? '',
            licenseData: licenseData,
          );
          print('Driver document created in Firestore');
        } else {
          Map<String, dynamic> userData = {
            'name': name,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
            'userType': 'user',
          };

          if (phoneNumber != null && phoneNumber.isNotEmpty) {
            userData['phoneNumber'] = phoneNumber;
          }

          await _firestore
              .collection('users')
              .doc(result.user?.uid)
              .set(userData)
              .timeout(
                const Duration(seconds: 15),
                onTimeout: () {
                  print(
                    'Firestore document creation timed out, but user is created',
                  );
                },
              );
          print('User document created in Firestore');
        }
      } catch (firestoreError) {
        print('Firestore error: $firestoreError');
        if (isDriver) {
          throw Exception('Driver registration failed: $firestoreError');
        }
      }

      return result;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('General exception during registration: $e');
      throw Exception('Registration failed: $e');
    }
  }

  // Register with email and password using a secondary Firebase App instance
  // This is used by admins to add new members without being logged out
  Future<UserCredential?> registerSecondaryUser(
    String email,
    String password,
    String name,
  ) async {
    FirebaseApp? secondaryApp;
    try {
      print('Starting secondary registration for email: $email');

      // Initialize secondary app
      secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: Firebase.app().options,
      );

      // Create user using secondary app's auth instance
      UserCredential result = await FirebaseAuth.instanceFor(app: secondaryApp)
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'Secondary registration timed out. Please check your internet connection.',
              );
            },
          );

      print('Secondary user created successfully: ${result.user?.uid}');

      // Update display name for the new user
      await result.user?.updateDisplayName(name);

      return result;
    } on FirebaseAuthException catch (e) {
      print('Secondary FirebaseAuthException: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('General exception during secondary registration: $e');
      throw Exception('Secondary registration failed: $e');
    } finally {
      // Always delete secondary app to free resources and avoid name conflicts
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw Exception('Error signing out: $e');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    print('Firebase Auth Error Code: ${e.code}');
    print('Firebase Auth Error Message: ${e.message}');

    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      case 'operation-not-allowed':
        return 'Signing in with Email and Password is not enabled.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'internal-error':
        return 'An internal error occurred. Please try again.';
      case 'invalid-api-key':
        return 'Invalid API key. Please check Firebase configuration.';
      case 'app-not-authorized':
        return 'App not authorized. Please check Firebase configuration.';
      default:
        return 'Authentication error (${e.code}): ${e.message ?? 'Unknown error'}';
    }
  }
}
