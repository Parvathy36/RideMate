import 'package:flutter/material.dart';

/// Chat input component with text field and send button
class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;
  final List<String>? quickReplies;

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.isLoading = false,
    this.quickReplies,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  bool _isMultiline = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Quick replies
        if (widget.quickReplies != null && widget.quickReplies!.isNotEmpty) ...[
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: widget.quickReplies!.map((reply) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(reply),
                    backgroundColor: Colors.deepPurple.shade100,
                    labelStyle: TextStyle(
                      color: Colors.deepPurple.shade800,
                      fontSize: 12,
                    ),
                    onPressed: widget.isLoading
                        ? null
                        : () {
                            widget.controller.text = reply;
                            widget.onSend();
                          },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Main input area
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Text input field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    maxLines: _isMultiline ? 4 : 1,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isMultiline ? Icons.expand_less : Icons.expand_more,
                          color: Colors.grey.shade600,
                        ),
                        onPressed: () {
                          setState(() {
                            _isMultiline = !_isMultiline;
                          });
                        },
                      ),
                    ),
                    onChanged: (text) {
                      // Auto-expand when text gets long
                      if (text.length > 50 && !_isMultiline) {
                        setState(() {
                          _isMultiline = true;
                        });
                      }
                    },
                    onSubmitted: (_) {
                      if (widget.controller.text.trim().isNotEmpty &&
                          !widget.isLoading) {
                        widget.onSend();
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Send button
              Container(
                decoration: BoxDecoration(
                  color:
                      widget.controller.text.trim().isEmpty || widget.isLoading
                      ? Colors.grey.shade300
                      : Colors.deepPurple,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: widget.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed:
                      widget.controller.text.trim().isEmpty || widget.isLoading
                      ? null
                      : widget.onSend,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
