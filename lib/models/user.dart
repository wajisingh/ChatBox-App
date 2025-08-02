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

  // Helper method to clean name for use as document ID
  static String cleanNameForId(String name) {
    return name.toLowerCase()
        .trim()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
  }

  // Factory constructor that automatically sets cleaned name as ID
  factory User.withNameAsId({
    required String name,
    required String email,
    String? profilePictureUrl,
    bool isOnline = false,
    Timestamp? lastSeen,
    Timestamp? createdAt,
  }) {
    return User(
      id: cleanNameForId(name),
      name: name,
      email: email,
      profilePictureUrl: profilePictureUrl,
      isOnline: isOnline,
      lastSeen: lastSeen,
      createdAt: createdAt,
    );
  }

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

  // Firestore operations methods

  /// Check if a username is already taken
  static Future<bool> isNameTaken(String name) async {
    String cleanName = cleanNameForId(name);
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(cleanName)
        .get();
    return doc.exists;
  }

  /// Create a new user with name as document ID
  static Future<User?> createUserWithNameAsId({
    required String name,
    required String email,
    String? profilePictureUrl,
    bool isOnline = false,
  }) async {
    try {
      // Check if name is already taken
      if (await isNameTaken(name)) {
        throw Exception('Username "$name" is already taken');
      }

      User newUser = User.withNameAsId(
        name: name,
        email: email,
        profilePictureUrl: profilePictureUrl,
        isOnline: isOnline,
        createdAt: Timestamp.now(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(newUser.id)
          .set(newUser.toMap());

      return newUser;
    } catch (e) {
      print('Error creating user: $e');
      return null;
    }
  }

  /// Get user by name (document ID)
  static Future<User?> getUserByName(String userName) async {
    try {
      String cleanName = cleanNameForId(userName);
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(cleanName)
          .get();

      if (doc.exists) {
        return User.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  /// Get user by document ID directly
  static Future<User?> getUserById(String userId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        return User.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  /// Update user information
  Future<bool> updateUser() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .update(toMap());
      return true;
    } catch (e) {
      print('Error updating user: $e');
      return false;
    }
  }

  /// Update user's online status
  Future<bool> updateOnlineStatus(bool isOnline) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .update({
        'isOnline': isOnline,
        'lastSeen': isOnline ? null : FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating online status: $e');
      return false;
    }
  }

  /// Change username (this will create a new document and delete the old one)
  Future<User?> changeUsername(String newName) async {
    try {
      // Check if new name is available
      if (await isNameTaken(newName)) {
        throw Exception('Username "$newName" is already taken');
      }

      String newCleanName = cleanNameForId(newName);

      // Create updated user with new name and ID
      User updatedUser = copyWith(
        id: newCleanName,
        name: newName,
      );

      // Create new document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(newCleanName)
          .set(updatedUser.toMap());

      // Delete old document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .delete();

      return updatedUser;
    } catch (e) {
      print('Error changing username: $e');
      return null;
    }
  }

  /// Delete user
  Future<bool> deleteUser() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .delete();
      return true;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  /// Search users by name (partial match)
  static Future<List<User>> searchUsersByName(String searchTerm) async {
    try {
      String searchLower = searchTerm.toLowerCase();
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: searchTerm)
          .where('name', isLessThanOrEqualTo: searchTerm + '\uf8ff')
          .get();

      return snapshot.docs
          .map((doc) => User.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  /// Get all online users
  static Future<List<User>> getOnlineUsers() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('isOnline', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => User.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting online users: $e');
      return [];
    }
  }

  /// Get all users
  static Future<List<User>> getAllUsers() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => User.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting all users: $e');
      return [];
    }
  }

  /// Stream of user changes
  static Stream<User?> streamUser(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return User.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Stream of all users
  static Stream<List<User>> streamAllUsers() {
    return FirebaseFirestore.instance
        .collection('users')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => User.fromFirestore(doc))
          .toList();
    });
  }
}