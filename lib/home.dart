import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'map_screen.dart';
import 'services/firestore_service.dart';
import 'package:flutter/foundation.dart';
// Removed google_place to avoid http version conflict
import 'user_profile_page.dart';
import 'ride_history_page.dart';
import 'rides_booking.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final AuthService _authService = AuthService();
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  // Autocomplete for web removed; simple text fields are used
  String _selectedRideType = 'Solo'; // Default to Solo
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    // Initialize Razorpay
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    // Start animations
    _fadeController.forward();
    _slideController.forward();

    // Check for rides when user logs in
    _checkForRides();

    // Initialize Places for web (optional)
    // Web Places autocomplete removed
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pickupController.dispose();
    _destinationController.dispose();
    _razorpay.clear(); // Clear Razorpay listeners
    super.dispose();
  }

  // Show payment dialog that cannot be closed until payment is successful
  Future<void> _showPaymentDialog(Map<String, dynamic> ride) async {
    final rideId = ride['id'] as String;
    final fare = ride['fare'] as num? ?? 0;
    final pickup = ride['pickupAddress'] as String? ?? 'Unknown pickup';
    final destination = ride['destinationAddress'] as String? ?? 'Unknown destination';
    final driver = ride['driver'] as Map<String, dynamic>? ?? {};
    final rideType = ride['rideType'] as String? ?? 'Solo';
    
    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text(
            'Ride Booking Payment',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your ride has been accepted!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Pickup: $pickup',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  'Destination: $destination',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Text(
                  'Total Fare: ₹${fare.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Please complete the payment to confirm your ride.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                // Close the dialog
                Navigator.of(context).pop();
                
                // Navigate to rides booking page
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => RidesBookingPage(
                      rideId: rideId,
                      driverDetails: driver,
                      pickupAddress: pickup,
                      destinationAddress: destination,
                      fare: fare.toDouble(),
                      rideType: rideType,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Pay Now'),
            ),
          ],
        );
      },
    );
  }

  // Open Razorpay checkout
  void _openCheckout(String rideId, double amount) {
    var options = {
      'key':
          'rzp_test_RVQP1hirXQFCVn', // Provided test key
      'amount': (amount * 100).toInt(), // Amount in paise
      'name': 'RideMate',
      'description': 'Ride Payment',
      'prefill': {'contact': '', 'email': ''},
      'external': {
        'wallets': ['paytm'],
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      print('Error opening Razorpay: $e');
      // Handle the MissingPluginException by showing an error message
      if (e.toString().contains('MissingPluginException')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment gateway not available.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error opening payment gateway'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Handle payment success
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print('Payment successful: ${response.paymentId}');

    // Close the payment dialog
    Navigator.of(context).pop();

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment successful! Your ride is confirmed.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Handle payment error
  void _handlePaymentError(PaymentFailureResponse response) {
    print('Payment error: ${response.message}');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${response.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Handle external wallet
  void _handleExternalWallet(ExternalWalletResponse response) {
    print('External wallet: ${response.walletName}');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected wallet: ${response.walletName}'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  // Check for rides when user logs in
  Future<void> _checkForRides() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      // Get rides for this user
      final rides = await FirestoreService.getRidesForUser(user.uid);

      // Check each ride for status
      for (final ride in rides) {
        final status = ride['status'] as String?;
        final rideId = ride['id'] as String;

        if (status == 'accepted') {
          // Show payment dialog for accepted rides
          if (mounted) {
            _showPaymentDialog(ride);
          }
        } else if (status == 'rejected') {
          // Show rejection message for rejected rides
          if (mounted) {
            _showRejectionMessage(ride);
          }
        }
      }
    } catch (e) {
      print('Error checking for rides: $e');
    }
  }

  // Show rejection message for rejected rides
  void _showRejectionMessage(Map<String, dynamic> ride) {
    final rejectionReason =
        ride['rejectionReason'] as String? ?? 'No reason provided';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Your ride request was rejected: $rejectionReason'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _signOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
      }
    }
  }

  // Fetch available drivers from Firestore
  Future<List<Driver>> _getAvailableDrivers() async {
    try {
      final driversData = await FirestoreService.getAvailableDrivers();
      return driversData.map((data) => Driver.fromFirestore(data)).toList();
    } catch (e) {
      print('Error fetching drivers: $e');
      // Return empty list on error
      return [];
    }
  }

  double _calculateFare(Driver driver) {
    return driver.baseFare + (driver.distance * driver.perKmRate);
  }

  Widget _buildAvailableDriversList() {
    return FutureBuilder<List<Driver>>(
      future: _getAvailableDrivers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Colors.deepPurple),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load drivers',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again later',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        final drivers = snapshot.data ?? [];

        if (drivers.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.local_taxi_outlined,
                    color: Colors.grey,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No drivers available',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again later',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: drivers
                .map((driver) => _buildDriverCard(driver))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildDriverCard(Driver driver) {
    final fare = _calculateFare(driver);

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.deepPurple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          driver.rating.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Car Model',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      driver.carModel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Distance',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${driver.distance.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fare',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '₹${fare.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Handle driver selection
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Selected ${driver.name} - ${driver.carModel}',
                    ),
                    backgroundColor: Colors.deepPurple,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Select Driver',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Autocomplete dialog removed

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final user = _authService.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = MediaQuery.of(context).size.width;

            // Desktop/Large Tablet Layout (>800px)
            if (screenWidth > 800) {
              return Row(
                children: [
                  // RideMate Logo
                  Text(
                    'RideMate',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: screenWidth > 1200 ? 24 : 20,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: screenWidth > 1200 ? 60 : 30),
                  // Desktop Navigation Menu
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildNavButton('Home', true, () {}),
                          _buildNavButton('Ride History', false, () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RideHistoryPage(),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            // Mobile/Tablet Layout (≤800px)
            else {
              return Row(
                children: [
                  // Professional Hamburger Menu
                  Container(
                    margin: EdgeInsets.only(right: screenWidth < 400 ? 8 : 16),
                    child: PopupMenuButton<String>(
                      offset: const Offset(0, 50),
                      icon: Container(
                        padding: EdgeInsets.all(screenWidth < 600 ? 6 : 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.menu,
                          color: Colors.white,
                          size: screenWidth < 600 ? 18 : 20,
                        ),
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'home':
                            // Already on home page
                            break;
                          case 'ride_history':
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RideHistoryPage(),
                              ),
                            );
                            break;
                        }
                      },
                      itemBuilder: (context) =>
                          _buildResponsiveMenuItems(screenWidth, 'home'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 12,
                      color: Colors.white,
                      shadowColor: Colors.black.withValues(alpha: 0.2),
                    ),
                  ),
                  // RideMate Logo
                  Flexible(
                    child: Text(
                      'RideMate',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: screenWidth < 400
                            ? 18
                            : (screenWidth < 600 ? 20 : 24),
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                ],
              );
            }
          },
        ),
        actions: _buildResponsiveActions(context),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Section with Modern Design
            Stack(
              children: [
                Container(
                  height: size.height * 0.65,
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
                ),
                // Animated floating elements for modern look
                AnimatedBuilder(
                  animation: _fadeController,
                  builder: (context, child) {
                    return Positioned(
                      right: -80,
                      top: 100,
                      child: Transform.scale(
                        scale: _fadeAnimation.value,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.amber.withValues(alpha: 0.4),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.2),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                AnimatedBuilder(
                  animation: _slideController,
                  builder: (context, child) {
                    return Positioned(
                      left: -60,
                      top: 200,
                      child: Transform.translate(
                        offset: Offset(_slideAnimation.value.dx * 50, 0),
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.deepPurple.withValues(alpha: 0.5),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurple.withValues(alpha: 0.3),
                                blurRadius: 25,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: Column(
                    children: [
                      // Animated App Logo/Icon
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.amber, Colors.amber.shade600],
                              ),
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.4),
                                  blurRadius: 25,
                                  spreadRadius: 8,
                                  offset: const Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.local_taxi,
                              size: 45,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: const Text(
                            'Welcome to RideMate',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -1.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  offset: Offset(0, 4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Text(
                            user != null
                                ? 'Hello ${user.displayName ?? user.email}! Ready for your next ride?'
                                : 'Your premium ride experience awaits',
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Enhanced Modern Booking Card
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Colors.white, Colors.grey.shade50],
                                ),
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 40,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 15),
                                  ),
                                  BoxShadow(
                                    color: Colors.deepPurple.withValues(
                                      alpha: 0.08,
                                    ),
                                    blurRadius: 20,
                                    spreadRadius: -5,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Book Your Ride',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Fast, safe, and affordable',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _pickupController,
                                      readOnly: false,
                                      onTap: null,
                                      decoration: InputDecoration(
                                        labelText: 'Pickup location',
                                        labelStyle: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.my_location,
                                          color: Colors.deepPurple,
                                          size: 20,
                                        ),
                                        suffixIcon: null,
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.all(
                                          16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _destinationController,
                                      readOnly: false,
                                      onTap: null,
                                      decoration: InputDecoration(
                                        labelText: 'Where to?',
                                        labelStyle: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.location_on,
                                          color: Colors.amber,
                                          size: 20,
                                        ),
                                        suffixIcon: null,
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.all(
                                          16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Ride Type Selection
                                  const Text(
                                    'Choose your ride type',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildRideTypeOption(
                                          'Solo',
                                          Icons.person,
                                          'Private ride for you',
                                          Colors.deepPurple,
                                          _selectedRideType == 'Solo',
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildRideTypeOption(
                                          'Pooling',
                                          Icons.people,
                                          'Share ride, save money',
                                          Colors.amber,
                                          _selectedRideType == 'Pooling',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
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
                                          color: Colors.deepPurple.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        final pickup = _pickupController.text
                                            .trim();
                                        final destination =
                                            _destinationController.text.trim();
                                        if (pickup.isEmpty ||
                                            destination.isEmpty) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Please enter both pickup and destination',
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        // Create ride request in Firestore
                                        String? rideId;
                                        try {
                                          rideId =
                                              await FirestoreService.createRideRequest(
                                                pickupAddress: pickup,
                                                destinationAddress: destination,
                                                rideType: _selectedRideType,
                                              );
                                          if (rideId == null) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Failed to create ride. Try again.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                        } catch (e) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Error creating ride: $e',
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        // rideId is non-null here; navigation proceeds
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                MapScreen(rideId: rideId!),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Find Ride',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Enhanced Features Section with Modern Cards
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 100,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [const Color(0xFFFAFAFA), Colors.grey.shade50],
                ),
              ),
              child: Column(
                children: [
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Text(
                      'Why Choose RideMate?',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A2E),
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Text(
                      'Experience the future of transportation with premium features',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 60),
                  Row(
                    children: [
                      Expanded(
                        child: ModernFeatureCard(
                          icon: Icons.verified_user,
                          title: 'Safe & Secure',
                          description:
                              'Verified drivers with background checks',
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ModernFeatureCard(
                          icon: Icons.flash_on,
                          title: 'Quick Rides',
                          description: 'Average pickup time under 5 minutes',
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ModernFeatureCard(
                          icon: Icons.attach_money,
                          title: 'Fair Pricing',
                          description:
                              'Transparent pricing with no hidden fees',
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ModernFeatureCard(
                          icon: Icons.support_agent,
                          title: '24/7 Support',
                          description: 'Round-the-clock customer assistance',
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Testimonials Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
              child: Column(
                children: [
                  const Text(
                    'What Our Riders Say',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 40),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: const [
                        TestimonialCard(
                          name: 'Sarah J.',
                          review:
                              'RideMate makes my daily commute so much easier. The drivers are always professional!',
                          rating: 5,
                        ),
                        TestimonialCard(
                          name: 'Michael T.',
                          review:
                              'Love the premium vehicles. Worth every penny for the comfort and style.',
                          rating: 4,
                        ),
                        TestimonialCard(
                          name: 'Emma K.',
                          review:
                              'Fastest pickup times I\'ve experienced with any ride service.',
                          rating: 5,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Available Drivers Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Drivers',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildAvailableDriversList(),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.deepPurple.shade900,
                    Colors.deepPurple.shade800,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Image.asset('lib/assets/RideMate.png', height: 150),
                  const SizedBox(height: 30),
                  const Text(
                    'Download the app today',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DownloadButton(
                        icon: Icons.apple,
                        label: 'App Store',
                        onPressed: () {},
                      ),
                      const SizedBox(width: 20),
                      DownloadButton(
                        icon: Icons.android,
                        label: 'Play Store',
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    '© 2025 RideMate. All rights reserved.',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method for desktop navigation buttons
  Widget _buildNavButton(String title, bool isActive, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: isActive
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.transparent,
      ),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          fontSize: 16,
          decoration: isActive ? TextDecoration.underline : null,
        ),
      ),
    );
  }

  // Helper method for responsive menu items
  List<PopupMenuEntry<String>> _buildResponsiveMenuItems(
    double screenWidth,
    String currentPage,
  ) {
    final double iconSize = screenWidth < 600 ? 16 : 18;
    final double fontSize = screenWidth < 600 ? 14 : 15;
    final double verticalPadding = screenWidth < 600 ? 6 : 8;

    return [
      PopupMenuItem(
        value: 'home',
        child: Container(
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          child: Row(
            children: [
              Icon(Icons.home, size: iconSize, color: const Color(0xFF1A1A2E)),
              const SizedBox(width: 12),
              Text(
                'Home',
                style: TextStyle(
                  fontWeight: currentPage == 'home'
                      ? FontWeight.w600
                      : FontWeight.w500,
                  fontSize: fontSize,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              if (currentPage == 'home') ...[
                const Spacer(),
                const Icon(Icons.check, size: 16, color: Colors.amber),
              ],
            ],
          ),
        ),
      ),
      PopupMenuItem(
        value: 'ride_history',
        child: Container(
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          child: Row(
            children: [
              Icon(Icons.history, size: iconSize, color: const Color(0xFF1A1A2E)),
              const SizedBox(width: 12),
              Text(
                'Ride History',
                style: TextStyle(
                  fontWeight: currentPage == 'ride_history'
                      ? FontWeight.w600
                      : FontWeight.w500,
                  fontSize: fontSize,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  // Helper method for ride type option
  Widget _buildRideTypeOption(
    String title,
    IconData icon,
    String description,
    Color color,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRideType = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper method for responsive action buttons (Profile and Logout)
  List<Widget> _buildResponsiveActions(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final user = _authService.currentUser;

    // Responsive sizing for all screen sizes
    final double horizontalPadding = screenWidth < 400
        ? 8
        : (screenWidth < 600 ? 12 : 20);
    final double verticalPadding = screenWidth < 400
        ? 6
        : (screenWidth < 600 ? 8 : 10);
    final double fontSize = screenWidth < 400
        ? 11
        : (screenWidth < 600 ? 12 : 14);
    final double rightMargin = screenWidth < 400
        ? 2
        : (screenWidth < 600 ? 4 : 8);
    final double finalMargin = screenWidth < 400
        ? 4
        : (screenWidth < 600 ? 8 : 16);

    return [
      // Profile button
      Container(
        margin: EdgeInsets.only(right: rightMargin),
        child: TextButton.icon(
          onPressed: () {
            // Navigate to user profile page
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserProfilePage()),
            );
          },
          icon: Icon(
            Icons.person,
            color: Colors.white,
            size: screenWidth < 400 ? 16 : 18,
          ),
          label: screenWidth < 350
              ? const SizedBox.shrink()
              : Text(
                  screenWidth < 400 ? 'Profile' : 'Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: fontSize,
                  ),
                ),
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            minimumSize: Size(screenWidth < 400 ? 40 : 70, 32),
          ),
        ),
      ),
      // Logout button
      Container(
        margin: EdgeInsets.only(right: finalMargin),
        child: ElevatedButton(
          onPressed: _signOut,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            elevation: 0,
            minimumSize: Size(screenWidth < 400 ? 50 : 70, 32),
          ),
          child: Text(
            'Logout',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: fontSize),
          ),
        ),
      ),
    ];
  }
}

// Reuse the same widget classes from main.dart
class RideOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String price;
  final Color color;

  const RideOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.price,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(description, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            Text(
              price,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const FeatureItem({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.deepPurple),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TestimonialCard extends StatelessWidget {
  final String name;
  final String review;
  final int rating;

  const TestimonialCard({
    super.key,
    required this.name,
    required this.review,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 20),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade200,
                ),
                child: const Icon(Icons.person, color: Colors.grey),
              ),
              const SizedBox(width: 15),
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            review,
            style: const TextStyle(color: Colors.grey, fontSize: 15),
          ),
          const SizedBox(height: 15),
          Row(
            children: List.generate(
              5,
              (index) => Icon(
                Icons.star,
                color: index < rating ? Colors.amber : Colors.grey.shade300,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DownloadButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const DownloadButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        side: const BorderSide(color: Colors.white54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }
}

class ModernFeatureCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const ModernFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  State<ModernFeatureCard> createState() => _ModernFeatureCardState();
}

class _ModernFeatureCardState extends State<ModernFeatureCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
    _elevationAnimation = Tween<double>(begin: 8.0, end: 20.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _hoverController.forward(),
      onExit: (_) => _hoverController.reverse(),
      child: AnimatedBuilder(
        animation: _hoverController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.grey.shade50],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.15),
                    blurRadius: _elevationAnimation.value,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: _elevationAnimation.value * 1.5,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: widget.color.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.color.withValues(alpha: 0.15),
                          widget.color.withValues(alpha: 0.25),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 28),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.description,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Driver model class
class Driver {
  final String name;
  final String carModel;
  final String carNumber;
  final double rating;
  final double distance; // in kilometers
  final double baseFare;
  final double perKmRate;
  final String? imageUrl;
  final String? userId;
  final String? email;
  final String? phoneNumber;

  Driver({
    required this.name,
    required this.carModel,
    required this.carNumber,
    required this.rating,
    required this.distance,
    required this.baseFare,
    required this.perKmRate,
    this.imageUrl,
    this.userId,
    this.email,
    this.phoneNumber,
  });

  // Constructor to create Driver from Firestore data
  factory Driver.fromFirestore(Map<String, dynamic> data) {
    // Calculate distance based on current location (simplified for demo)
    // In real app, you would calculate distance from user's location
    final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
    final distance = (data['distance'] as num?)?.toDouble() ?? (2.0 + rating);

    // Calculate fare based on car model
    double baseFare = 50.0;
    double perKmRate = 12.0;

    final carModel = (data['carModel'] as String?) ?? 'Unknown';
    switch (carModel.toLowerCase()) {
      case 'honda city':
        baseFare = 60.0;
        perKmRate = 15.0;
        break;
      case 'toyota innova':
        baseFare = 80.0;
        perKmRate = 18.0;
        break;
      case 'hyundai creta':
        baseFare = 70.0;
        perKmRate = 16.0;
        break;
      case 'maruti swift':
        baseFare = 50.0;
        perKmRate = 12.0;
        break;
      default:
        baseFare = 60.0;
        perKmRate = 14.0;
    }

    return Driver(
      name: data['name'] as String? ?? 'Unknown Driver',
      carModel: carModel,
      carNumber: data['carNumber'] as String? ?? 'Unknown',
      rating: (data['rating'] as num?)?.toDouble() ?? 4.5,
      distance: distance,
      baseFare: baseFare,
      perKmRate: perKmRate,
      imageUrl: data['profileImageUrl'] as String?,
      userId: data['id'] as String?,
      email: data['email'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
    );
  }
}
