import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'create_group_screen.dart';
import 'other_profile_screen.dart'; // Profil yönlendirmesi için
import '../widgets/story_avatar.dart'; // Akıllı Avatar
import '../widgets/custom_loading.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  String _searchText = ""; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mesajlar")),
      
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.greenAccent,
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateGroupScreen()));
        },
        child: const Icon(Icons.group_add, color: Colors.black),
      ),
      
      body: Column(
        children: [
          // ARAMA ÇUBUĞU
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Sohbet veya grup ara...",
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) {
                setState(() => _searchText = val.toLowerCase());
              },
            ),
          ),

          // SOHBET LİSTESİ
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('users', arrayContains: currentUid)
                  .orderBy('lastMessageTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: const CustomLoading());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Henüz mesaj yok.", style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    
                    bool isGroup = data['isGroup'] ?? false;
                    String lastMessage = data['lastMessage'] ?? '';
                    Timestamp? lastReadTime = data['lastRead_$currentUid'];
                    Timestamp? lastMessageTime = data['lastMessageTime'];
                    String lastSenderId = data['lastSenderId'] ?? '';

                    bool isUnread = false;
                    if (lastMessageTime != null && lastSenderId != currentUid) {
                      if (lastReadTime == null || lastMessageTime.compareTo(lastReadTime) > 0) {
                        isUnread = true;
                      }
                    }

                    // --- GRUP MU KİŞİ Mİ? ---
                    if (isGroup) {
                      // ** GRUP İSE (Yeşil Tık Yok) **
                      String groupName = data['groupName'] ?? 'Grup';
                      String groupImage = data['groupImage'] ?? ''; 
                      
                      if (_searchText.isNotEmpty && !groupName.toLowerCase().contains(_searchText)) {
                        return const SizedBox.shrink();
                      }

                      return ListTile(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
                            chatId: doc.id,
                            receiverName: groupName,
                            receiverImage: groupImage, 
                            isGroup: true,
                          )));
                        },
                        leading: CircleAvatar(
                          backgroundColor: Colors.greenAccent.withOpacity(0.2),
                          backgroundImage: groupImage.isNotEmpty ? NetworkImage(groupImage) : null,
                          child: groupImage.isEmpty ? const Icon(Icons.groups, color: Colors.greenAccent) : null,
                        ),
                        title: Text(groupName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isUnread ? Colors.white : Colors.grey)),
                        trailing: isUnread ? const CircleAvatar(radius: 5, backgroundColor: Colors.red) : null,
                      );
                    } else {
                      // ** KİŞİ İSE (StoryAvatar ve Yeşil Tık BURAYA GELİYOR) **
                      List users = data['users'];
                      String otherUserId = users.firstWhere((id) => id != currentUid, orElse: () => currentUid);

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData) return const SizedBox();
                          
                          var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                          String name = userData['name'] ?? 'Kullanıcı';
                          String? image = userData['profileImage'];
                          
                          // --- YENİ: Onay Durumu ---
                          bool isVerified = userData['isVerified'] ?? false;

                          if (_searchText.isNotEmpty && !name.toLowerCase().contains(_searchText)) {
                            return const SizedBox.shrink();
                          }

                          return ListTile(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
                                receiverId: otherUserId,
                                receiverName: name,
                                receiverImage: image,
                                isGroup: false,
                              )));
                            },
                            leading: StoryAvatar(
                              userId: otherUserId,
                              imageUrl: image,
                              radius: 20, 
                              onTapFallback: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfileScreen(userId: otherUserId)));
                              },
                            ),
                            // --- GÜNCELLENEN KISIM: İSİM VE TIK ---
                            title: Row(
                              children: [
                                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                if (isVerified)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4.0),
                                    child: Icon(Icons.verified, color: Colors.greenAccent, size: 16),
                                  ),
                              ],
                            ),
                            subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isUnread ? Colors.white : Colors.grey)),
                            trailing: isUnread ? const CircleAvatar(radius: 5, backgroundColor: Colors.red) : null,
                          );
                        },
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}