import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/admin_service.dart';
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
  List<Map<String, dynamic>> _filteredDrivers = [];
  bool _isLoadingDrivers = true;

  // System stats data
  int _totalUsers = 0;
  int _totalDrivers = 0;
  int _approvedDriversCount = 0;
  int _pendingDriversCount = 0;
  bool _isLoadingStats = true;

  // Police clearance data
  Map<String, Map<String, dynamic>> _policeClearanceData = {};

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, active, inactive, pending, approved

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
      final approvedDrivers = await FirestoreService.getActiveDrivers();

      // Get police clearance data for all drivers
      final licenseIds = allDrivers
          .map((driver) => driver['licenseId'] as String?)
          .where((licenseId) => licenseId != null && licenseId.isNotEmpty)
          .cast<String>()
          .toList();

      final policeClearanceData =
          await FirestoreService.getPoliceClearanceForDrivers(licenseIds);

      setState(() {
        _allDrivers = allDrivers;
        _pendingDrivers = pendingDrivers;
        _approvedDrivers = approvedDrivers;
        _filteredDrivers = allDrivers;
        _policeClearanceData = policeClearanceData;
        _isLoadingDrivers = false;
      });

      // Apply search filter if there's a query
      if (_searchQuery.isNotEmpty) {
        _filterDrivers(_searchQuery);
      }

      print('📊 Loaded ${allDrivers.length} total drivers');
      print('⏳ ${pendingDrivers.length} pending drivers');
      print('✅ ${approvedDrivers.length} approved drivers');
      print(
        '🚔 Loaded police clearance data for ${policeClearanceData.length} drivers',
      );
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
    _searchController.dispose();
    super.dispose();
  }

  void _filterDrivers(String query) {
    setState(() {
      _searchQuery = query;

      List<Map<String, dynamic>> filteredList = _allDrivers;

      // Apply text search filter
      if (query.isNotEmpty) {
        filteredList = filteredList.where((driver) {
          final name = (driver['name'] ?? '').toString().toLowerCase();
          final email = (driver['email'] ?? '').toString().toLowerCase();
          final phone = (driver['phoneNumber'] ?? '').toString().toLowerCase();
          final license = (driver['licenseId'] ?? '').toString().toLowerCase();
          final carNumber = (driver['carNumber'] ?? '')
              .toString()
              .toLowerCase();
          final searchLower = query.toLowerCase();

          return name.contains(searchLower) ||
              email.contains(searchLower) ||
              phone.contains(searchLower) ||
              license.contains(searchLower) ||
              carNumber.contains(searchLower);
        }).toList();
      }

      // Apply status filter
      if (_statusFilter != 'all') {
        filteredList = filteredList.where((driver) {
          switch (_statusFilter) {
            case 'pending':
              return !(driver['isApproved'] ?? false);
            case 'approved':
              return driver['isApproved'] ?? false;
            case 'active':
              return (driver['isApproved'] ?? false) &&
                  (driver['isActive'] ?? false);
            case 'inactive':
              return (driver['isApproved'] ?? false) &&
                  !(driver['isActive'] ?? false);
            default:
              return true;
          }
        }).toList();
      }

      _filteredDrivers = filteredList;
    });
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

  // Users content - shows all users (userType: 'user') from Firestore
  Widget _buildUsersContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: FirestoreService.getUsersByType('user'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading users: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return const Center(
            child: Text(
              'No users found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
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
                          colors: [
                            Colors.deepPurple,
                            Colors.deepPurple.shade700,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.people,
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
                            'Users',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${users.length} users, ${_allDrivers.length} drivers',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final name = (user['name'] ?? 'User').toString();
                    final email = (user['email'] ?? '').toString();
                    final phone = (user['phoneNumber'] ?? '').toString();
                    final createdAt = user['createdAt'];

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.deepPurple.shade100,
                            child: Icon(
                              Icons.person,
                              color: Colors.deepPurple.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.email,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        email,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (phone.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.phone,
                                        size: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        phone,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'user',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                              if (createdAt != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Joined',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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

          // Search Bar and Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterDrivers,
                      decoration: InputDecoration(
                        hintText:
                            'Search drivers by name, email, phone, license, or car number...',
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey.shade600,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  _filterDrivers('');
                                },
                                icon: Icon(
                                  Icons.clear,
                                  color: Colors.grey.shade600,
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusFilter,
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _statusFilter = newValue;
                          });
                          _filterDrivers(_searchQuery);
                        }
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All Status'),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'approved',
                          child: Text('Approved'),
                        ),
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value: 'inactive',
                          child: Text('Inactive'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Drivers List
          if (_isLoadingDrivers)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if ((_searchQuery.isNotEmpty || _statusFilter != 'all') &&
              _filteredDrivers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No drivers found matching "$_searchQuery"'
                          : 'No drivers found with status "${_statusFilter}"',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
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
    // If searching or filtering (but not "all"), show filtered results
    if (_searchQuery.isNotEmpty || _statusFilter != 'all') {
      String headerText = 'Filtered Results (${_filteredDrivers.length})';
      if (_searchQuery.isNotEmpty && _statusFilter != 'all') {
        headerText = 'Search & Filter Results (${_filteredDrivers.length})';
      } else if (_searchQuery.isNotEmpty) {
        headerText = 'Search Results (${_filteredDrivers.length})';
      } else {
        headerText =
            '${_statusFilter.toUpperCase()} Drivers (${_filteredDrivers.length})';
      }

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(
                  _searchQuery.isNotEmpty ? Icons.search : Icons.filter_list,
                  color: Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  headerText,
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
          ..._filteredDrivers.map(
            (driver) =>
                _buildDriverCard(driver, !(driver['isApproved'] ?? false)),
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    // Default view for "All Status" - show all drivers in a single list
    return Column(
      children: [
        // Header for all drivers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Icon(Icons.people, color: Colors.deepPurple, size: 20),
              const SizedBox(width: 8),
              Text(
                'All Drivers (${_allDrivers.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              // Show breakdown
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_pendingDrivers.length} Pending • ${_approvedDrivers.length} Approved',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Show all drivers in a single list (pending first, then approved)
        ...(_allDrivers..sort((a, b) {
              // Sort by approval status first (pending first), then by registration date
              final aApproved = a['isApproved'] ?? false;
              final bApproved = b['isApproved'] ?? false;

              if (aApproved != bApproved) {
                return aApproved ? 1 : -1; // Pending (false) comes first
              }

              // If same approval status, sort by registration date (newest first)
              final aDate = a['registrationDate'];
              final bDate = b['registrationDate'];

              if (aDate != null && bDate != null) {
                return bDate.compareTo(aDate);
              }

              return 0;
            }))
            .map(
              (driver) =>
                  _buildDriverCard(driver, !(driver['isApproved'] ?? false)),
            ),

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
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        FirestoreService.getUsersByType('user'),
        FirestoreService.getActiveDrivers(),
        FirestoreService.getPendingDrivers(),
      ]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data?[0] as List<Map<String, dynamic>>? ?? [];
        final approvedDrivers =
            snapshot.data?[1] as List<Map<String, dynamic>>? ?? [];
        final pendingDrivers =
            snapshot.data?[2] as List<Map<String, dynamic>>? ?? [];

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Users',
                '${users.length}',
                Icons.people,
                Colors.deepPurple,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Active Drivers',
                '${approvedDrivers.length}',
                Icons.local_taxi,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Pending Approvals',
                '${pendingDrivers.length}',
                Icons.pending,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Total Rides',
                '0',
                Icons.directions_car,
                Colors.deepPurple.shade400,
              ),
            ),
          ],
        );
      },
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (driver['isActive'] ?? false)
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        (driver['isActive'] ?? false) ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: (driver['isActive'] ?? false)
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (driver['isOnline'] ?? false)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Online',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    // Police clearance badge
                    _buildPoliceClearanceBadge(driver['licenseId']),
                  ],
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
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_policeClearanceData[driver['licenseId']]?['police_clearance'] ==
                      true) ...[
                    if (!(driver['isApproved'] ?? false)) ...[
                      IconButton(
                        onPressed: () => _approveDriver(driver['id']),
                        icon: const Icon(
                          Icons.check,
                          color: Colors.green,
                          size: 20,
                        ),
                        tooltip: 'Approve',
                      ),
                    ],
                    if ((driver['isApproved'] ?? false) &&
                        _driverHasAnyImage(driver))
                      IconButton(
                        onPressed: () => _showDriverImages(driver),
                        icon: const Icon(
                          Icons.image_outlined,
                          color: Colors.purple,
                          size: 20,
                        ),
                        tooltip: 'View Images',
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
                    IconButton(
                      onPressed: () => _showDriverDetails(driver),
                      icon: const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                      tooltip: 'View Details',
                    ),
                  ] else if (_policeClearanceData[driver['licenseId']]?['police_clearance'] ==
                      false) ...[
                    IconButton(
                      onPressed: () => _rejectDriver(driver['id']),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 20,
                      ),
                      tooltip: 'Reject',
                    ),
                    if ((driver['isApproved'] ?? false) &&
                        _driverHasAnyImage(driver))
                      IconButton(
                        onPressed: () => _showDriverImages(driver),
                        icon: const Icon(
                          Icons.image_outlined,
                          color: Colors.purple,
                          size: 20,
                        ),
                        tooltip: 'View Images',
                      ),
                    IconButton(
                      onPressed: () => _showDriverDetails(driver),
                      icon: const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                      tooltip: 'View Details',
                    ),
                  ],
                ],
              ),
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
    // Show rejection message dialog
    final String? rejectionMessage = await _showRejectionMessageDialog();
    
    if (rejectionMessage == null) {
      // User cancelled the dialog
      return;
    }

    try {
      await FirestoreService.updateDriverApprovalStatus(
        userId: driverId,
        isApproved: false,
        adminNotes: rejectionMessage,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Driver rejected: $rejectionMessage'),
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

  Future<String?> _showRejectionMessageDialog() async {
    final TextEditingController messageController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade600),
              const SizedBox(width: 8),
              const Text('Reject Driver'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please provide a reason for rejecting this driver:',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter rejection reason...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.red.shade300),
                  ),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final message = messageController.text.trim();
                if (message.isNotEmpty) {
                  Navigator.of(context).pop(message);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a rejection reason'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleDriverStatus(String driverId, bool currentStatus) async {
    try {
      // Show confirmation dialog
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(currentStatus ? 'Disable Driver' : 'Enable Driver'),
            content: Text(
              currentStatus
                  ? 'Are you sure you want to disable this driver? They will not be able to accept rides.'
                  : 'Are you sure you want to enable this driver? They will be able to accept rides.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: currentStatus ? Colors.red : Colors.green,
                ),
                child: Text(currentStatus ? 'Disable' : 'Enable'),
              ),
            ],
          );
        },
      );

      if (confirm == true) {
        await FirestoreService.updateDriverStatus(
          userId: driverId,
          isActive: !currentStatus,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                currentStatus
                    ? 'Driver disabled successfully!'
                    : 'Driver enabled successfully!',
              ),
              backgroundColor: currentStatus ? Colors.orange : Colors.green,
            ),
          );
        }

        _loadDriverData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating driver status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDriverDetails(Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.deepPurple.shade100,
                child: Text(
                  (driver['name'] ?? 'N/A')
                      .toString()
                      .substring(0, 1)
                      .toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  driver['name'] ?? 'Unknown Driver',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Email', driver['email'] ?? 'N/A'),
                _buildDetailRow('Phone', driver['phoneNumber'] ?? 'N/A'),
                _buildDetailRow('License ID', driver['licenseId'] ?? 'N/A'),
                _buildDetailRow(
                  'License Holder',
                  driver['licenseHolderName'] ?? 'N/A',
                ),
                _buildDetailRow('State', driver['licenseState'] ?? 'N/A'),
                _buildDetailRow('District', driver['licenseDistrict'] ?? 'N/A'),
                _buildDetailRow(
                  'Vehicle Class',
                  driver['vehicleClass'] ?? 'N/A',
                ),
                _buildDetailRow('Car Model', driver['carModel'] ?? 'N/A'),
                _buildDetailRow('Car Number', driver['carNumber'] ?? 'N/A'),
                _buildDetailRow(
                  'Status',
                  (driver['isActive'] ?? false) ? 'Active' : 'Inactive',
                ),
                _buildDetailRow(
                  'Approved',
                  (driver['isApproved'] ?? false) ? 'Yes' : 'No',
                ),
                _buildDetailRow(
                  'Online',
                  (driver['isOnline'] ?? false) ? 'Yes' : 'No',
                ),
                _buildDetailRow(
                  'Available',
                  (driver['isAvailable'] ?? false) ? 'Yes' : 'No',
                ),
                _buildDetailRow('Rating', '${driver['rating'] ?? 0.0}'),
                _buildDetailRow('Total Rides', '${driver['totalRides'] ?? 0}'),
                _buildDetailRow(
                  'Total Earnings',
                  '₹${driver['totalEarnings'] ?? 0.0}',
                ),
                // Show rejection message if driver was rejected
                if (!(driver['isApproved'] ?? false) && driver['rejectionMessage'] != null) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red.shade600, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'Rejection Reason',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          driver['rejectionMessage'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                // Police clearance section
                _buildPoliceClearanceSection(driver['licenseId']),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            if (driver['isApproved'] == true)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _toggleDriverStatus(
                    driver['id'],
                    driver['isActive'] ?? false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: (driver['isActive'] ?? false)
                      ? Colors.red
                      : Colors.green,
                ),
                child: Text(
                  (driver['isActive'] ?? false) ? 'Disable' : 'Enable',
                ),
              ),
          ],
        );
      },
    );
  }

  bool _driverHasAnyImage(Map<String, dynamic> driver) {
    final String profile = (driver['profileImageUrl'] ?? '').toString();
    final String license = (driver['licenseImageUrl'] ?? '').toString();
    return profile.isNotEmpty || license.isNotEmpty;
  }

  void _showDriverImages(Map<String, dynamic> driver) {
    final String profileUrl = (driver['profileImageUrl'] ?? '').toString();
    final String licenseUrl = (driver['licenseImageUrl'] ?? '').toString();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.image_outlined, color: Colors.purple),
              const SizedBox(width: 8),
              const Text('Driver Images'),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile Image',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: profileUrl.isNotEmpty
                        ? InteractiveViewer(
                            child: Image.network(
                              profileUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('Failed to load profile image'),
                              ),
                            ),
                          )
                        : const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No profile image uploaded'),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'License Image',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: licenseUrl.isNotEmpty
                        ? InteractiveViewer(
                            child: Image.network(
                              licenseUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('Failed to load license image'),
                              ),
                            ),
                          )
                        : const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No license image uploaded'),
                          ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // Build police clearance section for driver details
  Widget _buildPoliceClearanceSection(String? licenseId) {
    if (licenseId == null || licenseId.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: Colors.grey.shade600, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Police Clearance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange.shade600, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'No license ID available for verification',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final clearanceData = _policeClearanceData[licenseId];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.security, color: Colors.deepPurple.shade600, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Police Clearance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (clearanceData == null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.orange.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'No police clearance record found for this license',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: clearanceData['police_clearance'] == true
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: clearanceData['police_clearance'] == true
                    ? Colors.green.shade200
                    : Colors.red.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      clearanceData['police_clearance'] == true
                          ? Icons.verified
                          : Icons.warning,
                      color: clearanceData['police_clearance'] == true
                          ? Colors.green.shade600
                          : Colors.red.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      clearanceData['police_clearance'] == true
                          ? 'Verification Successful'
                          : 'Verification Failed',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: clearanceData['police_clearance'] == true
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Status',
                  clearanceData['police_clearance'] == true
                      ? 'Clear'
                      : 'Issues Found',
                ),
                _buildDetailRow(
                  'Clearance Date',
                  clearanceData['clearance_date'] ?? 'N/A',
                ),
                _buildDetailRow(
                  'Issuing Authority',
                  clearanceData['issuing_authority'] ?? 'N/A',
                ),
                _buildDetailRow(
                  'Valid Status',
                  clearanceData['valid'] == true ? 'Valid' : 'Invalid',
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Build police clearance badge
  Widget _buildPoliceClearanceBadge(String? licenseId) {
    if (licenseId == null || licenseId.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'No License',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
      );
    }

    final clearanceData = _policeClearanceData[licenseId];

    if (clearanceData == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'No Police Check',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.orange.shade700,
          ),
        ),
      );
    }

    final isPoliceClearanceValid = clearanceData['police_clearance'] == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isPoliceClearanceValid
            ? Colors.green.shade100
            : Colors.red.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPoliceClearanceValid ? Icons.verified : Icons.warning,
            size: 12,
            color: isPoliceClearanceValid
                ? Colors.green.shade700
                : Colors.red.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            isPoliceClearanceValid ? 'Police Clear' : 'Police Issue',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isPoliceClearanceValid
                  ? Colors.green.shade700
                  : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
