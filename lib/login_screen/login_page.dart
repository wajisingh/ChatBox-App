import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../login_screen/signup_screen.dart';
import '../home/home_screen.dart';
import '../provider/auth_provider.dart';
import '../models/app_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Listen to auth state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.addListener(_authStateListener);
    });
  }

  @override
  void dispose() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.removeListener(_authStateListener);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _authStateListener() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Navigate to home screen when successfully authenticated
    if (authProvider.isAuthenticated && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Clear any previous errors
    authProvider.clearError();

    final success = await authProvider.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!success && mounted) {
      // Show error message using SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? "Login failed"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  Hero(
                    tag: 'login',
                    child: Stack(
                      children: [
                        // Background image
                        Image.asset('assets/img/1_img.png'),

                        // Overlapping logo (centered)
                        Center(
                          child: Image.asset('assets/img/2_img.png'),
                        ),
                        Positioned(
                          top: 45,  // 45px from top
                          left: 33,  // 45px from left
                          child: Container(
                            width: 300,  // Match image width
                            height: 130, // Match image height
                            child: Center(  // Centers the image within the positioned container
                              child: Image.asset(
                                'assets/img/logo_img_2.png',
                                width: 300,
                                height: 130,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 40),
                      Text(
                        "Login in to Chatbox ",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Show error message if any
                  if (authProvider.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                authProvider.errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => authProvider.clearError(),
                              child: Icon(Icons.close, color: Colors.red.shade600, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (authProvider.errorMessage != null)
                    const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            enabled: !authProvider.isLoading,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: "Your Email",
                              hintText: "Enter your email...",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Email is required';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _passwordController,
                            enabled: !authProvider.isLoading,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: "Password",
                              hintText: "Enter password...",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  GestureDetector(
                    onTap: authProvider.isLoading ? null : _login,
                    child: Container(
                      width: 327,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: authProvider.isLoading
                            ? const Color(0xff5a0fc8).withOpacity(0.6)
                            : const Color(0xff5a0fc8),
                      ),
                      child: Center(
                        child: authProvider.isLoading
                            ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Text(
                          "Login",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      GestureDetector(
                        onTap: authProvider.isLoading ? null : () {
                          // Clear any errors before navigating
                          authProvider.clearError();
                          Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SignupScreen())
                          );
                        },
                        child: Text(
                          " Sign Up",
                          style: TextStyle(
                              color: authProvider.isLoading
                                  ? const Color(0xff5a0fc8).withOpacity(0.6)
                                  : const Color(0xff5a0fc8),
                              fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}