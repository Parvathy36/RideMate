import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_enums.dart';

/// Represents a support ticket created from escalated conversations
class SupportTicket {
  final String id;
  final String conversationId;
  final String userId;
  final String? userEmail;
  final String? userName;
  final TicketPriority priority;
  final TicketStatus status;
  final ConversationCategory category;
  final String subject;
  final String description;
  final String? assignedTo; // Support agent ID
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;
  final String? resolutionNotes;
  final List<TicketActivity>? activityLog;

  SupportTicket({
    required this.id,
    required this.conversationId,
    required this.userId,
    this.userEmail,
    this.userName,
    this.priority = TicketPriority.medium,
    this.status = TicketStatus.open,
    required this.category,
    required this.subject,
    required this.description,
    this.assignedTo,
    required this.createdAt,
    this.updatedAt,
    this.resolvedAt,
    this.resolutionNotes,
    this.activityLog,
  });

  /// Create SupportTicket from Firestore document
  factory SupportTicket.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SupportTicket(
      id: doc.id,
      conversationId: data['conversationId'] ?? '',
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'],
      userName: data['userName'],
      priority: TicketPriority.fromString(data['priority'] ?? 'medium'),
      status: TicketStatus.fromString(data['status'] ?? 'open'),
      category: ConversationCategory.fromString(data['category'] ?? 'general'),
      subject: data['subject'] ?? '',
      description: data['description'] ?? '',
      assignedTo: data['assignedTo'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      resolvedAt: data['resolvedAt'] != null
          ? (data['resolvedAt'] as Timestamp).toDate()
          : null,
      resolutionNotes: data['resolutionNotes'],
      activityLog: data['activityLog'] != null
          ? (data['activityLog'] as List)
                .map((item) => TicketActivity.fromJson(item))
                .toList()
          : null,
    );
  }

  /// Convert SupportTicket to Firestore-compatible map
  Map<String, dynamic> toFirestore() {
    return {
      'conversationId': conversationId,
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'priority': priority.toString().split('.').last,
      'status': status.toString().split('.').last,
      'category': category.toString().split('.').last,
      'subject': subject,
      'description': description,
      'assignedTo': assignedTo,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'resolutionNotes': resolutionNotes,
      'activityLog': activityLog?.map((activity) => activity.toJson()).toList(),
    };
  }

  /// Create a copy with updated values
  SupportTicket copyWith({
    String? id,
    String? conversationId,
    String? userId,
    String? userEmail,
    String? userName,
    TicketPriority? priority,
    TicketStatus? status,
    ConversationCategory? category,
    String? subject,
    String? description,
    String? assignedTo,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    String? resolutionNotes,
    List<TicketActivity>? activityLog,
  }) {
    return SupportTicket(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      category: category ?? this.category,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      assignedTo: assignedTo ?? this.assignedTo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      activityLog: activityLog ?? this.activityLog,
    );
  }

  /// Calculate ticket age in hours
  int get ageInHours {
    return DateTime.now().difference(createdAt).inHours;
  }

  /// Check if ticket is overdue (older than 24 hours and still open)
  bool get isOverdue {
    return status == TicketStatus.open && ageInHours > 24;
  }
}

/// Activity log entry for ticket tracking
class TicketActivity {
  final String id;
  final String action;
  final String performedBy;
  final String? performedByName;
  final DateTime timestamp;
  final Map<String, dynamic>? details;

  TicketActivity({
    required this.id,
    required this.action,
    required this.performedBy,
    this.performedByName,
    required this.timestamp,
    this.details,
  });

  factory TicketActivity.fromJson(Map<String, dynamic> json) {
    return TicketActivity(
      id: json['id'] ?? '',
      action: json['action'] ?? '',
      performedBy: json['performedBy'] ?? '',
      performedByName: json['performedByName'],
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      details: json['details'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action,
      'performedBy': performedBy,
      'performedByName': performedByName,
      'timestamp': Timestamp.fromDate(timestamp),
      'details': details,
    };
  }
}
