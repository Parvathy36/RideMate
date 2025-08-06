import 'package:flutter/material.dart';
import 'services/license_validation_service.dart';
import 'services/firestore_service.dart';

class InitializeLicensesPage extends StatefulWidget {
  const InitializeLicensesPage({super.key});

  @override
  State<InitializeLicensesPage> createState() => _InitializeLicensesPageState();
}

class _InitializeLicensesPageState extends State<InitializeLicensesPage> {
  String _statusMessage = 'Ready to initialize license database...';
  bool _isLoading = false;
  bool _isInitialized = false;

  Future<void> _initializeLicenses() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Initializing license database...';
      _isInitialized = false;
    });

    try {
      // Test Firestore connection first
      setState(() {
        _statusMessage += '\n🔄 Testing Firestore connection...';
      });

      await FirestoreService.testConnection();
      setState(() {
        _statusMessage += '\n✅ Firestore connection successful';
      });

      // Initialize license data
      setState(() {
        _statusMessage += '\n🔄 Initializing Kerala sample licenses...';
      });

      await LicenseValidationService.initializeKeralaSampleLicenses();
      setState(() {
        _statusMessage += '\n✅ Kerala sample licenses initialized successfully';
      });

      // Debug Firestore access
      setState(() {
        _statusMessage += '\n🔄 Testing Firestore access...';
      });

      await LicenseValidationService.debugFirestoreAccess();
      setState(() {
        _statusMessage += '\n✅ Firestore access test completed';
      });

      setState(() {
        _statusMessage += '\n\n🎉 License database initialization completed successfully!';
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _statusMessage += '\n❌ Error during initialization: $e';
        _isInitialized = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _reinitializeLicenses() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Re-initializing license database...';
      _isInitialized = false;
    });

    try {
      // Force re-initialization by calling the service method
      setState(() {
        _statusMessage += '\n🔄 Force re-initializing licenses collection...';
      });

      await LicenseValidationService.initializeLicensesCollection();
      setState(() {
        _statusMessage += '\n✅ Licenses collection re-initialized successfully';
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _statusMessage += '\n❌ Error during re-initialization: $e';
        _isInitialized = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearStatus() {
    setState(() {
      _statusMessage = 'Ready to initialize license database...';
      _isInitialized = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Initialize License Database'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'License Database Initialization',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'This will initialize the Firestore database with sample Kerala driving license data for testing purposes.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // Initialize button
            ElevatedButton(
              onPressed: _isLoading ? null : _initializeLicenses,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text('Initializing...'),
                      ],
                    )
                  : const Text('Initialize License Database'),
            ),
            const SizedBox(height: 10),

            // Re-initialize button
            ElevatedButton(
              onPressed: _isLoading ? null : _reinitializeLicenses,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Force Re-initialize'),
            ),
            const SizedBox(height: 10),

            // Clear status button
            ElevatedButton(
              onPressed: _isLoading ? null : _clearStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Clear Status'),
            ),
            const SizedBox(height: 20),

            // Status display
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isInitialized ? Colors.green[50] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isInitialized ? Colors.green[300]! : Colors.grey[300]!,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: _isInitialized ? Colors.green[800] : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Success indicator
            if (_isInitialized)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'License database has been successfully initialized! You can now test license validation.',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
