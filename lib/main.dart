import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. FİREBASE ÇAKIŞMA KONTROLÜ
  // Eğer Firebase zaten varsa hata verme, yoksa başlat.
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint("Firebase zaten hazır veya hata: $e");
  }

  // 2. DEBUG TOKEN ÜRETİCİ (Asenkron - Siyah ekranı engeller)
  // .then kullanarak ana akışı (runApp) bekletmiyoruz.
  FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  ).then((_) {
    // Burası çalıştığında terminale o meşhur token düşecek.
    debugPrint("App Check Debug Aktif Edildi.");
  }).catchError((e) {
    debugPrint("App Check Hatası: $e");
  });

  // 3. Bildirim servisi
  NotificationService().initNotifications().catchError((e) => debugPrint(e.toString()));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override 
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sportmen',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Colors.greenAccent,
          secondary: Colors.greenAccent,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}