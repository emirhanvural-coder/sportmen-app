import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  
  bool _isLoading = false;
  File? _imageFile; 
  String? _currentImageUrl;
  bool _isVerified = false; // --- YENİ DEĞİŞKEN ---

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    var doc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
    if (doc.exists) {
      var data = doc.data() as Map<String, dynamic>;
      setState(() {
        _nameController.text = data['name'] ?? "";
        _bioController.text = data['bio'] ?? "";
        _currentImageUrl = data['profileImage'];
        _isVerified = data['isVerified'] ?? false; // --- VERİ ÇEKME ---
      });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  void _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      String? newImageUrl = _currentImageUrl;

      if (_imageFile != null) {
        String fileName = "${currentUid}_profile.jpg";
        Reference ref = FirebaseStorage.instance.ref().child('profile_images/$fileName');
        await ref.putFile(_imageFile!);
        newImageUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('users').doc(currentUid).update({
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'profileImage': newImageUrl, 
      });

      if(mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil güncellendi ✅")));
      }
    } catch (e) {
      debugPrint("Hata: $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hata oluştu.")));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Profili Düzenle"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.greenAccent),
            onPressed: _isLoading ? null : _saveProfile,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            if (_isLoading) const LinearProgressIndicator(color: Colors.greenAccent),
            const SizedBox(height: 20),
            
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: _imageFile != null
                        ? FileImage(_imageFile!) as ImageProvider
                        : (_currentImageUrl != null 
                            ? NetworkImage(_currentImageUrl!) 
                            : const AssetImage('assets/logo.jpg')), 
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 20, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickImage,
              child: const Text("Profil Fotoğrafını Değiştir", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            ),

            const SizedBox(height: 30),
            
            // --- GÜNCELLEME: İSİM GİRİŞİ YANINDA ONAY TIKI (Görsel olarak) ---
            // Sadece bilgilendirme amaçlı gösteriyoruz, değiştirilemez olduğu anlaşılsın.
            if (_isVerified)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.verified, color: Colors.greenAccent, size: 20),
                    SizedBox(width: 5),
                    Text("Hesabınız Onaylıdır", style: TextStyle(color: Colors.greenAccent)),
                  ],
                ),
              ),

            _buildTextField("Ad Soyad", _nameController),
            const SizedBox(height: 20),
            _buildTextField("Biyografi", _bioController, maxLines: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.grey),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.greenAccent),
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.grey[900],
      ),
    );
  }
}