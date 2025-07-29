import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../login_screen/login_page.dart';
import '../home/home_screen.dart';
import '../provider/auth_provider.dart';

import '../models/app_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  void _initializeApp() async {
    // Wait for 2 seconds to show splash screen
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      _checkAuthenticationState();
    }
  }

  void _checkAuthenticationState() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Listen to auth state changes
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (authProvider.authStatus != AuthStatus.initial) {
        timer.cancel();
        _navigateBasedOnAuthState(authProvider.authStatus);
      }
    });
  }

  void _navigateBasedOnAuthState(AuthStatus authStatus) {
    if (!mounted) return;

    switch (authStatus) {
      case AuthStatus.authenticated:
      // User is logged in, go to home screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        break;

      case AuthStatus.unauthenticated:
      // User is not logged in, go to login screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
        break;

      case AuthStatus.loading:
      // Still checking auth state, stay on splash
        break;

      case AuthStatus.initial:
      // Initial state, wait for auth provider to initialize
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffAD87E4),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(
                child: Image.asset(
                  "assets/img/logo_img_2.png",
                  width: 154,
                  height: 123,
                ),
              ),
              const SizedBox(height: 30),

              // Show loading indicator and status
              if (authProvider.authStatus == AuthStatus.loading ||
                  authProvider.authStatus == AuthStatus.initial)
                Column(
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Loading...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

              // Show error if any
              if (authProvider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    authProvider.errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}