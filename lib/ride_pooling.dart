import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/firestore_service.dart';
import 'home.dart';

class RidePoolingPage extends StatefulWidget {
  final String rideId;

  const RidePoolingPage({super.key, required this.rideId});

  @override
  State<RidePoolingPage> createState() => _RidePoolingPageState();
}

class _RidePoolingPageState extends State<RidePoolingPage> {
  Map<String, dynamic>? _ride;
  List<Map<String, dynamic>> _matchingRides = [];
  bool _loading = true;
  bool _loadingMatches = false;
  String? _error;
  String? _requestError;
  final TextEditingController _membersController = TextEditingController();
  int _numberOfMembers = 1;

  @override
  void initState() {
    super.initState();
    _loadRideData();
  }

  @override
  void dispose() {
    _membersController.dispose();
    super.dispose();
  }

  Future<void> _loadRideData() async {
    try {
      final ride = await FirestoreService.getRideById(widget.rideId);
      if (mounted) {
        setState(() {
          _ride = ride;
          _loading = false;
        });

        // Load matching rides after main ride data is loaded
        if (ride != null) {
          _loadMatchingRides();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load ride data: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMatchingRides() async {
    setState(() {
      _loadingMatches = true;
      _requestError = null;
    });

    try {
      if (_ride != null && mounted) {
        final pickup = _ride!['pickupLocation'] as GeoPoint?;
        // Use the new service method that handles proximity, status, and destination
        final matchingRides = await FirestoreService.findMatchingPooledRides(
          pickupLat: pickup?.latitude ?? 0.0,
          pickupLng: pickup?.longitude ?? 0.0,
          destinationAddress: _ride!['destinationAddress'] as String? ?? '',
        );

        // Filter out the current ride
        matchingRides.removeWhere((ride) => ride['id'] == widget.rideId);

        if (mounted) {
          setState(() {
            _matchingRides = matchingRides;
            _loadingMatches = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingMatches = false;
          _requestError = 'Failed to load matching rides: $e';
        });
      }
    }
  }

  Future<void> _joinSharedRide(String targetRideId) async {
    setState(() {
      _requestError = null;
    });

    try {
      // Join the existing pooled ride
      await FirestoreService.joinPooledRide(
        rideId: targetRideId,
        seatsRequested: _numberOfMembers,
      );

      // Cancel the current ride request as the user has joined another one
      await FirestoreService.updateRideStatus(widget.rideId, 'cancelled', additionalData: {
        'cancellationReason': 'Joined an existing pooled ride',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Joined ride successfully! Pending driver approval.'),
            backgroundColor: Colors.green,
          ),
        );
        // Redirect to home
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _requestError = 'Failed to join ride: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: const Text('Pooling Ride'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadRideData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _ride == null
          ? const Center(child: Text('Ride not found'))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final pickup = _ride!['pickupAddress'] as String? ?? 'Unknown pickup';
    final destination =
        _ride!['destinationAddress'] as String? ?? 'Unknown destination';
    final status = _ride!['status'] as String? ?? 'unknown';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pooling Ride Details',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Route Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.location_on, 'Pickup', pickup),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.location_on, 'Destination', destination),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.info, 'Status', status),
                  const SizedBox(height: 16),
                  // Number of members input
                  const Text(
                    'Number of Members',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _membersController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Enter number of members (1-2)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              final num = int.tryParse(value);
                              if (num != null && num > 0 && num <= 2) {
                                setState(() {
                                  _numberOfMembers = num;
                                });
                              } else if (num != null && num > 2) {
                                // If number is greater than 2, show error and reset to 2
                                setState(() {
                                  _numberOfMembers = 2;
                                  _membersController.text = '2';
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Maximum 2 members allowed'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('$_numberOfMembers members'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Matching rides section
          const Text(
            'Matching Rides',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _loadingMatches
              ? const Center(child: CircularProgressIndicator())
              : _requestError != null
              ? Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(height: 8),
                        Text(_requestError!),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _loadMatchingRides,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _matchingRides.isEmpty
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No matching rides found. Try again later.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              : _buildMatchingRidesList(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // For now, just go back. In a real implementation, this would proceed with the pooling ride
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white, // Text color
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Continue with Pooling',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMatchingRidesList() {
    return Column(
      children: _matchingRides.map((ride) {
        final riderName = ride['rider']?['name'] ?? 'Unknown rider';
        final pickup = ride['pickupAddress'] as String? ?? 'Unknown pickup';
        final destination =
            ride['destinationAddress'] as String? ?? 'Unknown destination';
        final status = ride['status'] as String? ?? 'unknown';
        final fare = ride['fare']?.toString() ?? 'N/A';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      riderName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₹$fare',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.location_on, 'Pickup', pickup),
                const SizedBox(height: 4),
                _buildInfoRow(Icons.location_on, 'Destination', destination),
                const SizedBox(height: 4),
                _buildInfoRow(Icons.info, 'Status', status),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _joinSharedRide(ride['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white, // Text color
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Join Ride'),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.deepPurple),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Text(value)),
      ],
    );
  }
}
