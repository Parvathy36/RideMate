import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'login_page.dart';
import 'services/auth_service.dart';
import 'home.dart';
import 'admin.dart';
import 'debug_page.dart';

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
  final _carModelController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _autoValidate = false;
  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;
  bool _isDriverRegistration =
      false; // Toggle between user and driver registration

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
    'Honda Jazz',
    'Toyota Innova Crysta',
    'Toyota Fortuner',
    'Toyota Glanza',
    'Kia Seltos',
    'Kia Sonet',
    'Skoda Rapid',
    'Volkswagen Polo',
    'Renault Kwid',
    'Nissan Magnite',
    'MG Hector',
    'Other',
  ];
  String? _selectedCarModel;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validateForm);
    _emailController.addListener(_validateForm);
    _phoneController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
    _confirmPasswordController.addListener(_validateForm);
    _licenseIdController.addListener(_validateForm);
    _carModelController.addListener(_validateForm);
  }

  void _validateForm() {
    if (_autoValidate) {
      _formKey.currentState?.validate();
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your full name';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (value.length > 20) {
      return 'Name must not exceed 20 characters';
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

    // Check if first digit is 6, 7, 8, or 9
    String firstDigit = phoneNumber[0];
    if (!['6', '7', '8', '9'].contains(firstDigit)) {
      return 'Phone number must start with 6, 7, 8, or 9';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
      return 'Password must contain uppercase, lowercase and number';
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
    if (value == null || value.isEmpty) {
      return 'Please enter your driving license ID';
    }

    // Remove spaces and convert to uppercase for validation
    String cleanedValue = value.replaceAll(' ', '').toUpperCase();

    // Indian Driving License Format: SS-YYNNNNNNNNN
    // SS = State code (2 letters), YY = Year (2 digits), NNNNNNNNN = Unique number (9 digits)
    RegExp licenseRegex = RegExp(r'^[A-Z]{2}-\d{11}$');

    if (!licenseRegex.hasMatch(cleanedValue)) {
      return 'Invalid license format. Use: SS-YYNNNNNNNNN (e.g., KL-2012345678901)';
    }

    // Validate state codes (common Indian state codes)
    List<String> validStateCodes = [
      'AP',
      'AR',
      'AS',
      'BR',
      'CG',
      'GA',
      'GJ',
      'HR',
      'HP',
      'JH',
      'KA',
      'KL',
      'MP',
      'MH',
      'MN',
      'ML',
      'MZ',
      'NL',
      'OR',
      'PB',
      'RJ',
      'SK',
      'TN',
      'TG',
      'TR',
      'UP',
      'UK',
      'WB',
      'AN',
      'CH',
      'DN',
      'DD',
      'DL',
      'JK',
      'LA',
      'LD',
      'PY',
    ];

    String stateCode = cleanedValue.substring(0, 2);
    if (!validStateCodes.contains(stateCode)) {
      return 'Invalid state code. Please use a valid Indian state code';
    }

    return null;
  }

  String? _validateCarModel(String? value) {
    if (_isDriverRegistration && (value == null || value.isEmpty)) {
      return 'Please select your car model';
    }
    return null;
  }

  Future<void> _submitForm() async {
    setState(() {
      _autoValidate = true;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isEmailLoading = true;
    });

    try {
      print('Starting registration process...');
      print('Email: ${_emailController.text.trim()}');
      print('Name: ${_nameController.text.trim()}');

      final result = await _authService.registerWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
        isDriver: _isDriverRegistration,
        licenseId: _isDriverRegistration
            ? _licenseIdController.text.trim()
            : null,
        carModel: _isDriverRegistration
            ? (_selectedCarModel == 'Other'
                  ? _carModelController.text.trim()
                  : _selectedCarModel)
            : null,
        phoneNumber: _phoneController.text.trim(),
      );

      print('Registration result: $result');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isDriverRegistration
                  ? 'Driver registration successful! Awaiting approval.'
                  : 'Account created successfully!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        print('Showing success message and navigating...');

        // Wait longer for the user to see the success message
        await Future.delayed(const Duration(milliseconds: 2500));

        // Navigate to appropriate page after successful registration
        if (mounted) {
          // Check if user is admin and redirect accordingly
          if (_authService.isAdmin()) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const AdminPage()),
              (route) => false, // Remove all previous routes
            );
            print('Navigation to AdminPage completed');
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
              (route) => false, // Remove all previous routes
            );
            print('Navigation to HomePage completed');
          }
        }
      }
    } catch (e) {
      print('Registration error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEmailLoading = false;
        });
        print('Loading state set to false');
      }
    }
  }

  Future<void> _signUpWithGoogle() async {
    print('Google Sign-Up button pressed');
    setState(() {
      _isGoogleLoading = true;
    });

    try {
      print('Calling AuthService.signInWithGoogle() for registration...');
      final result = await _authService.signInWithGoogle();
      print('AuthService.signInWithGoogle() returned: $result');

      if (result != null && mounted) {
        print('Google sign-up successful, showing success message...');

        // Show success message and wait for it to be visible
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully with Google!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        print('Success message shown, waiting before navigation...');

        // Wait longer for the user to see the success message
        await Future.delayed(const Duration(milliseconds: 2500));

        // Navigate to appropriate page after successful registration
        if (mounted) {
          print('Checking admin status for navigation...');
          final isAdmin = _authService.isAdmin();
          print('Is admin: $isAdmin');

          // Reset loading state just before navigation
          setState(() {
            _isGoogleLoading = false;
          });

          // Check if user is admin and redirect accordingly
          if (isAdmin) {
            print('Navigating to AdminPage...');
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const AdminPage()),
              (route) => false, // Remove all previous routes
            );
          } else {
            print('Navigating to HomePage...');
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
              (route) => false, // Remove all previous routes
            );
          }
          print('Navigation completed');
        }
      } else {
        print(
          'Google sign-up result was null (user cancelled) or widget not mounted',
        );
        // Reset loading state when user cancels
        if (mounted) {
          setState(() {
            _isGoogleLoading = false;
          });
        }
      }
    } catch (e) {
      print('Google sign-up error in register page: $e');
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign-up failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _licenseIdController.dispose();
    _carModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Sign Up'),
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
              height: size.height * 0.4,
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
                    top: 120,
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
                        Text(
                          _isDriverRegistration
                              ? 'Drive with RideMate'
                              : 'Join RideMate',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isDriverRegistration
                              ? 'Start earning by becoming a driver'
                              : 'Create your account to get started',
                          style: const TextStyle(
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

            // Modern Register Form
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
                    const SizedBox(height: 8),
                    Text(
                      _isDriverRegistration
                          ? 'Register as Driver'
                          : 'Create your account',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isDriverRegistration
                          ? 'Fill in your driver details to get started'
                          : 'Fill in your details to get started',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Registration Type Toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
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
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: !_isDriverRegistration
                                      ? Colors.deepPurple
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'User',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: !_isDriverRegistration
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
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
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _isDriverRegistration
                                      ? Colors.deepPurple
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Driver',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _isDriverRegistration
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Name Field (Dynamic label)
                    Text(
                      _isDriverRegistration ? 'Driver Name' : 'Full Name',
                      style: const TextStyle(
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
                          hintText: 'Enter your phone number',
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

                    // Driver-specific fields
                    if (_isDriverRegistration) ...[
                      // License ID Field
                      const Text(
                        'Driving License ID',
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
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: 'e.g., KL-2012345678901',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            prefixIcon: Icon(
                              Icons.credit_card_outlined,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
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
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedCarModel = newValue;
                              if (newValue == 'Other') {
                                // If "Other" is selected, show text field
                                _carModelController.clear();
                              } else {
                                _carModelController.text = newValue ?? '';
                              }
                            });
                          },
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          style: const TextStyle(
                            color: Color(0xFF1A1A2E),
                            fontSize: 14,
                          ),
                        ),
                      ),

                      // Custom car model field (shown when "Other" is selected)
                      if (_selectedCarModel == 'Other') ...[
                        const SizedBox(height: 12),
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
                            controller: _carModelController,
                            validator: (value) {
                              if (_selectedCarModel == 'Other' &&
                                  (value == null || value.isEmpty)) {
                                return 'Please enter your car model';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              hintText: 'Enter your car model',
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              prefixIcon: Icon(
                                Icons.edit_outlined,
                                color: Colors.grey.shade600,
                                size: 20,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],

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
                    const SizedBox(height: 32),

                    // Create Account Button
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
                            : _submitForm,
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

                    // Show Google sign-up only for regular users, not drivers
                    if (!_isDriverRegistration) ...[
                      const SizedBox(height: 24),

                      // Divider with "OR"
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: Colors.grey.shade300,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Google Sign-Up Button (only for users)
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: (_isEmailLoading || _isGoogleLoading)
                              ? null
                              : _signUpWithGoogle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isGoogleLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.grey,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        image: DecorationImage(
                                          image: NetworkImage(
                                            'https://developers.google.com/identity/images/g-logo.png',
                                          ),
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Sign up with Google',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],

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
