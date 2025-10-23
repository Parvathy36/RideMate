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

  Future<void> _loadDriverData() async {
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
              // Rides button - show rides dialog
              _showRidesDialog();
              break;
            case 1:
              // Dashboard button - do nothing, just update the selected index
              // The dashboard content is already displayed in the main area
              break;
            case 2:
              _showFeatureDialog('Earnings');
              break;
            case 3:
              _showImageUploadDialog();
              break;
            case 4:
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
        destinations: [
          NavigationRailDestination(
            icon: Icon(Icons.local_taxi_outlined),
            selectedIcon: Icon(Icons.local_taxi),
            label: Text('Rides'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: Text('Dashboard'),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.list_alt, color: Colors.white70, size: 48),
          SizedBox(height: 16),
          Text(
            'View your ride requests',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tap the button above to see all your ride requests',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper method to build info chips
  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // Helper method to get status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'requested':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildRidesList(List<Map<String, dynamic>> rides) {
    return const SizedBox.shrink();
  }

  Future<void> _showRidesDialog({List<Map<String, dynamic>>? rides}) async {
    if (!mounted) {
      return;
    }

    // Ensure we have rides to display. If none provided, fetch them first.
    final resolvedRides = rides ?? await _loadRidesForDialog();
    if (resolvedRides == null) {
      return;
    }

    _showRidesDialogFromList(resolvedRides);
  }

  Future<List<Map<String, dynamic>>?> _loadRidesForDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load rides. Please sign in again.'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    try {
      // Query ONLY by driverId to avoid composite index requirements
      // Following the optimization pattern from FirestoreService.getRidesForDriver
      final ridesQuery = FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: user.uid)
          .get(); // Removed orderBy to avoid any potential index issues

      final snapshot = await ridesQuery;
      final docs = snapshot.docs;

      if (docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No rides found for your account yet.'),
            ),
          );
        }
        return [];
      }

      // Map docs to list and sort in memory to avoid index requirements
      final rides = docs.map((doc) => {'id': doc.id, ...doc.data()}).toList()
        ..sort((a, b) {
          // Sort by createdAt descending in memory
          final aTimestamp = a['createdAt'];
          final bTimestamp = b['createdAt'];
          if (aTimestamp is Timestamp && bTimestamp is Timestamp) {
            return bTimestamp.compareTo(aTimestamp);
          }
          return 0;
        });

      // For pooling rides, also fetch shared ride information
      final updatedRides = await _loadPoolingRideDetails(rides);

      return updatedRides;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load rides: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  /// Load additional details for pooling rides by checking shared_rides collection
  Future<List<Map<String, dynamic>>> _loadPoolingRideDetails(
    List<Map<String, dynamic>> rides,
  ) async {
    final updatedRides = <Map<String, dynamic>>[];

    for (final ride in rides) {
      final rideType = ride['rideType'] as String? ?? 'Solo';

      // If rideType is pooling, check shared_rides collection
      if (rideType.toLowerCase() == 'pooling') {
        try {
          // Check if there are shared rides for this ride
          final sharedRides = await _getSharedRidesForRide(
            ride['id'] as String,
          );

          // Add shared ride information to the ride
          if (sharedRides.isNotEmpty) {
            updatedRides.add({...ride, 'sharedRides': sharedRides});
          } else {
            updatedRides.add(ride);
          }
        } catch (e) {
          print('Error checking shared rides for ride ${ride['id']}: $e');
          // Add ride without shared information if there's an error
          updatedRides.add(ride);
        }
      } else {
        updatedRides.add(ride);
      }
    }

    return updatedRides;
  }

  /// Get shared rides for a specific ride by checking both requesterRideId and targetRideId
  Future<List<Map<String, dynamic>>> _getSharedRidesForRide(
    String rideId,
  ) async {
    try {
      // Query shared_rides where this ride is either the requester or target
      final sharedRidesSnapshot1 = await FirebaseFirestore.instance
          .collection('shared_rides')
          .where('requesterRideId', isEqualTo: rideId)
          .get();

      final sharedRidesSnapshot2 = await FirebaseFirestore.instance
          .collection('shared_rides')
          .where('targetRideId', isEqualTo: rideId)
          .get();

      final sharedRides = <Map<String, dynamic>>[];

      // Process requester rides
      for (final doc in sharedRidesSnapshot1.docs) {
        final sharedRideData = doc.data();

        // Get the target ride details
        final targetRide = await FirestoreService.getRideById(
          sharedRideData['targetRideId'] as String,
        );

        sharedRides.add({
          'id': doc.id,
          ...sharedRideData,
          'targetRideDetails': targetRide,
        });
      }

      // Process target rides
      for (final doc in sharedRidesSnapshot2.docs) {
        final sharedRideData = doc.data();

        // Get the requester ride details
        final requesterRide = await FirestoreService.getRideById(
          sharedRideData['requesterRideId'] as String,
        );

        sharedRides.add({
          'id': doc.id,
          ...sharedRideData,
          'requesterRideDetails': requesterRide,
        });
      }

      return sharedRides;
    } catch (e) {
      print('Error fetching shared rides for ride $rideId: $e');
      return [];
    }
  }

  void _showRideDetailsDialog(Map<String, dynamic> ride) {
    final status = ride['status'] as String? ?? 'unknown';
    final pickup = ride['pickupAddress'] as String? ?? 'Unknown pickup';
    final destination =
        ride['destinationAddress'] as String? ?? 'Unknown destination';
    final fareEstimate = ride['fare'] as num? ?? 0;

    // Rider details
    final riderData = ride['rider'] as Map<String, dynamic>?;
    final riderName = riderData?['name'] as String? ?? 'Unknown Rider';

    // Check if this is a pooling ride
    final rideType = ride['rideType'] as String? ?? 'Solo';
    final isPoolingRide = rideType.toLowerCase() == 'pooling';
    final sharedRides = ride['sharedRides'] as List<dynamic>?;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Row(
            children: [
              const Text('Ride Details', style: TextStyle(color: Colors.white)),
              if (isPoolingRide) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text(
                    'POOLING',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
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
                const SizedBox(height: 16),

                // Rider Information
                const Text(
                  'Rider:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  riderName,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 16),

                // Fare
                const Text(
                  'Fare:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${fareEstimate.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 16),

                // Pickup Location
                const Text(
                  'Pickup Location:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.my_location,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pickup,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Destination
                const Text(
                  'Destination:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.greenAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        destination,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),

                // Shared rides information for pooling rides
                if (isPoolingRide &&
                    sharedRides != null &&
                    sharedRides.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text(
                    'Pooling Requests:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...sharedRides.map((sharedRide) {
                    final sharedRideData = sharedRide as Map<String, dynamic>;
                    final sharedStatus =
                        sharedRideData['status'] as String? ?? 'unknown';
                    final numberOfMembers =
                        sharedRideData['numberOfMembers'] as int? ?? 1;

                    // Determine if this is requester or target ride
                    final isRequesterRide =
                        sharedRideData['requesterRideId'] == ride['id'];
                    final otherRideDetails = isRequesterRide
                        ? sharedRideData['targetRideDetails']
                              as Map<String, dynamic>?
                        : sharedRideData['requesterRideDetails']
                              as Map<String, dynamic>?;

                    final otherRiderName =
                        otherRideDetails?['rider']?['name'] as String? ??
                        'Unknown Rider';
                    final otherPickup =
                        otherRideDetails?['pickupAddress'] as String? ??
                        'Unknown pickup';
                    final otherDestination =
                        otherRideDetails?['destinationAddress'] as String? ??
                        'Unknown destination';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isRequesterRide
                                    ? 'Requested by:'
                                    : 'Requesting:',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    sharedStatus,
                                  ).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  sharedStatus.toUpperCase(),
                                  style: TextStyle(
                                    color: _getStatusColor(sharedStatus),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            otherRiderName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Members: $numberOfMembers',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Route:',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.amber,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  otherPickup,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: Icon(
                              Icons.arrow_downward,
                              color: Colors.white38,
                              size: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.green,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  otherDestination,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            if (status == 'requested') ...[
              ElevatedButton(
                onPressed: () async {
                  // Accept ride
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Accept'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Reject ride
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reject'),
              ),
            ] else if (status == 'accepted' || status == 'confirmed') ...[
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  // Implement ride completion logic
                  try {
                    await FirestoreService.updateRideStatus(
                      ride['id'],
                      'completed',
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ride marked as completed!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      // Refresh the rides dialog to show updated status
                      _showRidesDialog();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error completing ride: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Complete Ride'),
              ),
            ],
          ],
        );
      },
    );
  }

  // Helper method to build detail items
  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
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

  // Add this method for debugging Firestore issues
  Future<void> _runFirestoreDebug() async {
    try {
      print('🚀 Starting Firestore debug...');
      await FirestoreService.debugFirestoreAccess();
      print('✅ Firestore debug completed');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Firestore debug completed - check console for details',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Firestore debug failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Firestore debug failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Add this method for debugging all rides
  Future<void> _runAllRidesDebug() async {
    try {
      print('🚀 Starting all rides debug...');
      final allRides = await FirestoreService.getAllRides();
      print('✅ All rides debug completed. Found ${allRides.length} rides.');

      if (mounted) {
        // Show a dialog with the results
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text(
              'All Rides Debug',
              style: TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Found ${allRides.length} rides in total',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  ...allRides
                      .map(
                        (ride) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ID: ${ride['id']}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'Status: ${ride['status']}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'Driver ID: ${ride['driverId']}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'Rider: ${ride['rider']?['name'] ?? 'N/A'}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const Divider(color: Colors.white24),
                          ],
                        ),
                      )
                      .toList(),
                ],
              ),
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
    } catch (e) {
      print('❌ All rides debug failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All rides debug failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Add this method for debugging user info
  Future<void> _showUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No current user found');
      return;
    }

    print('Current user ID: ${user.uid}');
    print('Current user email: ${user.email}');

    // Get driver document
    try {
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(user.uid)
          .get();

      if (driverDoc.exists) {
        final driverData = driverDoc.data();
        print('Driver document found:');
        print('  Name: ${driverData?['name']}');
        print('  Email: ${driverData?['email']}');
        print('  Is Approved: ${driverData?['isApproved']}');
      } else {
        print('❌ No driver document found for user ID: ${user.uid}');
      }
    } catch (e) {
      print('❌ Error fetching driver document: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User ID: ${user.uid} - Check console for details'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  // Add this method for debugging rides for current driver
  Future<void> _debugRidesForCurrentDriver() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No current user found');
      return;
    }

    print('🔍 Debugging rides for current driver: ${user.uid}');

    try {
      await FirestoreService.debugRidesForDriver(user.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Driver rides debug completed - check console for details',
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('❌ Driver rides debug failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Driver rides debug failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Add this method to test dialog with sample data
  void _testRidesDialog() {
    print('Testing rides dialog with sample data');

    final sampleRides = [
      {
        'id': 'test_ride_1',
        'status': 'requested',
        'pickupAddress': 'Test Pickup Location',
        'destinationAddress': 'Test Destination',
        'fare': 250,
        'rider': {'name': 'Test Rider'},
      },
      {
        'id': 'test_ride_2',
        'status': 'accepted',
        'pickupAddress': 'Another Pickup',
        'destinationAddress': 'Another Destination',
        'fare': 350,
        'rider': {'name': 'Another Rider'},
      },
    ];

    print('Sample rides: $sampleRides');
    _showRidesDialog(rides: sampleRides);
  }

  // Add this method to test if dialogs can be shown at all
  void _testSimpleDialog() {
    print('Testing simple dialog');

    if (!mounted) {
      print('❌ Widget not mounted');
      return;
    }

    print('Showing simple dialog');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        print('Building simple dialog');
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text(
            'Test Dialog',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'This is a test dialog',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Colors.amber)),
            ),
          ],
        );
      },
    );
  }

  void _showFeatureDialog(String feature) {
    if (feature == 'Debug') {
      _runFirestoreDebug();
      return;
    }

    if (feature == 'All Rides') {
      _runAllRidesDebug();
      return;
    }

    if (feature == 'User Info') {
      _showUserInfo();
      return;
    }

    if (feature == 'My Rides Debug') {
      _debugRidesForCurrentDriver();
      return;
    }

    if (feature == 'Test Dialog') {
      _testRidesDialog();
      return;
    }

    if (feature == 'Test Simple Dialog') {
      _testSimpleDialog();
      return;
    }

    if (feature == 'Profile') {
      _showDriverProfileDialog();
      return;
    }

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

  void _showDriverProfileDialog() {
    if (_driverData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver data not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text(
            'Driver Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile header with avatar
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber, width: 2),
                        ),
                        child: CircleAvatar(
                          backgroundImage:
                              _driverData!['profileImageUrl'] != null
                              ? NetworkImage(_driverData!['profileImageUrl'])
                              : null,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          child: _driverData!['profileImageUrl'] == null
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white70,
                                  size: 40,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _driverData!['name'] ?? 'Unknown Driver',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _driverData!['email'] ?? 'No email provided',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Driver details section
                const Text(
                  'Driver Information',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                _buildProfileInfoRow(
                  'License ID',
                  _driverData!['licenseId'] ?? 'N/A',
                  Icons.credit_card,
                ),
                const SizedBox(height: 12),

                _buildProfileInfoRow(
                  'Car Model',
                  _driverData!['carModel'] ?? 'N/A',
                  Icons.directions_car,
                ),
                const SizedBox(height: 12),

                _buildProfileInfoRow(
                  'Phone Number',
                  _driverData!['phoneNumber'] ?? 'N/A',
                  Icons.phone,
                ),
                const SizedBox(height: 12),

                _buildProfileInfoRow(
                  'Total Rides',
                  '${_driverData!['totalRides'] ?? 0}',
                  Icons.local_taxi,
                ),
                const SizedBox(height: 12),

                _buildProfileInfoRow(
                  'Rating',
                  '${_driverData!['rating']?.toStringAsFixed(1) ?? '0.0'}',
                  Icons.star,
                ),
                const SizedBox(height: 12),

                _buildProfileInfoRow(
                  'Total Earnings',
                  '₹${_driverData!['totalEarnings']?.toStringAsFixed(0) ?? '0'}',
                  Icons.account_balance_wallet,
                ),
                const SizedBox(height: 12),

                _buildProfileInfoRow(
                  'Approval Status',
                  _driverData!['isApproved'] == true ? 'Approved' : 'Pending',
                  _driverData!['isApproved'] == true
                      ? Icons.verified
                      : Icons.pending,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.amber)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.amber, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showRidesDialogFromList(List<Map<String, dynamic>> rides) {
    print('Showing rides dialog with ${rides.length} rides');
    print('Dialog context: $context');
    print('Dialog mounted: $mounted');

    // Print details of each ride for debugging
    if (rides.isNotEmpty) {
      print('📋 Rides to display in dialog:');
      for (var i = 0; i < rides.length; i++) {
        final ride = rides[i];
        print(
          '  Ride $i: ID=${ride['id']}, Status=${ride['status']}, DriverId=${ride['driverId']}',
        );
      }
    }

    if (!mounted) {
      print('❌ Widget not mounted, cannot show dialog');
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        print('Building dialog with ${rides.length} rides');
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text(
            'Your Rides',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: rides.isEmpty
                ? const Center(
                    child: Text(
                      'No rides found for your account yet.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: rides.map((ride) {
                        print('Building ride card for: ${ride['id']}');
                        final status = ride['status'] as String? ?? 'unknown';
                        final pickup =
                            ride['pickupAddress'] as String? ??
                            'Unknown pickup';
                        final destination =
                            ride['destinationAddress'] as String? ??
                            'Unknown destination';
                        final fareEstimate = ride['fare'] as num? ?? 0;

                        // Rider details
                        final riderData =
                            ride['rider'] as Map<String, dynamic>?;
                        final riderName =
                            riderData?['name'] as String? ?? 'Unknown Rider';

                        // Check if this is a pooling ride
                        final rideType = ride['rideType'] as String? ?? 'Solo';
                        bool isPoolingRide =
                            rideType.toLowerCase() == 'pooling';
                        final sharedRides =
                            ride['sharedRides'] as List<dynamic>?;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with status
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (isPoolingRide) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: Colors.blue.withValues(
                                              alpha: 0.4,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'POOLING',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Ride details content
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Rider information
                                    const Text(
                                      'Rider:',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      riderName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Fare
                                    const Text(
                                      'Fare:',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${fareEstimate.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Route information
                                    const Text(
                                      'Pickup:',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          color: Colors.amber,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            pickup,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Padding(
                                      padding: EdgeInsets.only(left: 12),
                                      child: Icon(
                                        Icons.arrow_downward,
                                        color: Colors.white38,
                                        size: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Destination:',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          color: Colors.green,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            destination,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Shared rides information for pooling rides
                                    if (isPoolingRide &&
                                        sharedRides != null &&
                                        sharedRides.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      const Divider(color: Colors.white24),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Pooling Requests:',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ...sharedRides.map((sharedRide) {
                                        final sharedRideData =
                                            sharedRide as Map<String, dynamic>;
                                        final sharedStatus =
                                            sharedRideData['status']
                                                as String? ??
                                            'unknown';
                                        final numberOfMembers =
                                            sharedRideData['numberOfMembers']
                                                as int? ??
                                            1;

                                        // Determine if this is requester or target ride
                                        final isRequesterRide =
                                            sharedRideData['requesterRideId'] ==
                                            ride['id'];
                                        final otherRideDetails = isRequesterRide
                                            ? sharedRideData['targetRideDetails']
                                                  as Map<String, dynamic>?
                                            : sharedRideData['requesterRideDetails']
                                                  as Map<String, dynamic>?;

                                        final otherRiderName =
                                            otherRideDetails?['rider']?['name']
                                                as String? ??
                                            'Unknown Rider';
                                        final otherPickup =
                                            otherRideDetails?['pickupAddress']
                                                as String? ??
                                            'Unknown pickup';
                                        final otherDestination =
                                            otherRideDetails?['destinationAddress']
                                                as String? ??
                                            'Unknown destination';

                                        return Container(
                                          margin: const EdgeInsets.only(top: 8),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.05,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.1,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    isRequesterRide
                                                        ? 'Requested by:'
                                                        : 'Requesting:',
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: _getStatusColor(
                                                        sharedStatus,
                                                      ).withValues(alpha: 0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      sharedStatus
                                                          .toUpperCase(),
                                                      style: TextStyle(
                                                        color: _getStatusColor(
                                                          sharedStatus,
                                                        ),
                                                        fontSize: 8,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                otherRiderName,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Members: $numberOfMembers',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 10,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.location_on,
                                                    color: Colors.amber,
                                                    size: 12,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      otherPickup,
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 10,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.location_on,
                                                    color: Colors.green,
                                                    size: 12,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      otherDestination,
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 10,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ],

                                    const SizedBox(height: 16),

                                    // Action buttons based on status
                                    if (status == 'requested') ...[
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          ElevatedButton(
                                            onPressed: () async {
                                              // Accept ride - update status to 'accepted'
                                              try {
                                                await FirestoreService.updateRideStatus(
                                                  ride['id'],
                                                  'accepted',
                                                );
                                                if (mounted) {
                                                  Navigator.of(context).pop();
                                                  // Show success message
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Ride accepted successfully!',
                                                      ),
                                                      backgroundColor:
                                                          Colors.green,
                                                    ),
                                                  );
                                                  // Refresh the rides dialog to show updated status
                                                  _showRidesDialog();
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Error accepting ride: $e',
                                                      ),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: const Text(
                                              'Accept',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: () async {
                                              // Reject ride - update status to 'rejected'
                                              try {
                                                await FirestoreService.updateRideStatus(
                                                  ride['id'],
                                                  'rejected',
                                                );
                                                if (mounted) {
                                                  Navigator.of(context).pop();
                                                  // Show success message
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Ride rejected successfully!',
                                                      ),
                                                      backgroundColor:
                                                          Colors.orange,
                                                    ),
                                                  );
                                                  // Refresh the rides dialog to show updated status
                                                  _showRidesDialog();
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Error rejecting ride: $e',
                                                      ),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: const Text(
                                              'Reject',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else if (status == 'accepted' || status == 'confirmed') ...[
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          ElevatedButton(
                                            onPressed: () async {
                                              Navigator.of(context).pop();
                                              // Implement ride completion logic
                                              try {
                                                await FirestoreService.updateRideStatus(
                                                  ride['id'],
                                                  'completed',
                                                );
                                                if (mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Ride marked as completed!',
                                                      ),
                                                      backgroundColor:
                                                          Colors.green,
                                                    ),
                                                  );
                                                  // Refresh the rides dialog to show updated status
                                                  _showRidesDialog();
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Error completing ride: $e',
                                                      ),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Complete Ride'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        );
      },
    );
  }
}
