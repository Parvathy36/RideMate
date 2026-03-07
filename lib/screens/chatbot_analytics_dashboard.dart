import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/chatbot_service.dart';
import '../models/conversation.dart';
import '../models/chat_enums.dart';

/// Admin dashboard for chatbot analytics
class ChatbotAnalyticsDashboard extends StatefulWidget {
  final bool isEmbedded;
  const ChatbotAnalyticsDashboard({super.key, this.isEmbedded = false});

  @override
  State<ChatbotAnalyticsDashboard> createState() =>
      _ChatbotAnalyticsDashboardState();
}

class _ChatbotAnalyticsDashboardState extends State<ChatbotAnalyticsDashboard> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  ChatbotAnalytics? _analytics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final analytics = await ChatbotService.getAnalytics(
        startDate: _startDate,
        endDate: _endDate,
      );

      if (mounted) {
        setState(() {
          _analytics = analytics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading analytics: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
    final start = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (start != null) {
      final end = await showDatePicker(
        context: context,
        initialDate: _endDate,
        firstDate: start,
        lastDate: DateTime.now(),
      );

      if (end != null) {
        setState(() {
          _startDate = start;
          _endDate = end;
        });
        _loadAnalytics();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _analytics == null
            ? const Center(child: Text('No analytics data available'))
            : _buildAnalyticsContent();

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatbot Analytics'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadAnalytics,
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildAnalyticsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date range selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Period: ${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Change Period'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Summary cards
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - (widget.isEmbedded ? 48 : 32)) / (constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1));
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildSummaryCard(
                    title: 'Total Conversations',
                    value: _analytics!.totalConversations.toString(),
                    icon: Icons.chat_outlined,
                    color: Colors.blue,
                    width: cardWidth,
                  ),
                  _buildSummaryCard(
                    title: 'Resolved',
                    value: _analytics!.resolvedConversations.toString(),
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                    width: cardWidth,
                  ),
                  _buildSummaryCard(
                    title: 'Escalated',
                    value: _analytics!.escalatedConversations.toString(),
                    icon: Icons.warning_amber_rounded,
                    color: Colors.orange,
                    width: cardWidth,
                  ),
                  _buildSummaryCard(
                    title: 'Escalation Rate',
                    value: '${(_analytics!.escalationRate * 100).toStringAsFixed(1)}%',
                    icon: Icons.trending_up,
                    color: Colors.purple,
                    width: cardWidth,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Category distribution chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Conversations by Category',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildCategoryChart(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Top intents
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Common Issues Analytics',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildTopIntentsList(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Recent conversations
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Conversations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildRecentConversationsList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
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
        mainAxisSize: MainAxisSize.min,
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
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChart() {
    return Column(
      children: _analytics!.categoryDistribution.entries.map((entry) {
        final percentage = _analytics!.totalConversations > 0
            ? (entry.value / _analytics!.totalConversations * 100)
            : 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  _getCategoryDisplayName(entry.key),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                flex: 2,
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getCategoryColor(entry.key),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${percentage.toStringAsFixed(1)}%'),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopIntentsList() {
    final intentCounts = _analytics!.intentCounts;
    
    if (intentCounts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No intent data for this period'),
        ),
      );
    }

    final sortedIntents = intentCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sortedIntents.take(10).map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  _formatIntentName(entry.key),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                child: Text(
                  entry.value.toString(),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentConversationsList() {
    return SizedBox(
      height: 200,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chatbot_conversations')
            .orderBy('updatedAt', descending: true)
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final conversations = snapshot.data!.docs;

          if (conversations.isEmpty) {
            return const Center(child: Text('No recent conversations'));
          }

          return ListView.builder(
            shrinkWrap: true,
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final data = conversations[index].data() as Map<String, dynamic>;
              final conversation = Conversation(
                id: conversations[index].id,
                userId: data['userId'] ?? '',
                userEmail: data['userEmail'],
                userName: data['userName'],
                status: ConversationStatus.fromString(
                  data['status'] ?? 'active',
                ),
                category: ConversationCategory.fromString(
                  data['category'] ?? 'general',
                ),
                createdAt: (data['createdAt'] as Timestamp).toDate(),
                updatedAt: (data['updatedAt'] as Timestamp).toDate(),
                lastMessage: data['lastMessage'],
              );

              return ListTile(
                title: Text(conversation.displayName),
                subtitle: Text(
                  conversation.lastMessage ?? 'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Chip(
                  label: Text(conversation.category.toString().split('.').last),
                  backgroundColor: _getCategoryColor(conversation.category),
                ),
                onTap: () {
                  // TODO: Navigate to conversation details
                },
              );
            },
          );
        },
      ),
    );
  }

  String _getCategoryDisplayName(ConversationCategory category) {
    switch (category) {
      case ConversationCategory.booking:
        return 'Booking';
      case ConversationCategory.payment:
        return 'Payment';
      case ConversationCategory.complaint:
        return 'Complaint';
      case ConversationCategory.account:
        return 'Account';
      case ConversationCategory.technical:
        return 'Technical';
      case ConversationCategory.general:
        return 'General';
    }
  }

  Color _getCategoryColor(ConversationCategory category) {
    switch (category) {
      case ConversationCategory.booking:
        return Colors.blue;
      case ConversationCategory.payment:
        return Colors.green;
      case ConversationCategory.complaint:
        return Colors.orange;
      case ConversationCategory.account:
        return Colors.purple;
      case ConversationCategory.technical:
        return Colors.red;
      case ConversationCategory.general:
        return Colors.grey;
    }
  }

  String _formatIntentName(String intent) {
    return intent
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
