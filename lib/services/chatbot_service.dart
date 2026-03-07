import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/support_ticket.dart';
import '../models/chat_enums.dart';
import '../utils/nlp_processor.dart';
import '../services/firestore_service.dart';
import '../services/tflite_service.dart';

/// Main service for handling chatbot functionality
class ChatbotService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final Uuid _uuid = const Uuid();

  // Collection names
  static const String conversationsCollection = 'chatbot_conversations';
  static const String supportTicketsCollection = 'support_tickets';
  static const String chatbotAnalyticsCollection = 'chatbot_analytics';

  /// Get or create conversation for current user
  static Future<Conversation> getOrCreateConversation() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Try to find existing active conversation
      // Using simple get() instead of complex where() queries
      final allConversations = await _firestore
          .collection(conversationsCollection)
          .get();

      // Filter client-side to avoid where() queries
      final userConversations = allConversations.docs
          .map((doc) => Conversation.fromFirestore(doc))
          .where(
            (conv) =>
                conv.userId == user.uid &&
                (conv.status == ConversationStatus.active ||
                    conv.status == ConversationStatus.escalated),
          )
          .toList();

      // Sort by updatedAt descending and take the most recent
      if (userConversations.isNotEmpty) {
        userConversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return userConversations.first;
      }

      // Create new conversation
      final conversationId = _uuid.v4();
      final userData = await FirestoreService.getUserData(user.uid);

      final newConversation = Conversation(
        id: conversationId,
        userId: user.uid,
        userEmail: user.email,
        userName: userData?['name'] ?? user.displayName,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection(conversationsCollection)
          .doc(conversationId)
          .set(newConversation.toFirestore());

      return newConversation;
    } catch (e) {
      print('❌ Error getting/creating conversation: $e');
      rethrow;
    }
  }

  /// Send message from user and get AI response
  static Future<void> sendMessage(
    String content, {
    String? conversationId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get or create conversation
      Conversation conversation;
      if (conversationId != null) {
        final convDoc = await _firestore
            .collection(conversationsCollection)
            .doc(conversationId)
            .get();
        conversation = Conversation.fromFirestore(convDoc);
      } else {
        conversation = await getOrCreateConversation();
      }

      // Create user message
      final userMessage = ChatMessage(
        id: _uuid.v4(),
        conversationId: conversation.id,
        sender: 'user',
        content: content,
        timestamp: DateTime.now(),
      );

      // Save user message
      await _firestore
          .collection(conversationsCollection)
          .doc(conversation.id)
          .collection('messages')
          .doc(userMessage.id)
          .set(userMessage.toFirestore());

      // Check for active flow in metadata
      final metadata = conversation.metadata ?? {};
      final activeFlow = metadata['active_flow'] as String?;
      final flowStep = metadata['flow_step'] as String?;

      ProcessedIntent processedIntent;
      String aiResponse;
      Map<String, dynamic> updatedMetadata = Map.from(metadata);

      if (activeFlow != null && flowStep != null) {
        // Continue existing flow
        final flowResult = await _processFlowStep(
          activeFlow,
          flowStep,
          content,
          conversation,
          updatedMetadata,
        );
        aiResponse = flowResult.response;
        processedIntent = ProcessedIntent(
          intent: activeFlow,
          confidence: 1.0,
          entities: flowResult.entities,
          suggestedAction: flowResult.action,
        );
        updatedMetadata = flowResult.updatedMetadata;
      } else {
        // Process message with NLP (Try TFLite first, then fallback to keywords)
        final tfliteService = TFLiteService();
        if (tfliteService.isModelLoaded) {
          processedIntent = await tfliteService.predictIntent(content);
        } else {
          processedIntent = NLPProcessor.processMessage(content);
        }

        // Check if intent starts a flow
        if (processedIntent.intent == 'driver_late') {
          aiResponse = NLPProcessor.generateResponse(processedIntent);
          updatedMetadata['active_flow'] = 'driver_late';
          updatedMetadata['flow_step'] = 'ask_ride_id';
        } else if (processedIntent.intent == 'lost_item') {
          aiResponse = NLPProcessor.generateResponse(processedIntent);
          updatedMetadata['active_flow'] = 'lost_item';
          updatedMetadata['flow_step'] = 'ask_ride_id';
        } else {
          // Generate standard AI response
          aiResponse = NLPProcessor.generateResponse(processedIntent);
        }
      }

      // Create AI message with metadata
      final aiMessage = ChatMessage(
        id: _uuid.v4(),
        conversationId: conversation.id,
        sender: 'ai',
        content: aiResponse,
        timestamp: DateTime.now(),
        messageType: MessageType.text,
        metadata: MessageMetadata(
          intent: processedIntent.intent,
          confidence: processedIntent.confidence,
          action: processedIntent.suggestedAction,
          entities: processedIntent.entities,
        ),
      );

      // Save AI message
      await _firestore
          .collection(conversationsCollection)
          .doc(conversation.id)
          .collection('messages')
          .doc(aiMessage.id)
          .set(aiMessage.toFirestore());

      // Update conversation metadata
      final updatedConversation = conversation.copyWith(
        updatedAt: DateTime.now(),
        lastMessage: aiResponse,
        lastMessageTime: DateTime.now(),
        category: _mapIntentToCategory(processedIntent.intent),
        metadata: updatedMetadata,
      );

      await _firestore
          .collection(conversationsCollection)
          .doc(conversation.id)
          .set(updatedConversation.toFirestore());

      // Check if should escalate to human
      if (_shouldEscalateToHuman(processedIntent)) {
        await _escalateToHumanSupport(conversation, content, processedIntent);
      }

      // Log analytics
      await _logChatbotInteraction(
        intent: processedIntent.intent,
        confidence: processedIntent.confidence,
        wasEscalated: _shouldEscalateToHuman(processedIntent),
      );
    } catch (e) {
      print('❌ Error sending message: $e');
      rethrow;
    }
  }

  /// Get conversation messages stream
  static Stream<List<ChatMessage>> getMessagesStream(String conversationId) {
    return _firestore
        .collection(conversationsCollection)
        .doc(conversationId)
        .collection('messages')
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map((doc) => ChatMessage.fromFirestore(doc))
              .toList();
          // Sort by timestamp manually to avoid orderBy
          messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return messages;
        });
  }

  /// Get user's conversations
  static Stream<List<Conversation>> getUserConversations() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore.collection(conversationsCollection).snapshots().map((
      snapshot,
    ) {
      // Filter client-side to avoid where() queries
      final userConversations = snapshot.docs
          .map((doc) => Conversation.fromFirestore(doc))
          .where((conv) => conv.userId == user.uid)
          .toList();
      // Sort by updatedAt descending manually to avoid orderBy
      userConversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return userConversations;
    });
  }

  /// Mark conversation as resolved
  static Future<void> resolveConversation(String conversationId) async {
    try {
      final conversationRef = _firestore
          .collection(conversationsCollection)
          .doc(conversationId);

      await conversationRef.update({
        'status': 'resolved',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error resolving conversation: $e');
      rethrow;
    }
  }

  /// Escalate conversation to human support
  static Future<void> escalateToSupport(
    String conversationId, {
    String? notes,
  }) async {
    try {
      final conversationDoc = await _firestore
          .collection(conversationsCollection)
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) {
        throw Exception('Conversation not found');
      }

      final conversation = Conversation.fromFirestore(conversationDoc);

      // Create support ticket
      final ticket = SupportTicket(
        id: _uuid.v4(),
        conversationId: conversationId,
        userId: conversation.userId,
        userEmail: conversation.userEmail,
        userName: conversation.userName,
        category: conversation.category,
        subject: 'Chatbot Escalation${notes != null ? ': $notes' : ''}',
        description:
            'Escalated from chatbot conversation. User needs human assistance.',
        priority: _determineTicketPriority(conversation.category),
        createdAt: DateTime.now(),
      );

      // Save support ticket
      await _firestore
          .collection(supportTicketsCollection)
          .doc(ticket.id)
          .set(ticket.toFirestore());

      // Update conversation status
      await _firestore
          .collection(conversationsCollection)
          .doc(conversationId)
          .update({
            'status': 'escalated',
            'isEscalated': true,
            'assignedSupportAgent': null,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Add system message about escalation
      final systemMessage = ChatMessage(
        id: _uuid.v4(),
        conversationId: conversationId,
        sender: 'system',
        content:
            'This conversation has been escalated to our support team. A representative will contact you soon.',
        timestamp: DateTime.now(),
        messageType: MessageType.system,
      );

      await _firestore
          .collection(conversationsCollection)
          .doc(conversationId)
          .collection('messages')
          .doc(systemMessage.id)
          .set(systemMessage.toFirestore());
    } catch (e) {
      print('❌ Error escalating to support: $e');
      rethrow;
    }
  }

  /// Get admin analytics data
  static Future<ChatbotAnalytics> getAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final now = DateTime.now();
      final start = startDate ?? now.subtract(Duration(days: 30));
      final end = endDate ?? now;

      // Get all conversations and filter client-side
      final allConversationsSnapshot = await _firestore
          .collection(conversationsCollection)
          .get();

      final conversations = allConversationsSnapshot.docs
          .map((doc) => Conversation.fromFirestore(doc))
          .where(
            (conv) =>
                conv.createdAt.isAfter(start) && conv.createdAt.isBefore(end),
          )
          .toList();

      // Get all support tickets and filter client-side
      final allTicketsSnapshot = await _firestore
          .collection(supportTicketsCollection)
          .get();

      final tickets = allTicketsSnapshot.docs
          .map((doc) => SupportTicket.fromFirestore(doc))
          .where(
            (ticket) =>
                ticket.createdAt.isAfter(start) &&
                ticket.createdAt.isBefore(end),
          )
          .toList();

      // Calculate analytics
      final totalConversations = conversations.length;
      final resolvedConversations = conversations
          .where((c) => c.status == ConversationStatus.resolved)
          .length;
      final escalatedConversations = conversations
          .where((c) => c.needsHumanSupport)
          .length;

      final categoryCounts = <ConversationCategory, int>{};
      for (final category in ConversationCategory.values) {
        categoryCounts[category] = conversations
            .where((c) => c.category == category)
            .length;
      }

      final avgResolutionTime = _calculateAverageResolutionTime(tickets);

      return ChatbotAnalytics(
        periodStart: start,
        periodEnd: end,
        totalConversations: totalConversations,
        resolvedConversations: resolvedConversations,
        escalatedConversations: escalatedConversations,
        escalationRate: totalConversations > 0
            ? (escalatedConversations / totalConversations) * 100
            : 0,
        categoryDistribution: categoryCounts,
        averageResolutionTime: avgResolutionTime,
        totalSupportTickets: tickets.length,
        intentCounts: await _getRecentIntentCounts(start, end),
      );
    } catch (e) {
      print('❌ Error getting analytics: $e');
      rethrow;
    }
  }

  /// Helper methods
  static ConversationCategory _mapIntentToCategory(String intent) {
    final categoryMap = {
      'ride_booking_help': ConversationCategory.booking,
      'ride_pooling_explanation': ConversationCategory.booking,
      'ride_status_check': ConversationCategory.booking,
      'payment_failed': ConversationCategory.payment,
      'refund_status': ConversationCategory.payment,
      'payment_methods': ConversationCategory.payment,
      'ride_issues': ConversationCategory.complaint,
      'driver_behavior': ConversationCategory.complaint,
      'app_problems': ConversationCategory.technical,
      'account_issues': ConversationCategory.account,
      'driver_late': ConversationCategory.complaint,
      'lost_item': ConversationCategory.complaint,
    };

    return categoryMap[intent] ?? ConversationCategory.general;
  }

  static bool _shouldEscalateToHuman(ProcessedIntent intent) {
    // Escalate if confidence is low or intent suggests escalation
    return intent.confidence < 0.3 ||
        intent.suggestedAction == 'escalate_complaint' ||
        intent.suggestedAction == 'report_driver';
  }

  static Future<void> _escalateToHumanSupport(
    Conversation conversation,
    String userMessage,
    ProcessedIntent intent,
  ) async {
    // Auto-escalate certain intents
    if (intent.suggestedAction == 'escalate_complaint' ||
        intent.suggestedAction == 'report_driver') {
      await escalateToSupport(
        conversation.id,
        notes: 'Auto-escalated from: $userMessage',
      );
    }
  }

  static TicketPriority _determineTicketPriority(
    ConversationCategory category,
  ) {
    switch (category) {
      case ConversationCategory.complaint:
      case ConversationCategory.technical:
        return TicketPriority.high;
      case ConversationCategory.payment:
        return TicketPriority.medium;
      default:
        return TicketPriority.low;
    }
  }

  static Duration _calculateAverageResolutionTime(List<SupportTicket> tickets) {
    final resolvedTickets = tickets
        .where((t) => t.status == TicketStatus.resolved && t.resolvedAt != null)
        .toList();

    if (resolvedTickets.isEmpty) return Duration.zero;

    int totalMinutes = 0;
    for (final ticket in resolvedTickets) {
      totalMinutes += ticket.resolvedAt!.difference(ticket.createdAt).inMinutes;
    }

    return Duration(minutes: totalMinutes ~/ resolvedTickets.length);
  }

  static Future<void> _logChatbotInteraction({
    required String intent,
    required double confidence,
    required bool wasEscalated,
  }) async {
    try {
      final analyticsDoc = _firestore
          .collection(chatbotAnalyticsCollection)
          .doc('daily_${DateTime.now().toIso8601String().split('T')[0]}');

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(analyticsDoc);

        if (doc.exists) {
          final data = doc.data()!;
          transaction.update(analyticsDoc, {
            'totalInteractions': FieldValue.increment(1),
            'escalatedInteractions': wasEscalated
                ? FieldValue.increment(1)
                : FieldValue.increment(0),
            'intentCounts': {
              ...Map<String, dynamic>.from(data['intentCounts'] ?? {}),
              intent: FieldValue.increment(1),
            },
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(analyticsDoc, {
            'date': Timestamp.fromDate(DateTime.now()),
            'totalInteractions': 1,
            'escalatedInteractions': wasEscalated ? 1 : 0,
            'intentCounts': {intent: 1},
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print('⚠️ Warning: Could not log analytics: $e');
    }
  }

  /// Helper methods for client-side filtering to avoid where() and orderBy() queries

  /// Process steps for stateful conversation flows
  static Future<_FlowResult> _processFlowStep(
    String flow,
    String step,
    String content,
    Conversation conversation,
    Map<String, dynamic> metadata,
  ) async {
    String response = '';
    String? nextStep;
    String action = 'continue_flow';
    Map<String, dynamic> entities = Map.from(metadata['flow_entities'] ?? {});
    Map<String, dynamic> updatedMetadata = Map.from(metadata);

    if (flow == 'driver_late') {
      if (step == 'ask_ride_id') {
        entities['ride_id'] = content;
        response = 'How long has the driver been delayed? (5–10 minutes, 10–20 minutes, more than 20 minutes)';
        nextStep = 'ask_delay';
      } else if (step == 'ask_delay') {
        entities['delay_duration'] = content;
        response = 'Thank you for the information. You can choose to:\n1. Wait for the driver\n2. Cancel the ride without penalty\n3. Contact our support staff for further assistance.';
        nextStep = null; // Flow finished
        updatedMetadata.remove('active_flow');
        updatedMetadata.remove('flow_step');
      }
    } else if (flow == 'lost_item') {
      if (step == 'ask_ride_id') {
        entities['ride_id'] = content;
        response = 'What item was lost? (phone, wallet, bag, or other)';
        nextStep = 'ask_item_type';
      } else if (step == 'ask_item_type') {
        entities['item_type'] = content;
        response = 'Could you please provide a brief description of the item?';
        nextStep = 'ask_description';
      } else if (step == 'ask_description') {
        entities['item_description'] = content;
        
        // Create support ticket
        final ticketId = _uuid.v4();
        final ticket = SupportTicket(
          id: ticketId,
          conversationId: conversation.id,
          userId: conversation.userId,
          userEmail: conversation.userEmail,
          userName: conversation.userName,
          category: ConversationCategory.complaint,
          subject: 'Lost Item Report: ${entities['item_type']}',
          description: 'User reported a lost item.\nRide ID: ${entities['ride_id']}\nItem: ${entities['item_type']}\nDescription: $content',
          priority: TicketPriority.medium,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection(supportTicketsCollection)
            .doc(ticketId)
            .set(ticket.toFirestore());

        response = 'Thank you. I have created a support ticket (#${ticketId.substring(0, 6)}) and notified the team. They will contact the driver and get back to you soon.';
        nextStep = null; // Flow finished
        action = 'ticket_created';
        updatedMetadata.remove('active_flow');
        updatedMetadata.remove('flow_step');
      }
    }

    if (nextStep != null) {
      updatedMetadata['flow_step'] = nextStep;
      updatedMetadata['flow_entities'] = entities;
    } else {
      updatedMetadata.remove('flow_entities');
    }

    return _FlowResult(
      response: response,
      updatedMetadata: updatedMetadata,
      entities: entities,
      action: action,
    );
  }

  /// Aggregate intent counts from daily analytics docs
  static Future<Map<String, int>> _getRecentIntentCounts(DateTime start, DateTime end) async {
    final intentCounts = <String, int>{};
    try {
      final snapshot = await _firestore
          .collection(chatbotAnalyticsCollection)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final counts = Map<String, dynamic>.from(data['intentCounts'] ?? {});
        counts.forEach((intent, count) {
          intentCounts[intent] = (intentCounts[intent] ?? 0) + (count as int);
        });
      }
    } catch (e) {
      print('⚠️ Warning: Could not aggregate intent counts: $e');
    }
    return intentCounts;
  }

  static Future<List<Conversation>> _getAllConversations() async {
    final snapshot = await _firestore.collection(conversationsCollection).get();
    return snapshot.docs.map((doc) => Conversation.fromFirestore(doc)).toList();
  }

  /// Get all support tickets
  static Future<List<SupportTicket>> _getAllSupportTickets() async {
    final snapshot = await _firestore
        .collection(supportTicketsCollection)
        .get();
    return snapshot.docs
        .map((doc) => SupportTicket.fromFirestore(doc))
        .toList();
  }

  /// Simplified user data fetching
  static Future<Map<String, dynamic>?> _getUserDataSimple(String userId) async {
    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (docSnapshot.exists) {
        return docSnapshot.data();
      }
      return null;
    } catch (e) {
      print('Warning: Could not fetch user data: $e');
      return null;
    }
  }
}

/// Analytics data structure
class ChatbotAnalytics {
  final DateTime periodStart;
  final DateTime periodEnd;
  final int totalConversations;
  final int resolvedConversations;
  final int escalatedConversations;
  final double escalationRate;
  final Map<ConversationCategory, int> categoryDistribution;
  final Duration averageResolutionTime;
  final int totalSupportTickets;
  final Map<String, int> intentCounts;

  ChatbotAnalytics({
    required this.periodStart,
    required this.periodEnd,
    required this.totalConversations,
    required this.resolvedConversations,
    required this.escalatedConversations,
    required this.escalationRate,
    required this.categoryDistribution,
    required this.averageResolutionTime,
    required this.totalSupportTickets,
    required this.intentCounts,
  });
}

class _FlowResult {
  final String response;
  final Map<String, dynamic> updatedMetadata;
  final Map<String, dynamic> entities;
  final String action;

  _FlowResult({
    required this.response,
    required this.updatedMetadata,
    required this.entities,
    required this.action,
  });
}
