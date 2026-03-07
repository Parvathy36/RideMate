import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_enums.dart';

/// Represents a complete chat conversation
class Conversation {
  final String id;
  final String userId;
  final String? userEmail;
  final String? userName;
  final ConversationStatus status;
  final ConversationCategory category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isEscalated;
  final String? assignedSupportAgent;
  final Map<String, dynamic>? metadata;

  Conversation({
    required this.id,
    required this.userId,
    this.userEmail,
    this.userName,
    this.status = ConversationStatus.active,
    this.category = ConversationCategory.general,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isEscalated = false,
    this.assignedSupportAgent,
    this.metadata,
  });

  /// Create Conversation from Firestore document
  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'],
      userName: data['userName'],
      status: ConversationStatus.fromString(data['status'] ?? 'active'),
      category: ConversationCategory.fromString(data['category'] ?? 'general'),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      lastMessage: data['lastMessage'],
      lastMessageTime: data['lastMessageTime'] != null
          ? (data['lastMessageTime'] as Timestamp).toDate()
          : null,
      unreadCount: data['unreadCount'] ?? 0,
      isEscalated: data['isEscalated'] ?? false,
      assignedSupportAgent: data['assignedSupportAgent'],
      metadata: data['metadata'],
    );
  }

  /// Convert Conversation to Firestore-compatible map
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'status': status.toString().split('.').last,
      'category': category.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'unreadCount': unreadCount,
      'isEscalated': isEscalated,
      'assignedSupportAgent': assignedSupportAgent,
      'metadata': metadata,
    };
  }

  /// Create a copy with updated values
  Conversation copyWith({
    String? id,
    String? userId,
    String? userEmail,
    String? userName,
    ConversationStatus? status,
    ConversationCategory? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isEscalated,
    String? assignedSupportAgent,
    Map<String, dynamic>? metadata,
  }) {
    return Conversation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      status: status ?? this.status,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isEscalated: isEscalated ?? this.isEscalated,
      assignedSupportAgent: assignedSupportAgent ?? this.assignedSupportAgent,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Check if conversation needs human support
  bool get needsHumanSupport =>
      isEscalated || status == ConversationStatus.escalated;

  /// Get display name for the conversation
  String get displayName => userName ?? userEmail ?? 'Unknown User';
}
