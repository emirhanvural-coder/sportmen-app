import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:story_view/story_view.dart';
import 'package:video_player/video_player.dart';
import '../screens/other_profile_screen.dart';
import '../screens/add_story_screen.dart';
import '../widgets/custom_loading.dart';

// =========================================================
// --- PROFESYONEL HİKAYE İZLEME EKRANI ---
// =========================================================
class ProfessionalStoryViewer extends StatefulWidget {
  final List<QueryDocumentSnapshot> storyDocs;
  final String userName;
  final String? userImage;
  final int initialIndex;

  const ProfessionalStoryViewer({
    super.key,
    required this.storyDocs,
    required this.userName,
    this.userImage,
    this.initialIndex = 0,
  });

  @override
  State<ProfessionalStoryViewer> createState() => _ProfessionalStoryViewerState();
}

class _ProfessionalStoryViewerState extends State<ProfessionalStoryViewer> {
  final StoryController controller = StoryController();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  
  List<StoryItem> storyItems = [];
  int _currentIndex = 0; 

  @override
  void initState() {
    super.initState();
    
    // 1. Hikaye Listesini Hazırla
    for (var doc in widget.storyDocs) {
      var data = doc.data() as Map<String, dynamic>;
      String url = data['imageUrl'];
      String type = data['mediaType'] ?? 'image'; 

      if (type == 'video') {
        storyItems.add(
          StoryItem(
            StoryVideoPlayer(
              videoUrl: url, 
              storyController: controller,
            ),
            duration: const Duration(seconds: 15),
          ),
        );
      } else {
        storyItems.add(
          StoryItem.pageImage(
            url: url,
            controller: controller,
            duration: const Duration(seconds: 8), 
            imageFit: BoxFit.cover, 
          ),
        );
      }
    }

    // 2. OTOMATİK ATLAMA MANTIĞI
    if (widget.initialIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (int i = 0; i < widget.initialIndex; i++) {
          controller.next();
        }
      });
    }
  }

  void _onStoryShow(StoryItem shownItem) {
    int index = storyItems.indexOf(shownItem);

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentIndex = index;
          });
        }
      });
    }

    if (index != -1) {
      var doc = widget.storyDocs[index];
      List viewers = doc['viewers'] ?? [];
      
      if (!viewers.contains(currentUid)) {
        FirebaseFirestore.instance.collection('stories').doc(doc.id).update({
          'viewers': FieldValue.arrayUnion([currentUid]),
        });
      }
    }
  }

  void _deleteCurrentStory() async {
    controller.pause(); 

    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Hikayeyi Sil", style: TextStyle(color: Colors.white)),
        content: const Text("Bu hikaye kalıcı olarak silinecek.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
              controller.play(); 
            },
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("SİL", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        var doc = widget.storyDocs[_currentIndex];
        var data = doc.data() as Map<String, dynamic>;

        await FirebaseStorage.instance.refFromURL(data['imageUrl']).delete();
        await FirebaseFirestore.instance.collection('stories').doc(doc.id).delete();

        if (mounted) {
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hikaye silindi.")));
        }
      } catch (e) {
        debugPrint("Silme hatası: $e");
        if (mounted) controller.play();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isOwner = false;
    if (_currentIndex >= 0 && _currentIndex < widget.storyDocs.length) {
      isOwner = widget.storyDocs[_currentIndex]['uid'] == currentUid;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          StoryView(
            storyItems: storyItems,
            controller: controller,
            onStoryShow: (storyItem, index) { 
               _onStoryShow(storyItem);
            },
            onComplete: () {
              Navigator.pop(context); 
            },
            onVerticalSwipeComplete: (direction) {
              if (direction == Direction.down) {
                Navigator.pop(context); 
              }
            },
            repeat: false, 
          ),
          
          Positioned(
            top: 50, left: 20,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: const AssetImage('assets/logo.jpg'),
                  foregroundImage: (widget.userImage != null && widget.userImage!.isNotEmpty)
                      ? NetworkImage(widget.userImage!)
                      : null,
                ),
                const SizedBox(width: 10),
                Text(
                  widget.userName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
           
           Positioned(
            top: 50, right: 20,
            child: Row(
              children: [
                if (isOwner)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _deleteCurrentStory,
                  ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
           ),
        ],
      ),
    );
  }
}

// =========================================================
// --- AKILLI AVATAR (StoryAvatar) ---
// =========================================================
class StoryAvatar extends StatelessWidget {
  final String userId;
  final String? imageUrl;
  final double radius;
  final bool hasBorder; // <-- YENİ EKLENEN ÖZELLİK
  final VoidCallback? onTapFallback;

  const StoryAvatar({
    super.key,
    required this.userId,
    this.imageUrl,
    this.radius = 26,
    this.hasBorder = false, // Varsayılan olarak çerçeve yok
    this.onTapFallback,
  });

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stories')
          .where('uid', isEqualTo: userId)
          .where('expiresAt', isGreaterThan: DateTime.now())
          .orderBy('expiresAt', descending: false) 
          .snapshots(),
      builder: (context, snapshot) {
        bool hasStory = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        bool allSeen = true; 
        
        List<QueryDocumentSnapshot> userStories = [];
        int startIndex = 0;

        if (hasStory) {
          userStories = snapshot.data!.docs;
          
          // İlk izlenmemiş hikayeyi bul
          int firstUnseenIndex = userStories.indexWhere((doc) {
             List viewers = doc['viewers'] ?? [];
             return !viewers.contains(currentUid);
          });

          if (firstUnseenIndex != -1) {
            allSeen = false;
            startIndex = firstUnseenIndex;
          } else {
            allSeen = true;
            startIndex = 0; 
          }
        }

        return GestureDetector(
          onTap: () {
            if (hasStory) {
              var firstStoryData = userStories.first.data() as Map<String, dynamic>;
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => ProfessionalStoryViewer(
                  storyDocs: userStories, 
                  initialIndex: startIndex, 
                  userName: firstStoryData['userName'] ?? 'Kullanıcı',
                  userImage: firstStoryData['userImage'],
                ))
              );
            } else {
              if (onTapFallback != null) {
                onTapFallback!();
              } else if (userId == currentUid) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AddStoryScreen()));
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfileScreen(userId: userId)));
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // ÇERÇEVE MANTIĞI:
              // 1. Hikaye varsa: Renkli çerçeve
              // 2. Hikaye yok ama hasBorder true ise: Beyaz çerçeve (Reels vb. için)
              // 3. Hiçbiri yoksa: Şeffaf
              border: hasStory 
                ? Border.all(
                    color: allSeen ? Colors.grey : Colors.greenAccent, 
                    width: 3
                  )
                : (hasBorder 
                    ? Border.all(color: Colors.white, width: 1.5)
                    : Border.all(color: Colors.transparent, width: 0)
                  ),
            ),
            child: CircleAvatar(
              radius: radius,
              backgroundColor: Colors.grey[800],
              backgroundImage: const AssetImage('assets/logo.jpg'),
              foregroundImage: (imageUrl != null && imageUrl!.isNotEmpty) ? NetworkImage(imageUrl!) : null,
            ),
          ),
        );
      },
    );
  }
}

// =========================================================
// --- GÜVENLİ VİDEO OYNATICI ---
// =========================================================
class StoryVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final StoryController storyController;

  const StoryVideoPlayer({super.key, required this.videoUrl, required this.storyController});

  @override
  State<StoryVideoPlayer> createState() => _StoryVideoPlayerState();
}

class _StoryVideoPlayerState extends State<StoryVideoPlayer> {
  late VideoPlayerController _videoController;
  bool _isDisposed = false; 

  @override
  void initState() {
    super.initState();
    widget.storyController.pause();

    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (_isDisposed || !mounted) return;
        setState(() {});
        _videoController.play();
        widget.storyController.play(); 
      });

    _videoController.addListener(_videoListener);
  }

  void _videoListener() {
    if (_isDisposed || !_videoController.value.isInitialized) return;
    if (_videoController.value.position >= _videoController.value.duration) {
      widget.storyController.next();
    }
  }

  @override
  void dispose() {
    _isDisposed = true; 
    _videoController.removeListener(_videoListener);
    _videoController.pause(); 
    _videoController.dispose(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed || !_videoController.value.isInitialized) {
      return const Center(child: CustomLoading());
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _videoController.value.size.width,
          height: _videoController.value.size.height,
          child: VideoPlayer(_videoController),
        ),
      ),
    );
  }
}