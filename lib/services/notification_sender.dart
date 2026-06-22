import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationSender {
  static final _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  // --- LOGO DEĞİŞKENİ ---
  // Buraya Sportmen uygulamasının logo URL'sini yapıştır. 
  // Örn: Firebase Storage'daki logonun linki.
  static const String _appLogoUrl = 'gs://spor-4cf48.firebasestorage.app/yeni_logo.png';

  static Future<String> _getAccessToken() async {
    final String response = await rootBundle.loadString('service-account.json');
    final data = json.decode(response);
    final accountCredentials = ServiceAccountCredentials.fromJson(data);
    final client = await clientViaServiceAccount(accountCredentials, _scopes);
    final accessToken = client.credentials.accessToken.data;
    client.close();
    return accessToken;
  }

  static Future<void> sendPushNotification({
    required String receiverId,
    required String title,
    required String body,
    String? imageUrl, // Burası artık opsiyonel, gönderilmezse logo basacak
    Map<String, dynamic>? extraData,
  }) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users').doc(receiverId).get();
      
      if (!userDoc.exists) return;
      
      String? token = userDoc.get('fcmToken');
      if (token == null || token.isEmpty) return;

      final accessToken = await _getAccessToken();
      const String url = 'https://fcm.googleapis.com/v1/projects/spor-4cf48/messages:send';

      // --- LOGO MANTIĞI ---
      // Eğer dışarıdan özel bir resim (imageUrl) gelmezse, varsayılan uygulama logosunu kullan
      final String finalImage = (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : _appLogoUrl;

      final Map<String, dynamic> messagePayload = {
        'message': {
          'token': token,
          'notification': {
            'title': title,
            'body': body,
            'image': finalImage, // Burada uygulama logosu görünecek
          },
          'data': extraData ?? {'type': 'default'},
          'android': {
            'priority': 'high',
            'notification': {
              'channel_id': 'high_importance_channel',
              'sound': 'default',
              'icon': 'ic_notification', // Assets'teki (res/drawable) ikonun adı
            }
          }
        }
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(messagePayload),
      );

      if (response.statusCode == 200) {
        print("Logo içerikli bildirim başarıyla gönderildi.");
      } else {
        print("FCM Hatası: ${response.body}");
      }
    } catch (e) {
      print("Bildirim Hatası: $e");
    }
  }
}