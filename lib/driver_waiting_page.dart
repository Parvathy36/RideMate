import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'services/auth_service.dart';
import 'login_page.dart';

class DriverWaitingPage extends StatefulWidget {
  const DriverWaitingPage({super.key});

  @override
  State<DriverWaitingPage> createState() => _DriverWaitingPageState();
}

class _DriverWaitingPageState extends State<DriverWaitingPage>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  Map<String, dynamic>? _driverData;
  bool _isLoading = true;
  StreamSubscription<DocumentSnapshot>? _driverStreamSubscription;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Start animations
    _pulseController.repeat(reverse: true);
    _fadeController.forward();

    // Load driver data
    _listenToDriverData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _driverStreamSubscription?.cancel();
    super.dispose();
  }

  void _listenToDriverData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _driverStreamSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen(
            (DocumentSnapshot snapshot) {
              if (snapshot.exists) {
                setState(() {
                  _driverData = snapshot.data() as Map<String, dynamic>?;
                  _isLoading = false;
                });
              } else {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onError: (error) {
              print('Error listening to driver data: $error');
              setState(() {
                _isLoading = false;
              });
            },
          );
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              )
            : _driverData?['isApproved'] == false
            ? _buildRejectionContent()
            : _buildWaitingContent(),
      ),
    );
  }

  Widget _buildWaitingContent() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F0F23), Color(0xFF16213E), Color(0xFF1A1A2E)],
        ),
      ),
      child: Column(
        children: [
          // Header with sign out button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'RideMate',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                IconButton(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Scrollable main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    // Animated waiting icon
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.amber, Colors.amber.shade600],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.hourglass_empty,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // Title
                    const Text(
                      'Registration Under Review',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // Subtitle
                    Text(
                      'Hi ${_driverData?['name'] ?? 'Driver'}!\nYour driver registration is being reviewed by our admin team.',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),

                    // Status card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.amber,
                            size: 32,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'What happens next?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '• Admin will verify your license details\n'
                            '• Your vehicle information will be reviewed\n'
                            '• You\'ll receive approval notification\n'
                            '• Once approved, you can start accepting rides',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Estimated review time: 24-48 hours',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Driver details summary
                    if (_driverData != null) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Registration Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              'License ID',
                              _driverData!['licenseId'] ?? 'N/A',
                            ),
                            _buildDetailRow(
                              'Car Model',
                              _driverData!['carModel'] ?? 'N/A',
                            ),
                            _buildDetailRow(
                              'Phone',
                              _driverData!['phoneNumber'] ?? 'N/A',
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 40), // Bottom padding
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionContent() {
    final rejectionMessage =
        _driverData?['rejectionMessage'] ??
        'Your registration has been rejected by the admin.';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F0F23), Color(0xFF16213E), Color(0xFF1A1A2E)],
        ),
      ),
      child: Column(
        children: [
          // Header with sign out button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'RideMate',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                IconButton(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Scrollable main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    // Animated rejection icon
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.red, Colors.red.shade600],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.cancel,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // Title
                    const Text(
                      'Registration Rejected',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // Subtitle
                    Text(
                      'Hi ${_driverData?['name'] ?? 'Driver'}!',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    // Rejection message card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 32,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Reason for Rejection',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            rejectionMessage,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Driver details summary in rejection view
                    if (_driverData != null) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Registration Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              'Name',
                              _driverData!['name'] ?? 'N/A',
                            ),
                            _buildDetailRow(
                              'License ID',
                              _driverData!['licenseId'] ?? 'N/A',
                            ),
                            _buildDetailRow(
                              'Car Model',
                              _driverData!['carModel'] ?? 'N/A',
                            ),
                            _buildDetailRow(
                              'Phone',
                              _driverData!['phoneNumber'] ?? 'N/A',
                            ),
                            _buildDetailRow(
                              'Registration Date',
                              _driverData!['registrationDate'] != null
                                  ? '${(_driverData!['registrationDate'] as Timestamp).toDate()}'
                                  : 'N/A',
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.white60),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
