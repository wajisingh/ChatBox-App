import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/app_state.dart';

class AuthProvider extends ChangeNotifier {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;
  AuthStatus _authStatus = AuthStatus.initial;
  String? _errorMessage;
  bool _isLoading = false;

  // Getters
  User? get currentUser => _currentUser;
  AuthStatus get authStatus => _authStatus;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _authStatus == AuthStatus.authenticated;

  AuthProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    _auth.authStateChanges().listen((firebase_auth.User? firebaseUser) async {
      if (firebaseUser != null) {
        // Try to load user by display name (which should be the cleaned name)
        String? displayName = firebaseUser.displayName;
        if (displayName != null) {
          String cleanedName = User.cleanNameForId(displayName);
          await _loadUserDataByName(cleanedName);
        } else {
          // Fallback: try to load by UID (for existing users)
          await _loadUserData(firebaseUser.uid);
        }
        _setAuthStatus(AuthStatus.authenticated);
      } else {
        _currentUser = null;
        _setAuthStatus(AuthStatus.unauthenticated);
      }
    });
  }

  void _setAuthStatus(AuthStatus status) {
    _authStatus = status;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // Load user data by name (new method)
  Future<void> _loadUserDataByName(String userName) async {
    try {
      final doc = await _firestore.collection('users').doc(userName).get();
      if (doc.exists) {
        _currentUser = User.fromFirestore(doc);
        // Update user online status
        await _updateUserOnlineStatus(true);
      }
    } catch (e) {
      print('Failed to load user data by name: ${e.toString()}');
      _setError('Failed to load user data: ${e.toString()}');
    }
  }

  // Keep old method for backward compatibility
  Future<void> _loadUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        _currentUser = User.fromFirestore(doc);
        // Update user online status
        await _updateUserOnlineStatus(true);
      }
    } catch (e) {
      _setError('Failed to load user data: ${e.toString()}');
    }
  }

  Future<void> _updateUserOnlineStatus(bool isOnline) async {
    if (_currentUser != null) {
      try {
        await _firestore.collection('users').doc(_currentUser!.id).update({
          'isOnline': isOnline,
          'lastSeen': isOnline ? null : FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Error updating online status: $e');
      }
    }
  }

  // CORRECTED SIGNUP METHOD - Uses name as document ID
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      // 1. Check if username is already taken
      if (await User.isNameTaken(name)) {
        _setError('Username "$name" is already taken');
        return false;
      }

      // 2. Create Firebase Auth account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // 3. Use cleaned name as document ID (NOT Firebase Auth UID)
        String userId = User.cleanNameForId(name); // "Hammad" -> "hammad"

        // 4. Create user document with name as ID
        final user = User(
          id: userId,  // Use cleaned name as document ID
          name: name,  // Original name
          email: email,
          isOnline: true,
          createdAt: Timestamp.now(),
        );

        // 5. Save to Firestore with name as document ID
        await _firestore.collection('users').doc(userId).set(user.toMap());

        // 6. Update Firebase Auth display name for future reference
        await credential.user!.updateDisplayName(name);

        _currentUser = user;
        _setAuthStatus(AuthStatus.authenticated);
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      // Step 1: Sign in with Firebase Auth
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        _setError("No Firebase user returned.");
        return false;
      }

      // Step 2: Get user display name
      final displayName = firebaseUser.displayName;
      if (displayName == null || displayName.trim().isEmpty) {
        _setError("No display name found for Firebase user.");
        return false;
      }

      // Step 3: Fetch Firestore user using display name
      final cleanId = User.cleanNameForId(displayName);
      final snapshot = await _firestore.collection('users').doc(cleanId).get();

      if (!snapshot.exists) {
        _setError("User not found in Firestore.");
        return false;
      }

      // Step 4: Parse and set user
      _currentUser = User.fromFirestore(snapshot);
      _setAuthStatus(AuthStatus.authenticated);

      return true;
    } catch (e) {
      _setError("Login error: ${e.toString()}");
      return false;
    } finally {
      _setLoading(false);
    }
  }


  Future<void> signOut() async {
    try {
      _setLoading(true);

      // Update status in background (don't wait)
      if (_currentUser != null) {
        _updateUserOnlineStatus(false).catchError((_) {});
      }

      // Sign out immediately
      await _auth.signOut();
      _currentUser = null;
      _setAuthStatus(AuthStatus.unauthenticated);

    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      _setLoading(true);
      _setError(null);
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    _setError(null);
  }
}