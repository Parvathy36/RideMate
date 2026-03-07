import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';

class LiveDriverLocationScreen extends StatefulWidget {
  final String rideId;

  const LiveDriverLocationScreen({super.key, required this.rideId});

  @override
  State<LiveDriverLocationScreen> createState() =>
      _LiveDriverLocationScreenState();
}

class _LiveDriverLocationScreenState extends State<LiveDriverLocationScreen> {
  MapController? _mapController;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _ride;
  LatLng? _driverLocation;
  LatLng? _destinationLocation;
  StreamSubscription<DocumentSnapshot>? _rideSubscription;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // Load ride data
      _ride = await FirestoreService.getRideById(widget.rideId);
      if (_ride == null) {
        throw Exception('Ride not found');
      }

      // Get destination location
      final destination = _ride!['destinationLocation'] as GeoPoint?;
      if (destination != null) {
        _destinationLocation = LatLng(destination.latitude, destination.longitude);
      }

      // Start listening to ride updates
      _startRideListener();

      // Start periodic location updates
      _startLocationUpdates();
    } catch (e) {
      print('Error initializing live tracking: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load ride data: $e';
          _loading = false;
        });
      }
    }
  }

  void _startRideListener() {
    _rideSubscription = FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _ride = data;
          
          // Update driver location if available
          final driverLocation = data['driverLocation'] as GeoPoint?;
          if (driverLocation != null) {
            _driverLocation = LatLng(driverLocation.latitude, driverLocation.longitude);
          }
        });
      }
    });
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // The ride listener will handle location updates
      // This timer ensures we refresh the UI periodically
      if (mounted) {
        setState(() {
          // Trigger rebuild to update any animations or UI elements
        });
      }
    });
  }

  @override
  void dispose() {
    _rideSubscription?.cancel();
    _locationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: const Text(
          'Live Driver Location',
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
                        onPressed: _init,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildMap(),
    );
  }

  Widget _buildMap() {
    final markers = <Marker>{};
    
    // Add driver marker if location is available
    if (_driverLocation != null) {
      markers.add(
        Marker(
          point: _driverLocation!,
          width: 60,
          height: 60,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.deepPurple.withOpacity(0.2),
              border: Border.all(
                color: Colors.deepPurple,
                width: 3,
              ),
            ),
            child: const Icon(
              Icons.local_taxi,
              color: Colors.deepPurple,
              size: 30,
            ),
          ),
        ),
      );
    }

    // Add destination marker if available
    if (_destinationLocation != null) {
      markers.add(
        Marker(
          point: _destinationLocation!,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withOpacity(0.2),
              border: Border.all(
                color: Colors.red,
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.location_on,
              color: Colors.red,
              size: 20,
            ),
          ),
        ),
      );
    }

    // Create polyline if both locations are available
    final polylines = <Polyline>{};
    if (_driverLocation != null && _destinationLocation != null) {
      polylines.add(
        Polyline(
          points: [_driverLocation!, _destinationLocation!],
          color: Colors.deepPurple,
          strokeWidth: 4,
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _driverLocation ?? _destinationLocation ?? const LatLng(0, 0),
            initialZoom: 15,
            maxZoom: 18,
            minZoom: 5,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.ridemate',
            ),
            MarkerLayer(markers: markers.toList()),
            PolylineLayer(polylines: polylines.toList()),
          ],
        ),
        // Ride information overlay
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ride Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Status: ${_ride?['status'] ?? 'Unknown'}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                if (_driverLocation != null) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Driver is on the way',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Destination: ${_ride?['destinationAddress'] ?? 'Unknown'}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Refresh button
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _init,
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            child: const Icon(Icons.refresh),
          ),
        ),
      ],
    );
  }
}