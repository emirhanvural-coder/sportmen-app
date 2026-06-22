import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spor/screens/home_screen.dart';
import 'login_screen.dart'; // Giriş ekranı

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 3 Saniyelik bir zamanlayıcı başlat (GIF süresi kadar)
    Timer(const Duration(seconds: 3), () {
      _checkUserAndNavigate();
    });
  }

  void _checkUserAndNavigate() {
    // Kullanıcı zaten giriş yapmış mı kontrol et
    User? user = FirebaseAuth.instance.currentUser;

    if (mounted) {
      if (user != null) {
        // Giriş yapmışsa -> Ana Sayfaya (MainLayout) git
        // pushReplacement kullanıyoruz ki Geri tuşuna basınca Splash'e dönmesin.
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const HomeScreen())
        );
      } else {
        // Giriş yapmamışsa -> Login Ekranına git
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const LoginScreen())
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Arka plan siyah (GIF ile uyumlu olsun)
      body: Center(
        // GIF'ini burada gösteriyoruz
        child: Image.asset(
          'assets/loading.gif', 
          width: 150, // Boyutu kendine göre ayarla
          height: 150,
        ),
      ),
    );
  }
}