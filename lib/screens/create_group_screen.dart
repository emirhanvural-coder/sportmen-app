import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/custom_loading.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  
  File? _groupImage;
  bool _isLoading = false;
  List<String> _selectedUserIds = [];

  // --- RESİM SEÇME FONKSİYONU ---
  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      setState(() {
        _groupImage = File(image.path);
      });
    }
  }

  // --- KAMERA/GALERİ SEÇİM MENÜSÜ ---
  void _showImageSourceModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Grup Resmi Seç", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSourceOption(Icons.camera_alt, "Kamera", ImageSource.camera),
                    _buildSourceOption(Icons.photo_library, "Galeri", ImageSource.gallery),
                  ],
                ),
                const SizedBox(height: 20), 
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceOption(IconData icon, String label, ImageSource source) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context); 
        _pickImage(source); 
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 30, backgroundColor: Colors.grey[800], child: Icon(icon, color: Colors.greenAccent, size: 30)),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  void _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir grup ismi girin.")));
      return;
    }
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("En az 1 kişi seçmelisin.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl;
      // 1. Resim varsa Storage'a yükle
      if (_groupImage != null) {
        String fileName = "group_${DateTime.now().millisecondsSinceEpoch}.jpg";
        Reference ref = FirebaseStorage.instance.ref().child('group_images/$fileName');
        await ref.putFile(_groupImage!);
        imageUrl = await ref.getDownloadURL();
      }

      // 2. Kendimi de listeye ekle
      List<String> members = [..._selectedUserIds, currentUid];

      // 3. Veritabanına kaydet
      await FirebaseFirestore.instance.collection('chats').add({
        'isGroup': true,
        'groupName': _groupNameController.text.trim(),
        'groupImage': imageUrl ?? '',
        'adminId': currentUid, 
        'users': members,
        'lastMessage': 'Grup oluşturuldu',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastSenderId': currentUid,
        'lastRead_$currentUid': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Grup oluşturuldu!")));
      }

    } catch (e) {
      debugPrint("Grup hatası: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Yeni Grup", style: TextStyle(color: Colors.white)),
        leading: const BackButton(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createGroup,
            child: const Text("Oluştur", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
      body: _isLoading 
          ? const Center(child: const CustomLoading())
          : Column(
            children: [
              // --- ÜST KISIM: RESİM VE İSİM ---
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.grey[900],
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _showImageSourceModal, 
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey[800],
                        backgroundImage: _groupImage != null ? FileImage(_groupImage!) : null,
                        child: _groupImage == null ? const Icon(Icons.camera_alt, color: Colors.white) : null,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: TextField(
                        controller: _groupNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Grup Adı",
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const Padding(
                padding: EdgeInsets.all(10.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Üyeleri Seç", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                ),
              ),

              // --- KULLANICI LİSTESİ ---
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').limit(50).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: const CustomLoading());
                    var users = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        var userData = users[index].data() as Map<String, dynamic>;
                        String uid = users[index].id;

                        if (uid == currentUid) return const SizedBox();

                        bool isSelected = _selectedUserIds.contains(uid);
                        
                        // --- YENİ: Onay Durumu ---
                        bool isVerified = userData['isVerified'] ?? false;

                        return CheckboxListTile(
                          activeColor: Colors.greenAccent,
                          checkColor: Colors.black,
                          // --- GÜNCELLENEN KISIM: İSİM VE TIK ---
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
                          secondary: CircleAvatar(
                            backgroundImage: const AssetImage('assets/logo.jpg'),
                            foregroundImage: (userData['profileImage'] != null) ? NetworkImage(userData['profileImage']) : null,
                            backgroundColor: Colors.grey[800],
                          ),
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedUserIds.add(uid);
                              } else {
                                _selectedUserIds.remove(uid);
                              }
                            });
                          },
                        );
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