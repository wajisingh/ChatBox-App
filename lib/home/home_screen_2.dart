import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../provider/auth_provider.dart';
import '../provider/user_provider.dart';

class HomeScreen2 extends StatefulWidget {
  final String peerId;
  final String peerName;
  final bool isGroupChat; // Add this parameter

  const HomeScreen2({
    Key? key,
    required this.peerId,
    required this.peerName,
    this.isGroupChat = false, // Default to false
  }) : super(key: key);

  @override
  State<HomeScreen2> createState() => _HomeScreen2State();
}

class _HomeScreen2State extends State<HomeScreen2> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isTyping = false;
  String? _conversationId;
  User? _peerUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (authProvider.currentUser != null) {
      try {
        // Use different logic for group vs 1-on-1 chat
        if (widget.isGroupChat) {
          // For group chat, use the peerId directly as conversation ID
          _conversationId = widget.peerId; // This should be 'ii_group'
        } else {
          // For 1-on-1 chat, create conversation ID
          _conversationId = _getConversationId(authProvider.currentUser!.id, widget.peerId);
          // Load peer user data for 1-on-1 chat
          _peerUser = await userProvider.getUserById(widget.peerId);
        }

        // Create the conversation document if it doesn't exist
        await _ensureConversationExists();

        // Mark messages as read
        await _markMessagesAsRead();

        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        print('Error initializing chat: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error initializing chat: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  String _getConversationId(String userId1, String userId2) {
    return userId1.compareTo(userId2) < 0
        ? '${userId1}_$userId2'
        : '${userId2}_$userId1';
  }

  // Ensure conversation document exists
  Future<void> _ensureConversationExists() async {
    if (_conversationId == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;

    try {
      final doc = await _firestore.collection('conversations').doc(_conversationId).get();

      if (!doc.exists && !widget.isGroupChat) {
        // Only create conversation for 1-on-1 chats
        // Groups should already exist
        await _firestore.collection('conversations').doc(_conversationId).set({
          'participantIds': [authProvider.currentUser!.id, widget.peerId],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isGroup': false,
        });
        print('Created conversation: $_conversationId');
      }
    } catch (e) {
      print('Error ensuring conversation exists: $e');
    }
  }
  void _showDeleteGroupDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Group'),
          content: Text('Are you sure you want to delete "${widget.peerName}"? This action cannot be undone and will remove all messages.'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteGroup();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteGroup() async {
    if (_conversationId == null || !widget.isGroupChat) return;

    try {
      // Delete all messages first
      final messages = await _firestore
          .collection('conversations')
          .doc(_conversationId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }

      // Delete the group conversation
      batch.delete(_firestore.collection('conversations').doc(_conversationId));

      await batch.commit();

      if (mounted) {
        // Go back to home screen
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null || _conversationId == null) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();
    setState(() => _isTyping = false);

    try {
      setState(() => _isLoading = true);

      // Create message object
      final message = Message(
        id: '',
        senderId: authProvider.currentUser!.id,
        receiverId: widget.isGroupChat ? '' : widget.peerId, // Empty for groups
        message: messageText,
        timestamp: Timestamp.now(),
        isRead: false,
        senderName: authProvider.currentUser!.name,
        messageType: 'text',
      );

      // Add message to Firestore
      final docRef = await _firestore
          .collection('conversations')
          .doc(_conversationId)
          .collection('messages')
          .add(message.toMap());

      print('Message sent with ID: ${docRef.id}');

      // Update conversation metadata
      await _firestore
          .collection('conversations')
          .doc(_conversationId)
          .update({
        'lastMessage': message.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Auto scroll to bottom
      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markMessagesAsRead() async {
    if (_conversationId == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;

    try {
      final unreadMessages = await _firestore
          .collection('conversations')
          .doc(_conversationId)
          .collection('messages')
          .where('receiverId', isEqualTo: authProvider.currentUser!.id)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadMessages.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in unreadMessages.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
        print('Marked ${unreadMessages.docs.length} messages as read');
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onMessageTextChanged(String text) {
    if (text.isNotEmpty && !_isTyping) {
      setState(() => _isTyping = true);
    } else if (text.isEmpty && _isTyping) {
      setState(() => _isTyping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Consumer2<AuthProvider, UserProvider>(
          builder: (context, authProvider, userProvider, child) {
            final currentUser = authProvider.currentUser;

            if (currentUser == null) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF5A0FC8)),
              );
            }

            // Get peer user info
            final peerUser = userProvider.findUserById(widget.peerId) ?? _peerUser;
            final isOnline = peerUser?.isOnline ?? false;
            final lastSeen = userProvider.getUserLastSeen(widget.peerId);

            return Column(
              children: [
                // Header Container
                _buildHeader(peerUser, isOnline, lastSeen),

                // Chat Messages
                _buildMessagesList(currentUser),

                // Message Input Area
                _buildMessageInput(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(User? peerUser, bool isOnline, String lastSeen) {
    return Container(
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          backgroundImage: peerUser?.profilePictureUrl != null
                              ? NetworkImage(peerUser!.profilePictureUrl!)
                              : null,
                          child: peerUser?.profilePictureUrl == null
                              ? Icon(
                            widget.isGroupChat ? Icons.group : Icons.person,
                            color: Colors.white,
                          )
                              : null,
                        ),
                        if (isOnline && !widget.isGroupChat)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.peerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.isGroupChat ? 'Group Chat' : lastSeen,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                switch (value) {
                  case 'clear':
                    _showClearChatDialog();
                    break;
                  case 'refresh':
                    setState(() {}); // Refresh the screen
                    break;
                  case 'delete':
                    if (widget.isGroupChat) {
                      _showDeleteGroupDialog();
                    }
                    break;
                }
              },
              itemBuilder: (BuildContext context) {
                return [
                  const PopupMenuItem<String>(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, size: 20),
                        SizedBox(width: 8),
                        Text('Refresh'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20),
                        SizedBox(width: 8),
                        Text('Clear Chat'),
                      ],
                    ),
                  ),
                  // Add delete group option for group chats only
                  if (widget.isGroupChat)
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Group', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList(User currentUser) {
    if (_conversationId == null) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator(color: Color(0xFF5A0FC8))),
      );
    }

    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('conversations')
            .doc(_conversationId)
            .collection('messages')
            .orderBy('timestamp', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          // Add debug information
          print('Stream state: ${snapshot.connectionState}');
          print('Has error: ${snapshot.hasError}');
          print('Error: ${snapshot.error}');
          print('Has data: ${snapshot.hasData}');
          print('Doc count: ${snapshot.data?.docs.length ?? 0}');

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF5A0FC8)),
            );
          }

          if (snapshot.hasError) {
            print('Firestore error: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading messages',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {}); // Refresh
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start the conversation with ${widget.peerName}!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          try {
            final messages = snapshot.data!.docs
                .map((doc) => Message.fromFirestore(doc))
                .toList();

            // Auto scroll to bottom when new messages arrive
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });

            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isMe = message.isSentByUser(currentUser.id);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: isMe
                      ? _buildSentMessage(message, currentUser)
                      : _buildReceivedMessage(message),
                );
              },
            );
          } catch (e) {
            print('Error building message list: $e');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'Error displaying messages',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$e',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildReceivedMessage(Message message) {
    // Get sender's name initial
    String senderInitial = message.senderName != null && message.senderName!.isNotEmpty
        ? message.senderName![0].toUpperCase()
        : 'U';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFAD87E4),
          child: Text(
            senderInitial, // Use sender's initial instead of peer name
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show sender name for group chats
              if (widget.isGroupChat && message.senderName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    message.senderName!,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFAD87E4),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
                child: Text(
                  message.message,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message.getFormattedTime(),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSentMessage(Message message, User currentUser) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF5A0FC8),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  message.message,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    message.getFormattedTime(),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 16,
                    color: message.isRead ? Colors.blue : Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF5A0FC8),
          child: Text(
            currentUser.name.isNotEmpty ? currentUser.name[0].toUpperCase() : 'U',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Emoji picker coming soon! 😊'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextFormField(
                  controller: _messageController,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    hintText: 'Type message here...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(color: Colors.black),
                  onChanged: _onMessageTextChanged,
                  onFieldSubmitted: (_) => _sendMessage(),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: _isLoading
                    ? const Color(0xFF5A0FC8).withOpacity(0.6)
                    : const Color(0xFF5A0FC8),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: _isLoading ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Chat'),
          content: const Text('Are you sure you want to clear all messages? This action cannot be undone.'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Clear', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _clearChat();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearChat() async {
    if (_conversationId == null) return;

    try {
      final messages = await _firestore
          .collection('conversations')
          .doc(_conversationId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat cleared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}