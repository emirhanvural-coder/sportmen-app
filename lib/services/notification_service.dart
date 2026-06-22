import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initNotifications() async {
    // 1. İzin İste
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Token Al ve Kaydet
    String? token = await _messaging.getToken();
    if (token != null) {
      _saveTokenToFirestore(token);
    }

    // --- BURADA CONST KALDIRILDI ---
    var initializationSettingsAndroid = const AndroidInitializationSettings('@drawable/ic_notification');

    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    // 3. Başlatma (v20 Standartı)
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Bildirime tıklanınca yapılacaklar
      },
    );

    // 4. Dinleyici
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
  }

  void _saveTokenToFirestore(String token) async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': token,
      });
    }
  }

  void _showLocalNotification(RemoteMessage message) async {
    // --- BURADA DA CONST YERİNE VAR KULLANDIK ---
    var androidPlatformChannelSpecifics = const AndroidNotificationDetails(
      'high_importance_channel', 
      'Önemli Bildirimler',
      channelDescription: 'Bu kanal uygulama bildirimleri içindir.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    var platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    // show metodu v20'de bu parametreleri bekler
    await _localNotifications.show(
      message.hashCode, 
      message.notification?.title ?? "Sportmen",
      message.notification?.body ?? "Yeni bir bildiriminiz var.",
      platformChannelSpecifics,
    );
  }
}