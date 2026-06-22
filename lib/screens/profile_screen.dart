import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart'; 
import '../widgets/post_card.dart';
import '../widgets/story_avatar.dart';
import 'add_story_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart'; 
import 'post_detail_screen.dart';
import 'edit_profile_screen.dart';
import 'admin_panel_screen.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  // ignore: unused_element
  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        // --- DÜZELTME 1: APPBAR BAŞLIĞINDA @KULLANICIADI ---
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.exists) {
              var data = snapshot.data!.data() as Map<String, dynamic>;
              String username = data['name'] ?? "kullanici"; // name artık kullanıcı adını tutuyor
              bool isVerified = data['isVerified'] ?? false;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("@$username", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  if (isVerified)
                    const Padding(
                      padding: EdgeInsets.only(left: 4.0),
                      child: Icon(Icons.verified, color: Colors.greenAccent, size: 16),
                    ),
                ],
              );
            }
            return const Text("Profil");
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddStoryScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
               Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: _buildProfileHeader(),
              ),
              SliverPersistentHeader(
                delegate: _SliverAppBarDelegate(
                  const TabBar(
                    indicatorColor: Colors.white,
                    tabs: [
                      Tab(icon: Icon(Icons.grid_on)),
                      Tab(icon: Icon(Icons.list)),
                    ],
                  ),
                ),
                pinned: true,
              ),
            ];
          },
          body: TabBarView(
            children: [
              _buildGridView(),
              _buildListView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator(color: Colors.greenAccent);
        var data = snapshot.data!.data() as Map<String, dynamic>;
        
        // ignore: unused_local_variable
        bool isVerified = data['isVerified'] ?? false;
        String userRole = data['role'] ?? 'user';
        // --- DÜZELTME 2: GERÇEK İSİM SOYİSİM VERİSİ ---
        String fullName = data['fullName'] ?? "İsim Soyisim"; 

        return Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StoryAvatar(
                    userId: currentUid,
                    imageUrl: data['profileImage'],
                    radius: 40,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn("Gönderi", "${data['postsCount'] ?? 0}"),
                        _buildStatColumn("Takipçi", "${(data['followers'] as List?)?.length ?? 0}"),
                        _buildStatColumn("Takip", "${(data['following'] as List?)?.length ?? 0}"),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              
              // --- DÜZELTME 3: PROFİL RESMİ ALTINDA AD SOYAD ---
              Text(
                fullName, 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
              ),

              if (data['bio'] != null && data['bio'].toString().isNotEmpty)
                 Padding(
                   padding: const EdgeInsets.only(top: 4.0),
                   child: Text(data['bio'], style: const TextStyle(color: Colors.white70)),
                 ),

              const SizedBox(height: 15),
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen()));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[900],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("Profili Düzenle", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  
                  if (userRole == 'admin') ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPanelScreen()));
                        },
                        icon: const Icon(Icons.admin_panel_settings, color: Colors.black, size: 18),
                        label: const Text("Admin", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Diğer widget'lar (_buildStatColumn, _buildGridView vs.) değişmedi, aynen kalıyor.
  Widget _buildStatColumn(String label, String count) {
    return Column(
      children: [
        Text(count, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  Widget _buildGridView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: currentUid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Henüz gönderi yok.", style: TextStyle(color: Colors.grey)));
        }

        var allPosts = snapshot.data!.docs;

        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, 
            crossAxisSpacing: 2, 
            mainAxisSpacing: 2
          ),
          itemCount: allPosts.length,
          itemBuilder: (context, index) {
            var post = allPosts[index];
            var data = post.data() as Map<String, dynamic>;
            String mediaType = data['mediaType'] ?? 'image';
            String url = data['imageUrl'];
            
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => PostDetailScreen(
                      posts: allPosts, 
                      initialIndex: index 
                    )
                  )
                );
              },
              child: mediaType == 'video' 
                ? _VideoGridItem(videoUrl: url) 
                : Image.network(url, fit: BoxFit.cover, errorBuilder: (c,e,s)=> Container(color: Colors.grey[900])),
            );
          },
        );
      },
    );
  }

  Widget _buildListView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: currentUid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
        
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            return PostCard(post: snapshot.data!.docs[index]);
          },
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.black,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class _VideoGridItem extends StatefulWidget {
  final String videoUrl;
  const _VideoGridItem({required this.videoUrl});

  @override
  State<_VideoGridItem> createState() => _VideoGridItemState();
}

class _VideoGridItemState extends State<_VideoGridItem> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (_isDisposed || !mounted) return;

        setState(() {
          _initialized = true;
        });
        
        if (!_isDisposed) {
          _controller.seekTo(Duration.zero);
          _controller.pause();
        }
      });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _isDisposed) {
      return Container(
        color: Colors.grey[900],
        child: const Center(child: Icon(Icons.videocam, color: Colors.white24)),
      );
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
          const Positioned(
            top: 5,
            right: 5,
            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}