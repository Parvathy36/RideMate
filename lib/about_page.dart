import 'package:flutter/material.dart';
import 'service_page.dart';
import 'contact_page.dart';
import 'login_page.dart';
import 'register_page.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
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
                          _buildNavButton(
                            'Home',
                            false,
                            () => Navigator.pop(context),
                          ),
                          SizedBox(width: screenWidth > 1200 ? 32 : 16),
                          _buildNavButton('About', true, () {}),
                          SizedBox(width: screenWidth > 1200 ? 32 : 16),
                          _buildNavButton('Service', false, () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ServicePage(),
                              ),
                            );
                          }),
                          SizedBox(width: screenWidth > 1200 ? 32 : 16),
                          _buildNavButton('Contact', false, () {
                            Navigator.pushReplacement(
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
                            Navigator.pop(context);
                            break;
                          case 'about':
                            // Already on about page
                            break;
                          case 'service':
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ServicePage(),
                              ),
                            );
                            break;
                          case 'contact':
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ContactPage(),
                              ),
                            );
                            break;
                        }
                      },
                      itemBuilder: (context) =>
                          _buildResponsiveMenuItems(screenWidth, 'about'),
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
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 80),
                        // Enhanced App Icon with Animation
                        FadeTransition(
                          opacity: _fadeAnimation,
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
                        const SizedBox(height: 32),
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: const Text(
                            'About RideMate',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -1,
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
                        const SizedBox(height: 16),
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: const Text(
                            'Your premium ride-sharing experience',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // About Content
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  const Text(
                    'Our Story',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'RideMate was founded with a simple mission: to make transportation accessible, safe, and affordable for everyone. We believe that getting from point A to point B should be easy, reliable, and stress-free.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Text(
                    'Our Mission',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'To revolutionize urban transportation by connecting riders with reliable drivers through innovative technology, ensuring safe, convenient, and affordable rides for all.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Values Section
                  const Text(
                    'Our Values',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildValueCard(
                    icon: Icons.security,
                    title: 'Safety First',
                    description:
                        'Every driver is thoroughly vetted and all rides are tracked for your security.',
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),

                  _buildValueCard(
                    icon: Icons.handshake,
                    title: 'Reliability',
                    description:
                        'Count on us for consistent, on-time service whenever you need a ride.',
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),

                  _buildValueCard(
                    icon: Icons.favorite,
                    title: 'Community',
                    description:
                        'We\'re building a community of riders and drivers who care about each other.',
                    color: Colors.red,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    ];
  }
}
