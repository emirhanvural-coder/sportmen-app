import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'story_avatar.dart'; // Avatar görünümü için

class ShareBottomSheet extends StatefulWidget {
  final String postId;
  final String postImageUrl;
  final String mediaType; // 'image' veya 'video'
  final String postOwnerName; // Kartta göstermek için
  
  // --- YENİ EKLENEN ALANLAR ---
  final String? postOwnerImage; 
  final bool postOwnerVerified;

  const ShareBottomSheet({
    super.key,
    required this.postId,
    required this.postImageUrl,
    required this.mediaType,
    this.postOwnerName = 'Kullanıcı',
    this.postOwnerImage, 
    this.postOwnerVerified = false,
  });

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  
  List<Map<String, dynamic>> _allTargets = []; // Hem gruplar hem kişiler burada olacak
  List<Map<String, dynamic>> _filteredTargets = []; // Arama sonucu
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTargets();
  }

  // --- HEDEF KİTLEYİ ÇEK (Gruplar + Takip Edilenler) ---
  Future<void> _fetchTargets() async {
    List<Map<String, dynamic>> tempList = [];

    try {
      // 1. GRUPLARI ÇEK
      var groupSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('users', arrayContains: currentUid)
          .where('isGroup', isEqualTo: true)
          .get();

      for (var doc in groupSnapshot.docs) {
        var data = doc.data();
        tempList.add({
          'type': 'group',
          'id': doc.id, // Chat ID
          'name': data['groupName'] ?? 'Grup',
          'image': data['groupImage'],
          'isVerified': false, // Gruplarda tık olmaz
        });
      }

      // 2. TAKİP ETTİKLERİMİ ÇEK
      var currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
      List followingIds = currentUserDoc.data()?['following'] ?? [];

      if (followingIds.isNotEmpty) {
        for (var userId in followingIds) {
          var userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
          if (userDoc.exists) {
            var data = userDoc.data()!;
            tempList.add({
              'type': 'user',
              'id': userId, // User ID
              'name': data['name'] ?? 'Kullanıcı',
              'image': data['profileImage'],
              'isVerified': data['isVerified'] ?? false,
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _allTargets = tempList;
          _filteredTargets = tempList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Hata: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ARAMA FONKSİYONU ---
  void _filterSearchResults(String query) {
    if (query.isEmpty) {
      setState(() => _filteredTargets = _allTargets);
    } else {
      setState(() {
        _filteredTargets = _allTargets
            .where((target) => target['name'].toString().toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    }
  }

  // --- GÖNDERME İŞLEMİ ---
  void _sendPost(Map<String, dynamic> target) async {
    String chatId;

    // Eğer hedef bir GRUP ise ID zaten bellidir
    if (target['type'] == 'group') {
      chatId = target['id'];
    } 
    // Eğer hedef bir KİŞİ ise Chat ID'yi oluşturmamız lazım
    else {
      List<String> ids = [currentUid, target['id']];
      ids.sort();
      chatId = "${ids[0]}_${ids[1]}";
      
      var chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) {
        await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
          'users': ids,
          'isGroup': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // MESAJI GÖNDER (VERİLERİN EKSİKSİZ GİTMESİ ÇOK ÖNEMLİ)
    await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUid,
      'receiverId': target['type'] == 'user' ? target['id'] : '', 
      'message': 'Bir gönderi paylaştı',
      'type': 'post', // <--- TİP: POST
      
      // KART İÇİN GEREKLİ DETAYLAR:
      'postId': widget.postId,
      'postImageUrl': widget.postImageUrl,
      'mediaType': widget.mediaType,
      'postOwnerName': widget.postOwnerName,
      'postOwnerImage': widget.postOwnerImage, // <-- RESMİ KAYDEDİYORUZ
      'postOwnerVerified': widget.postOwnerVerified, // <-- TİKİ KAYDEDİYORUZ
      
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(), // Sıralama için
      'isRead': false,
    });

    // Sohbetin son mesajını güncelle
    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'lastMessage': '📷 Bir gönderi paylaşıldı',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': currentUid,
      'users': FieldValue.arrayUnion([currentUid]), 
    });

    if (mounted) {
      Navigator.pop(context); // Pencereyi kapat
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${target['name']} adlı kişiye gönderildi! 🚀"),
          backgroundColor: Colors.greenAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7, 
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 15),
          
          // ARAMA ÇUBUĞU
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: TextField(
              controller: _searchController,
              onChanged: _filterSearchResults,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Ara...",
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.black54,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          
          const SizedBox(height: 10),

          // LİSTE
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                : _filteredTargets.isEmpty
                    ? const Center(child: Text("Kimse bulunamadı.", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _filteredTargets.length,
                        itemBuilder: (context, index) {
                          var item = _filteredTargets[index];
                          bool isGroup = item['type'] == 'group';

                          return ListTile(
                            leading: isGroup 
                              ? CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.greenAccent.withOpacity(0.2),
                                  backgroundImage: (item['image'] != null && item['image'] != '') ? NetworkImage(item['image']) : null,
                                  child: (item['image'] == null || item['image'] == '') ? const Icon(Icons.groups, color: Colors.greenAccent) : null,
                                )
                              : StoryAvatar(
                                  userId: item['id'],
                                  imageUrl: item['image'],
                                  radius: 22,
                                  hasBorder: false,
                                ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    item['name'], 
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (item['isVerified'] == true)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4.0),
                                    child: Icon(Icons.verified, color: Colors.greenAccent, size: 14),
                                  ),
                              ],
                            ),
                            subtitle: Text(isGroup ? "Grup" : "Kişi", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            trailing: ElevatedButton(
                              onPressed: () => _sendPost(item),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent, 
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
                              ),
                              child: const Text("Gönder", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}