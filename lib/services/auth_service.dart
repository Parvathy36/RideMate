import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

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

      // Create user document in Firestore if it's a new user
      if (result.additionalUserInfo?.isNewUser == true) {
        print('Creating new user document in Firestore...');
        await _firestore.collection('users').doc(result.user?.uid).set({
          'name':
              result.user?.displayName ??
              googleUser.displayName ??
              'Google User',
          'email': result.user?.email ?? googleUser.email,
          'createdAt': FieldValue.serverTimestamp(),
          'signInMethod': 'google',
        });
        print('User document created successfully');
      } else {
        print('Existing user signed in');
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
    String name,
  ) async {
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

      // Create user document in Firestore
      try {
        await _firestore
            .collection('users')
            .doc(result.user?.uid)
            .set({
              'name': name,
              'email': email,
              'createdAt': FieldValue.serverTimestamp(),
            })
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                print(
                  'Firestore document creation timed out, but user is created',
                );
              },
            );
        print('User document created in Firestore');
      } catch (firestoreError) {
        print('Firestore error (non-critical): $firestoreError');
        // Don't throw here as the user account is already created
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
