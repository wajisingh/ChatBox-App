import 'package:chatbox/provider/auth_provider.dart';
import 'package:chatbox/provider/chat_provider.dart';
import 'package:chatbox/provider/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'splashscreen/splash_screen.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Authentication Provider - handles login/logout/signup
        ChangeNotifierProvider(
          create: (context) => AuthProvider(),
        ),

        // User Provider - handles user data and user lists
        ChangeNotifierProvider(
          create: (context) => UserProvider(),
        ),

        // Chat Provider - handles messages and conversations
        // It depends on AuthProvider to get current user
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (context) => ChatProvider(),
          update: (context, authProvider, chatProvider) =>
          chatProvider!..updateUser(authProvider.currentUser),
        ),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(),
      ),
    );
  }
}