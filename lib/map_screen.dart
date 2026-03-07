import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'services/firestore_service.dart';
import 'config/app_config.dart';
import 'home.dart';
import 'rides_booking.dart';
import 'ride_pooling.dart';
import 'live_tracking_map.dart';
import 'utils/responsive_utils.dart';

class _OsrmRoute {
  _OsrmRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
}

class MapScreen extends StatefulWidget {
  final String rideId;

  const MapScreen({super.key, required this.rideId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapController? _mapController;
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _ride;
  String? _rideType; // Add this line to store the ride type
  LatLng? _pickup;
  LatLng? _destination;
  List<LatLng> _route = <LatLng>[];
  double? _distanceKm;
  double? _durationMin;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // Load ride
      _ride = await FirestoreService.getRideById(widget.rideId);
      if (_ride == null) {
        throw Exception('Ride not found');
      }

      // Get ride type from the ride document
      _rideType = _ride!['rideType'] as String? ?? 'Solo';

      // Resolve coordinates (prefer stored GeoPoints if present)
      final pickupAddress = (_ride!['pickupAddress'] as String?)?.trim();
      final destinationAddress = (_ride!['destinationAddress'] as String?)
          ?.trim();

      _pickup =
          _extractLatLng(_ride!['pickupLocation']) ??
          (pickupAddress?.isNotEmpty == true
              ? await _geocodeAddress(pickupAddress!)
              : null) ??
          _fallbackLatLng(AppConfig.defaultPickupLocation);

      _destination =
          _extractLatLng(_ride!['destinationLocation']) ??
          (destinationAddress?.isNotEmpty == true
              ? await _geocodeAddress(destinationAddress!)
              : null) ??
          _fallbackLatLng(AppConfig.defaultDestinationLocation);

      // Persist fallback locations if original document lacked coordinates
      await FirestoreService.updateRideLocations(
        rideId: widget.rideId,
        pickup: {
          'latitude': _pickup!.latitude,
          'longitude': _pickup!.longitude,
        },
        destination: {
          'latitude': _destination!.latitude,
          'longitude': _destination!.longitude,
        },
      );

      if (_pickup == null || _destination == null) {
        throw Exception(
          'Could not resolve pickup/destination locations. Update the ride data or AppConfig fallbacks.',
        );
      }

      // Fetch route via OSRM (fastest alternative) and persist normalized points
      final meta = await _fetchOsrmRouteWithMeta(_pickup!, _destination!);
      if (meta != null) {
        _route = meta.points;
        _distanceKm = meta.distanceMeters / 1000.0;
        _durationMin = meta.durationSeconds / 60.0;
        if (_route.isNotEmpty) {
          _pickup = _route.first;
          _destination = _route.last;
        }
        await FirestoreService.updateRideLocations(
          rideId: widget.rideId,
          pickup: {
            'latitude': _pickup!.latitude,
            'longitude': _pickup!.longitude,
          },
          destination: {
            'latitude': _destination!.latitude,
            'longitude': _destination!.longitude,
          },
          summary: {'distanceKm': _distanceKm, 'durationMin': _durationMin},
        );
      } else {
        _route = <LatLng>[_pickup!, _destination!];
      }

      // Update markers and polylines
      _updateMarkersAndPolylines();

      // Fit map to polyline or endpoints after build
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToPolyline());
    } catch (e) {
      print('Map initialization error: $e');
      _error = 'Failed to load map: $e';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
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

  LatLng? _fallbackLatLng(dynamic fallback) {
    if (fallback == null) {
      return null;
    }
    final resolved = _extractLatLng(fallback);
    if (resolved != null) {
      return resolved;
    }
    if (fallback is Map<String, double>) {
      final lat = fallback['latitude'];
      final lng = fallback['longitude'];
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }
    return null;
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    try {
      // Use Nominatim API for geocoding (OSM alternative)
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(address)}'
        '&format=json'
        '&limit=1',
      );
      final resp = await http
          .get(
            url,
            headers: {
              'User-Agent': 'RideMate/1.0', // Required by Nominatim
            },
          )
          .timeout(AppConfig.geocodingTimeout);
      if (resp.statusCode != 200) return null;
      final data = json.decode(resp.body) as List;
      if (data.isEmpty) return null;

      final result = data.first as Map<String, dynamic>;
      final lat = double.parse(result['lat'] as String);
      final lng = double.parse(result['lon'] as String);
      return LatLng(lat, lng);
    } catch (_) {
      return null;
    }
  }

  Future<_OsrmRoute?> _fetchOsrmRouteWithMeta(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&alternatives=true&steps=true&annotations=true&continue_straight=true',
      );
      final resp = await http.get(url);
      if (resp.statusCode != 200) return null;
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      Map<String, dynamic> best = routes.first as Map<String, dynamic>;
      for (final r in routes) {
        final m = r as Map<String, dynamic>;
        if ((m['duration'] as num).toDouble() <
            (best['duration'] as num).toDouble()) {
          best = m;
        }
      }

      final geometry = best['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List<dynamic>;
      final points = coords
          .map(
            (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          )
          .toList(growable: false);
      final distance = (best['distance'] as num).toDouble();
      final duration = (best['duration'] as num).toDouble();
      return _OsrmRoute(
        points: points,
        distanceMeters: distance,
        durationSeconds: duration,
      );
    } catch (_) {
      return null;
    }
  }

  void _fitToPolyline() {
    if (_mapController == null) return;

    if (_route.isNotEmpty) {
      // Calculate bounds from route points
      double minLat = _route.first.latitude;
      double maxLat = _route.first.latitude;
      double minLng = _route.first.longitude;
      double maxLng = _route.first.longitude;

      for (final point in _route) {
        minLat = minLat < point.latitude ? minLat : point.latitude;
        maxLat = maxLat > point.latitude ? maxLat : point.latitude;
        minLng = minLng < point.longitude ? minLng : point.longitude;
        maxLng = maxLng > point.longitude ? maxLng : point.longitude;
      }

      _mapController!.move(
        LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
        _calculateZoomLevel(minLat, maxLat, minLng, maxLng),
      );
      return;
    }

    if (_pickup != null && _destination != null) {
      final centerLat = (_pickup!.latitude + _destination!.latitude) / 2;
      final centerLng = (_pickup!.longitude + _destination!.longitude) / 2;
      _mapController!.move(LatLng(centerLat, centerLng), 13);
    }
  }

  double _calculateZoomLevel(
    double minLat,
    double maxLat,
    double minLng,
    double maxLng,
  ) {
    final latDiff = (maxLat - minLat).abs();
    final lngDiff = (maxLng - minLng).abs();
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    // Simple zoom calculation - you might want to refine this
    if (maxDiff < 0.001) return 17.0;
    if (maxDiff < 0.01) return 15.0;
    if (maxDiff < 0.1) return 13.0;
    if (maxDiff < 1.0) return 11.0;
    return 9.0;
  }

  void _updateMarkersAndPolylines() {
    final markers = <Marker>{};
    final polylines = <Polyline>{};

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

    // Add nearby driver markers
    _addNearbyDriverMarkers(markers);

    if (_route.isNotEmpty) {
      polylines.add(
        Polyline(points: _route, color: Colors.deepPurple, strokeWidth: 5.0),
      );
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });
  }

  @override
  Widget build(BuildContext context) {
    final center = _pickup ?? const LatLng(12.9716, 77.5946);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Your Route',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          if (_distanceKm != null && _durationMin != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '${_distanceKm!.toStringAsFixed(1)} km • ${_durationMin!.toStringAsFixed(0)} min',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Map Section (Left side)
                Expanded(
                  flex: 2,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController ??= MapController(),
                        options: MapOptions(
                          initialCenter: center,
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
                                        'Map Loading Error',
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
                    ],
                  ),
                ),
                // Available Drivers Section (Right side)
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [const Color(0xFFFAFAFA), Colors.grey.shade50],
                      ),
                      border: Border(
                        left: BorderSide(color: Colors.grey.shade200, width: 1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(-2, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
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
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.amber,
                                      Colors.amber.shade600,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.local_taxi,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  'Nearby Drivers (5km) - Map & List',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(child: _buildAvailableDriversList()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // Fetch available drivers from Firestore (proximity-based)
  Future<List<Driver>> _getAvailableDrivers() async {
    try {
      // Ensure pickup location is available
      if (_pickup == null) {
        print('❌ Pickup location not available');
        return [];
      }

      print('🔍 Fetching nearby drivers for pickup at (${_pickup!.latitude}, ${_pickup!.longitude})');
      
      // Fetch drivers within 5km radius of pickup location (strictly enforced)
      final driversData = await FirestoreService.getNearbyAvailableDrivers(
        pickupLatitude: _pickup!.latitude,
        pickupLongitude: _pickup!.longitude,
        radiusInKm: 5.0, // Strict 5km radius limit
      );
      
      print('📊 Found ${driversData.length} nearby drivers within 5km radius');
      
      // Convert to Driver objects
      return driversData.map((data) => Driver.fromFirestore(data)).toList();
    } catch (e) {
      print('❌ Error fetching nearby drivers: $e');
      // Return empty list on error
      return [];
    }
  }

  // Add nearby driver markers to the map
  void _addNearbyDriverMarkers(Set<Marker> markers) {
    // This will be called after drivers are loaded in the FutureBuilder
    // For now, we'll load drivers asynchronously and update markers
    _loadAndAddDriverMarkers(markers);
  }

  // Load drivers and add their markers to the map
  Future<void> _loadAndAddDriverMarkers(Set<Marker> markers) async {
    try {
      // Ensure pickup location is available
      if (_pickup == null) return;

      // Fetch nearby drivers
      final driversData = await FirestoreService.getNearbyAvailableDrivers(
        pickupLatitude: _pickup!.latitude,
        pickupLongitude: _pickup!.longitude,
        radiusInKm: 5.0, // Strict 5km radius limit
      );

      print('📍 Adding ${driversData.length} driver markers to map');
      
      // Add marker for each nearby driver
      for (final driverData in driversData) {
        final currentLocation = driverData['currentLocation'] as GeoPoint?;
        if (currentLocation != null) {
          final driverLocation = LatLng(currentLocation.latitude, currentLocation.longitude);
          final driverName = driverData['name'] as String? ?? 'Driver';
          final carModel = driverData['carModel'] as String? ?? 'Car';
          
          markers.add(
            Marker(
              width: 60.0,
              height: 60.0,
              point: driverLocation,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_taxi,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          );
          
          print('📍 Added marker for driver: $driverName ($carModel) at (${driverLocation.latitude}, ${driverLocation.longitude})');
        }
      }
      
      // Update the state to refresh the map
      if (mounted) {
        setState(() {
          _markers = markers;
        });
      }
    } catch (e) {
      print('❌ Error adding driver markers: $e');
    }
  }

  // Calculate fare based on car model rate and actual ride distance
  // Formula: Base Fare + (Distance in KM × Per KM Rate)
  double _calculateFare(Driver driver, double distanceKm) {
    return driver.baseFare + (distanceKm * driver.perKmRate);
  }

  Widget _buildAvailableDriversList() {
    return FutureBuilder<List<Driver>>(
      future: _getAvailableDrivers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Colors.deepPurple),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load drivers',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again later',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        final drivers = snapshot.data ?? [];

        if (drivers.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.local_taxi_outlined,
                    color: Colors.grey,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No nearby drivers found',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No drivers within 5km radius',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: drivers.length,
          itemBuilder: (context, index) {
            final driver = drivers[index];
            return _buildDriverCard(driver);
          },
        );
      },
    );
  }

  Widget _buildDriverCard(Driver driver) {
    // Use distance from ride data if available, otherwise fallback to driver distance
    final distanceKm = _distanceKm ?? driver.distance;
    final fare = _calculateFare(driver, distanceKm);

    // Debug information (can be removed in production)
    print('Fare calculation for ${driver.carModel}:');
    print('  - Base Fare: ₹${driver.baseFare}');
    print('  - Per KM Rate: ₹${driver.perKmRate}');
    print('  - Distance: ${distanceKm.toStringAsFixed(2)} km');
    print('  - Total Fare: ₹${fare.toStringAsFixed(2)}');

    return Container(
      margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
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
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.deepPurple.withValues(alpha: 0.15),
                      Colors.deepPurple.withValues(alpha: 0.25),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.deepPurple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          driver.rating.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.deepPurple, width: 1),
                          ),
                          child: const Text(
                            'ON MAP',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.grey.shade50, Colors.white],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Car Model',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      driver.carModel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Distance from pickup',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${distanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fare',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '₹${fare.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                _showDriverDetailsDialog(driver, fare, distanceKm);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: const Text(
                'Select Driver',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Show driver details dialog
  void _showDriverDetailsDialog(Driver driver, double fare, double distanceKm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.deepPurple.withValues(alpha: 0.15),
                          Colors.deepPurple.withValues(alpha: 0.25),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.deepPurple,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      driver.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${driver.rating.toStringAsFixed(1)} Rating',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Vehicle Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDetailRow('Model', driver.carModel),
                _buildDetailRow('Number', driver.carNumber),
                const SizedBox(height: 16),
                const Text(
                  'Contact Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDetailRow('Email', driver.email ?? 'Not provided'),
                _buildDetailRow('Phone', driver.phoneNumber ?? 'Not provided'),
                const SizedBox(height: 16),
                const Text(
                  'Trip Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDetailRow('Distance', '${distanceKm.toStringAsFixed(1)} km'),
                _buildDetailRow('Estimated Fare', '₹${fare.toStringAsFixed(0)}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text(
                'CLOSE',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog
                await _selectDriver(driver, fare, distanceKm);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('CONFIRM DRIVER'),
            ),
          ],
        );
      },
    );
  }

  // Build detail row widget
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Select driver and proceed with booking
  Future<void> _selectDriver(Driver driver, double fare, double distanceKm) async {
    if (driver.userId == null || driver.userId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Driver information is incomplete.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecting driver...'),
          backgroundColor: Colors.deepPurple,
          duration: Duration(seconds: 1),
        ),
      );

      // Update ride with driver information
      await FirestoreService.updateRideWithDriver(
        rideId: widget.rideId,
        driverId: driver.userId!,
        driverName: driver.name,
        carModel: driver.carModel,
        fare: fare,
        carNumber: driver.carNumber,
        rating: driver.rating,
        distance: distanceKm,
        driverEmail: driver.email,
        driverPhoneNumber: driver.phoneNumber,
        driverImageUrl: driver.imageUrl,
      );

      // Record cash payment automatically
      final user = FirebaseAuth.instance.currentUser;
      Map<String, dynamic>? userData;
      if (user != null) {
        userData = await FirestoreService.getUserData(user.uid);
      }

      await FirestoreService.recordPayment(
        rideId: widget.rideId,
        amount: fare,
        method: 'Cash',
        reference: 'CASH_PAYMENT_AUTO',
        issuer: 'N/A',
        payerName: userData?['name'] ?? user?.displayName ?? 'User',
        rideType: _rideType ?? 'Solo',
        driver: {
          'name': driver.name,
          'carModel': driver.carModel,
          'carNumber': driver.carNumber,
          'rating': driver.rating,
          'email': driver.email,
          'phoneNumber': driver.phoneNumber,
          'imageUrl': driver.imageUrl,
        },
      );

      // Update ride status to confirmed
      await FirestoreService.updateRideStatus(widget.rideId, 'confirmed');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking confirmed! Driver assigned.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Navigate directly to home page
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const HomePage(),
          ),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select driver: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Driver model class
class Driver {
  final String name;
  final String carModel;
  final String carNumber;
  final double rating;
  final double distance; // in kilometers
  final double baseFare;
  final double perKmRate;
  final String? imageUrl;
  final String? userId;
  final String? email;
  final String? phoneNumber;

  Driver({
    required this.name,
    required this.carModel,
    required this.carNumber,
    required this.rating,
    required this.distance,
    required this.baseFare,
    required this.perKmRate,
    this.imageUrl,
    this.userId,
    this.email,
    this.phoneNumber,
  });

  // Constructor to create Driver from Firestore data
  factory Driver.fromFirestore(Map<String, dynamic> data) {
    // Use distance from pickup if available (calculated by proximity filter)
    // Otherwise fall back to rating-based distance estimation
    final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
    final distanceFromPickup = data['distanceFromPickup'];
    
    double distance;
    if (distanceFromPickup != null) {
      // Use the calculated distance from proximity filtering
      distance = (distanceFromPickup as num).toDouble();
      print('📍 Using calculated distance: ${distance.toStringAsFixed(2)} km');
    } else {
      // Fallback to rating-based estimation
      distance = (data['distance'] as num?)?.toDouble() ?? (2.0 + rating);
      print('📍 Using estimated distance: ${distance.toStringAsFixed(2)} km');
    }

    // Calculate fare based on car model
    double baseFare = 50.0;
    double perKmRate = 12.0;

    final carModel = (data['carModel'] as String?) ?? 'Unknown';
    switch (carModel.toLowerCase()) {
      case 'honda city':
        baseFare = 60.0;
        perKmRate = 15.0;
        break;
      case 'toyota innova':
        baseFare = 80.0;
        perKmRate = 18.0;
        break;
      case 'hyundai creta':
        baseFare = 70.0;
        perKmRate = 16.0;
        break;
      case 'maruti swift':
        baseFare = 50.0;
        perKmRate = 12.0;
        break;
      default:
        baseFare = 60.0;
        perKmRate = 14.0;
    }

    return Driver(
      name: data['name'] as String? ?? 'Unknown Driver',
      carModel: carModel,
      carNumber: data['carNumber'] as String? ?? 'Unknown',
      rating: (data['rating'] as num?)?.toDouble() ?? 4.5,
      distance: distance,
      baseFare: baseFare,
      perKmRate: perKmRate,
      imageUrl: data['profileImageUrl'] as String?,
      userId: data['id'] as String?,
      email: data['email'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
    );
  }
}
