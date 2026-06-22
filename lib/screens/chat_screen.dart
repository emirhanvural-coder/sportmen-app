import 'dart:io';
import 'package:flutter/cupertino.dart'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart'; 
import 'post_detail_screen.dart'; 
import 'group_info_screen.dart';
import 'other_profile_screen.dart';
import '../widgets/custom_loading.dart';
import '../services/notification_sender.dart'; // Bildirim servisi eklendi

class ChatScreen extends StatefulWidget {
  final String? receiverId; 
  final String receiverName; 
  final String? receiverImage;
  final bool isGroup; 
  final String? chatId; 

  const ChatScreen({
    super.key,
    this.receiverId,
    required this.receiverName,
    this.receiverImage,
    this.isGroup = false, 
    this.chatId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  late String chatId;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isGroup) {
      chatId = widget.chatId!;
    } else {
      List<String> ids = [currentUid, widget.receiverId!];
      ids.sort(); 
      chatId = "${ids[0]}_${ids[1]}";
    }
    _markAsRead();
  }

  void _markAsRead() async {
    try {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'lastRead_$currentUid': FieldValue.serverTimestamp(), 
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _sendMessageToFirestore({required String text, required String type, String? imageUrl}) async {
    // 1. Mesajı Kaydet
    await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUid, 
      'receiverId': widget.receiverId, 
      'text': text, 
      'imageUrl': imageUrl, 
      'type': type, 
      'isRead': false, 
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Chat Özetini Güncelle
    Map<String, dynamic> updateData = {
      'lastMessage': type == 'image' ? '📷 Fotoğraf' : (type == 'post' ? '📷 Bir gönderi paylaşıldı' : text),
      'lastSenderId': currentUid,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastRead_$currentUid': FieldValue.serverTimestamp(), 
    };

    if (!widget.isGroup && widget.receiverId != null) {
      updateData['users'] = FieldValue.arrayUnion([currentUid, widget.receiverId]);
    }
    
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set(updateData, SetOptions(merge: true));

    // 3. Bildirim Gönder (Instagram & WhatsApp Mantığı)
    try {
      var senderDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
      String senderName = senderDoc.data()?['name'] ?? 'Yeni Mesaj';

      if (widget.isGroup) {
        // --- GRUP BİLDİRİMİ ---
        var chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
        List members = chatDoc.data()?['users'] ?? [];
        
        for (var memberId in members) {
          if (memberId != currentUid) {
            await NotificationSender.sendPushNotification(
              receiverId: memberId,
              title: widget.receiverName, // Bildirimde Grup İsmi Yazar
              body: "$senderName: $text", // Kimin ne yazdığı görünür
              imageUrl: widget.receiverImage, // Varsa grup resmi
              extraData: {'type': 'group_chat', 'chatId': chatId},
            );
          }
        }
      } else if (widget.receiverId != null) {
        // --- BİREYSEL BİLDİRİM ---
        await NotificationSender.sendPushNotification(
          receiverId: widget.receiverId!,
          title: senderName,
          body: text,
          imageUrl: senderDoc.data()?['profileImage'], // Gönderenin resmi
          extraData: {'type': 'private_chat', 'chatId': chatId},
        );
      }
    } catch (e) {
      debugPrint("Bildirim gönderilemedi: $e");
    }
  }

  void _sendTextMessage() {
    if (_messageController.text.trim().isEmpty) return;
    String text = _messageController.text.trim();
    _messageController.clear();
    _sendMessageToFirestore(text: text, type: 'text');
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      setState(() => _isUploading = true);
      File file = File(image.path);
      try {
        String fileName = "${chatId}_${DateTime.now().millisecondsSinceEpoch}.jpg";
        Reference ref = FirebaseStorage.instance.ref().child('chat_images/$fileName');
        await ref.putFile(file);
        String downloadUrl = await ref.getDownloadURL();
        await _sendMessageToFirestore(text: "📷 Fotoğraf", type: 'image', imageUrl: downloadUrl);
      } catch (_) {} finally {
        if(mounted) setState(() => _isUploading = false);
      }
    }
  }

  void _deleteMessage(String messageId, bool isMyMessage) async {
    if (!isMyMessage) return;
    bool? confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Mesajı Sil", style: TextStyle(color: Colors.white)),
        content: const Text("Silmek istiyor musun?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("İptal")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("SİL", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
       var msgRef = FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').doc(messageId);
       var docSnapshot = await msgRef.get();
       if (docSnapshot.exists) {
         var data = docSnapshot.data() as Map<String, dynamic>;
         if (data['type'] == 'image' && data['imageUrl'] != null) {
           try { await FirebaseStorage.instance.refFromURL(data['imageUrl']).delete(); } catch (_) {}
         }
         await msgRef.delete();
       }
    }
  }

  void _goToPostDetail(String postId) async {
    try {
      DocumentSnapshot postDoc = await FirebaseFirestore.instance.collection('posts').doc(postId).get();
      if (postDoc.exists && mounted) {
        Navigator.push(
          context, 
          CupertinoPageRoute(builder: (context) => PostDetailScreen.single(post: postDoc))
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu gönderi silinmiş.")));
      }
    } catch (e) { debugPrint("Hata: $e"); }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 150,
        decoration: BoxDecoration(color: Colors.grey[900], borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildAttachmentOption(Icons.camera_alt, "Kamera", () { Navigator.pop(context); _pickAndSendImage(ImageSource.camera); }),
            _buildAttachmentOption(Icons.image, "Galeri", () { Navigator.pop(context); _pickAndSendImage(ImageSource.gallery); }),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(radius: 30, backgroundColor: Colors.grey[800], child: Icon(icon, color: Colors.greenAccent)),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
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
          title: GestureDetector(
            onTap: () {
               if (widget.isGroup) {
                 Navigator.push(context, MaterialPageRoute(builder: (context) => GroupInfoScreen(chatId: chatId, groupName: widget.receiverName, adminId: '')));
               } else if (widget.receiverId != null) {
                 Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfileScreen(userId: widget.receiverId!)));
               }
            },
            child: Row(
              children: [
                 CircleAvatar(
                   radius: 18,
                   backgroundColor: Colors.grey[800],
                   backgroundImage: (widget.receiverImage != null && widget.receiverImage!.isNotEmpty) 
                       ? NetworkImage(widget.receiverImage!) 
                       : (widget.isGroup ? null : const AssetImage('assets/logo.jpg')),
                   child: (widget.isGroup && (widget.receiverImage == null || widget.receiverImage!.isEmpty)) 
                       ? const Icon(Icons.groups, size: 20, color: Colors.white) 
                       : null,
                 ),
                const SizedBox(width: 10),
                widget.isGroup
                    ? Text(widget.receiverName, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold))
                    : StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').doc(widget.receiverId).snapshots(),
                        builder: (context, snapshot) {
                          bool isVerified = false;
                          String displayName = widget.receiverName;
                          if (snapshot.hasData && snapshot.data!.exists) {
                            var data = snapshot.data!.data() as Map<String, dynamic>;
                            isVerified = data['isVerified'] ?? false;
                            displayName = data['name'] ?? displayName; 
                          }
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(displayName, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                              if (isVerified)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4.0),
                                  child: Icon(Icons.verified, color: Colors.greenAccent, size: 16),
                                ),
                            ],
                          );
                        },
                      ),
              ],
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').orderBy('createdAt', descending: true).limit(50).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CustomLoading());
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Sohbeti başlat! 👋", style: TextStyle(color: Colors.grey)));

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    var unreadDocs = snapshot.data!.docs.where((d) => d['receiverId'] == currentUid && d['isRead'] == false).toList();
                    if (unreadDocs.isNotEmpty) {
                      var batch = FirebaseFirestore.instance.batch();
                      for(var doc in unreadDocs) batch.update(doc.reference, {'isRead': true});
                      batch.commit();
                    }
                  });

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(10),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var messageDoc = snapshot.data!.docs[index];
                      var data = messageDoc.data() as Map<String, dynamic>;
                      String type = data['type'] ?? 'text'; 
                      bool isMe = data['senderId'] == currentUid;

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: () { if (isMe) _deleteMessage(messageDoc.id, isMe); },
                          child: _buildMessageBubble(data, type, isMe),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_isUploading) const Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator(color: Colors.greenAccent)),
            SafeArea(child: _buildMessageInput()),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> data, String type, bool isMe) {
    if (type == 'image') {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FullScreenImageScreen(imageUrl: data['imageUrl']))),
        child: Container(
          margin: const EdgeInsets.all(5),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: isMe ? Colors.greenAccent.withOpacity(0.2) : Colors.grey[800], borderRadius: BorderRadius.circular(15)),
          child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(data['imageUrl'], width: 200, fit: BoxFit.cover)),
        ),
      );
    } 
    else if (type == 'post') { 
      return _buildSharedPostCard(data, isMe); 
    }
    
    return Container(
      margin: const EdgeInsets.all(5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? Colors.greenAccent : Colors.grey[800],
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(15), topRight: const Radius.circular(15),
          bottomLeft: isMe ? const Radius.circular(15) : Radius.zero,
          bottomRight: isMe ? Radius.zero : const Radius.circular(15),
        ),
      ),
      child: Text(data['text'] ?? (data['message'] ?? ''), style: TextStyle(color: isMe ? Colors.black : Colors.white)),
    );
  }

  Widget _buildSharedPostCard(Map<String, dynamic> data, bool isMe) {
    String imageUrl = data['postImageUrl'] ?? '';
    String postId = data['postId'] ?? '';
    String mediaType = data['mediaType'] ?? 'image';
    String postOwnerName = data['postOwnerName'] ?? 'Kullanıcı';
    String? postOwnerImage = data['postOwnerImage']; 
    bool isVerified = data['postOwnerVerified'] ?? false;
    String? thumbnail = data['thumbnailUrl']; 

    return GestureDetector(
      onTap: () => _goToPostDetail(postId),
      child: Container(
        width: 160, 
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.grey[900], 
          borderRadius: BorderRadius.circular(15), 
          border: Border.all(color: isMe ? Colors.greenAccent : Colors.grey[700]!, width: 1.5)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12, 
                    backgroundColor: Colors.grey[800],
                    backgroundImage: (postOwnerImage != null && postOwnerImage.isNotEmpty) 
                        ? NetworkImage(postOwnerImage) 
                        : const AssetImage('assets/logo.jpg') as ImageProvider,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      postOwnerName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isVerified)
                    const Padding(
                      padding: EdgeInsets.only(left: 4.0),
                      child: Icon(Icons.verified, color: Colors.greenAccent, size: 14),
                    ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13.5)), 
              child: SizedBox(
                height: 140, 
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  fit: StackFit.expand,
                  children: [
                      if (thumbnail != null && thumbnail.isNotEmpty)
                        Image.network(thumbnail, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[800]))
                      else if (mediaType == 'video')
                        _VideoThumbnail(videoUrl: imageUrl)
                      else
                        Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[800])),
                      if (mediaType == 'video')
                       const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40))
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: Colors.black, 
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent, size: 30), onPressed: _showAttachmentMenu),
          const SizedBox(width: 5),
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Mesaj yaz...",
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true, fillColor: Colors.grey[900],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(backgroundColor: Colors.greenAccent, child: IconButton(icon: const Icon(Icons.send, color: Colors.black), onPressed: _sendTextMessage)),
        ],
      ),
    );
  }
}

class _VideoThumbnail extends StatefulWidget {
  final String videoUrl;
  const _VideoThumbnail({required this.videoUrl});
  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  late VideoPlayerController _controller;
  bool _isReady = false;
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isReady = true);
          _controller.seekTo(Duration.zero); 
        }
      }).catchError((_) {});
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (!_isReady) return Container(color: Colors.grey[900]); 
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(width: _controller.value.size.width, height: _controller.value.size.height, child: VideoPlayer(_controller)),
    );
  }
}

class FullScreenImageScreen extends StatelessWidget {
  final String imageUrl;
  const FullScreenImageScreen({super.key, required this.imageUrl});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true, 
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.white)),
      body: Dismissible(
        key: const Key('fullscreen'),
        direction: DismissDirection.vertical,
        onDismissed: (_) => Navigator.pop(context),
        child: Center(child: InteractiveViewer(child: Image.network(imageUrl))),
      ),
    );
  }
}