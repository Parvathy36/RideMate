import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'dart:ui';
import 'dart:math' as math;
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/supervisor_analytics_service.dart';
import '../widgets/analytics_charts.dart';
import '../utils/location_utils.dart';
import '../login_page.dart';

class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  
  String _supervisorName = 'Supervisor';
  String _supervisorRegion = '';
  bool _isLoading = true;
  
  // Navigation
  int _selectedIndex = 0;
  final List<String> _menuItems = [
    'Dashboard',
    'Drivers',
    'Heatmaps',
    'Analytics',
    'Fraud Monitoring',
  ];

  String _selectedTimeRange = 'Today';
  AnalyticsData? _analyticsData;
  bool _isAnalyticsLoading = false;
  bool _showMockHeatmap = false;
  bool _showDashboardDemo = false;
  bool _showDriversDemo = false;

  @override
  void initState() {
    super.initState();
    _loadSupervisorData();
  }

  Future<void> _loadSupervisorData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userData = await FirestoreService.getUserData(currentUser.uid);
        if (userData != null && mounted) {
          setState(() {
            _supervisorName = userData['name'] ?? 'Supervisor';
            _supervisorRegion = userData['region'] ?? 'All Regions';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading supervisor data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(),
          // Main Content
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.supervisor_account,
                    color: Colors.white,
                    size: 35,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Supervisor Panel',
                  style: TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _supervisorName,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Region: $_supervisorRegion',
                    style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                return _buildSidebarItem(
                  title: _menuItems[index],
                  icon: _getMenuIcon(index),
                  isSelected: _selectedIndex == index,
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                    if (index == 3) {
                      _loadAnalytics();
                    }
                  },
                );
              },
            ),
          ),

          // Logout Button
          Container(
            padding: const EdgeInsets.all(16),
            child: _buildSidebarItem(
              title: 'Logout',
              icon: Icons.logout,
              isSelected: false,
              isLogout: true,
              onTap: _signOut,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMenuIcon(int index) {
    switch (index) {
      case 0: return Icons.dashboard;
      case 1: return Icons.directions_car;
      case 2: return Icons.map;
      case 3: return Icons.analytics;
      case 4: return Icons.security;
      default: return Icons.circle;
    }
  }

  Widget _buildSidebarItem({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.deepPurple.shade50
                  : isLogout
                  ? Colors.red.shade50
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: Colors.deepPurple.shade200)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? Colors.deepPurple.shade600
                      : isLogout
                      ? Colors.red.shade600
                      : const Color(0xFF1A1A2E),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.deepPurple.shade600
                        : isLogout
                        ? Colors.red.shade600
                        : const Color(0xFF1A1A2E),
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContentHeader(),
          const SizedBox(height: 24),
          Expanded(child: _buildSelectedContent()),
        ],
      ),
    );
  }

  Widget _buildContentHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.deepPurple.shade700],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getMenuIcon(_selectedIndex),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _menuItems[_selectedIndex],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Managing $_supervisorRegion region',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          const Spacer(),
          if (_selectedIndex == 3) _buildTimeRangeSelector(),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTimeRange,
          items: ['Today', 'Week', 'Month'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedTimeRange = value;
              });
              _loadAnalytics();
            }
          },
        ),
      ),
    );
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isAnalyticsLoading = true;
    });
    try {
      final data = await SupervisorAnalyticsService.getRegionalAnalytics(_supervisorRegion, _selectedTimeRange);
      setState(() {
        _analyticsData = data;
        _isAnalyticsLoading = false;
      });
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() {
        _isAnalyticsLoading = false;
      });
    }
  }

  Widget _buildSelectedContent() {
    switch (_selectedIndex) {
      case 0: return _buildDashboardView();
      case 1: return _buildDriversView();
      case 2: return _buildHeatmapsView();
      case 3: return _buildAnalyticsView();
      case 4: return _buildFraudMonitoringView();
      default: return _buildDashboardView();
    }
  }
  
  // Dashboard Overview
  Widget _buildDashboardView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: FirestoreService.getAllDrivers(),
                  builder: (context, snapshot) {
                    String value = '0';
                    if (_showDashboardDemo) {
                      value = '12';
                    } else if (snapshot.hasData) {
                      final count = snapshot.data!.where((driver) {
                        final location = driver['currentLocation'];
                        final region = LocationUtils.getRegionFromLatLng(location);
                        return region == _supervisorRegion || _supervisorRegion == 'All Regions';
                      }).length;
                      value = count.toString();
                    }
                    return _buildStatCard('Active Drivers', value, Icons.directions_car, Colors.blue);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('rides')
                      .snapshots(),
                  builder: (context, snapshot) {
                    String value = '0';
                    if (_showDashboardDemo) {
                      value = '48';
                    } else if (snapshot.hasData) {
                      final now = DateTime.now();
                      final todayStart = DateTime(now.year, now.month, now.day);
                      
                      final count = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        
                        // Check if today
                        final createdAt = data['createdAt'];
                        if (createdAt is Timestamp) {
                          if (createdAt.toDate().isBefore(todayStart)) return false;
                        } else {
                          return false; // No date, skip
                        }
                        
                        // Check region
                        if (_supervisorRegion == 'All Regions') return true;
                        final location = data['pickupLocation'];
                        final region = LocationUtils.getRegionFromLatLng(location);
                        return region == _supervisorRegion;
                      }).length;
                      value = count.toString();
                    }
                    return _buildStatCard('Total Rides Today', value, Icons.timeline, Colors.green);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: FirestoreService.getPendingDrivers(),
                  builder: (context, snapshot) {
                    String value = '0';
                    if (_showDashboardDemo) {
                      value = '3';
                    } else if (snapshot.hasData) {
                      value = snapshot.data!.length.toString();
                    }
                    return _buildStatCard('Alerts / Pending', value, Icons.warning, Colors.orange);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showDashboardDemo = !_showDashboardDemo;
                });
              },
              icon: Icon(_showDashboardDemo ? Icons.visibility_off : Icons.visibility, size: 16),
              label: Text(_showDashboardDemo ? 'Hide Demo Data' : 'Show Demo Data', style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: _showDashboardDemo ? Colors.orange : Colors.deepPurple,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildRecentActivityCard(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Regional Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('rides')
                .where('status', whereIn: ['request', 'accepted', 'ongoing', 'completed'])
                .orderBy('createdAt', descending: true)
                .limit(20)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ));
              }

              final allRides = snapshot.data?.docs ?? [];
              final regionalActivity = allRides.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                if (_supervisorRegion == 'All Regions') return true;
                
                final location = data['pickupLocation'];
                if (location != null) {
                  final region = LocationUtils.getRegionFromLatLng(location);
                  if (region == _supervisorRegion) return true;
                }
                
                // Fallback: check explicitly stored region if any
                return data['region'] == _supervisorRegion;
              }).toList();

              final List<Map<String, dynamic>> displayData = [];
              
              if (_showDashboardDemo) {
                displayData.addAll(_getMockDashboardActivity());
              } else {
                for (var doc in regionalActivity.take(6)) {
                  displayData.add(doc.data() as Map<String, dynamic>);
                }
              }

              if (displayData.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.history, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        const Text('No recent activity in this region', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayData.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final data = displayData[index];
                  final status = data['status'] as String? ?? 'request';
                  final createdAt = data['createdAt'];
                  final timeAgo = createdAt is Timestamp 
                      ? _formatTimeAgo(createdAt.toDate())
                      : (data['timeAgo'] ?? 'Recently');
                  final driverName = data['driverName'] ?? data['driver']?['name'] ?? 'Driver';
                  final riderName = data['riderName'] ?? data['rider']?['name'] ?? 'Rider';

                  IconData icon;
                  Color color;
                  String title;
                  String subtitle;

                  switch (status) {
                    case 'completed':
                      icon = Icons.check_circle;
                      color = Colors.green;
                      title = 'Ride Completed';
                      subtitle = '$driverName finished ride for $riderName';
                      break;
                    case 'ongoing':
                      icon = Icons.directions_car;
                      color = Colors.blue;
                      title = 'Ride in Progress';
                      subtitle = '$driverName is driving $riderName';
                      break;
                    case 'accepted':
                      icon = Icons.thumb_up;
                      color = Colors.indigo;
                      title = 'Ride Matched';
                      subtitle = '$driverName accepted $riderName\'s request';
                      break;
                    default:
                      icon = Icons.notification_important;
                      color = Colors.orange;
                      title = 'New Request';
                      subtitle = '$riderName is looking for a ride';
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    title: Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A2E)),
                        ),
                        const Spacer(),
                        Text(
                          timeAgo,
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // Drivers Management
  Widget _buildDriversView() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: FirestoreService.getAllDrivers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_showDriversDemo) {
           return const Center(child: CircularProgressIndicator());
        }
        
        final allDrivers = snapshot.data ?? [];
        
        // Filter drivers by region (coords first, then district fallback)
        final regionalDrivers = allDrivers.where((driver) {
          if (_supervisorRegion == 'All Regions') return true;
          
          final location = driver['currentLocation'];
          String driverRegion = LocationUtils.getRegionFromLatLng(location);
          
          if (driverRegion == 'Unknown') {
            driverRegion = LocationUtils.getRegionFromDistrict(driver['district']);
          }
          
          return driverRegion == _supervisorRegion;
        }).toList();

        final List<Map<String, dynamic>> displayDrivers = [];
        if (_showDriversDemo) {
          displayDrivers.addAll(_getMockDrivers());
        } else {
          for (var driver in regionalDrivers) {
            displayDrivers.add(driver);
          }
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showDriversDemo = !_showDriversDemo),
                  icon: Icon(_showDriversDemo ? Icons.visibility_off : Icons.visibility, size: 16),
                  label: Text(_showDriversDemo ? 'Hide Demo' : 'Show Demo', style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: _showDriversDemo ? Colors.orange : Colors.deepPurple),
                ),
              ),
            ),
            if (displayDrivers.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No drivers found in $_supervisorRegion region.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Container(
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
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: displayDrivers.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final driver = displayDrivers[index];
                      final bool isApproved = driver['isApproved'] ?? false;
                      final String driverId = driver['id'] ?? '';
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: Icon(Icons.person, color: Colors.blue.shade600),
                        ),
                        title: Text(driver['name'] ?? 'Unknown Driver'),
                        subtitle: Text('${driver['email'] ?? ''}\n${driver['district'] ?? 'Unknown District'}'),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isApproved)
                              ElevatedButton(
                                onPressed: _showDriversDemo ? null : () => _approveDriver(driverId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                  minimumSize: const Size(60, 32),
                                ),
                                child: const Text('Approve', style: TextStyle(fontSize: 11)),
                              ),
                            if (!isApproved) const SizedBox(width: 8),
                            Chip(
                               label: Text(isApproved ? 'Approved' : 'Pending'),
                               backgroundColor: isApproved ? Colors.green.shade50 : Colors.orange.shade50,
                               labelStyle: TextStyle(
                                 fontSize: 10,
                                 color: isApproved ? Colors.green.shade700 : Colors.orange.shade700
                               ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // Heatmaps View - Visualising Demand
  Widget _buildHeatmapsView() {
    final regionCenter = LocationUtils.getRegionCenter(_supervisorRegion);
    
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
                   if (_supervisorRegion == 'All Regions') return true;
                   
                   final location = data['pickupLocation'];
                   final region = LocationUtils.getRegionFromLatLng(location);
                   return region == _supervisorRegion;
                 }).toList();

                 final List<CircleMarker> circles = [];
                 
                 // Add real data from Firestore
                 for (var doc in regionalRides) {
                   final data = doc.data() as Map<String, dynamic>;
                   final location = data['pickupLocation'] as GeoPoint?;
                   if (location == null) continue;
                   
                   final status = data['status'] as String? ?? 'request';
                   _addHeatmapCircles(circles, ll.LatLng(location.latitude, location.longitude), status);
                 }

                 // Add mock data if enabled
                 if (_showMockHeatmap) {
                   _addMockHeatmapData(circles);
                 }

                 return FlutterMap(
                   options: MapOptions(
                     initialCenter: regionCenter,
                     initialZoom: 11.0,
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
             
             // Premium Glassmorphic Legend
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
                       boxShadow: [
                         BoxShadow(
                           color: Colors.black.withOpacity(0.1),
                           blurRadius: 20,
                           offset: const Offset(0, 10),
                         ),
                       ],
                     ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Row(
                           children: [
                             Container(
                               padding: const EdgeInsets.all(6),
                               decoration: BoxDecoration(
                                 color: Colors.deepPurple.shade50,
                                 borderRadius: BorderRadius.circular(8),
                               ),
                               child: Icon(Icons.legend_toggle, size: 16, color: Colors.deepPurple.shade700),
                             ),
                             const SizedBox(width: 10),
                             const Text(
                               'Activity Legend', 
                               style: TextStyle(
                                 fontWeight: FontWeight.w800, 
                                 fontSize: 15, 
                                 color: Color(0xFF1A1A2E),
                                 letterSpacing: -0.5,
                               )
                             ),
                           ],
                         ),
                         const SizedBox(height: 16),
                         _buildLegendItem('New Requests', Colors.orange, 'Ride Demand'),
                         const SizedBox(height: 12),
                         _buildLegendItem('Active Rides', Colors.blue, 'In Progress'),
                         const SizedBox(height: 12),
                         _buildLegendItem('Completed', Colors.green, 'Historical Data'),
                       ],
                     ),
                   ),
                 ),
               ),
             ),
             
             // Region Indicator
             Positioned(
               bottom: 16,
               left: 16,
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 decoration: BoxDecoration(
                   color: Colors.deepPurple.withOpacity(0.9),
                   borderRadius: BorderRadius.circular(20),
                   boxShadow: [
                     BoxShadow(color: Colors.deepPurple.withAlpha(75), blurRadius: 8, offset: const Offset(0, 4)),
                   ],
                 ),
                 child: Text(
                   'Viewing: $_supervisorRegion Activity',
                   style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                 ),
               ),
             ),
             
             // Mock Data Toggle
             Positioned(
               bottom: 16,
               right: 16,
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.end,
                 children: [
                   if (_showMockHeatmap)
                     Container(
                       margin: const EdgeInsets.only(bottom: 8),
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                       decoration: BoxDecoration(
                         color: Colors.orange.withOpacity(0.9),
                         borderRadius: BorderRadius.circular(12),
                       ),
                       child: const Text(
                         'Demo Data Active',
                         style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                       ),
                     ),
                   FloatingActionButton.extended(
                     onPressed: () {
                       setState(() {
                         _showMockHeatmap = !_showMockHeatmap;
                       });
                     },
                     backgroundColor: _showMockHeatmap ? Colors.orange : Colors.deepPurple,
                     icon: Icon(_showMockHeatmap ? Icons.visibility_off : Icons.visibility, color: Colors.white),
                     label: Text(
                       _showMockHeatmap ? 'Hide Demo' : 'Show Demo',
                       style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                     ),
                   ),
                 ],
               ),
             ),
           ],
         ),
       )
    );
  }

  Widget _buildLegendItem(String label, Color color, String sublabel) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
            Text(sublabel, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ],
    );
  }

  // Analytics View
  Widget _buildAnalyticsView() {
    if (_isAnalyticsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_analyticsData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No analytics data available', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadAnalytics, child: const Text('Reload Analytics')),
          ],
        ),
      );
    }

    final data = _analyticsData!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Cards
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
                  title: 'Completion Rate',
                  value: '${data.completionRate.toStringAsFixed(1)}%',
                  icon: Icons.check_circle,
                  color: Colors.green,
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
                  color: Colors.orange,
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
          
          // Charts Row 2
          Row(
            children: [
              Expanded(flex: 3, child: StatusDistributionChart(distribution: data.statusDistribution)),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: Container(
                  height: 300,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(20),
                    image: const DecorationImage(
                      image: NetworkImage('https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?q=80&w=2069&auto=format&fit=crop'),
                      fit: BoxFit.cover,
                      opacity: 0.15,
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Regional Efficiency',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Track and optimize driver distribution to improve ride matching speed.',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  List<Map<String, dynamic>> _getMockDrivers() {
    return [
      {
        'id': 'mock_1',
        'name': 'Rajesh Kumar',
        'email': 'rajesh.k@example.com',
        'district': 'Ernakulam',
        'isApproved': true,
      },
      {
        'id': 'mock_2',
        'name': 'Saritha Nair',
        'email': 'saritha.n@example.com',
        'district': 'Thrissur',
        'isApproved': false,
      },
      {
        'id': 'mock_3',
        'name': 'Gautham S.',
        'email': 'gautham.s@example.com',
        'district': 'Palakkad',
        'isApproved': false,
      },
      {
        'id': 'mock_4',
        'name': 'Meena P.',
        'email': 'meena.p@example.com',
        'district': 'Idukki',
        'isApproved': true,
      },
    ];
  }

  Future<void> _approveDriver(String driverId) async {
    try {
      await FirestoreService.updateDriverApprovalStatus(
        userId: driverId,
        isApproved: true,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver approved successfully')),
      );
      setState(() {}); // Refresh view
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving driver: $e')),
      );
    }
  }

  List<Map<String, dynamic>> _getMockDashboardActivity() {
    return [
      {
        'status': 'completed',
        'driverName': 'Suresh Kumar',
        'riderName': 'Anjali M.',
        'timeAgo': '15m ago',
      },
      {
        'status': 'ongoing',
        'driverName': 'Rahul R.',
        'riderName': 'Meera K.',
        'timeAgo': 'Just now',
      },
      {
        'status': 'accepted',
        'driverName': 'Vinod P.',
        'riderName': 'Arjun V.',
        'timeAgo': '2m ago',
      },
      {
        'status': 'request',
        'riderName': 'Priya S.',
        'timeAgo': '5m ago',
      },
    ];
  }

  void _addHeatmapCircles(List<CircleMarker> circles, ll.LatLng point, String status) {
    Color color;
    switch (status) {
      case 'completed':
        color = Colors.green;
        break;
      case 'accepted':
      case 'ongoing':
        color = Colors.blue;
        break;
      default:
        color = Colors.orange;
    }

    // Layered circles for heatmap effect
    circles.add(CircleMarker(
      point: point,
      radius: 1500,
      useRadiusInMeter: true,
      color: color.withOpacity(0.1),
    ));
    circles.add(CircleMarker(
      point: point,
      radius: 800,
      useRadiusInMeter: true,
      color: color.withOpacity(0.2),
    ));
    circles.add(CircleMarker(
      point: point,
      radius: 10,
      useRadiusInMeter: false,
      color: color,
      borderColor: Colors.white,
      borderStrokeWidth: 2,
    ));
  }

  void _addMockHeatmapData(List<CircleMarker> circles) {
    final center = LocationUtils.getRegionCenter(_supervisorRegion);
    final random = math.Random();
    
    // Add 15 mock points around the center
    for (int i = 0; i < 15; i++) {
      final latOffset = (random.nextDouble() - 0.5) * 0.15;
      final lngOffset = (random.nextDouble() - 0.5) * 0.15;
      final point = ll.LatLng(center.latitude + latOffset, center.longitude + lngOffset);
      
      final statuses = ['completed', 'ongoing', 'request'];
      final status = statuses[random.nextInt(statuses.length)];
      
      _addHeatmapCircles(circles, point, status);
    }
  }

  Widget _buildFraudMonitoringView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Suspicious Activities & Fraud Alerts',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('suspicious_activities')
                .orderBy('timestamp', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final activities = snapshot.data?.docs ?? [];
              if (activities.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user, size: 64, color: Colors.green[300]),
                      const SizedBox(height: 16),
                      const Text(
                        'No suspicious activities detected',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final data = activities[index].data() as Map<String, dynamic>;
                  final docId = activities[index].id;
                  final reason = data['reason'] ?? 'Unknown Reason';
                  final userId = data['userId'] ?? 'Unknown User';
                  final status = data['status'] ?? 'flagged';
                  final timestamp = data['timestamp'] as Timestamp?;
                  
                  final isBlocked = status == 'blocked';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: isBlocked ? Colors.red.shade100 : Colors.orange.shade100,
                        child: Icon(
                          isBlocked ? Icons.block : Icons.warning_amber_rounded,
                          color: isBlocked ? Colors.red : Colors.orange,
                        ),
                      ),
                      title: Text(
                        reason,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text('User ID: $userId'),
                          if (timestamp != null)
                            Text('Time: ${_formatTimeAgo(timestamp.toDate())}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isBlocked)
                            TextButton.icon(
                              onPressed: () => _blockUser(docId, userId),
                              icon: const Icon(Icons.block, color: Colors.red),
                              label: const Text('Block', style: TextStyle(color: Colors.red)),
                            ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _dismissAlert(docId),
                            icon: const Icon(Icons.check, color: Colors.green),
                            label: const Text('Dismiss', style: TextStyle(color: Colors.green)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _blockUser(String docId, String userId) async {
    try {
      await FirebaseFirestore.instance.collection('suspicious_activities').doc(docId).update({
        'status': 'blocked'
      });
      // Optionally update user document status here
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isBlocked': true
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User has been blocked successfully'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('Error blocking user: $e');
    }
  }

  Future<void> _dismissAlert(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('suspicious_activities').doc(docId).update({
        'status': 'dismissed'
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert dismissed'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print('Error dismissing alert: $e');
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }
}
