import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import '../screens/post_detail_screen.dart'; // Detay sayfasına gitmek için

class PostGridItem extends StatefulWidget {
  final DocumentSnapshot post;
  final List<DocumentSnapshot> allPosts; // Kaydırma için tüm liste
  final int index; // Şu anki sıra

  const PostGridItem({
    super.key,
    required this.post,
    required this.allPosts,
    required this.index,
  });

  @override
  State<PostGridItem> createState() => _PostGridItemState();
}

class _PostGridItemState extends State<PostGridItem> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool isLikeAnimating = false; // Kalp animasyonu için
  VideoPlayerController? _videoController;
  bool _initialized = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    var data = widget.post.data() as Map<String, dynamic>;
    String mediaType = data['mediaType'] ?? 'image';

    // Eğer videoy ise ilk karesini yükle (Önizleme için)
    if (mediaType == 'video') {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(data['imageUrl']))
        ..initialize().then((_) {
          if (_isDisposed || !mounted) return;
          setState(() => _initialized = true);
          // 0. saniyeye git ve dur (Kapak resmi gibi)
          _videoController!.seekTo(Duration.zero);
          _videoController!.pause();
        }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _videoController?.dispose();
    super.dispose();
  }

  // --- BEĞENİ VE BİLDİRİM FONKSİYONU ---
  void _toggleLike() async {
    // 1. Animasyonu Başlat (Ekranda kalp çıksın)
    setState(() { isLikeAnimating = true; });
    
    // 0.8 saniye sonra kalbi gizle
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() { isLikeAnimating = false; });
    });

    // 2. Veritabanı İşlemleri
    var data = widget.post.data() as Map<String, dynamic>;
    List likes = data['likes'] ?? [];
    String postId = widget.post.id;
    String postOwnerId = data['uid'];

    if (likes.contains(currentUid)) {
      // Zaten beğenilmişse geri al
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'likes': FieldValue.arrayRemove([currentUid]),
      });
    } else {
      // Beğen
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'likes': FieldValue.arrayUnion([currentUid]),
      });

      // Bildirim Gönder (Kendine değilse)
      if (postOwnerId != currentUid) {
        try {
          var userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
          if (userDoc.exists) {
            var userData = userDoc.data() as Map<String, dynamic>;
            await FirebaseFirestore.instance.collection('users').doc(postOwnerId).collection('notifications').add({
              'type': 'like',
              'senderId': currentUid,
              'senderName': userData['name'] ?? 'İsimsiz',
              'senderImage': userData['profileImage'],
              'postId': postId,
              'postImageUrl': data['imageUrl'],
              'mediaType': data['mediaType'] ?? 'image', // Video mu resim mi?
              'message': 'gönderini beğendi.',
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var data = widget.post.data() as Map<String, dynamic>;
    String mediaType = data['mediaType'] ?? 'image';
    String url = data['imageUrl'];

    return GestureDetector(
      // TEK TIKLAMA: Detay Sayfasına Git (Kaydırmalı)
      onTap: () {
        Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(
              posts: widget.allPosts,
              initialIndex: widget.index,
            )
          )
        );
      },
      // ÇİFT TIKLAMA: Beğen
      onDoubleTap: _toggleLike,
      
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          // 1. GÖRSEL / VİDEO ÖNİZLEME
          mediaType == 'video'
              ? _buildVideoPreview()
              : Image.network(url, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[900])),
          
          // 2. VİDEO İKONU (Sağ Üstte küçük ikon)
          if (mediaType == 'video')
            const Positioned(
              top: 5, right: 5,
              child: Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
            ),

          // 3. KALP ANİMASYONU (Ortada çıkan büyük beyaz kalp)
          if (isLikeAnimating)
            const Icon(Icons.favorite, color: Colors.white, size: 80),
        ],
      ),
    );
  }

  // Video Önizleme Kutusu
  Widget _buildVideoPreview() {
    if (!_initialized || _videoController == null) {
      return Container(color: Colors.grey[900], child: const Icon(Icons.videocam, color: Colors.white24));
    }
    // ClipRect ile taşmayı engelliyoruz
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: _videoController!.value.size.width,
          height: _videoController!.value.size.height,
          child: VideoPlayer(_videoController!),
        ),
      ),
    );
  }
}