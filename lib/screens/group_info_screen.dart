import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'other_profile_screen.dart';
import '../widgets/custom_loading.dart';

class GroupInfoScreen extends StatefulWidget {
  final String chatId;
  final String groupName;
  final String adminId;

  const GroupInfoScreen({
    super.key,
    required this.chatId,
    required this.groupName,
    required this.adminId,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool _isUploading = false;

  // --- GRUP RESMİNİ DEĞİŞTİRME ---
  Future<void> _updateGroupImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 70);

    if (image != null) {
      setState(() => _isUploading = true);
      try {
        File file = File(image.path);
        String fileName = "group_${widget.chatId}_${DateTime.now().millisecondsSinceEpoch}.jpg";
        Reference ref = FirebaseStorage.instance.ref().child('group_images/$fileName');
        
        await ref.putFile(file);
        String downloadUrl = await ref.getDownloadURL();

        await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
          'groupImage': downloadUrl
        });

        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Grup resmi güncellendi.")));

      } catch (e) {
        debugPrint("Hata: $e");
      } finally {
        if(mounted) setState(() => _isUploading = false);
      }
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        height: 150,
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildOption(Icons.camera_alt, "Kamera", () { Navigator.pop(context); _updateGroupImage(ImageSource.camera); }),
            _buildOption(Icons.photo_library, "Galeri", () { Navigator.pop(context); _updateGroupImage(ImageSource.gallery); }),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(IconData icon, String label, VoidCallback onTap) {
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

  // --- ÜYE ÇIKARMA İŞLEMİ ---
  void _removeMember(String memberId, String memberName) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Üyeyi Çıkar", style: TextStyle(color: Colors.white)),
        content: Text("$memberName gruptan çıkarılsın mı?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("İptal")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("ÇIKAR", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
        'users': FieldValue.arrayRemove([memberId])
      });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$memberName çıkarıldı.")));
    }
  }

  // --- GRUPTAN AYRILMA ---
  void _leaveGroup() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Gruptan Ayrıl", style: TextStyle(color: Colors.white)),
        content: const Text("Bu gruptan çıkmak istiyor musun?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("İptal")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("AYRIL", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
        'users': FieldValue.arrayRemove([currentUid])
      });
      if(mounted) {
        Navigator.pop(context); // Ekranı kapat
        Navigator.pop(context); // Sohbetten de çık
      }
    }
  }

  // --- GRUBU SİLME ---
  void _deleteGroup() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Grubu Sil", style: TextStyle(color: Colors.white)),
        content: const Text("Grup kalıcı olarak silinecek.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("İptal")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("SİL", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).delete();
      if(mounted) {
        Navigator.pop(context); 
        Navigator.pop(context);
      }
    }
  }

  // --- ÜYE EKLEME MENÜSÜ ---
  void _showAddMemberSheet(List<dynamic> currentMembers) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(15.0),
              child: Text("Üye Ekle", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: const CustomLoading());
                  
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').limit(50).snapshots(),
                    builder: (context, allUsersSnap) {
                      if (!allUsersSnap.hasData) return const SizedBox();
                      var allUsers = allUsersSnap.data!.docs;
                      
                      // Zaten grupta olanları çıkar
                      var potentialMembers = allUsers.where((doc) => !currentMembers.contains(doc.id)).toList();

                      if (potentialMembers.isEmpty) {
                        return const Center(child: Text("Eklenebilecek kimse yok.", style: TextStyle(color: Colors.grey)));
                      }

                      return ListView.builder(
                        itemCount: potentialMembers.length,
                        itemBuilder: (context, index) {
                          var userDoc = potentialMembers[index];
                          var user = userDoc.data() as Map<String, dynamic>;
                          // 1. ONAY DURUMU
                          bool isVerified = user['isVerified'] ?? false;
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: const AssetImage('assets/logo.jpg'),
                              foregroundImage: user['profileImage'] != null ? NetworkImage(user['profileImage']) : null,
                            ),
                            // 2. İSİM VE TIK
                            title: Row(
                              children: [
                                Text(user['name'] ?? 'İsimsiz', style: const TextStyle(color: Colors.white)),
                                if (isVerified)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4.0),
                                    child: Icon(Icons.verified, color: Colors.greenAccent, size: 16),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.greenAccent),
                              onPressed: () async {
                                await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
                                  'users': FieldValue.arrayUnion([userDoc.id])
                                });
                                if (context.mounted) Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Üye eklendi!")));
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool iAmAdmin = (widget.adminId == currentUid);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: const BackButton(color: Colors.white),
        title: const Text("Grup Bilgisi", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.red),
            onPressed: _leaveGroup,
            tooltip: "Gruptan Ayrıl",
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: const CustomLoading());
          
          if (!snapshot.data!.exists) return const Center(child: Text("Bu grup silinmiş.", style: TextStyle(color: Colors.white)));

          var data = snapshot.data!.data() as Map<String, dynamic>;
          List users = data['users'] ?? [];
          String adminId = data['adminId'] ?? widget.adminId;
          String groupImage = data['groupImage'] ?? '';
          String groupName = data['groupName'] ?? widget.groupName;

          iAmAdmin = (adminId == currentUid);

          return Column(
            children: [
              const SizedBox(height: 20),
              // GRUP RESMİ
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: iAmAdmin ? _showImagePickerModal : null, 
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: groupImage.isNotEmpty ? NetworkImage(groupImage) : null,
                            child: groupImage.isEmpty ? const Icon(Icons.groups, size: 50, color: Colors.white) : null,
                          ),
                          if (_isUploading)
                             const Positioned.fill(child: const CustomLoading()),
                          if (iAmAdmin)
                            const Positioned(
                              bottom: 0, right: 0,
                              child: CircleAvatar(radius: 15, backgroundColor: Colors.greenAccent, child: Icon(Icons.edit, size: 16, color: Colors.black)),
                            )
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(groupName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    Text("${users.length} Üye", style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // YÖNETİCİ BUTONLARI
              if (iAmAdmin)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                      icon: const Icon(Icons.person_add, color: Colors.black),
                      label: const Text("Ekle", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      onPressed: () => _showAddMemberSheet(users),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: const Text("Grubu Sil", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: _deleteGroup,
                    ),
                  ],
                ),
              
              const Divider(color: Colors.grey, height: 40),

              // ÜYE LİSTESİ
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Align(alignment: Alignment.centerLeft, child: Text("Üyeler", style: TextStyle(color: Colors.greenAccent, fontSize: 16))),
              ),
              
              Expanded(
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    String memberId = users[index];
                    
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(memberId).get(),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData) return const SizedBox();
                        var user = userSnap.data!.data() as Map<String, dynamic>;
                        
                        String name = user['name'] ?? 'İsimsiz';
                        String? image = user['profileImage'];
                        bool isMemberAdmin = (memberId == adminId);
                        bool isMe = (memberId == currentUid);
                        // 3. ONAY DURUMU
                        bool isVerified = user['isVerified'] ?? false;

                        return ListTile(
                          onTap: () {
                            if (!isMe) {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfileScreen(userId: memberId)));
                            }
                          },
                          leading: CircleAvatar(
                            backgroundImage: const AssetImage('assets/logo.jpg'),
                            foregroundImage: image != null ? NetworkImage(image) : null,
                          ),
                          // 4. İSİM VE TIK
                          title: Row(
                            children: [
                              Text(name, style: const TextStyle(color: Colors.white)),
                              if (isVerified)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4.0),
                                  child: Icon(Icons.verified, color: Colors.greenAccent, size: 16),
                                ),
                              if (isMe) const Text(" (Sen)", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                          subtitle: isMemberAdmin ? const Text("Yönetici", style: TextStyle(color: Colors.greenAccent)) : null,
                          
                          trailing: (iAmAdmin && !isMe) 
                            ? IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () => _removeMember(memberId, name),
                              ) 
                            : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}