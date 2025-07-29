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
        await _loadUserData(firebaseUser.uid);
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
          'lastSeen': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Error updating online status: $e');
      }
    }
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Create user document in Firestore
        final user = User(
          id: credential.user!.uid,
          name: name,
          email: email,
          isOnline: true,
          createdAt: Timestamp.now(),
        );

        await _firestore.collection('users').doc(user.id).set(user.toMap());
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

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    try {
      _setLoading(true);
      await _updateUserOnlineStatus(false);
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