import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'login_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Driver data
  List<Map<String, dynamic>> _allDrivers = [];
  List<Map<String, dynamic>> _pendingDrivers = [];
  List<Map<String, dynamic>> _approvedDrivers = [];
  bool _isLoadingDrivers = true;

  // Sidebar navigation
  int _selectedIndex = 0;
  final List<String> _menuItems = [
    'Dashboard',
    'Users',
    'Drivers',
    'Rides',
    'Analytics',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
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

    // Load driver data
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    try {
      setState(() {
        _isLoadingDrivers = true;
      });

      // Get all drivers from Firestore
      final allDrivers = await FirestoreService.getAllDrivers();
      final pendingDrivers = await FirestoreService.getPendingDrivers();
      final approvedDrivers = await FirestoreService.getApprovedDrivers();

      setState(() {
        _allDrivers = allDrivers;
        _pendingDrivers = pendingDrivers;
        _approvedDrivers = approvedDrivers;
        _isLoadingDrivers = false;
      });

      print('📊 Loaded ${allDrivers.length} total drivers');
      print('⏳ ${pendingDrivers.length} pending drivers');
      print('✅ ${approvedDrivers.length} approved drivers');
    } catch (e) {
      print('❌ Error loading driver data: $e');
      setState(() {
        _isLoadingDrivers = false;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
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

  // Build modern sidebar
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
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.3),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 35,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _authService.currentUser?.email?.split('@')[0] ?? 'Admin',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
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

  // Get icon for menu items
  IconData _getMenuIcon(int index) {
    switch (index) {
      case 0:
        return Icons.dashboard;
      case 1:
        return Icons.people;
      case 2:
        return Icons.local_taxi;
      case 3:
        return Icons.directions_car;
      case 4:
        return Icons.analytics;
      case 5:
        return Icons.settings;
      default:
        return Icons.circle;
    }
  }

  // Build sidebar item
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

  // Build main content based on selected menu
  Widget _buildMainContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildContentHeader(),
          const SizedBox(height: 24),
          // Content based on selection
          Expanded(child: _buildSelectedContent()),
        ],
      ),
    );
  }

  // Build content header
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
                _getContentDescription(_selectedIndex),
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Get content description
  String _getContentDescription(int index) {
    switch (index) {
      case 0:
        return 'Overview of your application';
      case 1:
        return 'Manage application users';
      case 2:
        return 'Manage drivers and approvals';
      case 3:
        return 'View and manage rides';
      case 4:
        return 'Application analytics and reports';
      case 5:
        return 'Application settings';
      default:
        return '';
    }
  }

  // Build content based on selected menu
  Widget _buildSelectedContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return _buildUsersContent();
      case 2:
        return _buildDriversContent();
      case 3:
        return _buildRidesContent();
      case 4:
        return _buildAnalyticsContent();
      case 5:
        return _buildSettingsContent();
      default:
        return _buildDashboardContent();
    }
  }

  // Dashboard content
  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStatsCards(),
          const SizedBox(height: 24),
          _buildRecentActivity(),
        ],
      ),
    );
  }

  // Users content
  Widget _buildUsersContent() {
    return const Center(
      child: Text(
        'Users Management\nComing Soon...',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }

  // Drivers content (existing driver management)
  Widget _buildDriversContent() {
    return SingleChildScrollView(child: _buildDriversSection());
  }

  // Build drivers section
  Widget _buildDriversSection() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
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
                  child: const Icon(
                    Icons.local_taxi,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Driver Management',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isLoadingDrivers
                            ? 'Loading drivers...'
                            : '${_allDrivers.length} total drivers • ${_pendingDrivers.length} pending approval',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    onPressed: _loadDriverData,
                    icon: Icon(
                      Icons.refresh,
                      color: Colors.grey.shade600,
                      size: 24,
                    ),
                    tooltip: 'Refresh Data',
                  ),
                ),
              ],
            ),
          ),

          // Driver Stats
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: _buildSimpleStatCard(
                    'Total',
                    '${_allDrivers.length}',
                    Colors.deepPurple,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSimpleStatCard(
                    'Pending',
                    '${_pendingDrivers.length}',
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSimpleStatCard(
                    'Approved',
                    '${_approvedDrivers.length}',
                    Colors.green,
                  ),
                ),
              ],
            ),
          ),

          // Drivers List
          if (_isLoadingDrivers)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_allDrivers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.no_accounts, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No drivers found',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            _buildDriversList(),
        ],
      ),
    );
  }

  // Build drivers list
  Widget _buildDriversList() {
    return Column(
      children: [
        // Show pending drivers first
        if (_pendingDrivers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.pending, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Pending Approval (${_pendingDrivers.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ..._pendingDrivers
              .take(5)
              .map((driver) => _buildDriverCard(driver, true)),
        ],

        // Show approved drivers
        if (_approvedDrivers.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.verified, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Approved Drivers (${_approvedDrivers.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ..._approvedDrivers
              .take(5)
              .map((driver) => _buildDriverCard(driver, false)),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  // Rides content
  Widget _buildRidesContent() {
    return const Center(
      child: Text(
        'Rides Management\nComing Soon...',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }

  // Analytics content
  Widget _buildAnalyticsContent() {
    return const Center(
      child: Text(
        'Analytics & Reports\nComing Soon...',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }

  // Settings content
  Widget _buildSettingsContent() {
    return const Center(
      child: Text(
        'Application Settings\nComing Soon...',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }

  // Build stats cards for dashboard
  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Users',
            '1,234',
            Icons.people,
            Colors.deepPurple,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Active Drivers',
            '${_approvedDrivers.length}',
            Icons.local_taxi,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Pending Approvals',
            '${_pendingDrivers.length}',
            Icons.pending,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total Rides',
            '5,678',
            Icons.directions_car,
            Colors.deepPurple.shade400,
          ),
        ),
      ],
    );
  }

  // Build individual stat card
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Icon(Icons.trending_up, color: Colors.green, size: 16),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // Build recent activity
  Widget _buildRecentActivity() {
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
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(5, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.deepPurple.shade100,
                    child: Icon(
                      Icons.person,
                      color: Colors.deepPurple.shade600,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User action ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${index + 1} minutes ago',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Build simple stat card
  Widget _buildSimpleStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Build driver card
  Widget _buildDriverCard(Map<String, dynamic> driver, bool isPending) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending ? Colors.orange.shade300 : Colors.green.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isPending
                ? Colors.orange.shade100
                : Colors.green.shade100,
            child: Text(
              (driver['name'] ?? 'N/A')
                  .toString()
                  .substring(0, 1)
                  .toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isPending
                    ? Colors.orange.shade700
                    : Colors.green.shade700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver['name'] ?? 'Unknown Driver',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  driver['email'] ?? 'No email',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  'Phone: ${driver['phoneNumber'] ?? 'N/A'} • License: ${driver['licenseId'] ?? 'N/A'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isPending ? Colors.orange : Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPending ? 'Pending' : 'Approved',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isPending) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _approveDriver(driver['id']),
                      icon: const Icon(
                        Icons.check,
                        color: Colors.green,
                        size: 20,
                      ),
                      tooltip: 'Approve',
                    ),
                    IconButton(
                      onPressed: () => _rejectDriver(driver['id']),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 20,
                      ),
                      tooltip: 'Reject',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approveDriver(String driverId) async {
    try {
      await FirestoreService.updateDriverApprovalStatus(
        userId: driverId,
        isApproved: true,
        adminNotes: 'Approved by admin',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Driver approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadDriverData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving driver: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectDriver(String driverId) async {
    try {
      await FirestoreService.updateDriverApprovalStatus(
        userId: driverId,
        isApproved: false,
        adminNotes: 'Rejected by admin',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Driver rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      _loadDriverData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting driver: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
