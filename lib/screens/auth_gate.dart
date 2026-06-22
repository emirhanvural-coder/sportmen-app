import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:spor/screens/home_screen.dart';
import 'login_screen.dart';
import '../widgets/custom_loading.dart';
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: const CustomLoading(),
            ),
          );
        }

        if (snapshot.hasData) {
          return const HomeScreen(); // DEĞİŞEN KISIM BURASI
        }

        return const LoginScreen();
      },
    );
  }
}