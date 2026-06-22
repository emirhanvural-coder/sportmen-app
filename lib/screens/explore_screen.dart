import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'comments_screen.dart'; 
import 'other_profile_screen.dart'; 
import '../widgets/story_avatar.dart';
import '../widgets/share_bottom_sheet.dart'; // Paylaşım Widget'ı

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final PageController _pageController = PageController();
  List<DocumentSnapshot> _posts = [];
  bool _isLoading = true;
  int _currentPage = 0; 

  @override
  void initState() {
    super.initState();
    _fetchAndShufflePosts();
  }

  Future<void> _fetchAndShufflePosts() async {
    setState(() => _isLoading = true);
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(50) 
          .get();

      var allDocs = snapshot.docs;
      allDocs.shuffle(); 

      if (mounted) {
        setState(() {
          _posts = allDocs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Reels hatası: $e");
      if (mounted) setState(() => _isLoading = false);
    }
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
          : _posts.isEmpty
              ? const Center(child: Text("Gösterilecek içerik yok.", style: TextStyle(color: Colors.grey)))
              : PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical, 
                  itemCount: _posts.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index; 
                    });
                  },
                  itemBuilder: (context, index) {
                    bool isActive = (index == _currentPage);
                    return _ReelsItem(
                      post: _posts[index],
                      isActive: isActive,
                    );
                  },
                ),
    );
  }
}

// --- REELS TARZI GÖNDERİ ---
class _ReelsItem extends StatefulWidget {
  final DocumentSnapshot post;
  final bool isActive; 

  const _ReelsItem({required this.post, required this.isActive});

  @override
  State<_ReelsItem> createState() => _ReelsItemState();
}

class _ReelsItemState extends State<_ReelsItem> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  VideoPlayerController? _videoController;
  bool _isLiked = false;
  bool _showHeartAnim = false;
  
  // --- TAKİP DURUMU ---
  bool _isFollowing = false;
  bool _isFollowLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeMedia();
    _checkFollowStatus(); 
  }

  @override
  void didUpdateWidget(_ReelsItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_videoController != null) {
      if (widget.isActive) {
        _videoController!.play();
      } else {
        _videoController!.pause();
      }
    }
  }

  void _initializeMedia() {
    var data = widget.post.data() as Map<String, dynamic>;
    String mediaType = data['mediaType'] ?? 'image';
    String url = data['imageUrl'] ?? '';
    List likes = data['likes'] ?? [];
    _isLiked = likes.contains(currentUid);

    if (mediaType == 'video' && url.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {}); 
            _videoController!.setLooping(true); 
            if (widget.isActive) _videoController!.play(); 
          }
        });
    }
  }

  void _checkFollowStatus() async {
    var data = widget.post.data() as Map<String, dynamic>;
    String ownerId = data['uid'];
    if (ownerId == currentUid) return; 

    try {
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(ownerId).get();
      if (userDoc.exists) {
        List followers = userDoc.data()?['followers'] ?? [];
        if (mounted) {
          setState(() {
            _isFollowing = followers.contains(currentUid);
          });
        }
      }
    } catch (_) {}
  }

  void _toggleFollow() async {
    var data = widget.post.data() as Map<String, dynamic>;
    String ownerId = data['uid'];
    if (ownerId == currentUid) return;

    setState(() => _isFollowLoading = true);

    try {
      if (_isFollowing) {
        await FirebaseFirestore.instance.collection('users').doc(ownerId).update({
          'followers': FieldValue.arrayRemove([currentUid]),
        });
        await FirebaseFirestore.instance.collection('users').doc(currentUid).update({
          'following': FieldValue.arrayRemove([ownerId]),
        });
      } else {
        await FirebaseFirestore.instance.collection('users').doc(ownerId).update({
          'followers': FieldValue.arrayUnion([currentUid]),
        });
        await FirebaseFirestore.instance.collection('users').doc(currentUid).update({
          'following': FieldValue.arrayUnion([ownerId]),
        });
        
        await FirebaseFirestore.instance.collection('users').doc(ownerId).collection('notifications').add({
          'receiverId': ownerId,
          'senderId': currentUid,
          'type': 'follow',
          'message': 'seni takip etmeye başladı.',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
        });
      }
    } catch (e) {
      debugPrint("Takip hatası: $e");
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) _showHeartAnim = true;
    });

    DocumentReference postRef = FirebaseFirestore.instance.collection('posts').doc(widget.post.id);
    if (_isLiked) {
      await postRef.update({'likes': FieldValue.arrayUnion([currentUid])});
    } else {
      await postRef.update({'likes': FieldValue.arrayRemove([currentUid])});
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showHeartAnim = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    var data = widget.post.data() as Map<String, dynamic>;
    String mediaType = data['mediaType'] ?? 'image';
    String url = data['imageUrl'] ?? '';
    String description = data['description'] ?? '';
    String ownerId = data['uid'];
    bool isMe = (ownerId == currentUid);

    int likeCount = (data['likes'] as List?)?.length ?? 0;
    if (_isLiked && !(data['likes'] as List).contains(currentUid)) likeCount++;
    if (!_isLiked && (data['likes'] as List).contains(currentUid)) likeCount--;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. MEDYA KATMANI
        GestureDetector(
          onDoubleTap: _toggleLike,
          onTap: () {
            if (_videoController != null) {
              _videoController!.value.isPlaying ? _videoController!.pause() : _videoController!.play();
            }
          },
          child: Container(
            color: Colors.black,
            child: mediaType == 'video'
                ? (_videoController != null && _videoController!.value.isInitialized)
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _videoController!.value.size.width,
                          height: _videoController!.value.size.height,
                          child: VideoPlayer(_videoController!),
                        ),
                      )
                    : const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                : Image.network(url, fit: BoxFit.cover),
          ),
        ),

        // 2. GRADIENT
        Positioned(
          bottom: 0, left: 0, right: 0, height: 250,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black87],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        // 3. SAĞ BUTONLAR
        Positioned(
          right: 10,
          bottom: 90, 
          child: Column(
            children: [
              IconButton(
                icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.red : Colors.white, size: 28),
                onPressed: _toggleLike,
              ),
              Text("$likeCount", style: const TextStyle(color: Colors.white, fontSize: 13)),
              
              const SizedBox(height: 15),

              IconButton(
                icon: const Icon(Icons.comment, color: Colors.white, size: 28),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => DraggableScrollableSheet(
                      initialChildSize: 0.8,
                      builder: (_, controller) => CommentsScreen(
                        postId: widget.post.id,
                        postOwnerId: ownerId,
                        postImageUrl: url,
                        mediaType: mediaType,
                      ),
                    ),
                  );
                },
              ),
              const Text("Yorum", style: TextStyle(color: Colors.white, fontSize: 12)),

              const SizedBox(height: 15),

              // --- GÜNCELLENEN PAYLAŞ BUTONU ---
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white, size: 28),
                onPressed: () async {
                  // 1. ÖNCE GÖNDERİ SAHİBİNİN GÜNCEL BİLGİLERİNİ ÇEKİYORUZ
                  String ownerName = 'Kullanıcı';
                  String? ownerImage;
                  bool ownerVerified = false;

                  try {
                    var userDoc = await FirebaseFirestore.instance.collection('users').doc(ownerId).get();
                    if(userDoc.exists) {
                      var userData = userDoc.data()!;
                      ownerName = userData['name'] ?? 'Kullanıcı';
                      ownerImage = userData['profileImage'];
                      ownerVerified = userData['isVerified'] ?? false;
                    }
                  } catch (_) {}

                  if (mounted) {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) => ShareBottomSheet(
                        postId: widget.post.id,
                        postImageUrl: url,
                        mediaType: mediaType,
                        // 2. VERİLERİ BURADAN GÖNDERİYORUZ
                        postOwnerName: ownerName,
                        postOwnerImage: ownerImage,
                        postOwnerVerified: ownerVerified,
                      ),
                    );
                  }
                },
              ),
              const Text("Paylaş", style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),

        // 4. SOL ALT BİLGİLER
        Positioned(
          left: 15,
          bottom: 20,
          right: 70, 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(ownerId).get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  var user = snapshot.data!.data() as Map<String, dynamic>;
                  bool isVerified = user['isVerified'] ?? false;
                  String? profileImg = user['profileImage'];
                  
                  return Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfileScreen(userId: ownerId))),
                        child: StoryAvatar(
                          userId: ownerId, 
                          imageUrl: profileImg, 
                          radius: 20, 
                          hasBorder: true,
                        ),
                      ),
                      const SizedBox(width: 10),

                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfileScreen(userId: ownerId))),
                        child: Text(
                          user['name'] ?? 'Kullanıcı',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      
                      if (isVerified)
                        const Padding(
                          padding: EdgeInsets.only(left: 4.0),
                          child: Icon(Icons.verified, color: Colors.greenAccent, size: 16),
                        ),

                      const SizedBox(width: 10),

                      if (!isMe)
                        GestureDetector(
                          onTap: _isFollowLoading ? null : _toggleFollow,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isFollowing ? Colors.transparent : Colors.greenAccent.withOpacity(0.2), 
                              border: Border.all(
                                color: _isFollowing ? Colors.grey : Colors.greenAccent, 
                                width: 1
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _isFollowLoading 
                              ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(
                                  _isFollowing ? "Takipte" : "Takip Et",
                                  style: TextStyle(
                                    color: _isFollowing ? Colors.white : Colors.greenAccent, 
                                    fontSize: 12, 
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              
              if (description.isNotEmpty)
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70),
                ),
            ],
          ),
        ),

        // 5. KALP ANİMASYONU
        if (_showHeartAnim)
          const Center(child: Icon(Icons.favorite, color: Colors.white54, size: 120)),
      ],
    );
  }
}