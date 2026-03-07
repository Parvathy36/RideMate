import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../services/chatbot_service.dart';
import '../models/conversation.dart';
import '../models/support_ticket.dart';
import '../models/chat_enums.dart';
import '../services/auth_service.dart';
import '../login_page.dart';
import '../widgets/responsive_layout.dart';
import 'chatbot_analytics_dashboard.dart';

/// Support dashboard for handling escalated conversations
class SupportDashboard extends StatefulWidget {
  const SupportDashboard({super.key});

  @override
  State<SupportDashboard> createState() => _SupportDashboardState();
}

class _SupportDashboardState extends State<SupportDashboard> {
  String _ticketFilter = 'all';
  String _priorityFilter = 'all';
  String _searchQuery = '';
  bool _isLoading = true;
  List<SupportTicket> _tickets = [];
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  int _selectedSidebarIndex = 0; // 0 for Overview/Tickets, 1 for Analytics

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all tickets to avoid requiring composite indexes in Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('support_tickets')
          .get();
      
      final tickets = snapshot.docs
          .map((doc) => SupportTicket.fromFirestore(doc))
          .toList();

      if (mounted) {
        setState(() {
          _tickets = tickets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Error loading tickets: ${e.toString()}');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.greenAccent[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  List<SupportTicket> get _filteredTickets {
    // 1. Apply Status/Priority filters
    List<SupportTicket> filtered = _tickets.where((ticket) {
      final statusMatch = _ticketFilter == 'all' || 
          ticket.status.toString().split('.').last == _ticketFilter;
      final priorityMatch = _priorityFilter == 'all' || 
          ticket.priority.toString().split('.').last == _priorityFilter;
      return statusMatch && priorityMatch;
    }).toList();

    // 2. Apply Search Query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((ticket) {
        return ticket.subject.toLowerCase().contains(query) ||
            ticket.description.toLowerCase().contains(query) ||
            (ticket.userName?.toLowerCase().contains(query) ?? false) ||
            (ticket.userEmail?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // 3. Apply Sorting (Newest first)
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return filtered;
  }

  Future<void> _updateTicketStatus(
    SupportTicket ticket,
    TicketStatus newStatus,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('support_tickets')
          .doc(ticket.id)
          .update({
            'status': newStatus.toString().split('.').last,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Update conversation status as well
      await FirebaseFirestore.instance
          .collection('chatbot_conversations')
          .doc(ticket.conversationId)
          .update({
            'status': newStatus == TicketStatus.resolved
                ? 'resolved'
                : 'escalated',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Add activity log
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final activity = TicketActivity(
          id: const Uuid().v4(),
          action: 'status_updated',
          performedBy: user.uid,
          performedByName: user.displayName,
          timestamp: DateTime.now(),
          details: {
            'previousStatus': ticket.status.toString().split('.').last,
            'newStatus': newStatus.toString().split('.').last,
          },
        );

        await FirebaseFirestore.instance
            .collection('support_tickets')
            .doc(ticket.id)
            .collection('activities')
            .doc(activity.id)
            .set(activity.toJson());
      }

      await _loadTickets(); // Reload tickets
      _showSuccessSnackBar('Ticket status updated to ${newStatus.toString().split('.').last}');
    } catch (e) {
      _showErrorSnackBar('Error updating ticket: ${e.toString()}');
    }
  }

  Future<void> _assignTicket(SupportTicket ticket) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('support_tickets')
          .doc(ticket.id)
          .update({
            'assignedTo': user.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      await _loadTickets(); // Reload tickets
      _showSuccessSnackBar('Ticket successfully assigned to you');
    } catch (e) {
      _showErrorSnackBar('Error assigning ticket: ${e.toString()}');
    }
  }

  Future<void> _handleLogout() async {
    bool confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      drawer: ResponsiveLayout.isMobile(context) ? _buildSidebar() : null,
      body: ResponsiveLayout(
        mobile: _buildMainContent(),
        desktop: Row(
          children: [
            _buildSidebar(),
            Expanded(
              child: _selectedSidebarIndex == 0
                  ? _buildMainContent()
                  : const ChatbotAnalyticsDashboard(isEmbedded: true),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.deepPurple,
      title: const Text(
        'Support Dashboard',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
      ),
      actions: [
        IconButton(
          onPressed: _loadTickets,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh Data',
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          backgroundColor: Colors.deepPurple[50],
          child: IconButton(
            icon: const Icon(Icons.person, color: Colors.deepPurple),
            onPressed: _showProfileDialog, // Call profile dialog
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildSidebar() {
    return Drawer(
      child: Column(
        children: [
          _buildSidebarHeader(),
          _buildSidebarItem(Icons.dashboard, 'Overview', _selectedSidebarIndex == 0, 0),
          _buildSidebarItem(Icons.analytics, 'Analytics', _selectedSidebarIndex == 1, 1),
          const Spacer(),
          const Divider(),
          _buildSidebarItem(Icons.settings, 'Settings', false, 2),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: _handleLogout,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.support_agent, size: 48, color: Colors.deepPurple),
          const SizedBox(height: 16),
          const Text(
            'RideMate Support',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            FirebaseAuth.instance.currentUser?.email ?? 'Agent',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, bool isSelected, int index) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.deepPurple : Colors.grey),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.deepPurple : Colors.grey[800],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      tileColor: isSelected ? Colors.deepPurple[50] : null,
      onTap: () {
        setState(() {
          _selectedSidebarIndex = index;
        });
        if (ResponsiveLayout.isMobile(context)) {
          Navigator.pop(context);
        }
      },
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        _buildStatsSection(),
        _buildFilterBar(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredTickets.isEmpty
                  ? _buildEmptyState()
                  : _buildTicketsList(),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    final openCount = _tickets.where((t) => t.status == TicketStatus.open).length;
    final inProgressCount = _tickets.where((t) => t.status == TicketStatus.inProgress).length;
    final resolvedCount = _tickets.where((t) => t.status == TicketStatus.resolved).length;
    final urgentCount = _tickets.where((t) => t.priority == TicketPriority.urgent).length;

    return Container(
      padding: const EdgeInsets.all(24),
      child: ResponsiveLayout(
        mobile: Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildStatCard('Open', openCount, Colors.orange, Icons.mail_outline)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Active', inProgressCount, Colors.blue, Icons.sync)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStatCard('Urgent', urgentCount, Colors.red, Icons.warning_amber)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Done', resolvedCount, Colors.green, Icons.check_circle_outline)),
              ],
            ),
          ],
        ),
        desktop: Row(
          children: [
            Expanded(child: _buildStatCard('Open Tickets', openCount, Colors.orange, Icons.mail_outline)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard('In Progress', inProgressCount, Colors.blue, Icons.sync)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard('Urgent', urgentCount, Colors.red, Icons.warning_amber)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard('Resolved', resolvedCount, Colors.green, Icons.check_circle_outline)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                count.toString(),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tickets...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(width: 16),
          _buildDropdownFilter(
            value: _ticketFilter,
            items: ['all', 'open', 'inProgress', 'resolved', 'closed'],
            onChanged: (value) {
              if (value != null) {
                setState(() => _ticketFilter = value);
                _loadTickets();
              }
            },
          ),
          const SizedBox(width: 8),
          _buildDropdownFilter(
            value: _priorityFilter,
            items: ['all', 'low', 'medium', 'high', 'urgent'],
            onChanged: (value) {
              if (value != null) {
                setState(() => _priorityFilter = value);
                _loadTickets();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        items: items.map((i) => DropdownMenuItem(
          value: i,
          child: Text(
            i[0].toUpperCase() + i.substring(1),
            style: const TextStyle(fontSize: 14),
          ),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No tickets found',
            style: TextStyle(color: Colors.grey[600], fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _filteredTickets.length,
      itemBuilder: (context, index) => _buildTicketCard(_filteredTickets[index]),
    );
  }

  Widget _buildTicketCard(SupportTicket ticket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(16),
          leading: _buildCategoryIcon(ticket.category),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  ticket.subject,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              _buildPriorityBadge(ticket.priority),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                _buildStatusChip(ticket.status),
                const SizedBox(width: 8),
                Text(
                  'ID: #${ticket.id.substring(0, 6)}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatRelativeDate(ticket.createdAt),
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Full Description',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ticket.description,
                    style: TextStyle(color: Colors.grey[800], height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.deepPurple[100],
                        child: Text(
                          (ticket.userName?[0] ?? ticket.userEmail?[0] ?? 'U').toUpperCase(),
                          style: const TextStyle(color: Colors.deepPurple, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket.userName ?? 'Anonymous User',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            ticket.userEmail ?? 'No email provided',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _buildActionButtons(ticket),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(ConversationCategory category) {
    IconData icon;
    Color color;

    switch (category) {
      case ConversationCategory.booking:
        icon = Icons.directions_car;
        color = Colors.blue;
        break;
      case ConversationCategory.payment:
        icon = Icons.payments;
        color = Colors.green;
        break;
      case ConversationCategory.complaint:
        icon = Icons.report_problem;
        color = Colors.orange;
        break;
      case ConversationCategory.account:
        icon = Icons.manage_accounts;
        color = Colors.purple;
        break;
      case ConversationCategory.technical:
        icon = Icons.settings_applications;
        color = Colors.red;
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildPriorityBadge(TicketPriority priority) {
    Color color;
    switch (priority) {
      case TicketPriority.urgent:
        color = Colors.red;
        break;
      case TicketPriority.high:
        color = Colors.orange;
        break;
      case TicketPriority.medium:
        color = Colors.blue;
        break;
      case TicketPriority.low:
        color = Colors.green;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        priority.toString().split('.').last.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatusChip(TicketStatus status) {
    Color color;
    switch (status) {
      case TicketStatus.open:
        color = Colors.orange;
        break;
      case TicketStatus.inProgress:
        color = Colors.blue;
        break;
      case TicketStatus.resolved:
        color = Colors.green;
        break;
      case TicketStatus.closed:
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toString().split('.').last,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActionButtons(SupportTicket ticket) {
    return Row(
      children: [
        if (ticket.assignedTo == null)
          OutlinedButton(
            onPressed: () => _assignTicket(ticket),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.deepPurple,
              side: const BorderSide(color: Colors.deepPurple),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ).copyWith(
                    overlayColor: WidgetStateProperty.all(Colors.deepPurple[100])
                  ),
            child: const Text('Assign to Me'),
          ),
        const SizedBox(width: 8),
        _buildStatusMenu(ticket),
      ],
    );
  }

  Widget _buildStatusMenu(SupportTicket ticket) {
    return PopupMenuButton<TicketStatus>(
      onSelected: (status) => _updateTicketStatus(ticket, status),
      itemBuilder: (context) => TicketStatus.values.map((status) => PopupMenuItem(
        value: status,
        child: Text(status.toString().split('.').last),
      )).toList(),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.more_horiz, color: Colors.grey),
      ),
    );
  }

  String _formatRelativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Future<void> _showProfileDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
    String name = userData?['name'] ?? user.displayName ?? 'Unknown';
    String email = userData?['email'] ?? user.email ?? 'No email';
    String role = userData?['userType'] ?? 'Support Team';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_outline, color: Colors.deepPurple),
            SizedBox(width: 12),
            Text('Agent Profile'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProfileRow('Name', name),
            const Divider(),
            _buildProfileRow('Email', email),
            const Divider(),
            _buildProfileRow('Role', role.toUpperCase()),
            const Divider(),
            _buildProfileRow('Last Login', _formatDateTime(user.metadata.lastSignInTime ?? DateTime.now())),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

