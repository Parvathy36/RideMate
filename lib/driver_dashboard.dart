import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'map_screen.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'widgets/driver_image_upload_dialog.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  Map<String, dynamic>? _driverData;
  bool _isLoading = true;
  bool _isOnline = false;
  bool _hasShownImageUploadDialog = false;
  int _navIndex = 0;

  List<Map<String, dynamic>> _rides = <Map<String, dynamic>>[];
  bool _isRidesLoading = false;
  String? _ridesError;

  Future<void> _loadDriverRides({bool initialLoad = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!initialLoad) {
      setState(() {
        _isRidesLoading = true;
        _ridesError = null;
      });
    }

    try {
      final rides = await FirestoreService.getRidesForDriver(user.uid);
      if (mounted) {
        setState(() {
          _rides = rides;
          _isRidesLoading = false;
          _ridesError = rides.isEmpty
              ? 'No rides found for your account yet.'
              : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRidesLoading = false;
          _ridesError = 'Failed to load rides: $e';
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Start animations
    _fadeController.forward();

    // Load driver data
    _loadDriverData();
  }

  Widget _buildQuickActionsRail({required bool extended}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF12122A), Color(0xFF0F0F23)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(4, 0),
          ),
        ],
      ),
      child: NavigationRail(
        backgroundColor: Colors.transparent,
        extended: extended,
        selectedIndex: _navIndex,
        onDestinationSelected: (index) async {
          setState(() => _navIndex = index);
          switch (index) {
            case 0:
              await _loadDriverRides();
              break;
            case 1:
              _showFeatureDialog('Earnings');
              break;
            case 2:
              _showImageUploadDialog();
              break;
            case 3:
              _showFeatureDialog('Profile');
              break;
          }
        },
        leading: Padding(
          padding: const EdgeInsets.only(top: 14, left: 8, right: 8),
          child: extended
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RideMate Driver',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome, ${_driverData?['name'] ?? 'Driver'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final bool isApproved =
                            _driverData?['isApproved'] == true;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isApproved
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isApproved
                                  ? Colors.green.withValues(alpha: 0.3)
                                  : Colors.orange.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isApproved
                                    ? Icons.verified
                                    : Icons.hourglass_top,
                                size: 14,
                                color: isApproved
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isApproved ? 'Approved' : 'Pending',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isApproved
                                      ? Colors.green
                                      : Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 56,
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: const Icon(Icons.flash_on, color: Colors.amber),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 36,
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ],
                ),
        ),
        trailing: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout, color: Colors.white70),
          ),
        ),
        groupAlignment: -0.75,
        labelType: extended
            ? NavigationRailLabelType.none
            : NavigationRailLabelType.all,
        minWidth: 72,
        minExtendedWidth: 240,
        useIndicator: true,
        indicatorColor: Colors.white.withValues(alpha: 0.10),
        indicatorShape: const StadiumBorder(),
        selectedIconTheme: const IconThemeData(color: Colors.white),
        unselectedIconTheme: const IconThemeData(color: Colors.white70),
        selectedLabelTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
        destinations: const [
          NavigationRailDestination(
            icon: Icon(Icons.list_alt),
            selectedIcon: Icon(Icons.list_alt),
            label: Text('Rides'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: Text('Earnings'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.photo_camera_outlined),
            selectedIcon: Icon(Icons.photo_camera),
            label: Text('Upload'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: Text('Profile'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadDriverData() async {
    await _loadDriverRides(initialLoad: true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final usersRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);
        final driversRef = FirebaseFirestore.instance
            .collection('drivers')
            .doc(user.uid);

        // Fetch user and driver docs in parallel
        final snapshots = await Future.wait([usersRef.get(), driversRef.get()]);
        final userDoc = snapshots[0];
        final driverDoc = snapshots[1];

        // Merge data (driver doc takes precedence for driver-specific fields)
        final merged = <String, dynamic>{};
        if (userDoc.exists) merged.addAll(userDoc.data()!);
        if (driverDoc.exists) merged.addAll(driverDoc.data()!);

        setState(() {
          _driverData = merged.isNotEmpty ? merged : null;
          _isOnline =
              (merged['isOnline'] ?? userDoc.data()?['isOnline'] ?? false)
                  as bool;
          _isLoading = false;
        });

        // Check if driver needs to upload images using merged data
        _checkAndShowImageUploadDialog(merged);
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading driver data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleOnlineStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final newStatus = !_isOnline;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'isOnline': newStatus,
              'isAvailable': newStatus,
              'lastStatusUpdate': FieldValue.serverTimestamp(),
            });

        // Also update in drivers collection
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(user.uid)
            .update({
              'isOnline': newStatus,
              'isAvailable': newStatus,
              'lastStatusUpdate': FieldValue.serverTimestamp(),
            });

        setState(() {
          _isOnline = newStatus;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newStatus
                    ? 'You are now online and available for rides'
                    : 'You are now offline',
              ),
              backgroundColor: newStatus ? Colors.green : Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      // Set driver offline before signing out
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _isOnline) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'isOnline': false,
              'isAvailable': false,
              'lastStatusUpdate': FieldValue.serverTimestamp(),
            });

        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(user.uid)
            .update({
              'isOnline': false,
              'isAvailable': false,
              'lastStatusUpdate': FieldValue.serverTimestamp(),
            });
      }

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
            : LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth >= 1000;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildQuickActionsRail(extended: isWide),
                      if (isWide) const SizedBox(width: 12),
                      Expanded(child: _buildDashboardContent()),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F0F23), Color(0xFF16213E), Color(0xFF1A1A2E)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Header
            _buildHeader(),

            const SizedBox(height: 30),

            // Main content
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: RefreshIndicator(
                  color: Colors.amber,
                  backgroundColor: const Color(0xFF0F0F23),
                  onRefresh: _loadDriverData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // Online/Offline Toggle
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _isOnline
                                  ? [Colors.green, Colors.green.shade600]
                                  : [
                                      Colors.grey.shade600,
                                      Colors.grey.shade700,
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: (_isOnline ? Colors.green : Colors.grey)
                                    .withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  _isOnline
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isOnline
                                          ? 'You\'re Online'
                                          : 'You\'re Offline',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _isOnline
                                          ? 'Ready to accept ride requests'
                                          : 'Tap to go online and start earning',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _isOnline,
                                onChanged: (value) => _toggleOnlineStatus(),
                                activeColor: Colors.white,
                                activeTrackColor: Colors.white.withValues(
                                  alpha: 0.3,
                                ),
                                inactiveThumbColor: Colors.white70,
                                inactiveTrackColor: Colors.white.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Stats Grid
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Total Rides',
                                '${_driverData?['totalRides'] ?? 0}',
                                Icons.local_taxi,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                'Rating',
                                '${_driverData?['rating']?.toStringAsFixed(1) ?? '0.0'}',
                                Icons.star,
                                Colors.amber,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Earnings',
                                '₹${_driverData?['totalEarnings']?.toStringAsFixed(0) ?? '0'}',
                                Icons.currency_rupee,
                                Colors.green,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                'Status',
                                _driverData?['isApproved'] == true
                                    ? 'Approved'
                                    : 'Pending',
                                Icons.verified,
                                _driverData?['isApproved'] == true
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Driver Info Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Driver Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_driverData != null) ...[
                                _buildInfoRow(
                                  'License ID',
                                  _driverData!['licenseId'] ?? 'N/A',
                                ),
                                _buildInfoRow(
                                  'Car Model',
                                  _driverData!['carModel'] ?? 'N/A',
                                ),
                                _buildInfoRow(
                                  'Phone',
                                  _driverData!['phoneNumber'] ?? 'N/A',
                                ),
                                _buildInfoRow(
                                  'Email',
                                  _driverData!['email'] ?? 'N/A',
                                ),
                              ],
                              const SizedBox(height: 24),
                              const Text(
                                'Your Recent Rides',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildRidesSection(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),
                      ],
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

  Widget _buildRidesSection() {
    if (_isRidesLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      );
    }

    if (_ridesError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Text(
          _ridesError!,
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }

    if (_rides.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: const Text(
          'No rides to display right now. Keep an eye out for new bookings!',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Column(
      children: _rides.map((ride) {
        final status = ride['status'] as String? ?? 'unknown';
        final pickup = ride['pickupAddress'] as String? ?? 'Unknown pickup';
        final destination =
            ride['destinationAddress'] as String? ?? 'Unknown destination';
        final createdAt = ride['createdAt'];
        String createdText = 'Just now';
        if (createdAt is Timestamp) {
          final date = createdAt.toDate();
          createdText =
              '${date.day}/${date.month}/${date.year} '
              '${date.hour.toString().padLeft(2, '0')}:'
              '${date.minute.toString().padLeft(2, '0')}';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    createdText,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.my_location, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pickup,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Colors.greenAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      destination,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            MapScreen(rideId: ride['id'] as String),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('View Route'),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHeader() {
    // header only shows avatar now; keep variables removed to avoid warnings
    final String? avatarUrl = _driverData?['profileImageUrl'] as String?;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: avatarUrl != null && avatarUrl.isNotEmpty
              ? Image.network(avatarUrl, fit: BoxFit.cover)
              : Container(
                  color: Colors.white.withValues(alpha: 0.08),
                  child: const Icon(Icons.person, color: Colors.white70),
                ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.white60),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // Removed old flat action button in favor of gradient action with ripple

  // Removed old gradient quick action (replaced by bottom NavigationBar)

  void _checkAndShowImageUploadDialog(Map<String, dynamic> driverData) {
    // Check if driver has uploaded both images
    final hasProfileImage =
        driverData['profileImageUrl'] != null &&
        driverData['profileImageUrl'].toString().isNotEmpty;
    final hasLicenseImage =
        driverData['licenseImageUrl'] != null &&
        driverData['licenseImageUrl'].toString().isNotEmpty;

    // Show dialog if images are missing and we haven't shown it yet
    if ((!hasProfileImage || !hasLicenseImage) && !_hasShownImageUploadDialog) {
      _hasShownImageUploadDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showImageUploadDialog();
      });
    }
  }

  void _showImageUploadDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => const DriverImageUploadDialog(),
    ).then((_) {
      // Reload driver data after dialog is closed
      _loadDriverData();
    });
  }

  void _showFeatureDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(feature, style: const TextStyle(color: Colors.white)),
        content: Text(
          'This feature is coming soon!',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }
}
