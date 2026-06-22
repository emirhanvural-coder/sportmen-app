import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart'; 
import 'post_detail_screen.dart'; 
import '../widgets/story_avatar.dart'; 
import '../services/notification_sender.dart'; 
import 'edit_profile_screen.dart'; 
import 'chat_screen.dart'; 

class OtherProfileScreen extends StatefulWidget {
  final String userId;

  const OtherProfileScreen({super.key, required this.userId});

  @override
  State<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends State<OtherProfileScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool isFollowing = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkIfFollowing();
  }

  void _checkIfFollowing() async {
    if (widget.userId == currentUid) return;

    try {
      var doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      if (doc.exists && mounted) {
        List followers = doc.data()?['followers'] ?? [];
        setState(() {
          isFollowing = followers.contains(currentUid);
        });
      }
    } catch (e) {
      debugPrint("Takip kontrol hatası: $e");
    }
  }

  void _toggleFollow() async {
    if (widget.userId == currentUid || isLoading) return; 

    setState(() => isLoading = true);
    try {
      if (isFollowing) {
        // Takibi Bırakma İşlemi
        await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
          'followers': FieldValue.arrayRemove([currentUid]),
        });
        await FirebaseFirestore.instance.collection('users').doc(currentUid).update({
          'following': FieldValue.arrayRemove([widget.userId]),
        });
      } else {
        // --- TAKİP ETME VE BİLDİRİM GÖNDERME ---
        // ÇÖKMEYİ ENGELLEYEN GÜVENLİ VERİ ÇEKME
        var currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
        
        if (currentUserDoc.exists) {
          var currentUserData = currentUserDoc.data() as Map<String, dynamic>;

          // Push Bildirimi Gönder
          await NotificationSender.sendPushNotification(
            receiverId: widget.userId,
            title: "Yeni Takipçi! 👤",
            body: "${currentUserData['name'] ?? 'Bir kullanıcı'} seni takip etmeye başladı.",
            imageUrl: currentUserData['profileImage'],
            extraData: {'type': 'follow', 'senderId': currentUid},
          );

          // Uygulama içi bildirim kaydı
          await FirebaseFirestore.instance.collection('users').doc(widget.userId).collection('notifications').add({
            'receiverId': widget.userId,
            'senderId': currentUid,
            'senderName': currentUserData['name'] ?? 'İsimsiz',
            'senderImage': currentUserData['profileImage'],
            'type': 'follow',
            'message': 'seni takip etmeye başladı.',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
          'followers': FieldValue.arrayUnion([currentUid]),
        });
        await FirebaseFirestore.instance.collection('users').doc(currentUid).update({
          'following': FieldValue.arrayUnion([widget.userId]),
        });
      }
      
      if (mounted) {
        setState(() {
          isFollowing = !isFollowing;
        });
      }
    } catch (e) {
      debugPrint("Takip hatası: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _startChat() async {
    if (widget.userId == currentUid) return; 

    try {
      List<String> ids = [currentUid, widget.userId];
      ids.sort(); 
      String chatId = "${ids[0]}_${ids[1]}";

      var userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      if (userDoc.exists && mounted) {
        var userData = userDoc.data() as Map<String, dynamic>;
        String name = userData['name'] ?? 'Kullanıcı';
        String? image = userData['profileImage'];

        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => ChatScreen(
            chatId: chatId,
            receiverId: widget.userId,
            receiverName: name,
            receiverImage: image,
          ))
        );
      }
    } catch (e) {
      debugPrint("Chat başlatma hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! > 300) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                var data = snapshot.data!.data() as Map<String, dynamic>;
                String username = data['name'] ?? "kullanici"; 
                bool isVerified = data['isVerified'] ?? false; 

                return Row(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    Flexible(
                      child: Text(
                        "@$username", 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isVerified)
                      const Padding(
                        padding: EdgeInsets.only(left: 4.0),
                        child: Icon(Icons.verified, color: Colors.greenAccent, size: 16),
                      ),
                  ],
                );
              }
              return const Text("Kullanıcı", style: TextStyle(color: Colors.white));
            },
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(child: _buildProfileHeader()),
            ];
          },
          body: _buildGridView(),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 100);
        if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text("Kullanıcı bulunamadı", style: TextStyle(color: Colors.white)));
        
        var data = snapshot.data!.data() as Map<String, dynamic>;
        bool isMe = widget.userId == currentUid;
        String fullName = data['fullName'] ?? "İsim Soyisim";

        return Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StoryAvatar(
                    userId: widget.userId,
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
                  if (isMe)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                           Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen()));
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[900], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text("Profili Düzenle", style: TextStyle(color: Colors.white)),
                      ),
                    )
                  else ...[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _toggleFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing ? Colors.grey[900] : Colors.greenAccent,
                          foregroundColor: isFollowing ? Colors.white : Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: isLoading 
                          ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(isFollowing ? "Takip Ediliyor" : "Takip Et"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _startChat, 
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[900], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text("Mesaj", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

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
          .where('uid', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.only(top: 50.0),
            child: Text("Henüz gönderi yok.", style: TextStyle(color: Colors.grey)),
          ));
        }

        var allPosts = snapshot.data!.docs;

        return GridView.builder(
          padding: const EdgeInsets.only(top: 2),
          itemCount: allPosts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemBuilder: (context, index) {
            return _OtherProfileGridItem(
              post: allPosts[index], 
              allPosts: allPosts, 
              index: index
            );
          },
        );
      },
    );
  }
}

// _OtherProfileGridItem aynen kalıyor...
class _OtherProfileGridItem extends StatefulWidget {
  final DocumentSnapshot post;
  final List<DocumentSnapshot> allPosts;
  final int index;
  const _OtherProfileGridItem({required this.post, required this.allPosts, required this.index});
  @override
  State<_OtherProfileGridItem> createState() => _OtherProfileGridItemState();
}

class _OtherProfileGridItemState extends State<_OtherProfileGridItem> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool isLikeAnimating = false;
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    var data = widget.post.data() as Map<String, dynamic>;
    if ((data['mediaType'] ?? 'image') == 'video') {
      _controller = VideoPlayerController.networkUrl(Uri.parse(data['imageUrl']))
        ..initialize().then((_) {
          if (!_isDisposed && mounted) {
            setState(() => _initialized = true);
            _controller!.seekTo(Duration.zero);
            _controller!.pause();
          }
        }).catchError((_) {});
    }
  }

  @override
  void dispose() { _isDisposed = true; _controller?.dispose(); super.dispose(); }

  void _toggleLike() async {
    setState(() => isLikeAnimating = true);
    Future.delayed(const Duration(milliseconds: 800), () => { if(mounted) setState(() => isLikeAnimating = false) });

    var data = widget.post.data() as Map<String, dynamic>;
    String postId = widget.post.id;
    String postOwnerId = data['uid'];
    List likes = data['likes'] ?? [];

    if (likes.contains(currentUid)) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({'likes': FieldValue.arrayRemove([currentUid])});
    } else {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({'likes': FieldValue.arrayUnion([currentUid])});
      if (postOwnerId != currentUid) {
        try {
          var userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
          if (userDoc.exists) {
            var userData = userDoc.data() as Map<String, dynamic>;
            
            // Push bildirimini de buradaki mantıkla ekleyebilirsin ama öncelik çökme sorununu çözmek
            await NotificationSender.sendPushNotification(
              receiverId: postOwnerId,
              title: "Gönderin Beğenildi! ❤️",
              body: "${userData['name'] ?? 'İsimsiz'} gönderini beğendi.",
              imageUrl: userData['profileImage'],
              extraData: {'type': 'like', 'postId': postId},
            );

            await FirebaseFirestore.instance.collection('users').doc(postOwnerId).collection('notifications').add({
              'type': 'like',
              'senderId': currentUid,
              'senderName': userData['name'] ?? 'İsimsiz',
              'senderImage': userData['profileImage'],
              'postId': postId,
              'postImageUrl': data['imageUrl'],
              'mediaType': data['mediaType'] ?? 'image',
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
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen(posts: widget.allPosts, initialIndex: widget.index))),
      onDoubleTap: _toggleLike,
      child: Stack(
        fit: StackFit.expand,
        children: [
          mediaType == 'video'
              ? (_initialized ? ClipRect(child: FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: _controller!.value.size.width, height: _controller!.value.size.height, child: VideoPlayer(_controller!)))) : Container(color: Colors.grey[900], child: const Icon(Icons.videocam, color: Colors.white24)))
              : Image.network(url, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[900])),
          if (mediaType == 'video') const Positioned(top: 5, right: 5, child: Icon(Icons.play_circle_fill, color: Colors.white, size: 20)),
          if (isLikeAnimating) const Center(child: Icon(Icons.favorite, color: Colors.white, size: 80)),
        ],
      ),
    );
  }
}