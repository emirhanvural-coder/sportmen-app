import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart'; 
import 'create_group_screen.dart'; 
import 'home_screen.dart'; 
import '../widgets/custom_loading.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const HomeScreen())
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! > 300) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: const Text("Sohbetler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _handleBack,
          ),
        ),
        
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.greenAccent,
          child: const Icon(Icons.add_comment_rounded, color: Colors.black),
          onPressed: () => _showNewChatModal(context),
        ),

        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .where('users', arrayContains: currentUid)
              .orderBy('lastMessageTime', descending: true)
              .limit(20) 
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CustomLoading());
            }
            
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState();
            }

            var docs = snapshot.data!.docs;

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (context, index) => Divider(color: Colors.grey[900], height: 1),
              itemBuilder: (context, index) {
                var chatDoc = docs[index];
                var chatData = chatDoc.data() as Map<String, dynamic>;
                
                bool isGroup = chatData['isGroup'] == true;
                
                String receiverId = "";
                String groupName = "";
                String? groupImage;

                if (isGroup) {
                  groupName = chatData['groupName'] ?? "Grup";
                  groupImage = chatData['groupImage'];
                } else {
                  List users = chatData['users'] ?? [];
                  receiverId = users.firstWhere((id) => id != currentUid, orElse: () => "");
                }

                bool hasUnread = false;
                String lastSenderId = chatData['lastSenderId'] ?? '';
                
                if (lastSenderId != currentUid) {
                  Timestamp? lastMsgTime = chatData['lastMessageTime'];
                  Timestamp? myLastRead = chatData['lastRead_$currentUid'];
                  if (lastMsgTime != null) {
                     if (myLastRead == null || lastMsgTime.compareTo(myLastRead) > 0) {
                       hasUnread = true;
                     }
                  }
                }

                if (!isGroup && receiverId.isEmpty) return const SizedBox();

                return _ChatListItem(
                  key: ValueKey(chatDoc.id),
                  chatId: chatDoc.id,
                  receiverId: receiverId, 
                  lastMessage: chatData['lastMessage'] ?? '',
                  hasUnread: hasUnread,
                  currentUid: currentUid,
                  isGroup: isGroup,       
                  staticName: groupName,  
                  staticImage: groupImage,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[800]),
          const SizedBox(height: 10),
          const Text("Henüz mesaj yok.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _showNewChatModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.9, expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Yeni Sohbet", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.greenAccent, child: Icon(Icons.group_add, color: Colors.black)),
                  title: const Text("Yeni Grup Oluştur", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateGroupScreen()));
                  },
                ),
                const Divider(color: Colors.grey),

                Expanded(
                  child: FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance.collection('users').limit(50).get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CustomLoading());
                      var users = snapshot.data!.docs;

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          var userData = users[index].data() as Map<String, dynamic>;
                          String uid = users[index].id;
                          if (uid == currentUid) return const SizedBox();
                          
                          bool isVerified = userData['isVerified'] ?? false;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey[800],
                              // BURADA SADECE KİŞİLER LİSTELENİYOR, O YÜZDEN VARSAYILAN HEP LOGO OLMALI
                              backgroundImage: const AssetImage('assets/logo.jpg'),
                              foregroundImage: (userData['profileImage'] != null && userData['profileImage'] != '') 
                                  ? NetworkImage(userData['profileImage']) 
                                  : null,
                            ),
                            title: Row(
                              children: [
                                Text(userData['name'] ?? 'Kullanıcı', style: const TextStyle(color: Colors.white)),
                                if (isVerified)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4.0),
                                    child: Icon(Icons.verified, color: Colors.greenAccent, size: 16),
                                  ),
                              ],
                            ),
                            trailing: const Icon(Icons.send, color: Colors.greenAccent),
                            onTap: () async {
                              Navigator.pop(context);
                              await Future.delayed(const Duration(milliseconds: 200));
                              if (mounted) {
                                _navigateToChat(uid, userData['name'], userData['profileImage']);
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _navigateToChat(String uid, String? name, String? image) {
    List<String> ids = [currentUid, uid];
    ids.sort(); 
    String chatId = "${ids[0]}_${ids[1]}";
    Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
        chatId: chatId, receiverId: uid, receiverName: name ?? 'Kullanıcı', receiverImage: image, isGroup: false
    )));
  }
}

// --- SOHBET LİSTESİ ELEMANI ---
class _ChatListItem extends StatefulWidget {
  final String chatId;
  final String receiverId;
  final String lastMessage;
  final bool hasUnread;
  final String currentUid;
  final bool isGroup;
  final String staticName; 
  final String? staticImage;

  const _ChatListItem({
    super.key,
    required this.chatId,
    required this.receiverId,
    required this.lastMessage,
    required this.hasUnread,
    required this.currentUid,
    required this.isGroup,
    required this.staticName,
    this.staticImage,
  });

  @override
  State<_ChatListItem> createState() => _ChatListItemState();
}

class _ChatListItemState extends State<_ChatListItem> {
  String name = "Yükleniyor...";
  String? image;
  bool isLoading = true;
  bool isVerified = false; 

  @override
  void initState() {
    super.initState();
    if (widget.isGroup) {
      name = widget.staticName;
      image = widget.staticImage;
      isLoading = false;
    } else {
      _loadUserData();
    }
  }

  void _loadUserData() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.receiverId)
          .get(const GetOptions(source: Source.serverAndCache)); 
      
      if (doc.exists && mounted) {
        var data = doc.data() as Map<String, dynamic>;
        setState(() {
          name = data['name'] ?? 'Kullanıcı';
          image = data['profileImage'];
          isVerified = data['isVerified'] ?? false; 
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _deleteChat() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Sohbeti Sil", style: TextStyle(color: Colors.white)),
        content: const Text("Silmek istiyor musun?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("İptal")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("SİL", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      var batch = FirebaseFirestore.instance.batch();
      var msgs = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').get();
      for(var m in msgs.docs) batch.delete(m.reference);
      batch.delete(FirebaseFirestore.instance.collection('chats').doc(widget.chatId));
      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const ListTile(
        leading: CircleAvatar(backgroundColor: Colors.grey, radius: 24),
        title: SizedBox(width: 100, height: 15, child: LinearProgressIndicator(color: Colors.grey, minHeight: 2)),
      );
    }

    return ListTile(
      onLongPress: _deleteChat,
      onTap: () {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => ChatScreen(
            chatId: widget.chatId,
            receiverId: widget.isGroup ? null : widget.receiverId,
            receiverName: name, 
            receiverImage: image, 
            isGroup: widget.isGroup, 
          ))
        );
      },
      // --- DÜZELTİLEN KISIM: LOGO vs GRUP İKONU MANTIĞI ---
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey[800],
        
        // 1. Resim varsa -> Göster
        // 2. Resim Yoksa VE Grupsa -> null (Child ikon gözüksün diye)
        // 3. Resim Yoksa VE Kişiyse -> Logo Göster
        backgroundImage: (image != null && image!.isNotEmpty) 
            ? NetworkImage(image!) 
            : (widget.isGroup ? null : const AssetImage('assets/logo.jpg')),
        
        // Sadece grup ve resmi yoksa İkon göster
        child: (widget.isGroup && (image == null || image!.isEmpty)) 
            ? const Icon(Icons.groups, color: Colors.white) 
            : null,
      ),
      title: Row(
        children: [
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          if (isVerified && !widget.isGroup) 
            const Padding(
              padding: EdgeInsets.only(left: 4.0),
              child: Icon(Icons.verified, color: Colors.greenAccent, size: 16),
            ),
        ],
      ),
      subtitle: Text(
        widget.lastMessage, 
        style: TextStyle(color: widget.hasUnread ? Colors.white : Colors.grey, fontWeight: widget.hasUnread ? FontWeight.bold : FontWeight.normal),
        maxLines: 1, 
        overflow: TextOverflow.ellipsis
      ),
      trailing: widget.hasUnread 
        ? Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))
        : null,
    );
  }
}