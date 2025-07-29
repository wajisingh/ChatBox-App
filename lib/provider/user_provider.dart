import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class UserProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<User> _users = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<User> get users => _users;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // Load all users (excluding current user)
  Future<void> loadUsers({String? excludeUserId}) async {
    try {
      _setLoading(true);
      _setError(null);

      Query query = _firestore.collection('users');

      if (excludeUserId != null) {
        query = query.where(FieldPath.documentId, isNotEqualTo: excludeUserId);
      }

      final snapshot = await query.get();
      _users = snapshot.docs.map((doc) => User.fromFirestore(doc)).toList();

      notifyListeners();
    } catch (e) {
      _setError('Failed to load users: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Get real-time stream of users (excluding current user)
  Stream<List<User>> getUsersStream({String? excludeUserId}) {
    Query query = _firestore.collection('users');

    if (excludeUserId != null) {
      query = query.where(FieldPath.documentId, isNotEqualTo: excludeUserId);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => User.fromFirestore(doc)).toList());
  }

  // Get online users stream
  Stream<List<User>> getOnlineUsersStream({String? excludeUserId}) {
    Query query = _firestore.collection('users').where('isOnline', isEqualTo: true);

    if (excludeUserId != null) {
      query = query.where(FieldPath.documentId, isNotEqualTo: excludeUserId);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => User.fromFirestore(doc)).toList());
  }

  // Get user by ID
  Future<User?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return User.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      _setError('Failed to get user: ${e.toString()}');
      return null;
    }
  }

  // Find user by ID from loaded users list
  User? findUserById(String userId) {
    try {
      return _users.firstWhere((user) => user.id == userId);
    } catch (e) {
      return null;
    }
  }

  // Search users by name
  List<User> searchUsers(String query, {String? excludeUserId}) {
    if (query.isEmpty) return _users;

    final lowercaseQuery = query.toLowerCase();
    return _users.where((user) {
      final matchesQuery = user.name.toLowerCase().contains(lowercaseQuery) ||
          user.email.toLowerCase().contains(lowercaseQuery);
      final notExcluded = excludeUserId == null || user.id != excludeUserId;
      return matchesQuery && notExcluded;
    }).toList();
  }

  // Get online users from loaded list
  List<User> getOnlineUsers({String? excludeUserId}) {
    return _users.where((user) {
      final isOnline = user.isOnline;
      final notExcluded = excludeUserId == null || user.id != excludeUserId;
      return isOnline && notExcluded;
    }).toList();
  }

  // Get offline users from loaded list
  List<User> getOfflineUsers({String? excludeUserId}) {
    return _users.where((user) {
      final isOffline = !user.isOnline;
      final notExcluded = excludeUserId == null || user.id != excludeUserId;
      return isOffline && notExcluded;
    }).toList();
  }

  // Update user online status (usually called by AuthProvider)
  Future<void> updateUserOnlineStatus(String userId, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      // Update local list if user exists
      final index = _users.indexWhere((user) => user.id == userId);
      if (index != -1) {
        _users[index] = _users[index].copyWith(
          isOnline: isOnline,
          lastSeen: Timestamp.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to update online status: ${e.toString()}');
    }
  }

  // Update user profile
  Future<bool> updateUserProfile({
    required String userId,
    String? name,
    String? profilePictureUrl,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      Map<String, dynamic> updateData = {};

      if (name != null) updateData['name'] = name;
      if (profilePictureUrl != null) updateData['profilePictureUrl'] = profilePictureUrl;

      if (updateData.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update(updateData);

        // Update local list if user exists
        final index = _users.indexWhere((user) => user.id == userId);
        if (index != -1) {
          _users[index] = _users[index].copyWith(
            name: name ?? _users[index].name,
            profilePictureUrl: profilePictureUrl ?? _users[index].profilePictureUrl,
          );
          notifyListeners();
        }
      }

      return true;
    } catch (e) {
      _setError('Failed to update profile: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get user count
  int get userCount => _users.length;

  // Get online user count
  int get onlineUserCount => _users.where((user) => user.isOnline).length;

  // Check if user is online
  bool isUserOnline(String userId) {
    final user = findUserById(userId);
    return user?.isOnline ?? false;
  }

  // Get user's last seen
  String getUserLastSeen(String userId) {
    final user = findUserById(userId);
    if (user == null || user.lastSeen == null) return 'Never';

    final lastSeen = user.lastSeen!.toDate();
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (user.isOnline) {
      return 'Online';
    } else if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  // Refresh users list
  Future<void> refreshUsers({String? excludeUserId}) async {
    await loadUsers(excludeUserId: excludeUserId);
  }

  // Clear error
  void clearError() {
    _setError(null);
  }

  // Clear users list
  void clearUsers() {
    _users = [];
    notifyListeners();
  }
}