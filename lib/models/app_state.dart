import 'package:chatbox/models/user.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
}

enum ChatStatus {
  initial,
  loading,
  loaded,
  error,
}

class AppState {
  final AuthStatus authStatus;
  final ChatStatus chatStatus;
  final User? currentUser;
  final String? errorMessage;
  final bool isLoading;

  AppState({
    this.authStatus = AuthStatus.initial,
    this.chatStatus = ChatStatus.initial,
    this.currentUser,
    this.errorMessage,
    this.isLoading = false,
  });

  AppState copyWith({
    AuthStatus? authStatus,
    ChatStatus? chatStatus,
    User? currentUser,
    String? errorMessage,
    bool? isLoading,
  }) {
    return AppState(
      authStatus: authStatus ?? this.authStatus,
      chatStatus: chatStatus ?? this.chatStatus,
      currentUser: currentUser ?? this.currentUser,
      errorMessage: errorMessage ?? this.errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool get isAuthenticated => authStatus == AuthStatus.authenticated;
  bool get isUnauthenticated => authStatus == AuthStatus.unauthenticated;
  bool get isAuthLoading => authStatus == AuthStatus.loading;
}