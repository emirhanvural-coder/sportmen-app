import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart'; 
import 'package:visibility_detector/visibility_detector.dart'; 

import '../screens/comments_screen.dart';
import '../screens/other_profile_screen.dart';
import '../screens/profile_screen.dart';
import '../services/notification_sender.dart'; 
import 'story_avatar.dart';
import 'share_bottom_sheet.dart'; 

class PostCard extends StatefulWidget {
  final DocumentSnapshot post; 
  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  CachedVideoPlayerPlusController? _videoController; 
  
  bool _isMuted = true;
  bool _isVideo = false;
  bool _isDisposed = false; 
  bool _isVideoLoading = true; 
  
  late bool _isLiked;
  late int _likeCount;
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;

  // --- SPAM KORUMASI İÇİN DEĞİŞKENLER ---
  DateTime? _lastLikeActionTime; // Son tıklama zamanı
  bool _isLikeProcessing = false; // İşlem durumu

  @override
  void initState() {
    super.initState();
    var data = widget.post.data() as Map<String, dynamic>;
    
    List likes = data['likes'] ?? [];
    _isLiked = likes.contains(_currentUid);
    _likeCount = likes.length;

    String mediaType = data.containsKey('mediaType') ? data['mediaType'] : 'image';
    _isVideo = (mediaType == 'video');

    if (_isVideo) {
      _videoController = CachedVideoPlayerPlusController.network(data['imageUrl'])
        ..initialize().then((_) {
          if (_isDisposed || !mounted) return;
          setState(() {
            _videoController!.setVolume(0); 
            _videoController!.setLooping(true);
            _isVideoLoading = false;
          });
        });
    }
  }

  @override
  void dispose() {
    _isDisposed = true; 
    if (_videoController != null) {
      _videoController!.dispose();
    }
    super.dispose();
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (_isDisposed || !_isVideo || _videoController == null || !_videoController!.value.isInitialized) return;

    if (info.visibleFraction > 0.6) { 
       if (!_videoController!.value.isPlaying) {
         _videoController!.play().then((_) {
            if (mounted) setState(() {}); 
         });
       }
    } else {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        if (mounted) setState(() {}); 
      }
    }
  }

  void _toggleVideoPlay() {
    if (_isDisposed || _videoController == null) return;
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    });
  }

  void _toggleMute() {
    if (_isDisposed || _videoController == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _videoController!.setVolume(_isMuted ? 0 : 1);
    });
  }

  void _toggleLike() async {
    final now = DateTime.now();

    // 1. KORUMA: Eğer işlem zaten devam ediyorsa reddet
    if (_isLikeProcessing) return;

    // 2. KORUMA (SPAM): Eğer son işlemden sonra 3 saniye geçmediyse reddet
    if (_lastLikeActionTime != null && 
        now.difference(_lastLikeActionTime!).inSeconds < 3) {
      debugPrint("Spam engellendi: Çok hızlı beğenme yapılıyor.");
      return;
    }

    _lastLikeActionTime = now; // Zaman damgasını güncelle

    setState(() {
      _isLikeProcessing = true; 
      if (_isLiked) {
        _isLiked = false;
        _likeCount--;
      } else {
        _isLiked = true;
        _likeCount++;
      }
    });

    try {
      String postId = widget.post.id;
      var data = widget.post.data() as Map<String, dynamic>;
      String postOwnerId = data['uid'];
      String imageUrl = data['imageUrl'];
      String mediaType = data.containsKey('mediaType') ? data['mediaType'] : 'image';

      String notificationId = "like_${_currentUid}_$postId";

      if (!_isLiked) { 
        // Beğeni geri çekildiğinde sessizce işlemi yap
        await FirebaseFirestore.instance.collection('posts').doc(postId).update({
          'likes': FieldValue.arrayRemove([_currentUid]),
        });

        if (postOwnerId != _currentUid) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(postOwnerId)
              .collection('notifications')
              .doc(notificationId)
              .delete();
        }
      } else {
        // Beğenildiğinde işlemleri yap
        await FirebaseFirestore.instance.collection('posts').doc(postId).update({
          'likes': FieldValue.arrayUnion([_currentUid]),
        });

        if (postOwnerId != _currentUid) {
            var userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUid).get();
            var userData = userDoc.data() as Map<String, dynamic>;

            // --- INSTAGRAM MANTIĞI PUSH BİLDİRİM ---
            await NotificationSender.sendPushNotification(
              receiverId: postOwnerId,
              title: "Gönderin Beğenildi! ❤️",
              body: "${userData['name'] ?? 'Bir kullanıcı'} gönderini beğendi.",
              imageUrl: userData['profileImage'],
              extraData: {'type': 'like', 'postId': postId},
            );

            await FirebaseFirestore.instance
                .collection('users')
                .doc(postOwnerId)
                .collection('notifications')
                .doc(notificationId)
                .set({
              'type': 'like',
              'senderId': _currentUid,
              'senderName': userData['name'] ?? 'İsimsiz',
              'senderImage': userData['profileImage'],
              'postId': postId,
              'postImageUrl': imageUrl,
              'mediaType': mediaType,
              'message': 'gönderini beğendi.',
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_isLiked) { _isLiked = false; _likeCount--; } 
          else { _isLiked = true; _likeCount++; }
        });
      }
    } finally {
      // İşlem bittikten sonra kilidi aç
      if (mounted) {
        setState(() {
          _isLikeProcessing = false;
        });
      }
    }
  }

  void _toggleSave(bool isSaved) async {
    if (isSaved) {
      await FirebaseFirestore.instance.collection('users').doc(_currentUid).collection('saved_posts').doc(widget.post.id).delete();
    } else {
      await FirebaseFirestore.instance.collection('users').doc(_currentUid).collection('saved_posts').doc(widget.post.id).set({
        'postId': widget.post.id,
        'imageUrl': (widget.post.data() as Map<String, dynamic>)['imageUrl'],
        'mediaType': _isVideo ? 'video' : 'image',
        'savedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void _showSendMenu(BuildContext context) async {
    var data = widget.post.data() as Map<String, dynamic>;
    String ownerId = data['uid'];
    
    String ownerName = data['userName'] ?? 'Kullanıcı';
    String? ownerImage;
    bool ownerVerified = false;

    try {
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(ownerId).get();
      if (userDoc.exists) {
        var userData = userDoc.data()!;
        ownerName = userData['name'] ?? ownerName;
        ownerImage = userData['profileImage'];
        ownerVerified = userData['isVerified'] ?? false;
      }
    } catch (_) {}

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ShareBottomSheet(
          postId: widget.post.id,
          postImageUrl: data['imageUrl'],
          mediaType: _isVideo ? 'video' : 'image',
          postOwnerName: ownerName,
          postOwnerImage: ownerImage,
          postOwnerVerified: ownerVerified,
        ),
      );
    }
  }

  void _navigateToProfile(BuildContext context, String userId, String currentUid) {
    if (userId == currentUid) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfileScreen(userId: userId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    var data = widget.post.data() as Map<String, dynamic>;
    String postOwnerId = data['uid'];
    String? thumbnailUrl = data['thumbnailUrl']; 
    
    String dateText = "";
    if (data['createdAt'] != null) {
      Timestamp t = data['createdAt'];
      DateTime d = t.toDate();
      dateText = "${d.day}/${d.month}/${d.year}";
    }

    return VisibilityDetector(
      key: Key(widget.post.id),
      onVisibilityChanged: _handleVisibilityChanged,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20), 
        color: Colors.grey[900],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(postOwnerId).snapshots(),
              builder: (context, snapshot) {
                String userName = data['userName'] ?? 'Kullanıcı'; 
                String rawRole = data['userRole'] ?? ''; 
                String? profileImage;
                bool isVerified = false; 

                if (snapshot.hasData && snapshot.data!.exists) {
                  var userData = snapshot.data!.data() as Map<String, dynamic>;
                  userName = userData['name'] ?? userName;
                  rawRole = userData['role'] ?? rawRole;
                  profileImage = userData['profileImage'];
                  isVerified = userData['isVerified'] ?? false; 
                }

                String displayRole = rawRole;
                Map<String, String> roleTranslations = {
                  'admin': 'YÖNETİCİ',
                  'moderator': 'MODERATÖR',
                  'premium': 'PREMIUM',
                  'vip': 'VIP ÜYE',
                  'athlete': 'SPORCU', 
                  'coach': 'ANTRENÖR',
                  'club': 'SPOR KULÜBÜ', 
                  'scout': 'SCOUT',    
                  'user': '', 
                };
                
                if (roleTranslations.containsKey(rawRole.toLowerCase())) {
                  displayRole = roleTranslations[rawRole.toLowerCase()]!;
                } else {
                  displayRole = rawRole.toUpperCase();
                }

                return Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    children: [
                      StoryAvatar(
                        userId: postOwnerId,
                        imageUrl: profileImage,
                        radius: 20,
                        onTapFallback: () => _navigateToProfile(context, postOwnerId, _currentUid),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _navigateToProfile(context, postOwnerId, _currentUid),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                if (isVerified)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4.0),
                                    child: Icon(Icons.verified, color: Colors.greenAccent, size: 16),
                                  ),
                              ],
                            ),
                            if (displayRole.isNotEmpty)
                               Text(displayRole, style: const TextStyle(fontSize: 11, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(dateText, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      const Icon(Icons.more_vert, color: Colors.grey),
                    ],
                  ),
                );
              },
            ),

            GestureDetector(
              onDoubleTap: _toggleLike,
              onTap: _isVideo ? _toggleVideoPlay : null,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isVideo)
                    SizedBox(
                      height: 400,
                      width: double.infinity,
                      child: _videoController != null && _videoController!.value.isInitialized && !_isDisposed
                          ? AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: CachedVideoPlayerPlus(_videoController!), 
                            )
                          : const SizedBox(), 
                    )
                  else
                    Image.network(
                      data['imageUrl'],
                      width: double.infinity,
                      height: 400,
                      fit: BoxFit.cover,
                    ),

                  if (_isVideo && (_videoController == null || !_videoController!.value.isInitialized))
                      thumbnailUrl != null 
                        ? Image.network(
                            thumbnailUrl, 
                            width: double.infinity, 
                            height: 400, 
                            fit: BoxFit.cover
                          )
                        : Container(height: 400, color: Colors.black), 

                  if (_isVideo && _isVideoLoading && thumbnailUrl == null)
                      const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
                  
                  if (_isVideo && !_isVideoLoading && _videoController != null && !_videoController!.value.isPlaying)
                    const Icon(Icons.play_circle_fill, color: Colors.white54, size: 60),

                  if (_isVideo)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: _toggleMute,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          radius: 15,
                          child: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.red : Colors.white, size: 28),
                    onPressed: _toggleLike,
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('posts').doc(widget.post.id).collection('comments').snapshots(),
                    builder: (context, commentSnapshot) {
                      int count = commentSnapshot.hasData ? commentSnapshot.data!.docs.length : 0;
                      return Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.comment_outlined, color: Colors.white, size: 28),
                            onPressed: () {
                              String secureMediaType = data.containsKey('mediaType') ? data['mediaType'] : 'image';
                              Navigator.push(
                                context, 
                                MaterialPageRoute(builder: (context) => CommentsScreen(
                                  postId: widget.post.id,
                                  postOwnerId: postOwnerId,
                                  postImageUrl: data['imageUrl'],
                                  mediaType: secureMediaType, 
                                ))
                              );
                            },
                          ),
                          if (count > 0) Text("$count", style: const TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_outlined, color: Colors.white, size: 28),
                    onPressed: () => _showSendMenu(context),
                  ),
                  const Spacer(),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(_currentUid).collection('saved_posts').doc(widget.post.id).snapshots(),
                    builder: (context, snapshot) {
                      bool isSaved = snapshot.hasData && snapshot.data!.exists;
                      return IconButton(
                        icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, color: Colors.white, size: 28),
                        onPressed: () => _toggleSave(isSaved),
                      );
                    },
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_likeCount > 0) 
                    Text("$_likeCount beğenme", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 5),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white),
                      children: [
                        TextSpan(text: "${data['userName']} ", style: const TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: data['description']),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  GestureDetector(
                    onTap: () {
                      String secureMediaType = data.containsKey('mediaType') ? data['mediaType'] : 'image';
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => CommentsScreen(
                          postId: widget.post.id,
                          postOwnerId: postOwnerId,
                          postImageUrl: data['imageUrl'],
                          mediaType: secureMediaType,
                        ))
                      );
                    },
                    child: const Text("Tüm yorumları gör...", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                  const SizedBox(height: 15), 
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}