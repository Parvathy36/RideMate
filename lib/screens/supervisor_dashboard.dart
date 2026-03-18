import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
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
  ];

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
        ],
      ),
    );
  }

  Widget _buildSelectedContent() {
    switch (_selectedIndex) {
      case 0: return _buildDashboardView();
      case 1: return _buildDriversView();
      case 2: return _buildHeatmapsView();
      case 3: return _buildAnalyticsView();
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
              Expanded(child: _buildStatCard('Active Drivers', '12', Icons.directions_car, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Total Rides Today', '45', Icons.timeline, Colors.green)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Alerts', '2', Icons.warning, Colors.orange)),
            ],
          ),
          const SizedBox(height: 24),
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
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade50,
                  child: Icon(Icons.local_taxi, color: Colors.deepPurple.shade600),
                ),
                title: const Text('Ride Completed'),
                subtitle: const Text('Driver John Doe • 10 mins ago'),
                trailing: const Text('\$15.00', style: TextStyle(fontWeight: FontWeight.bold)),
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
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
           return Center(child: Text('Error loading drivers: ${snapshot.error}'));
        }

        final allDrivers = snapshot.data ?? [];
        // Optional: Filter by supervisor region if you add a 'region' field to drivers later. 
        // For now displaying all or simulating filtering.
        final regionalDrivers = allDrivers; 

        if (regionalDrivers.isEmpty) {
          return const Center(child: Text('No drivers found in this region.'));
        }

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
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: regionalDrivers.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final driver = regionalDrivers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Icon(Icons.person, color: Colors.blue.shade600),
                ),
                title: Text(driver['name'] ?? 'Unknown Driver'),
                subtitle: Text(driver['email'] ?? ''),
                trailing: Chip(
                   label: Text((driver['isApproved'] ?? false) ? 'Approved' : 'Pending'),
                   backgroundColor: (driver['isApproved'] ?? false) ? Colors.green.shade50 : Colors.orange.shade50,
                   labelStyle: TextStyle(
                     color: (driver['isApproved'] ?? false) ? Colors.green.shade700 : Colors.orange.shade700
                   ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Heatmaps View (Mock View)
  Widget _buildHeatmapsView() {
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
       child: Center(
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Icon(Icons.map, size: 80, color: Colors.grey[300]),
             const SizedBox(height: 16),
             Text('Demand Heatmap for $_supervisorRegion', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
             const SizedBox(height: 8),
             const Text('Visual representation of high rider demand areas will appear here.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
           ],
         ),
       )
    );
  }

  // Analytics View (Mock View)
  Widget _buildAnalyticsView() {
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
       child: Center(
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Icon(Icons.insert_chart, size: 80, color: Colors.grey[300]),
             const SizedBox(height: 16),
             Text('Analytics corresponding to $_supervisorRegion', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
             const SizedBox(height: 8),
             const Text('Detailed ride performance and revenue analytics charts will be displayed here.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
           ],
         ),
       )
    );
  }
}
