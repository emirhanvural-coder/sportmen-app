import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data'; 
import 'package:video_thumbnail/video_thumbnail.dart'; 
import 'post_detail_screen.dart';
import 'other_profile_screen.dart';
import '../widgets/custom_loading.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _markNotificationsAsRead();
  }

  void _markNotificationsAsRead() async {
    var collection = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .collection('notifications');

    var snapshot = await collection.get();

    if (snapshot.docs.isNotEmpty) {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      bool needsUpdate = false;
      
      for (var doc in snapshot.docs) {
        var data = doc.data();
        bool isRead = data.containsKey('isRead') ? data['isRead'] : false;

        if (isRead == false) {
          batch.update(doc.reference, {'isRead': true});
          needsUpdate = true;
        }
      }

      if (needsUpdate) {
        await batch.commit();
      }
    }
  }

  void _deleteNotification(String notificationId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Bildirimi Sil", style: TextStyle(color: Colors.white)),
        content: const Text("Bu bildirimi silmek istediğine emin misin?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("SİL", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .collection('notifications')
            .doc(notificationId)
            .delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Bildirim silindi.")),
          );
        }
      } catch (e) {
        debugPrint("Silme hatası: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Bildirimler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CustomLoading());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("Henüz bildirim yok.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var notification = snapshot.data!.docs[index];
              var data = notification.data() as Map<String, dynamic>;

              return _NotificationTile(
                data: data,
                notificationId: notification.id,
                onDelete: () => _deleteNotification(notification.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String notificationId;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.data,
    required this.notificationId,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    String senderId = data['senderId'] ?? '';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(senderId).get(),
      builder: (context, snapshot) {
        bool isVerified = false;
        
        if (snapshot.hasData && snapshot.data!.exists) {
           var userData = snapshot.data!.data() as Map<String, dynamic>;
           isVerified = userData['isVerified'] ?? false;
        }

        return _buildTileContent(context, isVerified);
      },
    );
  }

  Widget _buildTileContent(BuildContext context, bool isVerified) {
    String type = data['type'] ?? ''; 
    String senderName = data['senderName'] ?? 'Biri';
    String? senderImage = data['senderImage'];
    bool isRead = data.containsKey('isRead') ? data['isRead'] : false;
    String? postImageUrl = data['postImageUrl'];

    String text = "";
    IconData icon = Icons.notifications;
    Color iconColor = Colors.white;

    if (type == 'like') {
      text = "gönderini beğendi.";
      icon = Icons.favorite;
      iconColor = Colors.red;
    } else if (type == 'comment') {
      text = "yorum yaptı: ${data['comment'] ?? ''}";
      icon = Icons.comment;
      iconColor = Colors.blue;
    } else if (type == 'follow') {
      text = "seni takip etmeye başladı.";
      icon = Icons.person_add;
      iconColor = Colors.greenAccent;
    }

    Widget? trailingWidget;
    if (postImageUrl != null && postImageUrl.isNotEmpty) {
      trailingWidget = _TrailingMediaWidget(data: data);
    } else {
      trailingWidget = Icon(icon, color: iconColor);
    }

    return Container(
      color: isRead ? Colors.transparent : Colors.greenAccent.withOpacity(0.1),
      child: ListTile(
        onLongPress: onDelete,
        leading: GestureDetector(
          onTap: () {
            if (data.containsKey('senderId')) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfileScreen(userId: data['senderId'])));
            }
          },
          child: CircleAvatar(
            backgroundImage: const AssetImage('assets/logo.jpg'),
            foregroundImage: (senderImage != null && senderImage.isNotEmpty) ? NetworkImage(senderImage) : null,
            backgroundColor: Colors.grey[800],
          ),
        ),
        title: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white),
            children: [
              TextSpan(text: "$senderName ", style: const TextStyle(fontWeight: FontWeight.bold)),
              if (isVerified)
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: EdgeInsets.only(right: 4.0),
                    child: Icon(Icons.verified, color: Colors.greenAccent, size: 14),
                  ),
                ),
              TextSpan(text: text),
            ],
          ),
        ),
        trailing: trailingWidget, 
        onTap: () async {
          if (type == 'follow') {
            Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfileScreen(userId: data['senderId'])));
          } else if (data.containsKey('postId')) {
            try {
              DocumentSnapshot postDoc = await FirebaseFirestore.instance.collection('posts').doc(data['postId']).get();
              if (postDoc.exists && context.mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen.single(post: postDoc)));
              }
            } catch (e) {
                debugPrint("Post hatası: $e");
            }
          }
        },
      ),
    );
  }
}

// --- AKILLI VE ASLA ÇÖKMEYEN MEDYA GÖSTERİCİ (YÜKLEME ANİMASYONLU) ---
class _TrailingMediaWidget extends StatelessWidget {
  final Map<String, dynamic> data;

  const _TrailingMediaWidget({required this.data});

  @override
  Widget build(BuildContext context) {
    String mediaType = data['mediaType'] ?? 'image';
    String? postImageUrl = data['postImageUrl']; 
    String? thumbnailUrl = data['thumbnailUrl']; 
    String? postId = data['postId'];

    if (postImageUrl == null) return const SizedBox.shrink();

    // 1. DURUM: EĞER GÖNDERİ RESİMSE DİREKT GÖSTER
    if (mediaType == 'image') {
      return _buildImage(postImageUrl);
    }

    // 2. DURUM: EĞER GÖNDERİ VİDEOYSA
    if (mediaType == 'video') {
      
      // A) Bildirimde kapak resmi varsa direkt göster
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        return _buildVideoThumbnail(thumbnailUrl);
      }
      
      // B) Bildirimde kapak yoksa Post veritabanına bak
      if (postId != null) {
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('posts').doc(postId).get(),
          builder: (context, snapshot) {
            
            if (snapshot.hasData && snapshot.data!.exists) {
              var postData = snapshot.data!.data() as Map<String, dynamic>;
              String? realThumb = postData['thumbnailUrl'];
              String? realVideoUrl = postData['imageUrl']; 
              
              if (realThumb != null && realThumb.isNotEmpty) {
                return _buildVideoThumbnail(realThumb);
              } else if (realVideoUrl != null && realVideoUrl.isNotEmpty) {
                return _buildNetworkVideoThumbnail(realVideoUrl);
              }
            }
            return _buildFallbackIcon();
          },
        );
      }
      return _buildFallbackIcon();
    }
    return const SizedBox.shrink();
  }

  // YÜKLEME ANİMASYONU EKLENMİŞ RESİM GÖSTERİCİ
  Widget _buildImage(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 44, height: 44,
        child: Image.network(
          url, 
          fit: BoxFit.cover, 
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child; // Resim indiyse göster
            return Container(
              color: Colors.grey[900],
              child: const Center(
                child: SizedBox(
                  width: 15, height: 15, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent)
                ),
              ),
            );
          },
          errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported, color: Colors.grey, size: 20),
        ),
      ),
    );
  }

  // YÜKLEME ANİMASYONU EKLENMİŞ HAZIR KAPAK GÖSTERİCİ
  Widget _buildVideoThumbnail(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 44, height: 44,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url, 
              fit: BoxFit.cover, 
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child; 
                return Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: SizedBox(
                      width: 15, height: 15, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent)
                    ),
                  ),
                );
              },
              errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported, color: Colors.grey, size: 20),
            ),
            Container(
              color: Colors.black38, 
              child: const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 24)),
            ),
          ],
        ),
      ),
    );
  }

  // --- İNTERNETTEKİ VİDEODAN ÇÖKMEDEN ANLIK KAPAK FOTOĞRAFI ÇEKEN FONKSİYON ---
  Widget _buildNetworkVideoThumbnail(String videoUrl) {
    return FutureBuilder<Uint8List?>(
      future: VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 100, 
        quality: 25,   
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(4)),
            child: const Center(child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent))),
          );
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 44, height: 44,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(snapshot.data!, fit: BoxFit.cover),
                  Container(
                    color: Colors.black38,
                    child: const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 24)),
                  ),
                ],
              ),
            ),
          );
        }
        
        return _buildFallbackIcon();
      },
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(4)),
      child: const Center(child: Icon(Icons.play_arrow, color: Colors.white, size: 24)),
    );
  }
}