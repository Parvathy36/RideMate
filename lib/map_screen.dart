import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:http/http.dart' as http;
import 'services/firestore_service.dart';

class _OsrmRoute {
  _OsrmRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
  final List<ll.LatLng> points;
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
  final MapController _mapController = MapController();
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _ride;
  ll.LatLng? _pickup;
  ll.LatLng? _destination;
  List<ll.LatLng> _route = const [];
  double? _distanceKm;
  double? _durationMin;

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

      // Resolve coordinates (prefer stored GeoPoints if present)
      _pickup =
          _extractLatLng(_ride!['pickupLocation']) ??
          await _geocodeAddress(_ride!['pickupAddress']);
      _destination =
          _extractLatLng(_ride!['destinationLocation']) ??
          await _geocodeAddress(_ride!['destinationAddress']);

      if (_pickup == null || _destination == null) {
        throw Exception('Could not resolve pickup/destination locations');
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
        _route = <ll.LatLng>[_pickup!, _destination!];
      }

      // Fit map to polyline or endpoints after build
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToPolyline());
    } catch (e) {
      _error = 'Failed to load map: $e';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  ll.LatLng? _extractLatLng(dynamic value) {
    try {
      if (value == null) return null;
      if (value is Map<String, dynamic>) {
        final lat = value['latitude'] as num?;
        final lng = value['longitude'] as num?;
        if (lat != null && lng != null) {
          return ll.LatLng(lat.toDouble(), lng.toDouble());
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<ll.LatLng?> _geocodeAddress(String address) async {
    try {
      // Bias to India (Kerala) to disambiguate short names like Kottayam, Kanjirappally
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=json&addressdetails=1&limit=5&countrycodes=in'
        '&q=${Uri.encodeComponent(address)}',
      );
      final resp = await http.get(
        url,
        headers: {'User-Agent': 'RideMate/1.0 (contact: support@example.com)'},
      );
      if (resp.statusCode != 200) return null;
      final List results = json.decode(resp.body) as List;
      if (results.isEmpty) return null;

      Map<String, dynamic>? pick;
      for (final r in results) {
        final m = r as Map<String, dynamic>;
        final addr = (m['address'] as Map<String, dynamic>?) ?? {};
        final state = (addr['state'] as String?)?.toLowerCase() ?? '';
        if (state.contains('kerala')) {
          pick = m;
          break;
        }
      }
      pick ??= results.first as Map<String, dynamic>;

      final lat = double.tryParse(pick['lat'] as String? ?? '');
      final lon = double.tryParse(pick['lon'] as String? ?? '');
      if (lat == null || lon == null) return null;
      return ll.LatLng(lat, lon);
    } catch (_) {
      return null;
    }
  }

  Future<_OsrmRoute?> _fetchOsrmRouteWithMeta(
    ll.LatLng origin,
    ll.LatLng destination,
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
            (c) =>
                ll.LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
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
    if (_route.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(_route);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
      );
      return;
    }
    if (_pickup == null || _destination == null) return;
    final bounds = LatLngBounds.fromPoints([_pickup!, _destination!]);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = _pickup ?? const ll.LatLng(12.9716, 77.5946);
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
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 13,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c'],
                            userAgentPackageName: 'com.example.ridemate',
                          ),
                          if (_route.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _route,
                                  strokeWidth: 5,
                                  color: Colors.deepPurple,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              if (_pickup != null)
                                Marker(
                                  point: _pickup!,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_pin,
                                    color: Colors.deepPurple,
                                    size: 40,
                                  ),
                                ),
                              if (_destination != null)
                                Marker(
                                  point: _destination!,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.flag,
                                    color: Colors.amber,
                                    size: 36,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (_error != null)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 24,
                          child: Material(
                            color: Colors.white,
                            elevation: 4,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.black87),
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
                                  'Available Drivers',
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

  // Fetch available drivers from Firestore
  Future<List<Driver>> _getAvailableDrivers() async {
    try {
      final driversData = await FirestoreService.getAvailableDrivers();
      return driversData.map((data) => Driver.fromFirestore(data)).toList();
    } catch (e) {
      print('Error fetching drivers: $e');
      // Return empty list on error
      return [];
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
                    'No drivers available',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
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
                      'Distance',
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
              onPressed: () {
                // Handle driver selection
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Selected ${driver.name} - ${driver.carModel}',
                    ),
                    backgroundColor: Colors.deepPurple,
                  ),
                );
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
    // Calculate distance based on current location (simplified for demo)
    // In real app, you would calculate distance from user's location
    final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
    final distance = (data['distance'] as num?)?.toDouble() ?? (2.0 + rating);

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
