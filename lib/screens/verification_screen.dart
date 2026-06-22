import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  File? _imageFile;
  bool _isUploading = false;
  final TextEditingController _noteController = TextEditingController();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<void> _submitRequest() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir belge veya fotoğraf seçin.")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1. Resmi Yükle
      String fileName = "verification_$_uid.jpg";
      Reference ref = FirebaseStorage.instance.ref().child('verifications/$fileName');
      await ref.putFile(_imageFile!);
      String downloadUrl = await ref.getDownloadURL();

      // 2. İsteği Kaydet
      await FirebaseFirestore.instance.collection('verification_requests').doc(_uid).set({
        'uid': _uid,
        'documentUrl': downloadUrl,
        'note': _noteController.text.trim(),
        'status': 'pending', 
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text("Başarılı", style: TextStyle(color: Colors.white)),
            content: const Text("Belgelerin gönderildi. Ekibimiz inceledikten sonra hesabın onaylanacak.", style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  Navigator.pop(context);
                },
                child: const Text("Tamam", style: TextStyle(color: Colors.greenAccent)),
              )
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Hesap Doğrulama", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.security, size: 80, color: Colors.greenAccent),
            const SizedBox(height: 20),
            const Text(
              "Paylaşım yapabilmek için hesabını doğrulamamız gerekiyor.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Lütfen antrenörlük belgeni veya spor kulübünün logosunu/resmi evrağını yükle.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),

            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: _imageFile != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(_imageFile!, fit: BoxFit.cover))
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, color: Colors.white, size: 40),
                          SizedBox(height: 10),
                          Text("Belge/Fotoğraf Seç", style: TextStyle(color: Colors.white70)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _noteController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Ek not (Opsiyonel)",
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                ),
                child: _isUploading 
                  ? const CircularProgressIndicator(color: Colors.black) 
                  : const Text("Gönder ve Onay İste", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}