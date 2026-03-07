/// Shared enums used across chatbot models

/// Status of a conversation
enum ConversationStatus {
  active, // Ongoing conversation
  resolved, // Issue resolved
  escalated, // Escalated to human support
  archived; // Archived conversation

  static ConversationStatus fromString(String value) {
    return ConversationStatus.values.firstWhere(
      (status) => status.toString().split('.').last == value,
      orElse: () => ConversationStatus.active,
    );
  }
}

/// Category of the conversation for analytics and routing
enum ConversationCategory {
  booking, // Ride booking related
  payment, // Payment issues
  complaint, // Complaints and issues
  general, // General inquiries
  account, // Account related
  technical; // Technical issues

  static ConversationCategory fromString(String value) {
    return ConversationCategory.values.firstWhere(
      (category) => category.toString().split('.').last == value,
      orElse: () => ConversationCategory.general,
    );
  }
}

/// Priority levels for support tickets
enum TicketPriority {
  low,
  medium,
  high,
  urgent;

  static TicketPriority fromString(String value) {
    return TicketPriority.values.firstWhere(
      (priority) => priority.toString().split('.').last == value,
      orElse: () => TicketPriority.medium,
    );
  }
}

/// Status of support tickets
enum TicketStatus {
  open,
  inProgress,
  resolved,
  closed;

  static TicketStatus fromString(String value) {
    return TicketStatus.values.firstWhere(
      (status) => status.toString().split('.').last == value,
      orElse: () => TicketStatus.open,
    );
  }
}
