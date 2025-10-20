import 'package:flutter/material.dart';
import 'services/firestore_service.dart';

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
      // Get all rides with similar destination
      final allRides = await FirestoreService.getAllRides();
      
      if (_ride != null && mounted) {
        final currentDestination = _ride!['destinationAddress'] as String? ?? '';
        
        // Filter rides with matching destinations (excluding current ride)
        final matchingRides = allRides.where((ride) {
          // Skip the current ride
          if (ride['id'] == widget.rideId) return false;
          
          // Check if status is appropriate for pooling
          final status = ride['status'] as String? ?? '';
          if (status != 'requested' && status != 'matched') return false;
          
          // Check if destination matches (simple string matching for now)
          final rideDestination = ride['destinationAddress'] as String? ?? '';
          return rideDestination.toLowerCase().contains(currentDestination.toLowerCase()) ||
                 currentDestination.toLowerCase().contains(rideDestination.toLowerCase());
        }).toList();

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

  Future<void> _sendRideRequest(String targetRideId) async {
    setState(() {
      _requestError = null;
    });

    try {
      // Create a shared ride request in Firestore
      await FirestoreService.createSharedRideRequest(
        rideId: widget.rideId,
        targetRideId: targetRideId,
        numberOfMembers: _numberOfMembers,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride request sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _requestError = 'Failed to send ride request: $e';
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
        final destination = ride['destinationAddress'] as String? ?? 'Unknown destination';
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
                    onPressed: () => _sendRideRequest(ride['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white, // Text color
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Request'),
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