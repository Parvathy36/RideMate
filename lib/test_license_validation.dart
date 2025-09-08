import 'package:flutter/material.dart';
import 'services/license_validation_service.dart';

class TestLicenseValidationPage extends StatefulWidget {
  const TestLicenseValidationPage({super.key});

  @override
  State<TestLicenseValidationPage> createState() =>
      _TestLicenseValidationPageState();
}

class _TestLicenseValidationPageState extends State<TestLicenseValidationPage> {
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _carNumberController = TextEditingController();
  String _testResults = 'Ready to test license validation...';
  bool _isLoading = false;

  // Sample test licenses
  final List<String> _sampleLicenses = [
    'KL01 20230000001', // Valid
    'KL02 20230000002', // Valid
    'KL14 20240000014', // Valid
    'KL15 20240000015', // Valid
    'KL99 99999999999', // Invalid
    'TN01 20230000001', // Invalid (wrong state)
  ];

  Future<void> _testSingleCarNumber() async {
    final carNumber = _carNumberController.text.trim();
    if (carNumber.isEmpty) {
      setState(() {
        _testResults = '❌ Please enter a car number to test';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _testResults = 'Testing car number: $carNumber\n';
    });

    try {
      // Test format validation first
      final isValidFormat = LicenseValidationService.isValidCarNumberFormat(
        carNumber,
      );
      setState(() {
        _testResults +=
            '📋 Format validation: ${isValidFormat ? '✅ Valid' : '❌ Invalid'}\n';
      });

      if (!isValidFormat) {
        setState(() {
          _testResults +=
              '💡 Expected format: SSRRXXNNNN (e.g., KL01AB1234, TN9Z4321, MH20A1)\n';
        });
        return;
      }

      // Check if car exists in database
      setState(() {
        _testResults += '🔄 Checking car in database...\n';
      });

      final carData = await LicenseValidationService.validateCarNumber(
        carNumber,
      );
      if (carData != null) {
        setState(() {
          _testResults += '✅ Car found in database!\n';
          _testResults += '👤 Owner: ${carData['ownerName']}\n';
          _testResults += '🚗 Model: ${carData['carModel']}\n';
          _testResults += '📍 District: ${carData['district']}\n';
          _testResults += '🏛️ State: ${carData['state']}\n';
          _testResults +=
              '✅ Valid: ${carData['isValid'] == true ? 'Yes' : 'No'}\n';
        });
      } else {
        setState(() {
          _testResults += '❌ Car not found in database\n';
        });
        return;
      }

      // Check if already registered
      setState(() {
        _testResults += '🔄 Checking registration status...\n';
      });

      final isRegistered =
          await LicenseValidationService.isCarNumberAlreadyRegistered(
            carNumber,
          );
      setState(() {
        _testResults +=
            '📝 Registration status: ${isRegistered ? '⚠️ Already registered' : '✅ Available for registration'}\n';
      });
    } catch (e) {
      setState(() {
        _testResults += '❌ Error during validation: $e\n';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testSingleLicense() async {
    final licenseId = _licenseController.text.trim();
    if (licenseId.isEmpty) {
      setState(() {
        _testResults = '❌ Please enter a license ID to test';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _testResults = 'Testing license: $licenseId\n';
    });

    try {
      // Test format validation first
      final isValidFormat = LicenseValidationService.isValidLicenseFormat(
        licenseId,
      );
      setState(() {
        _testResults +=
            '📋 Format validation: ${isValidFormat ? '✅ Valid' : '❌ Invalid'}\n';
      });

      if (!isValidFormat) {
        setState(() {
          _testResults +=
              '💡 Expected format: KLDD YYYYNNNNNNN (e.g., KL01 20230000001)\n';
        });
        return;
      }

      // Test license validation with detailed expiry check
      setState(() {
        _testResults += '🔄 Checking license in database...\n';
      });

      final validationResult =
          await LicenseValidationService.validateLicenseDetailed(licenseId);

      if (validationResult['isValid'] == true) {
        final licenseData =
            validationResult['licenseData'] as Map<String, dynamic>;
        setState(() {
          _testResults += '✅ License found and valid!\n';
          _testResults += '👤 Name: ${licenseData['name']}\n';
          _testResults += '📍 State: ${licenseData['state']}\n';
          _testResults += '🏛️ District: ${licenseData['district']}\n';
          _testResults += '📅 Issue Date: ${licenseData['issueDate']}\n';
          _testResults += '⏰ Expiry Date: ${validationResult['expiryDate']}\n';
          _testResults += '🚗 Vehicle Class: ${licenseData['vehicleClass']}\n';
          _testResults +=
              '✅ Status: ${licenseData['isActive'] == true ? 'Active' : 'Inactive'}\n';
          _testResults +=
              '📆 Days until expiry: ${validationResult['daysUntilExpiry']}\n';
        });

        // Check if already registered
        setState(() {
          _testResults += '🔄 Checking registration status...\n';
        });

        final isRegistered =
            await LicenseValidationService.isLicenseAlreadyRegistered(
              licenseId,
            );
        setState(() {
          _testResults +=
              '📝 Registration status: ${isRegistered ? '⚠️ Already registered' : '✅ Available for registration'}\n';
        });
      } else {
        final status = validationResult['status'];
        final message = validationResult['message'];

        setState(() {
          _testResults += '❌ License validation failed\n';
          _testResults += '📋 Status: $status\n';
          _testResults += '💡 Message: $message\n';

          // Show additional info for expired licenses
          if (status == 'expired') {
            _testResults +=
                '📅 Expiry Date: ${validationResult['expiryDate']}\n';
            _testResults +=
                '⏰ Days expired: ${validationResult['daysExpired']}\n';
          }
        });
      }
    } catch (e) {
      setState(() {
        _testResults += '❌ Error during validation: $e\n';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isLoading = true;
      _testResults = '🧪 Running comprehensive license validation tests...\n\n';
    });

    try {
      // Test license format validation
      setState(() {
        _testResults += '📋 Testing License Format Validation:\n';
      });

      final licenseFormatTests = [
        {
          'license': 'KL01 20230000001',
          'expected': true,
          'description': 'Valid Kerala format',
        },
        {
          'license': 'KL1 20230000001',
          'expected': false,
          'description': 'Missing district digit',
        },
        {
          'license': 'TN01 20230000001',
          'expected': false,
          'description': 'Wrong state code',
        },
        {
          'license': 'KL01 230000001',
          'expected': false,
          'description': 'Missing year digit',
        },
        {
          'license': 'KL01-20230000001',
          'expected': false,
          'description': 'Wrong separator',
        },
      ];

      for (final test in licenseFormatTests) {
        final license = test['license'] as String;
        final expected = test['expected'] as bool;
        final description = test['description'] as String;

        final result = LicenseValidationService.isValidLicenseFormat(license);
        final status = result == expected ? '✅' : '❌';

        setState(() {
          _testResults += '$status $description: $license\n';
        });
      }

      // Test car number format validation
      setState(() {
        _testResults += '\n🚗 Testing Car Number Format Validation:\n';
      });

      final carNumberFormatTests = [
        // Valid formats that should be accepted
        {
          'carNumber': 'KL01AB1234',
          'expected': true,
          'description': 'Valid Indian format (KL01AB1234)',
        },
        {
          'carNumber': 'TN9Z4321',
          'expected': true,
          'description': 'Valid Indian format (TN9Z4321)',
        },
        {
          'carNumber': 'MH20A1',
          'expected': true,
          'description': 'Valid Indian format (MH20A1)',
        },
        {
          'carNumber': 'KL 01 AB 1234',
          'expected': true,
          'description': 'Valid with spaces',
        },
        {
          'carNumber': 'tn9z4321',
          'expected': true,
          'description': 'Valid lowercase',
        },
        {
          'carNumber': 'DL8CAB9999',
          'expected': true,
          'description': 'Valid Delhi format',
        },
        {
          'carNumber': 'UP14BC5678',
          'expected': true,
          'description': 'Valid UP format',
        },
        {
          'carNumber': 'GJ1A123',
          'expected': true,
          'description': 'Valid Gujarat format',
        },
        // Invalid formats that should be rejected
        {
          'carNumber': 'KLL01',
          'expected': false,
          'description': 'Too many letters at start',
        },
        {
          'carNumber': '1234KL',
          'expected': false,
          'description': 'Numbers first',
        },
        {
          'carNumber': 'ABCD12345',
          'expected': false,
          'description': 'Too many letters',
        },
        {'carNumber': 'KL', 'expected': false, 'description': 'Too short'},
        {
          'carNumber': '12345',
          'expected': false,
          'description': 'Only numbers',
        },
        {
          'carNumber': 'ABCDE',
          'expected': false,
          'description': 'Only letters',
        },
        {
          'carNumber': 'K1AB1234',
          'expected': false,
          'description': 'Only 1 letter for state',
        },
        {
          'carNumber': 'KL01ABC12345',
          'expected': false,
          'description': 'Too many letters in series',
        },
        {
          'carNumber': 'KL01AB12345',
          'expected': false,
          'description': 'Too many digits',
        },
      ];

      for (final test in carNumberFormatTests) {
        final carNumber = test['carNumber'] as String;
        final expected = test['expected'] as bool;
        final description = test['description'] as String;

        final result = LicenseValidationService.isValidCarNumberFormat(
          carNumber,
        );
        final status = result == expected ? '✅' : '❌';

        setState(() {
          _testResults += '$status $description: $carNumber\n';
        });
      }

      setState(() {
        _testResults += '\n🔍 Testing Database Validation:\n';
      });

      // Test database validation with sample licenses
      for (final license in _sampleLicenses) {
        setState(() {
          _testResults += '\n🔄 Testing: $license\n';
        });

        final licenseData = await LicenseValidationService.validateLicense(
          license,
        );

        if (licenseData != null) {
          setState(() {
            _testResults +=
                '✅ Found: ${licenseData['name']} (${licenseData['district']})\n';
          });
        } else {
          setState(() {
            _testResults += '❌ Not found (expected for invalid licenses)\n';
          });
        }
      }

      setState(() {
        _testResults += '\n🎉 All tests completed!\n';
      });
    } catch (e) {
      setState(() {
        _testResults += '\n❌ Error during testing: $e\n';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearResults() {
    setState(() {
      _testResults = 'Ready to test license validation...';
    });
  }

  @override
  void dispose() {
    _licenseController.dispose();
    _carNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test License Validation'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'License Validation Testing',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Test individual licenses or run comprehensive validation tests.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // License input field
            TextField(
              controller: _licenseController,
              decoration: const InputDecoration(
                labelText: 'License ID',
                hintText: 'Enter license ID (e.g., KL01 20230000001)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.credit_card),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 10),

            // Car number input field
            TextField(
              controller: _carNumberController,
              decoration: const InputDecoration(
                labelText: 'Car Registration Number',
                hintText: 'Enter car number (e.g., KL01AB1234, TN9Z4321)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 10),

            // Test single license button
            ElevatedButton(
              onPressed: _isLoading ? null : _testSingleLicense,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Test This License'),
            ),
            const SizedBox(height: 10),

            // Test single car number button
            ElevatedButton(
              onPressed: _isLoading ? null : _testSingleCarNumber,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Test This Car Number'),
            ),
            const SizedBox(height: 10),

            // Run all tests button
            ElevatedButton(
              onPressed: _isLoading ? null : _runAllTests,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text('Running Tests...'),
                      ],
                    )
                  : const Text('Run All Tests'),
            ),
            const SizedBox(height: 10),

            // Clear results button
            ElevatedButton(
              onPressed: _isLoading ? null : _clearResults,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Clear Results'),
            ),
            const SizedBox(height: 10),

            const SizedBox(height: 20),

            // Sample licenses info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sample Test Data:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Licenses:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  ...(_sampleLicenses
                      .take(3)
                      .map(
                        (license) => Text(
                          '• $license',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      )),
                  const SizedBox(height: 8),
                  const Text(
                    'Car Numbers (Kerala format):',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const Text(
                    '• KL01 AB 1234',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                  const Text(
                    '• KL14 XY 9999',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                  const Text(
                    '• KL07 CD 5678',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Results display
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
                    _testResults,
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
}
