import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/custom_loading.dart';
import '../services/notification_sender.dart'; // <--- Bildirim servisi eklendi

class CommentsScreen extends StatefulWidget {
  final String postId;
  final String postOwnerId;  
  final String postImageUrl; 
  final String mediaType;    

  const CommentsScreen({
    super.key, 
    required this.postId,
    required this.postOwnerId,
    required this.postImageUrl,
    required this.mediaType,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  // --- YORUM GÖNDERME ---
  void _postComment() async {
    String commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    // 1. Yorumu Ekle
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .add({
      'uid': currentUid,
      'text': commentText,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Bildirim Gönder (Kendine değilse)
    if (widget.postOwnerId != currentUid) {
      try {
        var userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
        var userData = userDoc.data() as Map<String, dynamic>;

        // --- INSTAGRAM MANTIĞI PUSH BİLDİRİM ---
        await NotificationSender.sendPushNotification(
          receiverId: widget.postOwnerId,
          title: "Yeni Yorum 💬",
          body: "${userData['name'] ?? 'Biri'} gönderine yorum yaptı: $commentText",
          imageUrl: userData['profileImage'], // Yorum yapanın resmi
          extraData: {'type': 'comment', 'postId': widget.postId},
        );

        // Firestore içi bildirim kaydı
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.postOwnerId)
            .collection('notifications')
            .add({
          'type': 'comment',
          'senderId': currentUid,
          'senderName': userData['name'] ?? 'Biri',
          'senderImage': userData['profileImage'],
          'comment': commentText,
          'message': 'yorum yaptı: $commentText',
          'postId': widget.postId,
          'postImageUrl': widget.postImageUrl, 
          'mediaType': widget.mediaType,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint("Bildirim hatası: $e");
      }
    }

    _commentController.clear();
    if (mounted) FocusScope.of(context).unfocus(); 
  }

  // --- YORUM SİLME FONKSİYONU ---
  void _deleteComment(String commentId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Yorumu Sil", style: TextStyle(color: Colors.white)),
        content: const Text("Bu yorumu silmek istediğine emin misin?", style: TextStyle(color: Colors.white70)),
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
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yorum silindi.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Yorumlar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Yorum Listesi
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CustomLoading());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Henüz yorum yok. İlk yorumu sen yap!", style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index]; 
                    var data = doc.data() as Map<String, dynamic>;
                    
                    return _CommentTile(
                      data: data,
                      commentId: doc.id,
                      currentUid: currentUid,
                      postOwnerId: widget.postOwnerId, 
                      onDelete: () => _deleteComment(doc.id),
                    );
                  },
                );
              },
            ),
          ),
          
          // Yorum Yazma Alanı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            color: Colors.grey[900],
            child: SafeArea(
              child: Row(
                children: [
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
                    builder: (context, snapshot) {
                      String? myImage;
                      if (snapshot.hasData && snapshot.data!.exists) {
                          var data = snapshot.data!.data() as Map<String, dynamic>;
                          myImage = data['profileImage'];
                      }
                      
                      ImageProvider? foregroundImage;
                      if (myImage != null && myImage.isNotEmpty) {
                        foregroundImage = NetworkImage(myImage);
                      }

                      return CircleAvatar(
                        radius: 18,
                        backgroundImage: const AssetImage('assets/logo.jpg'),
                        foregroundImage: foregroundImage,
                        backgroundColor: Colors.grey[800],
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Yorum ekle...",
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.greenAccent),
                    onPressed: _postComment,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String commentId;
  final String currentUid;
  final String postOwnerId;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.data,
    required this.commentId,
    required this.currentUid,
    required this.postOwnerId,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(data['uid']).get(),
      builder: (context, snapshot) {
        String name = "Kullanıcı";
        String? image;
        bool isVerified = false; 
        
        if (snapshot.hasData && snapshot.data!.exists) {
          var userData = snapshot.data!.data() as Map<String, dynamic>;
          name = userData['name'] ?? name;
          image = userData['profileImage'];
          isVerified = userData['isVerified'] ?? false; 
        }

        ImageProvider? foregroundImage;
        if (image != null && image.isNotEmpty) {
          foregroundImage = NetworkImage(image);
        }

        bool canDelete = (data['uid'] == currentUid) || (postOwnerId == currentUid);

        return ListTile(
          onLongPress: canDelete ? onDelete : null,
          leading: CircleAvatar(
            backgroundImage: const AssetImage('assets/logo.jpg'),
            foregroundImage: foregroundImage,
            backgroundColor: Colors.grey[800],
          ),
          title: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white),
              children: [
                TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (isVerified)
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Icon(Icons.verified, color: Colors.greenAccent, size: 14),
                    ),
                  ),
                const TextSpan(text: " "), 
                TextSpan(text: data['text']),
              ],
            ),
          ),
        );
      },
    );
  }
}