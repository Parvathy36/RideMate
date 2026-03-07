import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/location_service.dart';

class LiveTrackingMap extends StatefulWidget {
  final String rideId;

  const LiveTrackingMap({super.key, required this.rideId});

  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap> {
  MapController? _mapController;
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _ride;
  LatLng? _pickup;
  LatLng? _destination;
  LatLng? _driverLocation;
  List<LatLng> _route = <LatLng>[];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  StreamSubscription<DocumentSnapshot>? _rideSubscription;
  Timer? _locationUpdateTimer;
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // Load ride
      _ride = await _getRideData();
      if (_ride == null) {
        throw Exception('Ride not found');
      }

      // Extract locations
      _pickup =
          _extractLatLng(_ride!['pickupLocation']) ??
          _extractLatLngFromString(_ride!['pickupAddress']);
      _destination =
          _extractLatLng(_ride!['destinationLocation']) ??
          _extractLatLngFromString(_ride!['destinationAddress']);

      // Initialize map with pickup location
      _updateMarkersAndPolylines();

      // Subscribe to ride updates to track driver location
      _subscribeToRideUpdates();

      // Fit map to pickup location initially
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToRide());
    } catch (e) {
      print('Live tracking map initialization error: $e');
      _error = 'Failed to load tracking data: $e';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _getRideData() async {
    try {
      final rideDoc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .get();

      if (rideDoc.exists) {
        final data = rideDoc.data()!;
        return {...data, 'id': rideDoc.id};
      }
      return null;
    } catch (e) {
      print('Error getting ride data: $e');
      return null;
    }
  }

  void _subscribeToRideUpdates() {
    _rideSubscription = FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
          if (snapshot.exists) {
            final rideData = snapshot.data() as Map<String, dynamic>;

            // Update driver location if it has changed
            final newDriverLocation = _extractLatLng(
              rideData['driverLocation'],
            );
            if (newDriverLocation != null &&
                newDriverLocation != _driverLocation) {
              setState(() {
                _driverLocation = newDriverLocation;
                _ride = rideData;
              });

              // Update markers and fit to view
              _updateMarkersAndPolylines();
              _fitToRide();
            }
          }
        });
  }

  LatLng? _extractLatLng(dynamic value) {
    try {
      if (value == null) return null;
      if (value is LatLng) return value;
      if (value is GeoPoint) {
        return LatLng(value.latitude, value.longitude);
      }
      if (value is Map<String, dynamic>) {
        final lat = (value['latitude'] ?? value['lat']) as num?;
        final lng = (value['longitude'] ?? value['lng']) as num?;
        if (lat != null && lng != null) {
          return LatLng(lat.toDouble(), lng.toDouble());
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  LatLng? _extractLatLngFromString(String? address) {
    // For simplicity, this would use geocoding in a real app
    // Here we return null as we expect locations to be stored as GeoPoints
    return null;
  }

  void _updateMarkersAndPolylines() {
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    // Add pickup marker
    if (_pickup != null) {
      markers.add(
        Marker(
          width: 80.0,
          height: 80.0,
          point: _pickup!,
          child: Icon(Icons.location_on, size: 40.0, color: Colors.blue),
        ),
      );
    }

    // Add destination marker
    if (_destination != null) {
      markers.add(
        Marker(
          width: 80.0,
          height: 80.0,
          point: _destination!,
          child: Icon(Icons.location_on, size: 40.0, color: Colors.red),
        ),
      );
    }

    // Add driver marker if available
    if (_driverLocation != null) {
      markers.add(
        Marker(
          width: 60.0,
          height: 60.0,
          point: _driverLocation!,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.local_taxi, color: Colors.white, size: 28),
          ),
        ),
      );
    }

    // Create route polyline if we have all locations
    if (_pickup != null && _destination != null) {
      final routePoints = <LatLng>[];
      if (_driverLocation != null) {
        // Route from driver to pickup to destination
        routePoints.addAll([
          _driverLocation!, // Current driver location
          _pickup!, // Pickup location
          _destination!, // Destination location
        ]);
      } else {
        // Route from pickup to destination
        routePoints.addAll([_pickup!, _destination!]);
      }

      polylines.add(
        Polyline(
          points: routePoints,
          color: Colors.deepPurple,
          strokeWidth: 5.0,
        ),
      );
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });
  }

  void _fitToRide() {
    if (_mapController == null) return;

    if (_markers.isNotEmpty) {
      // Calculate bounds from all markers
      double minLat = double.infinity;
      double maxLat = double.negativeInfinity;
      double minLng = double.infinity;
      double maxLng = double.negativeInfinity;

      for (final marker in _markers) {
        final point = marker.point;
        minLat = minLat < point.latitude ? minLat : point.latitude;
        maxLat = maxLat > point.latitude ? maxLat : point.latitude;
        minLng = minLng < point.longitude ? minLng : point.longitude;
        maxLng = maxLng > point.longitude ? maxLng : point.longitude;
      }

      // Add some padding to the bounds
      final latPadding = (maxLat - minLat) * 0.2;
      final lngPadding = (maxLng - minLng) * 0.2;

      minLat -= latPadding;
      maxLat += latPadding;
      minLng -= lngPadding;
      maxLng += lngPadding;

      _mapController!.fitBounds(
        LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
        options: FitBoundsOptions(
          padding: const EdgeInsets.all(50.0),
          maxZoom: 16.0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: const Text(
          'Live Ride Tracking',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          // Show ride status
          if (_ride != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                _ride!['status']?.toUpperCase() ?? 'UNKNOWN',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController ??= MapController(),
                  options: MapOptions(
                    initialCenter: _pickup ?? const LatLng(12.9716, 77.5946),
                    initialZoom: 13.0,
                    maxZoom: 18.0,
                    minZoom: 2.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.ridemate',
                    ),
                    PolylineLayer(polylines: _polylines.toList()),
                    MarkerLayer(markers: _markers.toList()),
                  ],
                ),
                if (_error != null)
                  Positioned.fill(
                    child: Container(
                      color: Colors.red.shade50,
                      child: Center(
                        child: Material(
                          color: Colors.white,
                          elevation: 8,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade600,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Tracking Error',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _error = null;
                                      _loading = true;
                                    });
                                    _init();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Driver info overlay
                if (_ride != null && _ride!['driver'] != null)
                  Positioned(
                    top: 100,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _ride!['driver']['name'] ?? 'Driver',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _ride!['driver']['rating']
                                                  ?.toString() ??
                                              '0.0',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(_ride!['status']),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _ride!['status']?.toUpperCase() ?? 'UNKNOWN',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Car details
                          if (_ride!['driver']['carModel'] != null)
                            Row(
                              children: [
                                const Icon(Icons.directions_car, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  _ride!['driver']['carModel'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                if (_ride!['driver']['carNumber'] != null) ...[
                                  const Icon(
                                    Icons.confirmation_number,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _ride!['driver']['carNumber'],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'requested':
        return Colors.orange;
      case 'accepted':
      case 'confirmed':
        return Colors.blue;
      case 'enroute':
      case 'arrived':
        return Colors.purple;
      case 'in_progress':
        return Colors.indigo;
      case 'completed':
        return Colors.green;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _rideSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }
}
