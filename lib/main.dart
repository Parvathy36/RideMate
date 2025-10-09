import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'about_page.dart';
import 'service_page.dart';
import 'contact_page.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'home.dart';
import 'admin.dart';
import 'firebase_test.dart';
import 'driver_waiting_page.dart';
import 'driver_dashboard.dart';
import 'debug_page.dart';
import 'email_verification_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Google Maps Flutter
  if (!kIsWeb) {
    // For Android and iOS, set the API key
    // The API key is already configured in platform-specific files
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully in main()');

    // Run Firebase connection test
    await FirebaseTest.testFirebaseConnection();

    // Initialize Firestore with license data
    await FirestoreService.initializeFirestore();

    // Test Email/Password authentication (uncomment after enabling in Firebase Console)
    // await FirebaseTest.testEmailPasswordAuth();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully in main()');

    // Run Firebase connection test
    await FirebaseTest.testFirebaseConnection();

    // Initialize Firestore with license data
    await FirestoreService.initializeFirestore();

    // Test Email/Password authentication (uncomment after enabling in Firebase Console)
    // await FirebaseTest.testEmailPasswordAuth();

    // Initialize Google Maps Flutter
    if (!kIsWeb) {
      // For Android and iOS, initialize with API key
      // The API key is already configured in platform-specific files
    }
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
  }

  runApp(const RideShareApp());
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
}

class RideShareApp extends StatelessWidget {
  const RideShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RideMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1A2E),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          // User is logged in, check user type from users collection
          print('🔍 Checking user: ${snapshot.data!.uid}');
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (userSnapshot.hasError) {
                return const Scaffold(
                  body: Center(child: Text('Error loading user data')),
                );
              }

              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>;
                final userType = userData['userType'] ?? 'user';

                print('👤 User found in users collection');
                print('📊 User data: $userData');
                print('🏷️ userType: $userType');

                // Route directly based on userType
                if (userType == 'admin') {
                  print('➡️ Routing to AdminPage');
                  return const AdminPage();
                } else if (userType == 'driver') {
                  // Check if driver is approved
                  final isApproved = userData['isApproved'] ?? false;

                  if (isApproved) {
                    print('➡️ Routing to DriverDashboard (approved)');
                    return const DriverDashboard();
                  } else {
                    print('➡️ Routing to DriverWaitingPage (not approved)');
                    return const DriverWaitingPage();
                  }
                } else {
                  print('➡️ Routing to HomePage');
                  return const HomePage();
                }
              } else {
                // No user data found, default to home page
                print(
                  '❌ User not found in users collection, defaulting to HomePage',
                );
                return const HomePage();
              }
            },
          );
        } else {
          // User is not logged in, show landing page
          return const LandingPage();
        }
      },
    );
  }
}

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
                          SizedBox(width: screenWidth > 1200 ? 32 : 16),
                          _buildNavButton('About', false, () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AboutPage(),
                              ),
                            );
                          }),
                          SizedBox(width: screenWidth > 1200 ? 32 : 16),
                          _buildNavButton('Service', false, () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ServicePage(),
                              ),
                            );
                          }),
                          SizedBox(width: screenWidth > 1200 ? 32 : 16),
                          _buildNavButton('Contact', false, () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ContactPage(),
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
                          case 'about':
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AboutPage(),
                              ),
                            );
                            break;
                          case 'service':
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ServicePage(),
                              ),
                            );
                            break;
                          case 'contact':
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ContactPage(),
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
                            'RideMate',
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
                          child: const Text(
                            'Your premium ride experience awaits',
                            style: TextStyle(
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
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.all(
                                          16,
                                        ),
                                      ),
                                    ),
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
                                      onPressed: () {},
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
                              'UrbanRide makes my daily commute so much easier. The drivers are always professional!',
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
        value: 'about',
        child: Container(
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          child: Row(
            children: [
              Icon(Icons.info, size: iconSize, color: const Color(0xFF1A1A2E)),
              const SizedBox(width: 12),
              Text(
                'About',
                style: TextStyle(
                  fontWeight: currentPage == 'about'
                      ? FontWeight.w600
                      : FontWeight.w500,
                  fontSize: fontSize,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              if (currentPage == 'about') ...[
                const Spacer(),
                const Icon(Icons.check, size: 16, color: Colors.amber),
              ],
            ],
          ),
        ),
      ),
      PopupMenuItem(
        value: 'service',
        child: Container(
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          child: Row(
            children: [
              Icon(Icons.build, size: iconSize, color: const Color(0xFF1A1A2E)),
              const SizedBox(width: 12),
              Text(
                'Service',
                style: TextStyle(
                  fontWeight: currentPage == 'service'
                      ? FontWeight.w600
                      : FontWeight.w500,
                  fontSize: fontSize,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              if (currentPage == 'service') ...[
                const Spacer(),
                const Icon(Icons.check, size: 16, color: Colors.amber),
              ],
            ],
          ),
        ),
      ),
      PopupMenuItem(
        value: 'contact',
        child: Container(
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          child: Row(
            children: [
              Icon(
                Icons.contact_mail,
                size: iconSize,
                color: const Color(0xFF1A1A2E),
              ),
              const SizedBox(width: 12),
              Text(
                'Contact',
                style: TextStyle(
                  fontWeight: currentPage == 'contact'
                      ? FontWeight.w600
                      : FontWeight.w500,
                  fontSize: fontSize,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              if (currentPage == 'contact') ...[
                const Spacer(),
                const Icon(Icons.check, size: 16, color: Colors.amber),
              ],
            ],
          ),
        ),
      ),
    ];
  }

  // Helper method for responsive action buttons
  List<Widget> _buildResponsiveActions(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

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

    // For very small screens, show only Login button
    if (screenWidth < 350) {
      return [
        Container(
          margin: EdgeInsets.only(right: finalMargin),
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: const Color(0xFF1A1A2E),
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 0,
              minimumSize: Size(60, 32),
            ),
            child: Text(
              'Login',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: fontSize),
            ),
          ),
        ),
      ];
    }

    // For larger screens, show both buttons
    return [
      Container(
        margin: EdgeInsets.only(right: rightMargin),
        child: TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RegisterPage()),
            );
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            minimumSize: Size(screenWidth < 400 ? 50 : 70, 32),
          ),
          child: Text(
            screenWidth < 400 ? 'Sign' : 'Sign Up',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
            ),
          ),
        ),
      ),
      Container(
        margin: EdgeInsets.only(right: finalMargin),
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: const Color(0xFF1A1A2E),
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
            'Login',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: fontSize),
          ),
        ),
      ),
      // Debug button (only in debug mode)
      if (kDebugMode)
        Container(
          margin: EdgeInsets.only(right: finalMargin),
          child: IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DebugPage()),
              );
            },
            icon: const Icon(Icons.storage, color: Colors.white70, size: 20),
            tooltip: 'Firestore Test',
          ),
        ),
    ];
  }
}

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
