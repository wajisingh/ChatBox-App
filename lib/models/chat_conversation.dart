import 'package:cloud_firestore/cloud_firestore.dart';
import 'message.dart';
import 'user.dart';

class ChatConversation {
  final String id;
  final List<String> participantIds;
  final Message? lastMessage;
  final Map<String, int> unreadCounts;
  final Timestamp? updatedAt;
  final User? otherUser; // For 1-on-1 chats

  ChatConversation({
    required this.id,
    required this.participantIds,
    this.lastMessage,
    this.unreadCounts = const {},
    this.updatedAt,
    this.otherUser,
  });

  factory ChatConversation.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChatConversation(
      id: doc.id,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      lastMessage: data['lastMessage'] != null
          ? Message.fromMap(data['lastMessage'], '')
          : null,
      unreadCounts: Map<String, int>.from(data['unreadCounts'] ?? {}),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participantIds': participantIds,
      'lastMessage': lastMessage?.toMap(),
      'unreadCounts': unreadCounts,
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    };
  }

  ChatConversation copyWith({
    String? id,
    List<String>? participantIds,
    Message? lastMessage,
    Map<String, int>? unreadCounts,
    Timestamp? updatedAt,
    User? otherUser,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      participantIds: participantIds ?? this.participantIds,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      updatedAt: updatedAt ?? this.updatedAt,
      otherUser: otherUser ?? this.otherUser,
    );
  }

  int getUnreadCount(String userId) {
    return unreadCounts[userId] ?? 0;
  }

  bool hasUnreadMessages(String userId) {
    return getUnreadCount(userId) > 0;
  }

  String getOtherParticipantId(String currentUserId) {
    return participantIds.firstWhere(
          (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  bool isGroupChat() {
    return participantIds.length > 2;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatConversation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}