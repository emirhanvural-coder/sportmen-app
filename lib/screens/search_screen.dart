import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'post_detail_screen.dart'; 
import 'other_profile_screen.dart'; 
import '../widgets/story_avatar.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Kullanıcı ara...",
            hintStyle: const TextStyle(color: Colors.grey),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            suffixIcon: _isSearching
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      // Çarpıya basıldığında güvenli temizleme
                      _searchController.clear();
                      if (mounted) {
                        setState(() {
                          _isSearching = false;
                        });
                      }
                      FocusScope.of(context).unfocus();
                    },
                  )
                : null,
          ),
          onChanged: (val) {
            setState(() {
              _isSearching = val.isNotEmpty;
            });
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isSearching ? _buildUserSearchResults() : _buildExploreGrid(),
          ),
        ],
      ),
    );
  }

  // --- 1. KULLANICI ARAMA (YEŞİL TIK EKLENDİ) ---
  Widget _buildUserSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: _searchController.text)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
        
        var docs = snapshot.data!.docs;
        var filtered = docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String name = data['name'] ?? '';
          return doc.id != currentUid && name.toLowerCase().contains(_searchController.text.toLowerCase());
        }).toList();

        if (filtered.isEmpty) return const Center(child: Text("Kullanıcı bulunamadı.", style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            var data = filtered[index].data() as Map<String, dynamic>;
            // Null kontrolü ile veri çekme
            bool isVerified = data['isVerified'] ?? false; 

            return ListTile(
              leading: StoryAvatar(
                userId: filtered[index].id,
                imageUrl: data['profileImage'], 
                radius: 24,
              ),
              // İsim ve Tık Yanyana
              title: Row(
                children: [
                  Text(data['name'] ?? 'Kullanıcı', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  if (isVerified)
                    const Padding(
                      padding: EdgeInsets.only(left: 4.0),
                      child: Icon(Icons.verified, color: Colors.greenAccent, size: 16),
                    ),
                ],
              ),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfileScreen(userId: filtered[index].id)));
              },
            );
          },
        );
      },
    );
  }

  // --- 2. KEŞFET VİTRİNİ (HATA DÜZELTİLDİ) ---
  Widget _buildExploreGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).limit(50).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));

        var allPosts = snapshot.data!.docs;

        return GridView.builder(
          padding: const EdgeInsets.all(2),
          itemCount: allPosts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemBuilder: (context, index) {
            var doc = allPosts[index];
            var data = doc.data() as Map<String, dynamic>;
            
            // --- HATA DÜZELTME: Null Check ---
            // data['imageUrl'] null gelirse uygulama çöküyordu.
            // ?? '' ekleyerek null gelirse boş string olmasını sağladık.
            String mediaType = data['mediaType'] ?? 'image';
            String url = data['imageUrl'] ?? ''; 

            // Eğer URL boşsa boş kutu göster (Çökmesin)
            if (url.isEmpty) return Container(color: Colors.grey[900]);

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => PostDetailScreen(
                      posts: allPosts, 
                      initialIndex: index, 
                    )
                  )
                );
              },
              child: mediaType == 'video'
                  ? _SearchVideoGridItem(videoUrl: url)
                  : Image.network(url, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[900])),
            );
          },
        );
      },
    );
  }
}

// --- DAHİLİ VİDEO WIDGET ---
class _SearchVideoGridItem extends StatefulWidget {
  final String videoUrl;
  const _SearchVideoGridItem({required this.videoUrl});

  @override
  State<_SearchVideoGridItem> createState() => _SearchVideoGridItemState();
}

class _SearchVideoGridItemState extends State<_SearchVideoGridItem> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    // Video URL boşsa başlatma
    if (widget.videoUrl.isEmpty) return;

    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (_isDisposed || !mounted) return;
        setState(() => _initialized = true);
        if (!_isDisposed) {
          _controller.seekTo(Duration.zero);
          _controller.pause();
        }
      }).catchError((_) {
        // Hata olursa sessizce geç
      });
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