import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single message in a chat conversation
class ChatMessage {
  final String id;
  final String conversationId;
  final String sender; // 'user', 'ai', 'support'
  final String content;
  final DateTime timestamp;
  final MessageType messageType;
  final MessageMetadata? metadata;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.content,
    required this.timestamp,
    this.messageType = MessageType.text,
    this.metadata,
    this.isRead = false,
  });

  /// Create ChatMessage from Firestore document
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      conversationId: data['conversationId'] ?? '',
      sender: data['sender'] ?? 'user',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      messageType: MessageType.fromString(data['messageType'] ?? 'text'),
      metadata: data['metadata'] != null
          ? MessageMetadata.fromJson(data['metadata'])
          : null,
      isRead: data['isRead'] ?? false,
    );
  }

  /// Convert ChatMessage to Firestore-compatible map
  Map<String, dynamic> toFirestore() {
    return {
      'conversationId': conversationId,
      'sender': sender,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'messageType': messageType.toString().split('.').last,
      'metadata': metadata?.toJson(),
      'isRead': isRead,
    };
  }

  /// Create a copy with updated values
  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? sender,
    String? content,
    DateTime? timestamp,
    MessageType? messageType,
    MessageMetadata? metadata,
    bool? isRead,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      sender: sender ?? this.sender,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      messageType: messageType ?? this.messageType,
      metadata: metadata ?? this.metadata,
      isRead: isRead ?? this.isRead,
    );
  }
}

/// Type of message for different UI treatments
enum MessageType {
  text,
  quickReply,
  suggestion,
  card,
  image,
  system;

  static MessageType fromString(String value) {
    return MessageType.values.firstWhere(
      (type) => type.toString().split('.').last == value,
      orElse: () => MessageType.text,
    );
  }
}

/// Metadata containing NLP processing results
class MessageMetadata {
  final String? intent;
  final double? confidence;
  final String? action;
  final Map<String, dynamic>? entities;
  final Map<String, dynamic>? additionalData;

  MessageMetadata({
    this.intent,
    this.confidence,
    this.action,
    this.entities,
    this.additionalData,
  });

  factory MessageMetadata.fromJson(Map<String, dynamic> json) {
    return MessageMetadata(
      intent: json['intent'],
      confidence: json['confidence'] is num
          ? json['confidence'].toDouble()
          : null,
      action: json['action'],
      entities: json['entities'],
      additionalData: json['additionalData'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'intent': intent,
      'confidence': confidence,
      'action': action,
      'entities': entities,
      'additionalData': additionalData,
    };
  }
}
