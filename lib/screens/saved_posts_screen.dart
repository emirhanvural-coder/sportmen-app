import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'post_detail_screen.dart';
import '../widgets/custom_loading.dart';

class SavedPostsScreen extends StatelessWidget {
  const SavedPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    String currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Kaydedilenler", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .collection('saved_posts')
            .orderBy('savedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CustomLoading());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Henüz kaydedilmiş gönderi yok.", style: TextStyle(color: Colors.grey)));
          }

          return GridView.builder(
            itemCount: snapshot.data!.docs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemBuilder: (context, index) {
              var savedDoc = snapshot.data!.docs[index];
              var data = savedDoc.data() as Map<String, dynamic>;
              String postId = data['postId'];
              String mediaType = data['mediaType'] ?? 'image';
              String url = data['imageUrl'] ?? ''; // Null check

              return GestureDetector(
                onTap: () {
                  // Orijinal gönderiyi bulmak için posts koleksiyonuna gidiyoruz
                  FirebaseFirestore.instance.collection('posts').doc(postId).get().then((postDoc) {
                    if (postDoc.exists && context.mounted) {
                      // Detay sayfasına gider (Burada Yeşil Tık Görünür)
                      Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen.single(post: postDoc)));
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu gönderi silinmiş.")));
                      }
                    }
                  });
                },
                child: mediaType == 'video'
                    ? _SavedVideoItem(videoUrl: url)
                    : Image.network(
                        url, 
                        fit: BoxFit.cover,
                        errorBuilder: (c,e,s) => Container(color: Colors.grey[900]),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- KAYDEDİLENLER İÇİN GÜVENLİ VİDEO ÖNİZLEME ---
class _SavedVideoItem extends StatefulWidget {
  final String videoUrl;
  const _SavedVideoItem({required this.videoUrl});

  @override
  State<_SavedVideoItem> createState() => _SavedVideoItemState();
}

class _SavedVideoItemState extends State<_SavedVideoItem> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    // Güvenlik: URL boşsa işlem yapma
    if (widget.videoUrl.isEmpty) return;

    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (_isDisposed || !mounted) return;
        setState(() => _initialized = true);
        if (!_isDisposed) {
          _controller.seekTo(Duration.zero);
          _controller.pause();
        }
      }).catchError((_) {});
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (_initialized) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _isDisposed) {
      return Container(color: Colors.grey[900], child: const Icon(Icons.videocam, color: Colors.white24));
    }
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
          const Positioned(top: 5, right: 5, child: Icon(Icons.play_circle_fill, color: Colors.white, size: 20)),
        ],
      ),
    );
  }
}