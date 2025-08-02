import 'package:cloud_firestore/cloud_firestore.dart';
import 'message.dart';

class ChatConversation {
  final String id;
  final List<String> participantIds;
  final Message? lastMessage;
  final Map<String, int> unreadCounts;
  final Timestamp? updatedAt;
  final Timestamp? createdAt;
  final bool isGroup;
  final String? groupName;
  final String? groupImage;
  final String? adminId;

  ChatConversation({
    required this.id,
    required this.participantIds,
    this.lastMessage,
    this.unreadCounts = const {},
    this.updatedAt,
    this.createdAt,
    this.isGroup = false,
    this.groupName,
    this.groupImage,
    this.adminId,
  });

  factory ChatConversation.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChatConversation(
      id: doc.id,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      lastMessage: data['lastMessage'] != null ? Message.fromMap(data['lastMessage'], '') : null,
      unreadCounts: Map<String, int>.from(data['unreadCounts'] ?? {}),
      updatedAt: data['updatedAt'] as Timestamp?,
      createdAt: data['createdAt'] as Timestamp?,
      isGroup: data['isGroup'] ?? false,
      groupName: data['groupName'],
      groupImage: data['groupImage'],
      adminId: data['adminId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participantIds': participantIds,
      'lastMessage': lastMessage?.toMap(),
      'unreadCounts': unreadCounts,
      'updatedAt': updatedAt,
      'createdAt': createdAt,
      'isGroup': isGroup,
      'groupName': groupName,
      'groupImage': groupImage,
      'adminId': adminId,
    };
  }

  // Get unread count for user
  int getUnreadCount(String userId) {
    return unreadCounts[userId] ?? 0;
  }

  // Check if user is admin
  bool isAdmin(String userId) {
    return adminId == userId;
  }

  // Get other user ID in 1-on-1 chat
  String getOtherUserId(String currentUserId) {
    return participantIds.firstWhere((id) => id != currentUserId, orElse: () => '');
  }

  // Create 1-on-1 conversation
  static Future<ChatConversation?> createChat(String user1Id, String user2Id) async {
    try {
      List<String> sortedIds = [user1Id, user2Id]..sort();
      String chatId = '${sortedIds[0]}_${sortedIds[1]}';

      ChatConversation chat = ChatConversation(
        id: chatId,
        participantIds: [user1Id, user2Id],
        unreadCounts: {user1Id: 0, user2Id: 0},
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(chatId)
          .set(chat.toMap());

      return chat;
    } catch (e) {
      return null;
    }
  }

  // Get user's conversations
  static Future<List<ChatConversation>> getUserChats(String userId) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .where('participantIds', arrayContains: userId)
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => ChatConversation.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  // Update last message
  Future<bool> updateLastMessage(Message message) async {
    try {
      await FirebaseFirestore.instance.collection('conversations').doc(id).update({
        'lastMessage': message.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}