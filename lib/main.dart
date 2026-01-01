import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'providers/expense_provider.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'services/auth_service.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/profile_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}


void checkAuth() {
  final auth = FirebaseAuth.instance;
  print('Current user: ${auth.currentUser?.email ?? "No user"}');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ExpenseProvider(),
      child: MaterialApp(
        title: 'Expense Tracker',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const AuthWrapper(),
        routes: {
          '/register': (context) => RegisterScreen(),
          '/home': (context) => HomeScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/profile': (context) => const ProfileScreen()
        },
      ),
    );
  }
}
  class AuthWrapper extends StatelessWidget {
    const AuthWrapper({super.key});

    @override
    Widget build(BuildContext context) {
      final authService = AuthService();

      return StreamBuilder<User?>(
        stream: authService.authStateChanges,
        builder: (context, snapshot) {
        // Loading inicial
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
            );
          }

          // Utilizador autenticado
          if (snapshot.hasData) {
            return HomeScreen();
          }

          // Não autenticado
          return LoginScreen();
        },
      );
    }
  }

