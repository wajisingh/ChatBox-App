import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String? profilePictureUrl;
  final bool isOnline;
  final Timestamp? lastSeen;
  final Timestamp? createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.profilePictureUrl,
    this.isOnline = false,
    this.lastSeen,
    this.createdAt,
  });

  factory User.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return User(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      profilePictureUrl: data['profilePictureUrl'],
      isOnline: data['isOnline'] ?? false,
      lastSeen: data['lastSeen'] as Timestamp?,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  factory User.fromMap(Map<String, dynamic> map, String id) {
    return User(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      profilePictureUrl: map['profilePictureUrl'],
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] as Timestamp?,
      createdAt: map['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'profilePictureUrl': profilePictureUrl,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? profilePictureUrl,
    bool? isOnline,
    Timestamp? lastSeen,
    Timestamp? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}