import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'login_page.dart';
import 'services/auth_service.dart';
import 'services/license_validation_service.dart';
import 'home.dart';
import 'admin.dart';
import 'debug_page.dart';
import 'driver_waiting_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  // Driver-specific controllers
  final _licenseIdController = TextEditingController();
  final _carNumberController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _autoValidate = false;
  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;
  bool _isDriverRegistration =
      false; // Toggle between user and driver registration
  bool _isValidatingLicense = false;
  String? _licenseHolderName;
  String? _selectedCarModel;

  // Car models list
  final List<String> _carModels = [
    'Maruti Suzuki Swift',
    'Maruti Suzuki Baleno',
    'Maruti Suzuki Dzire',
    'Maruti Suzuki Alto',
    'Maruti Suzuki WagonR',
    'Hyundai i20',
    'Hyundai Creta',
    'Hyundai Verna',
    'Hyundai Grand i10',
    'Tata Nexon',
    'Tata Harrier',
    'Tata Altroz',
    'Tata Tiago',
    'Mahindra XUV700',
    'Mahindra Scorpio',
    'Mahindra Bolero',
    'Honda City',
    'Honda Amaze',
    'Toyota Innova',
    'Toyota Fortuner',
    'Kia Seltos',
    'Kia Sonet',
    'Nissan Magnite',
    'Renault Kwid',
    'Ford EcoSport',
    'Volkswagen Polo',
    'Skoda Rapid',
    'MG Hector',
    'Jeep Compass',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _licenseIdController.dispose();
    _carNumberController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your name';
    }

    // Check minimum length
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters long';
    }

    // Check maximum length
    if (value.trim().length > 50) {
      return 'Name must be less than 50 characters';
    }

    // Check if first letter is capitalized
    String trimmedValue = value.trim();
    if (trimmedValue.isNotEmpty && !RegExp(r'^[A-Z]').hasMatch(trimmedValue)) {
      return 'Name must start with a capital letter';
    }

    // Check if name contains only letters and spaces
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(trimmedValue)) {
      return 'Name must contain only letters and spaces';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    String emailRegex = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
    if (!RegExp(emailRegex).hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }

    // Remove all spaces and special characters except +
    String cleanedValue = value.replaceAll(RegExp(r'[^\d+]'), '');

    // Check if it starts with +91 (India country code)
    if (!cleanedValue.startsWith('+91')) {
      return 'Phone number must start with +91 (India)';
    }

    // Remove +91 to get the actual phone number
    String phoneNumber = cleanedValue.substring(3);

    // Check if phone number is exactly 10 digits
    if (phoneNumber.length != 10) {
      return 'Phone number must be exactly 10 digits after +91';
    }

    // Check if all characters are digits
    if (!RegExp(r'^[0-9]+$').hasMatch(phoneNumber)) {
      return 'Phone number must contain only digits';
    }

    // Check if phone number starts with valid digits (6-9)
    if (!RegExp(r'^[6-9]').hasMatch(phoneNumber)) {
      return 'Phone number must start with 6, 7, 8, or 9';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  String? _validateLicenseId(String? value) {
    if (!_isDriverRegistration) return null;

    if (value == null || value.isEmpty) {
      return 'Please enter your license ID';
    }

    // Check format
    if (!LicenseValidationService.isValidLicenseFormat(value)) {
      return 'Invalid license format. Use Kerala format: KLDD YYYYNNNNNNN (e.g., KL01 20230000001)';
    }

    return null;
  }

  String? _validateCarModel(String? value) {
    if (!_isDriverRegistration) return null;

    if (value == null || value.isEmpty) {
      return 'Please select your car model';
    }
    return null;
  }

  String? _validateCarNumber(String? value) {
    if (!_isDriverRegistration) return null;

    if (value == null || value.isEmpty) {
      return 'Please enter your car registration number';
    }

    // Check format using the service
    if (!LicenseValidationService.isValidCarNumberFormat(value)) {
      return 'Invalid car number format. Use Kerala format: KLDD XX NNNN (e.g., KL01 AB 1234)';
    }

    return null;
  }

  Future<void> _validateLicenseInDatabase() async {
    if (!_isDriverRegistration || _licenseIdController.text.isEmpty) return;

    setState(() {
      _isValidatingLicense = true;
      _licenseHolderName = null;
    });

    try {
      final validationResult =
          await LicenseValidationService.validateLicenseDetailed(
            _licenseIdController.text.trim(),
          );

      setState(() {
        _isValidatingLicense = false;
        if (validationResult['isValid'] == true) {
          final licenseData =
              validationResult['licenseData'] as Map<String, dynamic>;
          _licenseHolderName = licenseData['name'];
        } else {
          _licenseHolderName = null;
        }
      });

      if (validationResult['isValid'] == true) {
        final licenseData =
            validationResult['licenseData'] as Map<String, dynamic>;
        final daysUntilExpiry = validationResult['daysUntilExpiry'];

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'License verified for ${licenseData['name']} (expires in $daysUntilExpiry days)',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final status = validationResult['status'];
        final message = validationResult['message'];
        String errorMessage = message;

        // Provide specific error messages based on status
        if (status == 'expired') {
          final daysExpired = validationResult['daysExpired'];
          errorMessage =
              'License expired $daysExpired days ago. Please renew your license.';
        } else if (status == 'inactive') {
          errorMessage = 'License is not active. Please contact RTO.';
        } else if (status == 'not_found') {
          errorMessage = 'License ID not found in database.';
        } else if (status == 'invalid_format') {
          errorMessage =
              'Invalid license format. Use Kerala format: KLDD YYYYNNNNNNN';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isValidatingLicense = false;
        _licenseHolderName = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error validating license: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _registerWithEmail() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _autoValidate = true;
      });
      return;
    }

    // For driver registration, validate license in database
    if (_isDriverRegistration) {
      if (_licenseHolderName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please validate your license ID first'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check if car number is already registered
      if (_carNumberController.text.trim().isNotEmpty) {
        try {
          final isCarRegistered =
              await LicenseValidationService.isCarNumberAlreadyRegistered(
                _carNumberController.text.trim(),
              );
          if (isCarRegistered) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'This car number is already registered with another driver',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error checking car number: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }
    }

    setState(() {
      _isEmailLoading = true;
    });

    try {
      final user = await _authService.registerWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
        isDriver: _isDriverRegistration,
        phoneNumber: _phoneController.text.trim(),
        licenseId: _isDriverRegistration
            ? _licenseIdController.text.trim()
            : null,
        carModel: _isDriverRegistration ? _selectedCarModel : null,
        carNumber: _isDriverRegistration
            ? _carNumberController.text.trim()
            : null,
      );

      if (user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isDriverRegistration
                  ? 'Driver registration successful! Please wait for admin approval.'
                  : 'Registration successful!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate based on user type
        if (_isDriverRegistration) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DriverWaitingPage()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEmailLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Modern Header Section
            Container(
              height: size.height * 0.35,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1A1A2E),
                    const Color(0xFF16213E),
                    Colors.deepPurple.shade800,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Floating design elements
                  Positioned(
                    right: -60,
                    top: 80,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.amber.withValues(alpha: 0.2),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -40,
                    top: 150,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.deepPurple.withValues(alpha: 0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 80),
                        // App Icon
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.3),
                                blurRadius: 15,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_taxi,
                            size: 35,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Join RideMate',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create your account to get started',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Modern Registration Form
            Container(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                autovalidateMode: _autoValidate
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),

                    // Registration Type Toggle
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isDriverRegistration = false;
                                  _licenseHolderName = null;
                                  _licenseIdController.clear();
                                  _carNumberController.clear();
                                  _selectedCarModel = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: !_isDriverRegistration
                                      ? Colors.deepPurple
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: !_isDriverRegistration
                                      ? [
                                          BoxShadow(
                                            color: Colors.deepPurple.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  'User',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: !_isDriverRegistration
                                        ? Colors.white
                                        : const Color(0xFF1A1A2E),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isDriverRegistration = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: _isDriverRegistration
                                      ? Colors.deepPurple
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: _isDriverRegistration
                                      ? [
                                          BoxShadow(
                                            color: Colors.deepPurple.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  'Driver',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _isDriverRegistration
                                        ? Colors.white
                                        : const Color(0xFF1A1A2E),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Form Title
                    Text(
                      _isDriverRegistration
                          ? 'Create Driver Account'
                          : 'Create User Account',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Fill in your details to get started',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Name Field
                    const Text(
                      'Full Name',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: TextFormField(
                        controller: _nameController,
                        validator: _validateName,
                        decoration: InputDecoration(
                          hintText: 'Enter your full name',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Email Field
                    const Text(
                      'Email Address',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: TextFormField(
                        controller: _emailController,
                        validator: _validateEmail,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Enter your email',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Phone Field
                    const Text(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: TextFormField(
                        controller: _phoneController,
                        validator: _validatePhone,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: '+91XXXXXXXXXX',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          prefixIcon: Icon(
                            Icons.phone_outlined,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Password Field
                    const Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: TextFormField(
                        controller: _passwordController,
                        validator: _validatePassword,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'Enter your password',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Confirm Password Field
                    const Text(
                      'Confirm Password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: TextFormField(
                        controller: _confirmPasswordController,
                        validator: _validateConfirmPassword,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          hintText: 'Confirm your password',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),

                    // Driver-specific fields
                    if (_isDriverRegistration) ...[
                      const SizedBox(height: 20),

                      // License ID Field
                      const Text(
                        'License ID',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: TextFormField(
                          controller: _licenseIdController,
                          validator: _validateLicenseId,
                          decoration: InputDecoration(
                            hintText: 'KL01 20230000001',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            prefixIcon: Icon(
                              Icons.credit_card,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                            suffixIcon: _isValidatingLicense
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : IconButton(
                                    onPressed: _validateLicenseInDatabase,
                                    icon: Icon(
                                      _licenseHolderName != null
                                          ? Icons.check_circle
                                          : Icons.search,
                                      color: _licenseHolderName != null
                                          ? Colors.green
                                          : Colors.grey.shade600,
                                      size: 20,
                                    ),
                                  ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          onChanged: (value) {
                            if (_licenseHolderName != null) {
                              setState(() {
                                _licenseHolderName = null;
                              });
                            }
                          },
                        ),
                      ),

                      // License validation result
                      if (_licenseHolderName != null)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Valid License - Holder: $_licenseHolderName',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Car Model Field
                      const Text(
                        'Car Model',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedCarModel,
                          validator: _validateCarModel,
                          decoration: InputDecoration(
                            hintText: 'Select your car model',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            prefixIcon: Icon(
                              Icons.directions_car_outlined,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          items: _carModels.map((String model) {
                            return DropdownMenuItem<String>(
                              value: model,
                              child: Text(
                                model,
                                style: const TextStyle(
                                  color: Color(0xFF1A1A2E),
                                  fontSize: 14,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedCarModel = newValue;
                            });
                          },
                          dropdownColor: Colors.white,
                          icon: Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Car Number Field
                      const Text(
                        'Car Registration Number',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: TextFormField(
                          controller: _carNumberController,
                          validator: _validateCarNumber,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: 'Enter car number (e.g., KL01 AB 1234)',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            prefixIcon: Icon(
                              Icons.confirmation_number_outlined,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Register Button
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepPurple,
                            Colors.deepPurple.shade700,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: (_isEmailLoading || _isGoogleLoading)
                            ? null
                            : _registerWithEmail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isEmailLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _isDriverRegistration
                                    ? 'Register as Driver'
                                    : 'Create Account',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Sign In Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account? ",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginPage(),
                              ),
                            );
                          },
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
