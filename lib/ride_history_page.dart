import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/firestore_service.dart';
import 'services/auth_service.dart';

class RideHistoryPage extends StatefulWidget {
  const RideHistoryPage({super.key});

  @override
  State<RideHistoryPage> createState() => _RideHistoryPageState();
}

class _RideHistoryPageState extends State<RideHistoryPage>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _rides = [];
  List<Map<String, dynamic>> _pendingSharedRides =
      []; // New field for pending shared rides
  List<Map<String, dynamic>> _acceptedSharedRides =
      []; // New field for accepted shared rides
  String? _error;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
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

    _loadRideHistory();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadRideHistory() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final rides = await FirestoreService.getRidesForUser(user.uid);

      // For pooling rides, check shared_rides collection
      final updatedRides = await _checkPoolingRides(rides);

      // Get pending shared rides where targetRideId matches user's rides
      final pendingSharedRides = await _getPendingSharedRides(user.uid);

      // Get accepted shared rides where targetRideId matches user's rides
      final acceptedSharedRides = await _getAcceptedSharedRides(user.uid);

      if (mounted) {
        setState(() {
          _rides = updatedRides;
          _pendingSharedRides = pendingSharedRides;
          _acceptedSharedRides = acceptedSharedRides;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading ride history: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load ride history: $e';
          _isLoading = false;
        });
      }
    }
  }

  // Check shared_rides collection for pooling rides
  Future<List<Map<String, dynamic>>> _checkPoolingRides(
    List<Map<String, dynamic>> rides,
  ) async {
    final updatedRides = <Map<String, dynamic>>[];

    for (final ride in rides) {
      final rideType = ride['rideType'] as String? ?? 'Solo';

      // If rideType is pooling, check shared_rides collection
      if (rideType.toLowerCase() == 'pooling') {
        try {
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

  // Get shared rides for a specific ride
  Future<List<Map<String, dynamic>>> _getSharedRidesForRide(
    String rideId,
  ) async {
    try {
      final sharedRidesSnapshot = await FirebaseFirestore.instance
          .collection('shared_rides')
          .where('requesterRideId', isEqualTo: rideId)
          .get();

      final sharedRides = <Map<String, dynamic>>[];

      for (final doc in sharedRidesSnapshot.docs) {
        final sharedRideData = doc.data();

        // Verify that targetRideId matches a ride in rides collection
        final targetRide = await FirestoreService.getRideById(
          sharedRideData['targetRideId'] as String,
        );

        if (targetRide != null) {
          sharedRides.add({
            'id': doc.id,
            ...sharedRideData,
            'targetRideDetails': targetRide,
          });
        }
      }

      return sharedRides;
    } catch (e) {
      print('Error fetching shared rides for ride $rideId: $e');
      return [];
    }
  }

  // Get pending shared rides where targetRideId matches user's rides
  Future<List<Map<String, dynamic>>> _getPendingSharedRides(
    String userId,
  ) async {
    try {
      final pendingSharedRides = <Map<String, dynamic>>[];

      // Get all pending shared rides
      final sharedRidesSnapshot = await FirebaseFirestore.instance
          .collection('shared_rides')
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in sharedRidesSnapshot.docs) {
        final sharedRideData = doc.data();

        // Check if the targetRideId matches any of the user's rides
        final targetRide = await FirestoreService.getRideById(
          sharedRideData['targetRideId'] as String,
        );

        // If target ride exists and belongs to the current user, add to pending shared rides
        if (targetRide != null && targetRide['riderId'] == userId) {
          // Get requester ride details
          final requesterRide = await FirestoreService.getRideById(
            sharedRideData['requesterRideId'] as String,
          );

          pendingSharedRides.add({
            'id': doc.id,
            ...sharedRideData,
            'targetRideDetails': targetRide,
            'requesterRideDetails': requesterRide,
          });
        }
      }

      return pendingSharedRides;
    } catch (e) {
      print('Error fetching pending shared rides: $e');
      return [];
    }
  }

  // Get accepted shared rides where targetRideId matches user's rides
  Future<List<Map<String, dynamic>>> _getAcceptedSharedRides(
    String userId,
  ) async {
    try {
      final acceptedSharedRides = <Map<String, dynamic>>[];

      // Get all accepted shared rides
      final sharedRidesSnapshot = await FirebaseFirestore.instance
          .collection('shared_rides')
          .where('status', isEqualTo: 'accepted')
          .get();

      for (final doc in sharedRidesSnapshot.docs) {
        final sharedRideData = doc.data();

        // Check if the targetRideId matches any of the user's rides
        final targetRide = await FirestoreService.getRideById(
          sharedRideData['targetRideId'] as String,
        );

        // If target ride exists and belongs to the current user, add to accepted shared rides
        if (targetRide != null && targetRide['riderId'] == userId) {
          // Get requester ride details
          final requesterRide = await FirestoreService.getRideById(
            sharedRideData['requesterRideId'] as String,
          );

          acceptedSharedRides.add({
            'id': doc.id,
            ...sharedRideData,
            'targetRideDetails': targetRide,
            'requesterRideDetails': requesterRide,
          });
        }
      }

      return acceptedSharedRides;
    } catch (e) {
      print('Error fetching accepted shared rides: $e');
      return [];
    }
  }

  // Update shared ride status
  Future<void> _updateSharedRideStatus(
    String sharedRideId,
    String status, {
    String? rejectionMessage,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (rejectionMessage != null && rejectionMessage.isNotEmpty) {
        updateData['rejectionMessage'] = rejectionMessage;
      }

      await FirebaseFirestore.instance
          .collection('shared_rides')
          .doc(sharedRideId)
          .update(updateData);

      // Refresh the data
      _loadRideHistory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'accepted'
                  ? 'Ride sharing request accepted!'
                  : 'Ride sharing request rejected!',
            ),
            backgroundColor: status == 'accepted' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update ride sharing request'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error updating shared ride status: $e');
    }
  }

  // Show rejection dialog
  Future<void> _showRejectionDialog(String sharedRideId) async {
    final rejectionController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject Ride Sharing Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason for rejecting this request:'),
              const SizedBox(height: 16),
              TextField(
                controller: rejectionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Enter rejection reason...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateSharedRideStatus(
                  sharedRideId,
                  'rejected',
                  rejectionMessage: rejectionController.text,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: const Text(
          'Ride History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Background with gradient similar to home page
          Container(
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
          // Animated floating elements
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
          // Content
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 30),
                // Header section with animation
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Your Ride History',
                        style: TextStyle(
                          fontSize: 32,
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
                ),
                const SizedBox(height: 16),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'View your past rides and trip details',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Pending shared ride requests section
                if (_pendingSharedRides.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
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
                            color: Colors.deepPurple.withValues(alpha: 0.08),
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
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pending Ride Sharing Requests',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ..._pendingSharedRides.map((sharedRide) {
                              return _buildPendingSharedRideCard(sharedRide);
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                // Accepted shared ride requests section
                if (_acceptedSharedRides.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
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
                            color: Colors.deepPurple.withValues(alpha: 0.08),
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
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Accepted Ride Sharing Requests',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ..._acceptedSharedRides.map((sharedRide) {
                              return _buildAcceptedSharedRideCard(sharedRide);
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                // Ride history content
                _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(50),
                          child: CircularProgressIndicator(color: Colors.amber),
                        ),
                      )
                    : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _loadRideHistory,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _rides.isEmpty &&
                          _pendingSharedRides.isEmpty &&
                          _acceptedSharedRides.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Colors.amber, Colors.amber.shade600],
                                ),
                                borderRadius: BorderRadius.circular(20),
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
                                Icons.history,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'No ride history yet',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Your completed rides will appear here',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Container(
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
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: _rides.length,
                            itemBuilder: (context, index) {
                              final ride = _rides[index];
                              return _buildRideCard(ride);
                            },
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSharedRideCard(Map<String, dynamic> sharedRide) {
    final requesterDetails =
        sharedRide['requesterDetails'] as Map<String, dynamic>?;
    final requesterName =
        requesterDetails?['name'] as String? ?? 'Unknown User';
    final numberOfMembers = sharedRide['numberOfMembers'] as int? ?? 1;
    final requesterRideDetails =
        sharedRide['requesterRideDetails'] as Map<String, dynamic>?;
    final requesterPickup =
        requesterRideDetails?['pickupAddress'] as String? ?? 'Unknown pickup';
    final requesterDestination =
        requesterRideDetails?['destinationAddress'] as String? ??
        'Unknown destination';
    final createdAt = sharedRide['createdAt'] as Timestamp?;
    final sharedRideId = sharedRide['id'] as String?;

    // Format date
    String dateText = 'Unknown date';
    if (createdAt != null) {
      final date = createdAt.toDate();
      dateText = '${date.day}/${date.month}/${date.year}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ride Sharing Request',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'From: $requesterName',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Members: $numberOfMembers',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Their Route:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$requesterPickup → $requesterDestination',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Requested on: $dateText',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: () {
                  _showRejectionDialog(sharedRideId!);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reject'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  _updateSharedRideStatus(sharedRideId!, 'accepted');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Accept'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptedSharedRideCard(Map<String, dynamic> sharedRide) {
    final requesterDetails =
        sharedRide['requesterDetails'] as Map<String, dynamic>?;
    final requesterName =
        requesterDetails?['name'] as String? ?? 'Unknown User';
    final numberOfMembers = sharedRide['numberOfMembers'] as int? ?? 1;
    final requesterRideDetails =
        sharedRide['requesterRideDetails'] as Map<String, dynamic>?;
    final requesterPickup =
        requesterRideDetails?['pickupAddress'] as String? ?? 'Unknown pickup';
    final requesterDestination =
        requesterRideDetails?['destinationAddress'] as String? ??
        'Unknown destination';
    final createdAt = sharedRide['createdAt'] as Timestamp?;

    // Format date
    String dateText = 'Unknown date';
    if (createdAt != null) {
      final date = createdAt.toDate();
      dateText = '${date.day}/${date.month}/${date.year}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Accepted Ride Sharing',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'Accepted',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Shared with: $requesterName',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Members: $numberOfMembers',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Their Route:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$requesterPickup → $requesterDestination',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Accepted on: $dateText',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    final status = ride['status'] as String? ?? 'unknown';
    final pickup = ride['pickupAddress'] as String? ?? 'Unknown pickup';
    final destination =
        ride['destinationAddress'] as String? ?? 'Unknown destination';
    final fare = ride['fare'] as num?;
    final createdAt = ride['createdAt'] as Timestamp?;
    final driverName = ride['driver']?['name'] as String?;
    final carModel = ride['driver']?['carModel'] as String?;
    final rideType = ride['rideType'] as String? ?? 'N/A';
    final routeSummary = ride['routeSummary'] as Map<String, dynamic>?;
    final distanceKm = routeSummary?['distanceKm'] as num?;
    final durationMin = routeSummary?['durationMin'] as num?;
    final sharedRides = ride['sharedRides'] as List<dynamic>?;

    // Format date
    String dateText = 'Unknown date';
    if (createdAt != null) {
      final date = createdAt.toDate();
      dateText = '${date.day}/${date.month}/${date.year}';
    }

    // Get status color and text
    Color statusColor = Colors.grey;
    String statusText = status;

    switch (status.toLowerCase()) {
      case 'completed':
        statusColor = Colors.green;
        statusText = 'Completed';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'Cancelled';
        break;
      case 'rejected':
        statusColor = Colors.orange;
        statusText = 'Rejected';
        break;
      default:
        statusText = status.substring(0, 1).toUpperCase() + status.substring(1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
          // Header with date and status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Ride type
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_taxi,
                  color: Colors.deepPurple,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Ride Type: $rideType',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Route information
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  pickup,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  destination,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Route summary (distance and duration)
          if (distanceKm != null || durationMin != null) ...[
            const Divider(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (distanceKm != null) ...[
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.straighten,
                          color: Colors.amber,
                          size: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${distanceKm.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const Text(
                        'Distance',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                if (durationMin != null) ...[
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.access_time,
                          color: Colors.deepPurple,
                          size: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${durationMin.toStringAsFixed(0)} min',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const Text(
                        'Duration',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Driver information (if available)
          if (driverName != null || carModel != null) ...[
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.deepPurple.withValues(alpha: 0.1),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.deepPurple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (driverName != null)
                        Text(
                          driverName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      if (carModel != null)
                        Text(
                          carModel,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Shared rides information for pooling rides
          if (rideType.toLowerCase() == 'pooling' &&
              sharedRides != null &&
              sharedRides.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Pooling Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            ...sharedRides.map((sharedRide) {
              final targetRideDetails =
                  sharedRide['targetRideDetails'] as Map<String, dynamic>?;
              final targetRiderName =
                  targetRideDetails?['rider']?['name'] as String? ??
                  'Unknown Rider';
              final targetPickup =
                  targetRideDetails?['pickupAddress'] as String? ??
                  'Unknown pickup';
              final targetDestination =
                  targetRideDetails?['destinationAddress'] as String? ??
                  'Unknown destination';
              final numberOfMembers =
                  sharedRide['numberOfMembers'] as int? ?? 1;
              final sharedRideStatus =
                  sharedRide['status'] as String? ?? 'unknown';

              Color sharedStatusColor = Colors.grey;
              String sharedStatusText = sharedRideStatus;

              switch (sharedRideStatus.toLowerCase()) {
                case 'pending':
                  sharedStatusColor = Colors.orange;
                  sharedStatusText = 'Pending';
                  break;
                case 'accepted':
                  sharedStatusColor = Colors.green;
                  sharedStatusText = 'Accepted';
                  break;
                case 'rejected':
                  sharedStatusColor = Colors.red;
                  sharedStatusText = 'Rejected';
                  break;
                default:
                  sharedStatusText =
                      sharedRideStatus.substring(0, 1).toUpperCase() +
                      sharedRideStatus.substring(1);
              }

              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Shared with: $targetRiderName',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: sharedStatusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: sharedStatusColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            sharedStatusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: sharedStatusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Members: $numberOfMembers',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Their Route: $targetPickup → $targetDestination',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
          ],

          // Fare information
          if (fare != null) ...[
            const Divider(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Fare',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                Text(
                  '₹${fare.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
