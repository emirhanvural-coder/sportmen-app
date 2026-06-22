import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/post_card.dart';

class PostDetailScreen extends StatefulWidget {
  final List<DocumentSnapshot> posts; // Liste hali
  final int initialIndex; // Kaçıncı sıradan başlayacak

  // 1. STANDART MOD (Liste alır - Keşfet, Profil için)
  const PostDetailScreen({
    super.key,
    required this.posts,
    required this.initialIndex,
  });

  // 2. TEKİL MOD (Bildirimler, Arama Sonucu için pratik kullanım)
  PostDetailScreen.single({
    super.key, 
    required DocumentSnapshot post
  }) : posts = [post],
       initialIndex = 0;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    // Tıklanan fotoğraftan başlat
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Gönderiler", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white), // Geri okunun rengi
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // Dikey kaydırma (Reels/TikTok tarzı)
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical, 
        itemCount: widget.posts.length,
        itemBuilder: (context, index) {
          return SizedBox(
            height: MediaQuery.of(context).size.height, // Tam ekran kaplasın
            child: Center(
              // PostCard zaten içinde yeşil tık kontrolünü yapıyor.
              child: PostCard(post: widget.posts[index]),
            ),
          );
        },
      ),
    );
  }
}