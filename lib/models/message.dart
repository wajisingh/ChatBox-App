import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final Timestamp? timestamp;
  final bool isRead;
  final String? senderName;
  final String? messageType; // 'text', 'image', 'file' etc.

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.timestamp,
    this.isRead = false,
    this.senderName,
    this.messageType = 'text',
  });

  // Create Message from Firestore document
  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      message: data['message'] ?? '',
      timestamp: data['timestamp'] as Timestamp?,
      isRead: data['isRead'] ?? false,
      senderName: data['senderName'],
      messageType: data['messageType'] ?? 'text',
    );
  }

  // Create Message from Map
  factory Message.fromMap(Map<String, dynamic> map, String id) {
    return Message(
      id: id,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      message: map['message'] ?? '',
      timestamp: map['timestamp'] as Timestamp?,
      isRead: map['isRead'] ?? false,
      senderName: map['senderName'],
      messageType: map['messageType'] ?? 'text',
    );
  }

  // Convert Message to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
      'isRead': isRead,
      'senderName': senderName,
      'messageType': messageType,
    };
  }

  // Convert Message to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp?.millisecondsSinceEpoch,
      'isRead': isRead,
      'senderName': senderName,
      'messageType': messageType,
    };
  }

  // Create copy of Message with updated fields
  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? message,
    Timestamp? timestamp,
    bool? isRead,
    String? senderName,
    String? messageType,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      senderName: senderName ?? this.senderName,
      messageType: messageType ?? this.messageType,
    );
  }

  // Check if message is sent by current user
  bool isSentByUser(String currentUserId) {
    return senderId == currentUserId;
  }

  // Format timestamp to readable time
  String getFormattedTime() {
    if (timestamp == null) return '';

    final dateTime = timestamp!.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    // If message is from today, show only time
    if (messageDate == today) {
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    // If message is from yesterday
    final yesterday = today.subtract(Duration(days: 1));
    if (messageDate == yesterday) {
      return 'Yesterday';
    }

    // If message is older, show date
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    return '$day/$month/$year';
  }

  // Get formatted date for message grouping
  String getFormattedDate() {
    if (timestamp == null) return '';

    final dateTime = timestamp!.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return 'Today';
    }

    final yesterday = today.subtract(Duration(days: 1));
    if (messageDate == yesterday) {
      return 'Yesterday';
    }

    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    return '$day/$month/$year';
  }

  @override
  String toString() {
    return 'Message{id: $id, senderId: $senderId, receiverId: $receiverId, message: $message, timestamp: $timestamp, isRead: $isRead, messageType: $messageType}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message &&
        other.id == id &&
        other.senderId == senderId &&
        other.receiverId == receiverId &&
        other.message == message &&
        other.isRead == isRead &&
        other.messageType == messageType;
  }

  @override
  int get hashCode {
    return id.hashCode ^
    senderId.hashCode ^
    receiverId.hashCode ^
    message.hashCode ^
    isRead.hashCode ^
    messageType.hashCode;
  }
}