import 'dart:io';
import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:pro_image_editor/pro_image_editor.dart'; 
import 'package:video_compress/video_compress.dart'; 
import 'verification_screen.dart'; // <--- DOĞRULAMA EKRANI İMPORTU

class AddStoryScreen extends StatefulWidget {
  const AddStoryScreen({super.key});

  @override
  State<AddStoryScreen> createState() => _AddStoryScreenState();
}

class _AddStoryScreenState extends State<AddStoryScreen> {
  File? _file;
  String _mediaType = 'image'; 
  bool _isUploading = false;
  VideoPlayerController? _videoController;

  final ImagePicker _picker = ImagePicker();

  // --- YENİ EKLENEN DEĞİŞKENLER (ONAY SİSTEMİ) ---
  bool _isCheckingPermission = true;
  bool _canPost = false;
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  // --- ONAY KONTROLÜ ---
  void _checkPermission() async {
    try {
      var doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (doc.exists) {
        var data = doc.data()!;
        String role = data['role'] ?? 'user';
        bool isApproved = data['isApproved'] ?? false; 

        if ((role == 'coach' || role == 'club') && !isApproved) {
          if (mounted) setState(() { _canPost = false; _isCheckingPermission = false; });
        } else {
          if (mounted) setState(() { _canPost = true; _isCheckingPermission = false; });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingPermission = false);
    }
  }

  // --- VİDEO SIKIŞTIRMA ---
  Future<File?> _compressVideo(File file) async {
    try {
      await VideoCompress.setLogLevel(0);
      final MediaInfo? info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality, 
        deleteOrigin: false,
        includeAudio: true,
      );
      return info != null ? File(info.path!) : null;
    } catch (e) {
      debugPrint("Sıkıştırma hatası: $e");
      return file;
    }
  }

  // --- RESİM EDİTÖRÜ ---
  Future<void> _openEditor(File originalFile) async {
    if (!mounted) return;
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProImageEditor.file(
          originalFile,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (Uint8List bytes) async {
              String path = originalFile.path;
              File editedFile = await File(path).writeAsBytes(bytes);
              
              if (mounted) {
                setState(() {
                  _file = editedFile;
                  _mediaType = 'image';
                  _disposeVideoController();
                });
                Navigator.pop(context); 
              }
            },
          ),
          configs: ProImageEditorConfigs(
            i18n: const I18n(
              done: 'Bitti',
              cancel: 'İptal',
              undo: 'Geri Al',
              redo: 'İleri',
              filterEditor: I18nFilterEditor(bottomNavigationBarText: 'Filtreler'),
              blurEditor: I18nBlurEditor(bottomNavigationBarText: 'Bulanıklık'),
              paintEditor: I18nPaintingEditor(bottomNavigationBarText: 'Çizim'),
              textEditor: I18nTextEditor(bottomNavigationBarText: 'Metin', inputHintText: 'Bir şeyler yaz...'),
              stickerEditor: I18nStickerEditor(bottomNavigationBarText: 'Çıkartma')
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? selected = await _picker.pickImage(source: source, imageQuality: 80);
    if (selected != null) {
      await _openEditor(File(selected.path));
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    final XFile? selected = await _picker.pickVideo(source: source, maxDuration: const Duration(seconds: 15));
    
    if (selected != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Video işleniyor...")));
      
      File originalFile = File(selected.path);
      
      // Sıkıştırma işlemi
      File? compressedFile = await _compressVideo(originalFile);

      if (compressedFile != null) {
        File finalFile = compressedFile;
        _disposeVideoController();
        
        _videoController = VideoPlayerController.file(finalFile)
          ..initialize().then((_) {
            setState(() {
              _file = finalFile;
              _mediaType = 'video';
              _videoController!.play(); 
              _videoController!.setLooping(true);
            });
          });
      }
    }
  }

  void _disposeVideoController() {
    if (_videoController != null) {
      _videoController!.dispose();
      _videoController = null;
    }
  }

  @override
  void dispose() {
    _disposeVideoController();
    VideoCompress.deleteAllCache(); 
    super.dispose();
  }

  void _uploadStory() async {
    if (_file == null) return;
    setState(() => _isUploading = true);

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      String fileName = "${uid}_${DateTime.now().millisecondsSinceEpoch}";
      String ext = _mediaType == 'video' ? 'mp4' : 'jpg';
      Reference ref = FirebaseStorage.instance.ref().child('stories/$fileName.$ext');
      
      await ref.putFile(_file!);
      String downloadUrl = await ref.getDownloadURL();

      var userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      var userData = userDoc.data() as Map<String, dynamic>;

      await FirebaseFirestore.instance.collection('stories').add({
        'uid': uid,
        'userName': userData['name'] ?? 'Kullanıcı',
        'userImage': userData['profileImage'],
        'imageUrl': downloadUrl, 
        'mediaType': _mediaType,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': DateTime.now().add(const Duration(hours: 24)),
        'viewers': [],
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hikaye paylaşıldı! 🚀")));
      }
    } catch (e) {
      debugPrint("Hata: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yükleme başarısız.")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. KONTROL EDİLİYORSA
    if (_isCheckingPermission) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
      );
    }

    // 2. İZİN YOKSA (Onaysızsa)
    if (!_canPost) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_clock, size: 80, color: Colors.grey),
                const SizedBox(height: 20),
                const Text("Hesabın Onaylanmadı", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Hikaye paylaşmak için hesabını doğrulaman gerekiyor.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const VerificationScreen()));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                  child: const Text("Şimdi Doğrula"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. İZİN VARSA (Senin Normal Hikaye Ekranın)
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Hikaye Ekle"),
        backgroundColor: Colors.black,
        actions: [
          if (_file != null && !_isUploading)
            TextButton(
              onPressed: _uploadStory,
              child: const Text("PAYLAŞ", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _file == null
                  ? const Text("Fotoğraf veya Video Seç", style: TextStyle(color: Colors.grey))
                  : _mediaType == 'video'
                      ? (_videoController != null && _videoController!.value.isInitialized)
                          ? AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            )
                          : const CircularProgressIndicator(color: Colors.greenAccent) 
                      : Image.file(_file!, fit: BoxFit.contain),
            ),
          ),
          if (_isUploading) const LinearProgressIndicator(color: Colors.greenAccent),
          Container(
            color: Colors.grey[900],
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOptionButton(Icons.photo_library, "Galeri", () => _pickImage(ImageSource.gallery)),
                _buildOptionButton(Icons.camera_alt, "Fotoğraf", () => _pickImage(ImageSource.camera)),
                _buildOptionButton(Icons.videocam, "Video", () => _pickVideo(ImageSource.camera)),
                _buildOptionButton(Icons.video_library, "V.Galeri", () => _pickVideo(ImageSource.gallery)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(radius: 25, backgroundColor: Colors.grey[800], child: Icon(icon, color: Colors.white)),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
    );
  }
}