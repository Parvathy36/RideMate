import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/chatbot_service.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../models/chat_enums.dart';
import '../widgets/chat/chat_bubble.dart';
import '../widgets/chat/chat_input.dart';
import '../utils/responsive_utils.dart';

/// Main chatbot screen
class ChatbotScreen extends StatefulWidget {
  final String? conversationId;

  const ChatbotScreen({super.key, this.conversationId});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Future<Conversation> _conversationFuture;
  bool _isLoading = false;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _conversationFuture = ChatbotService.getOrCreateConversation();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _textController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isLoading = true;
      _isTyping = true;
    });

    _textController.clear();

    try {
      final conversation = await _conversationFuture;
      await ChatbotService.sendMessage(
        message,
        conversationId: conversation.id,
      );

      // Scroll to bottom after message is sent
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isTyping = false;
        });
      }
    }
  }

  Future<void> _escalateToSupport() async {
    final shouldEscalate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Escalate to Support'),
        content: const Text(
          'Would you like to escalate this conversation to our human support team? '
          'They will review your chat history and assist you personally.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 251, 250, 253)),
            child: const Text('Escalate'),
          ),
        ],
      ),
    );

    if (shouldEscalate == true) {
      try {
        final conversation = await _conversationFuture;
        await ChatbotService.escalateToSupport(conversation.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversation escalated to support team'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to escalate: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RideMate Support'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: _escalateToSupport,
            tooltip: 'Escalate to Human Support',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'end_chat':
                  _endChat();
                  break;
                case 'clear_history':
                  _clearHistory();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'end_chat',
                child: ListTile(
                  leading: Icon(Icons.chat_bubble_outline),
                  title: Text('End Chat'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear_history',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Clear History'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<Conversation>(
        future: _conversationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load chat: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _conversationFuture =
                            ChatbotService.getOrCreateConversation();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final conversation = snapshot.data!;
          return _buildChatInterface(conversation);
        },
      ),
    );
  }

  Widget _buildChatInterface(Conversation conversation) {
    return Column(
      children: [
        // Welcome message
        if (conversation.status == ConversationStatus.active) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple.shade50,
            child: Column(
              children: [
                const Icon(
                  Icons.support_agent,
                  size: 32,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hi there! I\'m your RideMate Assistant',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'I can help with ride bookings, payments, complaints, and more.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],

        // Messages list
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: ChatbotService.getMessagesStream(conversation.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading messages: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Start a conversation!',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Ask me anything about RideMate services',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              final messages = snapshot.data!;

              if (messages.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Start a conversation!',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Ask me anything about RideMate services',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= messages.length) {
                    // Typing indicator
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'RideMate Assistant is typing',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                SizedBox(width: 8),
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final message = messages[index];
                  final isCurrentUser = message.sender == 'user';

                  return ChatBubble(
                    message: message,
                    isCurrentUser: isCurrentUser,
                    onLongPress: () {
                      _showMessageOptions(message);
                    },
                  );
                },
              );
            },
          ),
        ),

        // Quick replies for new conversations
        if (conversation.status == ConversationStatus.active) ...[
          ChatInput(
            controller: _textController,
            onSend: _sendMessage,
            isLoading: _isLoading,
            quickReplies: const [
              'How to book a ride?',
              'Payment failed',
              'Ride pooling',
              'Report driver issue',
            ],
          ),
        ] else ...[
          // Disabled input for resolved/escalated conversations
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: const Text(
              'This conversation has been resolved or escalated. Start a new chat for additional help.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ],
    );
  }

  void _showMessageOptions(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Message Options',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Message'),
              onTap: () {
                Navigator.pop(context);
                // Copy to clipboard logic would go here
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag),
              title: const Text('Report Issue'),
              onTap: () {
                Navigator.pop(context);
                // Report logic would go here
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _endChat() async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Chat'),
        content: const Text('Are you sure you want to end this conversation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('End Chat'),
          ),
        ],
      ),
    );

    if (shouldEnd == true && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _clearHistory() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text(
          'This will permanently delete all messages in this conversation. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear History'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      // Clear history logic would go here
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat history cleared'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
