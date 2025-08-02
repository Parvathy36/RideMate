import 'package:flutter/material.dart';
import 'about_page.dart';
import 'contact_page.dart';
import 'login_page.dart';
import 'register_page.dart';

class ServicePage extends StatefulWidget {
  const ServicePage({super.key});

  @override
  State<ServicePage> createState() => _ServicePageState();
}

class _ServicePageState extends State<ServicePage> {
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
                          _buildNavButton('About', false, () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AboutPage(),
                              ),
                            );
                          }),
                          SizedBox(width: screenWidth > 1200 ? 32 : 16),
                          _buildNavButton('Service', true, () {}),
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
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AboutPage(),
                              ),
                            );
                            break;
                          case 'service':
                            // Already on service page
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
                          _buildResponsiveMenuItems(screenWidth, 'service'),
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
                        // Service Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.room_service,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Our Services',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Comprehensive ride solutions for every need',
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

            // Services Content
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  const Text(
                    'What We Offer',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose from our range of services designed to meet your transportation needs',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Service Cards
                  _buildServiceCard(
                    icon: Icons.directions_car,
                    title: 'RideMate Go',
                    description:
                        'Affordable everyday rides for your daily commute and errands.',
                    features: [
                      'Shared rides',
                      'Budget-friendly',
                      'Quick pickup',
                    ],
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 20),

                  _buildServiceCard(
                    icon: Icons.star,
                    title: 'RideMate Premium',
                    description:
                        'Luxury vehicles with professional drivers for special occasions.',
                    features: [
                      'Premium cars',
                      'Professional drivers',
                      'Enhanced comfort',
                    ],
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 20),

                  _buildServiceCard(
                    icon: Icons.local_shipping,
                    title: 'RideMate Delivery',
                    description:
                        'Fast and reliable delivery service for packages and documents.',
                    features: [
                      'Same-day delivery',
                      'Package tracking',
                      'Secure handling',
                    ],
                    color: Colors.green,
                  ),
                  const SizedBox(height: 20),

                  _buildServiceCard(
                    icon: Icons.schedule,
                    title: 'RideMate Schedule',
                    description:
                        'Book rides in advance for important appointments and events.',
                    features: [
                      'Advance booking',
                      'Guaranteed pickup',
                      'Reminder notifications',
                    ],
                    color: Colors.deepPurple,
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

  Widget _buildServiceCard({
    required IconData icon,
    required String title,
    required String description,
    required List<String> features,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
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
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: features
                .map(
                  (feature) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      feature,
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
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
