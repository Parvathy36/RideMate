import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'dart:ui';
import 'analytics_charts.dart';
import '../services/admin_analytics_service.dart';
import '../utils/location_utils.dart';
import 'dart:math' as math;

class AdminAnalyticsDashboard extends StatefulWidget {
  const AdminAnalyticsDashboard({super.key});

  @override
  State<AdminAnalyticsDashboard> createState() => _AdminAnalyticsDashboardState();
}

class _AdminAnalyticsDashboardState extends State<AdminAnalyticsDashboard> {
  bool _isLoading = true;
  AdminAnalyticsData? _data;
  String _timeRange = 'Week';
  String _category = 'All';
  String _region = 'All Regions';
  bool _showMockHeatmap = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final data = await AdminAnalyticsService.getSystemAnalytics(_timeRange, category: _category, region: _region);
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load analytics: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Advanced Analytics',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
            ),
            Row(
              children: [
                _buildFilterDropdown('Region', _region, ['All Regions', 'Ernakulam', 'Thrissur', 'Palakkad', 'Kozhikode', 'Malappuram', 'Thiruvananthapuram'], (val) {
                  setState(() => _region = val!);
                  _loadData();
                }),
                const SizedBox(width: 8),
                _buildFilterDropdown('Category', _category, ['All', 'Solo', 'Pooling'], (val) {
                  setState(() => _category = val!);
                  _loadData();
                }),
                const SizedBox(width: 8),
                _buildFilterDropdown('Time', _timeRange, ['Today', 'Week', 'Month', 'Year'], (val) {
                  setState(() => _timeRange = val!);
                  _loadData();
                }),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_data == null)
          const Expanded(
            child: Center(
              child: Text('No data available', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ),
          )
        else
          Expanded(
            child: _buildAnalyticsView(_data!),
          ),
      ],
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(label),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildAnalyticsView(AdminAnalyticsData data) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Cards Row 1
          Row(
            children: [
              Expanded(
                child: StatSummaryCard(
                  title: 'Peak Booking Hour',
                  value: data.peakHour,
                  icon: Icons.access_time_filled,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatSummaryCard(
                  title: 'Demand/Supply Ratio',
                  value: '${data.demandSupplyRatio.toStringAsFixed(2)}x',
                  icon: Icons.balance,
                  color: data.demandSupplyRatio > 1.5 ? Colors.deepOrange : Colors.green,
                  trend: data.demandSupplyRatio > 1.5 ? 'High Demand' : 'Balanced',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatSummaryCard(
                  title: 'Active Drivers',
                  value: '${data.activeDrivers} / ${data.totalDrivers}',
                  icon: Icons.local_taxi,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatSummaryCard(
                  title: 'Cancellation Rate',
                  value: '${data.cancellationRate.toStringAsFixed(1)}%',
                  icon: Icons.cancel_outlined,
                  color: Colors.red,
                  trend: data.cancellationRate > 15 ? 'Alert' : 'Normal',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stat Cards Row 2 (the old ones)
          Row(
            children: [
              Expanded(
                child: StatSummaryCard(
                  title: 'Total Rides',
                  value: data.totalRides.toString(),
                  icon: Icons.directions_car,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatSummaryCard(
                  title: 'Surge Incidents',
                  value: '${data.surgeIncidents}',
                  icon: Icons.trending_up,
                  color: Colors.orange,
                  trend: data.surgeIncidents > 5 ? 'High Surge' : '',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatSummaryCard(
                  title: 'Total Revenue',
                  value: '₹${data.totalRevenue.toStringAsFixed(0)}',
                  icon: Icons.payments,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatSummaryCard(
                  title: 'Avg. Fare',
                  value: '₹${data.averageFare.toStringAsFixed(0)}',
                  icon: Icons.analytics,
                  color: Colors.indigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Charts Row 1
          Row(
            children: [
              Expanded(child: RideVolumeChart(data: data.volumeTrend)),
              const SizedBox(width: 24),
              Expanded(child: RevenueTrendChart(data: data.revenueTrend)),
            ],
          ),
          const SizedBox(height: 24),
          // Charts Row 2 (Pie Charts)
          Row(
            children: [
              Expanded(child: StatusDistributionChart(distribution: data.statusDistribution)),
              const SizedBox(width: 24),
              Expanded(child: TypeDistributionChart(distribution: data.rideTypeDistribution)),
            ],
          ),
          const SizedBox(height: 24),
          // Heatmap Row
          SizedBox(
            height: 400,
            child: _buildHeatmapsView(),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeatmapsView() {
    final regionCenter = LocationUtils.getRegionCenter(_region);
    
    return Container(
       decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(16),
         boxShadow: [
           BoxShadow(
             color: Colors.black.withOpacity(0.05),
             blurRadius: 10,
             offset: const Offset(0, 2),
           ),
         ],
       ),
       child: ClipRRect(
         borderRadius: BorderRadius.circular(16),
         child: Stack(
           children: [
             StreamBuilder<QuerySnapshot>(
               stream: FirebaseFirestore.instance
                   .collection('rides')
                   .where('status', whereIn: ['request', 'accepted', 'ongoing', 'completed'])
                   .snapshots(),
               builder: (context, snapshot) {
                 if (snapshot.connectionState == ConnectionState.waiting) {
                   return const Center(child: CircularProgressIndicator());
                 }

                 final allRides = snapshot.data?.docs ?? [];
                 final regionalRides = allRides.where((doc) {
                   final data = doc.data() as Map<String, dynamic>;
                   if (_region == 'All Regions') return true;
                   
                   final location = data['pickupLocation'];
                   final region = LocationUtils.getRegionFromLatLng(location);
                   return region == _region;
                 }).toList();

                 final List<CircleMarker> circles = [];
                 
                 for (var doc in regionalRides) {
                   final data = doc.data() as Map<String, dynamic>;
                   final location = data['pickupLocation'] as GeoPoint?;
                   if (location == null) continue;
                   
                   final status = data['status'] as String? ?? 'request';
                   _addHeatmapCircles(circles, ll.LatLng(location.latitude, location.longitude), status);
                 }

                 if (_showMockHeatmap) {
                   _addMockHeatmapData(circles, regionCenter);
                 }

                 return FlutterMap(
                   options: MapOptions(
                     initialCenter: regionCenter,
                     initialZoom: _region == 'All Regions' ? 7.0 : 11.0,
                   ),
                   children: [
                     TileLayer(
                       urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                       userAgentPackageName: 'com.ridemate.app',
                     ),
                     CircleLayer(circles: circles),
                   ],
                 );
               },
             ),
             
             // Legend
             Positioned(
               top: 24,
               right: 24,
               child: ClipRRect(
                 borderRadius: BorderRadius.circular(20),
                 child: BackdropFilter(
                   filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                   child: Container(
                     padding: const EdgeInsets.all(20),
                     decoration: BoxDecoration(
                       color: Colors.white.withOpacity(0.8),
                       borderRadius: BorderRadius.circular(20),
                       border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                     ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         const Text('Activity Legend', style: TextStyle(fontWeight: FontWeight.bold)),
                         const SizedBox(height: 12),
                         _buildLegendItem('High Demand (Request)', Colors.orange),
                         const SizedBox(height: 8),
                         _buildLegendItem('In Progress', Colors.blue),
                         const SizedBox(height: 8),
                         _buildLegendItem('Completed Historic', Colors.green),
                       ],
                     ),
                   ),
                 ),
               ),
             ),
             
             // Demo Toggle
             Positioned(
               bottom: 16,
               right: 16,
               child: FloatingActionButton.extended(
                 onPressed: () {
                   setState(() {
                     _showMockHeatmap = !_showMockHeatmap;
                   });
                 },
                 backgroundColor: _showMockHeatmap ? Colors.orange : Colors.deepPurple,
                 icon: Icon(_showMockHeatmap ? Icons.visibility_off : Icons.visibility, color: Colors.white),
                 label: Text(
                   _showMockHeatmap ? 'Hide Demo' : 'Show Demo',
                   style: const TextStyle(color: Colors.white),
                 ),
               ),
             ),
           ],
         ),
       )
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color.withOpacity(0.6), shape: BoxShape.circle, border: Border.all(color: color, width: 2))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  void _addHeatmapCircles(List<CircleMarker> circles, ll.LatLng point, String status) {
    Color baseColor;
    if (status == 'request') baseColor = Colors.orange;
    else if (status == 'accepted' || status == 'ongoing') baseColor = Colors.blue;
    else baseColor = Colors.green;
    
    circles.addAll([
      CircleMarker(point: point, color: baseColor.withOpacity(0.2), borderStrokeWidth: 0, radius: 40),
      CircleMarker(point: point, color: baseColor.withOpacity(0.4), borderStrokeWidth: 0, radius: 25),
      CircleMarker(point: point, color: baseColor.withOpacity(0.8), borderStrokeWidth: 0, radius: 10),
    ]);
  }

  void _addMockHeatmapData(List<CircleMarker> circles, ll.LatLng center) {
    final random = math.Random(42);
    for (int i = 0; i < 30; i++) {
        final latOffset = (random.nextDouble() - 0.5) * 0.1;
        final lngOffset = (random.nextDouble() - 0.5) * 0.1;
        final point = ll.LatLng(center.latitude + latOffset, center.longitude + lngOffset);
        final status = random.nextDouble() > 0.6 ? 'request' : (random.nextDouble() > 0.3 ? 'ongoing' : 'completed');
        _addHeatmapCircles(circles, point, status);
    }
  }
}
