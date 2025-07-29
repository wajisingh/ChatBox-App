import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../models/chat_conversation.dart';

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;
  List<Message> _messages = [];
  List<ChatConversation> _conversations = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _activeConversationId;

  // Getters
  User? get currentUser => _currentUser;
  List<Message> get messages => _messages;
  List<ChatConversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get activeConversationId => _activeConversationId;

  // 🔧 FIXED: Prevent setState during build
  void updateUser(User? user) {
    _currentUser = user;
    if (user != null) {
      // Use Future.microtask to avoid setState during build
      Future.microtask(() => loadConversations());
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // Original method that triggers loadMessages
  void setActiveConversation(String? conversationId) {
    _activeConversationId = conversationId;
    if (conversationId != null) {
      // Use Future.microtask to avoid setState during build
      Future.microtask(() => loadMessages(conversationId));
    }
    notifyListeners();
  }

  // 🔧 NEW: Safe method to set active conversation without triggering loadMessages immediately
  void setActiveConversationSafe(String? conversationId) {
    _activeConversationId = conversationId;
    // Don't call loadMessages here to avoid setState during build
    notifyListeners();
  }

  Future<void> sendMessage({
    required String receiverId,
    required String message,
    String messageType = 'text',
  }) async {
    if (_currentUser == null) return;

    try {
      final conversationId = _getConversationId(_currentUser!.id, receiverId);

      final messageData = Message(
        id: '',
        senderId: _currentUser!.id,
        receiverId: receiverId,
        message: message,
        timestamp: Timestamp.now(),
        senderName: _currentUser!.name,
        messageType: messageType,
      );

      // Add message to messages collection
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add(messageData.toMap());

      // Update conversation metadata
      await _updateConversation(conversationId, messageData, [_currentUser!.id, receiverId]);

    } catch (e) {
      _setError('Failed to send message: ${e.toString()}');
    }
  }

  String _getConversationId(String userId1, String userId2) {
    return userId1.compareTo(userId2) < 0
        ? '${userId1}_$userId2'
        : '${userId2}_$userId1';
  }

  Future<void> _updateConversation(String conversationId, Message lastMessage, List<String> participantIds) async {
    final conversationData = {
      'participantIds': participantIds,
      'lastMessage': lastMessage.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .set(conversationData, SetOptions(merge: true));
  }

  Stream<List<Message>> getMessagesStream(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Message.fromFirestore(doc))
        .toList());
  }

  Future<void> loadMessages(String conversationId) async {
    try {
      _setLoading(true);
      final snapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();

      _messages = snapshot.docs
          .map((doc) => Message.fromFirestore(doc))
          .toList();

      notifyListeners();
    } catch (e) {
      _setError('Failed to load messages: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadConversations() async {
    if (_currentUser == null) return;

    try {
      _setLoading(true);
      final snapshot = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: _currentUser!.id)
          .orderBy('updatedAt', descending: true)
          .get();

      _conversations = snapshot.docs
          .map((doc) => ChatConversation.fromFirestore(doc))
          .toList();

      notifyListeners();
    } catch (e) {
      _setError('Failed to load conversations: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Stream<List<ChatConversation>> getConversationsStream() {
    if (_currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('conversations')
        .where('participantIds', arrayContains: _currentUser!.id)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ChatConversation.fromFirestore(doc))
        .toList());
  }

  Future<void> markMessageAsRead(String conversationId, String messageId) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .update({'isRead': true});
    } catch (e) {
      _setError('Failed to mark message as read: ${e.toString()}');
    }
  }

  // Get unread message count for a conversation
  Future<int> getUnreadMessageCount(String conversationId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      _setError('Failed to get unread count: ${e.toString()}');
      return 0;
    }
  }

  // Get unread message count stream for a conversation
  Stream<int> getUnreadMessageCountStream(String conversationId, String userId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark all messages in a conversation as read
  Future<void> markAllMessagesAsRead(String conversationId, String userId) async {
    try {
      final unreadMessages = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      _setError('Failed to mark messages as read: ${e.toString()}');
    }
  }

  // Delete a message
  Future<void> deleteMessage(String conversationId, String messageId) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      _setError('Failed to delete message: ${e.toString()}');
    }
  }

  // Clear all messages in a conversation
  Future<void> clearConversation(String conversationId) async {
    try {
      final messages = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Also clear the conversation metadata
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .delete();

    } catch (e) {
      _setError('Failed to clear conversation: ${e.toString()}');
    }
  }

  // Search messages in a conversation
  Future<List<Message>> searchMessages(String conversationId, String query) async {
    try {
      final snapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .get();

      final allMessages = snapshot.docs
          .map((doc) => Message.fromFirestore(doc))
          .toList();

      return allMessages
          .where((message) => message.message.toLowerCase().contains(query.toLowerCase()))
          .toList();
    } catch (e) {
      _setError('Failed to search messages: ${e.toString()}');
      return [];
    }
  }

  // Get conversation by ID
  Future<ChatConversation?> getConversationById(String conversationId) async {
    try {
      final doc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (doc.exists) {
        return ChatConversation.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      _setError('Failed to get conversation: ${e.toString()}');
      return null;
    }
  }

  // Update typing status
  Future<void> updateTypingStatus(String conversationId, bool isTyping) async {
    if (_currentUser == null) return;

    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'typing.${_currentUser!.id}': isTyping,
      });

      // Auto-remove typing indicator after 3 seconds
      if (isTyping) {
        Future.delayed(const Duration(seconds: 3), () {
          updateTypingStatus(conversationId, false);
        });
      }
    } catch (e) {
      _setError('Failed to update typing status: ${e.toString()}');
    }
  }

  // Get typing status stream
  Stream<Map<String, bool>> getTypingStatusStream(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return <String, bool>{};

      final data = snapshot.data() as Map<String, dynamic>?;
      final typing = data?['typing'] as Map<String, dynamic>? ?? {};

      return typing.map((key, value) => MapEntry(key, value as bool? ?? false));
    });
  }

  // Get last message for a conversation
  Future<Message?> getLastMessage(String conversationId) async {
    try {
      final snapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Message.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      _setError('Failed to get last message: ${e.toString()}');
      return null;
    }
  }

  // Get last message stream for a conversation
  Stream<Message?> getLastMessageStream(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return Message.fromFirestore(snapshot.docs.first);
      }
      return null;
    });
  }

  // Get message count for a conversation
  Future<int> getMessageCount(String conversationId) async {
    try {
      final snapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      _setError('Failed to get message count: ${e.toString()}');
      return 0;
    }
  }

  // Send image message
  Future<void> sendImageMessage({
    required String receiverId,
    required String imageUrl,
    String? caption,
  }) async {
    if (_currentUser == null) return;

    try {
      final conversationId = _getConversationId(_currentUser!.id, receiverId);

      final messageData = Message(
        id: '',
        senderId: _currentUser!.id,
        receiverId: receiverId,
        message: caption ?? imageUrl,
        timestamp: Timestamp.now(),
        senderName: _currentUser!.name,
        messageType: 'image',
      );

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add(messageData.toMap());

      await _updateConversation(conversationId, messageData, [_currentUser!.id, receiverId]);

    } catch (e) {
      _setError('Failed to send image: ${e.toString()}');
    }
  }

  // Send file message
  Future<void> sendFileMessage({
    required String receiverId,
    required String fileUrl,
    required String fileName,
  }) async {
    if (_currentUser == null) return;

    try {
      final conversationId = _getConversationId(_currentUser!.id, receiverId);

      final messageData = Message(
        id: '',
        senderId: _currentUser!.id,
        receiverId: receiverId,
        message: fileName,
        timestamp: Timestamp.now(),
        senderName: _currentUser!.name,
        messageType: 'file',
      );

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add(messageData.toMap());

      await _updateConversation(conversationId, messageData, [_currentUser!.id, receiverId]);

    } catch (e) {
      _setError('Failed to send file: ${e.toString()}');
    }
  }

  // Get messages by type
  Future<List<Message>> getMessagesByType(String conversationId, String messageType) async {
    try {
      final snapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('messageType', isEqualTo: messageType)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Message.fromFirestore(doc))
          .toList();
    } catch (e) {
      _setError('Failed to get messages by type: ${e.toString()}');
      return [];
    }
  }

  // Get conversation info (participants, last activity, etc.)
  Future<Map<String, dynamic>?> getConversationInfo(String conversationId) async {
    try {
      final doc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final messageCount = await getMessageCount(conversationId);

        return {
          ...data,
          'messageCount': messageCount,
          'conversationId': conversationId,
        };
      }
      return null;
    } catch (e) {
      _setError('Failed to get conversation info: ${e.toString()}');
      return null;
    }
  }

  // Block user (placeholder for future implementation)
  Future<void> blockUser(String userId) async {
    try {
      // Implementation for blocking user
      // This would typically involve updating user's blocked list
      // and preventing messages from blocked users
      _setError('Block feature not implemented yet');
    } catch (e) {
      _setError('Failed to block user: ${e.toString()}');
    }
  }

  // Unblock user (placeholder for future implementation)
  Future<void> unblockUser(String userId) async {
    try {
      // Implementation for unblocking user
      _setError('Unblock feature not implemented yet');
    } catch (e) {
      _setError('Failed to unblock user: ${e.toString()}');
    }
  }

  // Get blocked users list (placeholder)
  Future<List<String>> getBlockedUsers() async {
    try {
      // Return list of blocked user IDs
      return [];
    } catch (e) {
      _setError('Failed to get blocked users: ${e.toString()}');
      return [];
    }
  }

  void clearError() {
    _setError(null);
  }

  void clearMessages() {
    _messages = [];
    _activeConversationId = null;
    notifyListeners();
  }

  void clearConversations() {
    _conversations = [];
    notifyListeners();
  }

  // Refresh conversations
  Future<void> refreshConversations() async {
    await loadConversations();
  }

  // Refresh messages for active conversation
  Future<void> refreshMessages() async {
    if (_activeConversationId != null) {
      await loadMessages(_activeConversationId!);
    }
  }

  // Dispose method to clean up resources
  @override
  void dispose() {
    clearMessages();
    clearConversations();
    super.dispose();
  }
}