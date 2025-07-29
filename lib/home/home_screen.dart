import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home/home_screen_2.dart';
import '../login_screen/login_page.dart';
import '../provider/auth_provider.dart';
import '../provider/chat_provider.dart';
import '../provider/user_provider.dart';
import '../models/user.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Load users when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      if (authProvider.currentUser != null) {
        userProvider.loadUsers(excludeUserId: authProvider.currentUser!.id);
      }
    });
  }

  void _openChatScreen(BuildContext context, String peerId, String peerName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen2(
          peerId: peerId,
          peerName: peerName,
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error logging out: $e")),
        );
      }
    }
  }

  // Get conversation ID for two users
  String _getConversationId(String userId1, String userId2) {
    return userId1.compareTo(userId2) < 0
        ? '${userId1}_$userId2'
        : '${userId2}_$userId1';
  }

  // Get unread message count for a specific chat
  Stream<int> _getUnreadCount(String peerId, String currentUserId) {
    final conversationId = _getConversationId(currentUserId, peerId);

    return FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Get last message for a user
  Stream<Map<String, dynamic>?> _getLastMessage(String peerId, String currentUserId) {
    final conversationId = _getConversationId(currentUserId, peerId);

    return FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final data = doc.data();

      return {
        'lastMessage': data['message'] ?? '',
        'lastMessageTime': data['timestamp'] as Timestamp?,
        'lastMessageSender': data['senderId'],
        'messageType': data['messageType'] ?? 'text',
      };
    });
  }

  String _formatLastMessageTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      final hour = messageTime.hour.toString().padLeft(2, '0');
      final minute = messageTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      final day = messageTime.day.toString().padLeft(2, '0');
      final month = messageTime.month.toString().padLeft(2, '0');
      return '$day/$month';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: Consumer3<AuthProvider, UserProvider, ChatProvider>(
          builder: (context, authProvider, userProvider, chatProvider, child) {
            final currentUser = authProvider.currentUser;

            if (currentUser == null) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xff7B3FD3)),
              );
            }

            return Column(
              children: [
                // Header Container
                Container(
                  width: double.infinity,
                  height: 155,
                  decoration: const BoxDecoration(
                    color: Color(0xff7B3FD3),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(35),
                      bottomRight: Radius.circular(35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xff7B3FD3),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "ChatBox App",
                                  style: TextStyle(
                                    fontSize: 24,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  "Welcome, ${currentUser.name}",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                // Online indicator for current user
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.circle, size: 8, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'Online',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: authProvider.isLoading ? null : () => _logout(context),
                                  icon: authProvider.isLoading
                                      ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                      : const Icon(
                                    Icons.logout,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Search Bar
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          width: MediaQuery.of(context).size.width - 16,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xffF2F2F2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value.toLowerCase();
                                });
                              },
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                labelText: "Search users...",
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Users List
                Expanded(
                  child: StreamBuilder<List<User>>(
                    stream: userProvider.getUsersStream(excludeUserId: currentUser.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xff7B3FD3),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading users',
                                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () => userProvider.refreshUsers(excludeUserId: currentUser.id),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text(
                            'No other users found.\nSign up more accounts to see them here!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        );
                      }

                      // Filter users based on search query
                      final users = _searchQuery.isEmpty
                          ? snapshot.data!
                          : snapshot.data!.where((user) {
                        final userName = user.name.toLowerCase();
                        final userEmail = user.email.toLowerCase();
                        return userName.contains(_searchQuery) || userEmail.contains(_searchQuery);
                      }).toList();

                      if (users.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No users found for "$_searchQuery"',
                                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: users.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final user = users[index];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: StreamBuilder<Map<String, dynamic>?>(
                              stream: _getLastMessage(user.id, currentUser.id),
                              builder: (context, lastMessageSnapshot) {
                                final lastMessageData = lastMessageSnapshot.data;
                                final lastMessage = lastMessageData?['lastMessage'] as String? ?? '';
                                final lastMessageTime = lastMessageData?['lastMessageTime'] as Timestamp?;
                                final lastMessageSender = lastMessageData?['lastMessageSender'] as String?;
                                final isLastMessageFromPeer = lastMessageSender == user.id;

                                return StreamBuilder<int>(
                                  stream: _getUnreadCount(user.id, currentUser.id),
                                  builder: (context, unreadSnapshot) {
                                    final unreadCount = unreadSnapshot.data ?? 0;
                                    final hasUnreadMessages = unreadCount > 0;

                                    return GestureDetector(
                                      onTap: () => _openChatScreen(context, user.id, user.name),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: hasUnreadMessages ? const Color(0xff7B3FD3).withOpacity(0.05) : Colors.white,
                                          borderRadius: BorderRadius.circular(15),
                                          border: hasUnreadMessages ? Border.all(color: const Color(0xff7B3FD3).withOpacity(0.3)) : null,
                                          boxShadow: [
                                            BoxShadow(
                                              color: hasUnreadMessages
                                                  ? const Color(0xff7B3FD3).withOpacity(0.15)
                                                  : Colors.grey.withOpacity(0.2),
                                              spreadRadius: hasUnreadMessages ? 3 : 2,
                                              blurRadius: hasUnreadMessages ? 8 : 5,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Stack(
                                              children: [
                                                CircleAvatar(
                                                  radius: 30,
                                                  backgroundColor: const Color(0xff7B3FD3).withOpacity(0.2),
                                                  backgroundImage: user.profilePictureUrl != null
                                                      ? NetworkImage(user.profilePictureUrl!)
                                                      : null,
                                                  child: user.profilePictureUrl == null
                                                      ? Text(
                                                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                                    style: const TextStyle(
                                                      color: Color(0xff7B3FD3),
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 18,
                                                    ),
                                                  )
                                                      : null,
                                                ),
                                                Positioned(
                                                  bottom: 0,
                                                  right: 0,
                                                  child: Container(
                                                    width: 16,
                                                    height: 16,
                                                    decoration: BoxDecoration(
                                                      color: user.isOnline ? Colors.green : Colors.grey,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(color: Colors.white, width: 2),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          user.name,
                                                          style: TextStyle(
                                                            fontWeight: hasUnreadMessages ? FontWeight.bold : FontWeight.w600,
                                                            fontSize: 16,
                                                            color: hasUnreadMessages ? const Color(0xff7B3FD3) : Colors.black87,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      if (lastMessageTime != null)
                                                        Text(
                                                          _formatLastMessageTime(lastMessageTime),
                                                          style: TextStyle(
                                                            color: hasUnreadMessages ? const Color(0xff7B3FD3) : Colors.grey,
                                                            fontSize: 12,
                                                            fontWeight: hasUnreadMessages ? FontWeight.w600 : FontWeight.normal,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  if (lastMessage.isNotEmpty)
                                                    Row(
                                                      children: [
                                                        if (!isLastMessageFromPeer)
                                                          Icon(Icons.reply, size: 14, color: Colors.grey[600]),
                                                        if (!isLastMessageFromPeer) const SizedBox(width: 4),
                                                        Expanded(
                                                          child: Text(
                                                            lastMessage,
                                                            style: TextStyle(
                                                              color: hasUnreadMessages ? Colors.black87 : Colors.grey[600],
                                                              fontSize: 13,
                                                              fontWeight: hasUnreadMessages ? FontWeight.w500 : FontWeight.normal,
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                            maxLines: 1,
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  else
                                                    Text(
                                                      user.email,
                                                      style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 13,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    userProvider.getUserLastSeen(user.id),
                                                    style: TextStyle(
                                                      color: user.isOnline ? Colors.green : Colors.grey,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Notification area
                                            Column(
                                              children: [
                                                if (hasUnreadMessages)
                                                  Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xff7B3FD3),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Text(
                                                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  )
                                                else if (user.isOnline)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.circle, size: 8, color: Colors.green),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          'Active',
                                                          style: TextStyle(
                                                            color: Colors.green,
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (hasUnreadMessages)
                                                  const SizedBox(height: 8),
                                                if (hasUnreadMessages)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                                    ),
                                                    child: const Text(
                                                      'NEW',
                                                      style: TextStyle(
                                                        color: Colors.orange,
                                                        fontSize: 8,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}