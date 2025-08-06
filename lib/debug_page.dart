import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/auth_service.dart';
import 'services/license_validation_service.dart';
import 'home.dart';
import 'initialize_licenses.dart';
import 'test_license_validation.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  final AuthService _authService = AuthService();
  String _debugInfo = 'Ready to test...';
  bool _isLoading = false;

  Future<void> _testFirebaseConnection() async {
    setState(() {
      _isLoading = true;
      _debugInfo = 'Testing Firebase connection...';
    });

    try {
      // Test basic Firebase Auth instance
      final auth = FirebaseAuth.instance;
      setState(() {
        _debugInfo += '\n✅ Firebase Auth instance created';
      });

      // Test if Email/Password auth is enabled
      try {
        await auth.fetchSignInMethodsForEmail('test@example.com');
        setState(() {
          _debugInfo += '\n✅ Email/Password auth is enabled';
        });
      } catch (e) {
        setState(() {
          _debugInfo += '\n❌ Email/Password auth test failed: $e';
        });
      }

      // Test current user status
      final currentUser = auth.currentUser;
      setState(() {
        _debugInfo +=
            '\n📱 Current user: ${currentUser?.email ?? 'Not signed in'}';
      });
    } catch (e) {
      setState(() {
        _debugInfo += '\n❌ Firebase connection failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testRegistration() async {
    setState(() {
      _isLoading = true;
      _debugInfo = 'Testing registration...';
    });

    try {
      final testEmail =
          'test_${DateTime.now().millisecondsSinceEpoch}@example.com';
      const testPassword = 'TestPassword123!';
      const testName = 'Test User';

      setState(() {
        _debugInfo += '\n🔄 Attempting registration with email: $testEmail';
      });

      final result = await _authService.registerWithEmailAndPassword(
        testEmail,
        testPassword,
        testName,
      );

      setState(() {
        _debugInfo += '\n✅ Registration successful!';
        _debugInfo += '\n👤 User ID: ${result?.user?.uid}';
        _debugInfo += '\n📧 Email: ${result?.user?.email}';
      });

      // Clean up - delete the test user
      try {
        await result?.user?.delete();
        setState(() {
          _debugInfo += '\n🗑️ Test user deleted successfully';
        });
      } catch (e) {
        setState(() {
          _debugInfo += '\n⚠️ Could not delete test user: $e';
        });
      }
    } catch (e) {
      setState(() {
        _debugInfo += '\n❌ Registration failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testNavigation() async {
    setState(() {
      _debugInfo = 'Testing navigation to HomePage...';
    });

    try {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } catch (e) {
      setState(() {
        _debugInfo += '\n❌ Navigation failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Firebase'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Firebase Debug Tools',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _isLoading ? null : _testFirebaseConnection,
              child: const Text('Test Firebase Connection'),
            ),
            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: _isLoading ? null : _testRegistration,
              child: const Text('Test Registration'),
            ),
            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: _testNavigation,
              child: const Text('Test Navigation to Home'),
            ),
            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const InitializeLicensesPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Initialize License Database'),
            ),
            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TestLicenseValidationPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Test License Validation'),
            ),
            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: _testSpecificLicense,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Test KL01 20230000001'),
            ),
            const SizedBox(height: 20),

            if (_isLoading) const Center(child: CircularProgressIndicator()),

            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _debugInfo,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testSpecificLicense() async {
    const testLicenseId = 'KL01 20230000001';

    setState(() {
      _debugInfo = 'Testing license: $testLicenseId...\n';
    });

    try {
      print('🧪 Testing specific license: $testLicenseId');

      setState(() {
        _debugInfo += 'Step 1: Testing direct Firestore access...\n';
      });

      // Test direct Firestore access first
      final docSnapshot = await FirebaseFirestore.instance
          .collection('licenses')
          .doc(testLicenseId.toUpperCase())
          .get();

      setState(() {
        _debugInfo += 'Document exists: ${docSnapshot.exists}\n';
        if (docSnapshot.exists) {
          final data = docSnapshot.data()!;
          _debugInfo += 'Name: ${data['name']}\n';
          _debugInfo += 'District: ${data['district']}\n';
          _debugInfo += 'Expiry: ${data['expiryDate']}\n';
          _debugInfo += 'Active: ${data['isActive']}\n\n';
        }
      });

      setState(() {
        _debugInfo += 'Step 2: Testing license validation service...\n';
      });

      // Test the license validation service
      final result = await LicenseValidationService.validateLicenseDetailed(
        testLicenseId,
      );

      setState(() {
        _debugInfo +=
            'Validation Result:\n'
            'Valid: ${result['isValid']}\n'
            'Status: ${result['status']}\n'
            'Message: ${result['message']}\n';

        if (result['licenseData'] != null) {
          _debugInfo +=
              'License Holder: ${result['licenseData']['name']}\n'
              'District: ${result['licenseData']['district']}\n';
        }

        if (result['expiryDate'] != null) {
          _debugInfo += 'Expiry Date: ${result['expiryDate']}\n';
        }

        if (result['daysUntilExpiry'] != null) {
          _debugInfo += 'Days Until Expiry: ${result['daysUntilExpiry']}\n';
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['isValid'] == true
                  ? 'License validation successful!'
                  : 'License validation failed: ${result['message']}',
            ),
            backgroundColor: result['isValid'] == true
                ? Colors.green
                : Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _debugInfo += 'Error testing license: $e\n';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error testing license: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
