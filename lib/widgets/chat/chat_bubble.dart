import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/chat_message.dart';

/// Individual chat bubble widget
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isCurrentUser;
  final VoidCallback? onLongPress;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isAi = message.sender == 'ai';
    final isSystem = message.sender == 'system';
    final isSupport = message.sender == 'support';

    return Container(
      margin: EdgeInsets.only(
        bottom: 12,
        left: isCurrentUser ? 60 : 0,
        right: isCurrentUser ? 0 : 60,
      ),
      child: Column(
        crossAxisAlignment: isCurrentUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Sender indicator (for non-user messages)
          if (!isCurrentUser && !isSystem) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                _getSenderName(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _getSenderColor(isAi, isSupport),
                ),
              ),
            ),
          ],

          // Message bubble
          GestureDetector(
            onLongPress: onLongPress,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: _getBubbleColor(
                  isCurrentUser,
                  isAi,
                  isSystem,
                  isSupport,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isCurrentUser ? 18 : 4),
                  topRight: Radius.circular(isCurrentUser ? 4 : 18),
                  bottomLeft: const Radius.circular(18),
                  bottomRight: const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message content
                  if (message.messageType == MessageType.text) ...[
                    Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 16,
                        color: _getTextColor(isCurrentUser, isSystem),
                        height: 1.4,
                      ),
                    ),
                  ] else if (message.messageType == MessageType.system) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            message.content,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 16,
                        color: _getTextColor(isCurrentUser, isSystem),
                        height: 1.4,
                      ),
                    ),
                  ],

                  // Metadata (confidence indicator for AI messages)
                  if (isAi && message.metadata?.confidence != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.psychology, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Confidence: ${(message.metadata!.confidence! * 100).round()}%',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Timestamp
          Padding(
            padding: EdgeInsets.only(
              left: isCurrentUser ? 0 : 12,
              right: isCurrentUser ? 12 : 0,
              top: 4,
            ),
            child: Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  String _getSenderName() {
    switch (message.sender) {
      case 'ai':
        return 'RideMate Assistant';
      case 'support':
        return 'Support Agent';
      case 'system':
        return 'System';
      default:
        return 'Unknown';
    }
  }

  Color _getSenderColor(bool isAi, bool isSupport) {
    if (isAi) return Colors.deepPurple;
    if (isSupport) return Colors.green;
    return Colors.grey;
  }

  Color _getBubbleColor(
    bool isCurrentUser,
    bool isAi,
    bool isSystem,
    bool isSupport,
  ) {
    if (isCurrentUser) {
      return Colors.deepPurple;
    } else if (isSystem) {
      return Colors.blue.shade50;
    } else if (isSupport) {
      return Colors.green.shade100;
    } else if (isAi) {
      return Colors.grey.shade200;
    } else {
      return Colors.grey.shade300;
    }
  }

  Color _getTextColor(bool isCurrentUser, bool isSystem) {
    if (isCurrentUser) {
      return Colors.white;
    } else if (isSystem) {
      return Colors.blue.shade800;
    } else {
      return Colors.black87;
    }
  }
}
