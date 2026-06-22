import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';
import 'verification_screen.dart'; // Bu dosyanın aynı klasörde olduğundan emin ol

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  File? _file;
  File? _thumbnailFile;
  bool _isCustomThumbnail = false;

  String _mediaType = 'image';
  bool _isLoading = false;
  bool _isProcessingVideo = false;

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  final ImagePicker _picker = ImagePicker();

  // --- ONAY SİSTEMİ DEĞİŞKENLERİ ---
  bool _isCheckingPermission = true;
  bool _canPost = false;
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _checkPermission(); // Sayfa açılınca yetki kontrolü yap
  }

  // --- YETKİ KONTROLÜ ---
  void _checkPermission() async {
    try {
      var doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (doc.exists) {
        var data = doc.data()!;
        String role = data['role'] ?? 'user';
        bool isApproved = data['isApproved'] ?? false;

        // Kural: Antrenör veya Kulüp ise ve Onaylı Değilse -> ENGELLE
        if ((role == 'coach' || role == 'club') && !isApproved) {
          if (mounted) {
            setState(() {
              _canPost = false;
              _isCheckingPermission = false;
            });
          }
        } else {
          // Diğerleri (Sporcu veya Onaylılar) -> İZİN VER
          if (mounted) {
            setState(() {
              _canPost = true;
              _isCheckingPermission = false;
            });
          }
        }
      } else {
        // Kullanıcı verisi yoksa varsayılan olarak izin ver (veya engelle)
        if (mounted) setState(() => _isCheckingPermission = false);
      }
    } catch (e) {
      // Hata durumunda yüklemeyi durdur
      debugPrint("Yetki hatası: $e");
      if (mounted) setState(() => _isCheckingPermission = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _disposeVideoController();
    VideoCompress.deleteAllCache();
    super.dispose();
  }

  void _disposeVideoController() {
    if (_videoController != null) {
      _videoController!.dispose();
      _videoController = null;
      _isVideoInitialized = false;
    }
  }

  // --- VİDEO İŞLEMLERİ ---
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
      return file;
    }
  }

  Future<File?> _generateAutoThumbnail(File file) async {
    try {
      final File thumbnail = await VideoCompress.getFileThumbnail(
        file.path,
        quality: 50,
        position: -1,
      );
      return thumbnail;
    } catch (e) {
      return null;
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final XFile? selected = await _picker.pickVideo(source: source, maxDuration: const Duration(seconds: 60));

      if (selected != null) {
        await VideoCompress.deleteAllCache();
        _disposeVideoController();

        setState(() {
          _isProcessingVideo = true;
        });

        // UI donmasın diye küçük gecikme
        await Future.delayed(const Duration(milliseconds: 300));

        File originalFile = File(selected.path);
        File? compressedFile = await _compressVideo(originalFile);

        if (compressedFile != null) {
          File? autoThumb = await _generateAutoThumbnail(compressedFile);
          VideoPlayerController controller = VideoPlayerController.file(compressedFile);
          await controller.initialize();

          if (mounted) {
            setState(() {
              _file = compressedFile;
              _thumbnailFile = autoThumb;
              _isCustomThumbnail = false;
              _mediaType = 'video';
              _videoController = controller;
              _isVideoInitialized = true;
              _videoController!.setLooping(true);
              _isProcessingVideo = false;
            });
          }
        } else {
          if (mounted) setState(() => _isProcessingVideo = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessingVideo = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? selected = await _picker.pickImage(source: source, imageQuality: 70);
    if (selected != null) {
      setState(() {
        _file = File(selected.path);
        _mediaType = 'image';
        _thumbnailFile = null;
        _isCustomThumbnail = false;
        _disposeVideoController();
      });
    }
  }

  // --- KAPAK SEÇİCİ ---
  void _showCoverSelector(BuildContext context) {
    if (_videoController == null || !_videoController!.value.isInitialized) return;

    _videoController!.pause();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final duration = _videoController!.value.duration.inMilliseconds.toDouble();
            double currentSliderValue = _videoController!.value.position.inMilliseconds.toDouble();

            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text("Kapak Karesini Seç", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[800]!)),
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Slider(
                    value: currentSliderValue,
                    min: 0,
                    max: duration,
                    activeColor: Colors.greenAccent,
                    inactiveColor: Colors.grey[800],
                    onChanged: (value) {
                      setModalState(() {
                        currentSliderValue = value;
                      });
                      _videoController!.seekTo(Duration(milliseconds: value.toInt()));
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                      onPressed: () async {
                        int position = _videoController!.value.position.inMilliseconds;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kapak işleniyor...")));

                        File thumbnail = await VideoCompress.getFileThumbnail(
                          _file!.path,
                          quality: 75,
                          position: position,
                        );

                        if (mounted) {
                          setState(() {
                            _thumbnailFile = thumbnail;
                            _isCustomThumbnail = true;
                          });
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kapak güncellendi! ✅")));
                        }
                      },
                      child: const Text("Bu Kareyi Seç", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _videoController!.pause();
    });
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    });
  }

  void _sharePost() async {
    if (_file == null) return;
    setState(() => _isLoading = true);

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      String timeId = DateTime.now().millisecondsSinceEpoch.toString();
      String fileName = "${uid}_$timeId";
      String ext = _mediaType == 'video' ? 'mp4' : 'jpg';

      Reference ref = FirebaseStorage.instance.ref().child('posts/$fileName.$ext');
      await ref.putFile(_file!);
      String downloadUrl = await ref.getDownloadURL();

      String? thumbnailUrl;
      if (_mediaType == 'video' && _thumbnailFile != null) {
        Reference thumbRef = FirebaseStorage.instance.ref().child('posts/thumbnails/${fileName}_thumb.jpg');
        await thumbRef.putFile(_thumbnailFile!);
        thumbnailUrl = await thumbRef.getDownloadURL();
      }

      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      var userData = userDoc.data() as Map<String, dynamic>;

      await FirebaseFirestore.instance.collection('posts').add({
        'uid': uid,
        'userName': userData['name'] ?? 'Kullanıcı',
        'userRole': userData['role'] ?? 'user',
        'description': _descriptionController.text.trim(),
        'imageUrl': downloadUrl,
        'thumbnailUrl': thumbnailUrl,
        'mediaType': _mediaType,
        'likes': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gönderi paylaşıldı!")));
        setState(() => _isLoading = false);
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Hata: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hata oluştu.")));
      }
    }
  }

  void _clearSelection() {
    setState(() {
      _file = null;
      _thumbnailFile = null;
      _mediaType = 'image';
      _isCustomThumbnail = false;
      _disposeVideoController();
    });
  }

  Widget _buildOptionBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(backgroundColor: Colors.grey[800], child: Icon(icon, color: Colors.white)),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Yetki Kontrolü Sürüyorsa
    if (_isCheckingPermission) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
      );
    }

    // 2. Yetki Yoksa (Onaysız Antrenör/Kulüp)
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
                const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
                const SizedBox(height: 20),
                const Text(
                  "Hesabın Henüz Onaylanmadı",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Antrenör ve Spor Kulübü hesaplarının gönderi paylaşabilmesi için doğrulanması gerekmektedir.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
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

    // 3. Yetki Varsa (Normal Post Ekranı)
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Yeni Gönderi", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_file != null && !_isProcessingVideo)
            TextButton(
              onPressed: _isLoading ? null : _sharePost,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("PAYLAŞ", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: _isProcessingVideo
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(color: Colors.greenAccent),
                  SizedBox(height: 20),
                  Text("Video işleniyor...", style: TextStyle(color: Colors.white)),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  if (_isLoading) const LinearProgressIndicator(color: Colors.greenAccent),
                  
                  if (_file == null)
                    Container(
                      height: 300,
                      width: double.infinity,
                      color: Colors.grey[900],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildOptionBtn(Icons.photo, "Galeri", () => _pickImage(ImageSource.gallery)),
                              const SizedBox(width: 20),
                              _buildOptionBtn(Icons.camera_alt, "Foto", () => _pickImage(ImageSource.camera)),
                              const SizedBox(width: 20),
                              _buildOptionBtn(Icons.videocam, "Video", () => _pickVideo(ImageSource.camera)),
                              const SizedBox(width: 20),
                              _buildOptionBtn(Icons.video_library, "V.Galeri", () => _pickVideo(ImageSource.gallery)),
                            ],
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        // Medya Önizleme
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              height: 400,
                              width: double.infinity,
                              color: Colors.black,
                              child: _mediaType == 'video'
                                  ? (_isVideoInitialized && _videoController != null
                                      ? AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: VideoPlayer(_videoController!))
                                      : (_thumbnailFile != null
                                          ? Image.file(_thumbnailFile!, fit: BoxFit.cover)
                                          : Container(color: Colors.black)))
                                  : Image.file(_file!, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 5,
                              right: 5,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                onPressed: _clearSelection,
                              ),
                            ),
                            if (_mediaType == 'video' && _videoController != null && !_videoController!.value.isPlaying)
                              IconButton(
                                icon: Icon(
                                  _videoController!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                  color: Colors.white54,
                                  size: 70,
                                ),
                                onPressed: _togglePlayPause,
                              ),
                          ],
                        ),

                        // Kapak Fotoğrafı Seçimi (Sadece Video ise)
                        if (_mediaType == 'video')
                          Container(
                            color: Colors.grey[900],
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                            child: Row(
                              children: [
                                if (_thumbnailFile != null)
                                  Stack(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        margin: const EdgeInsets.only(right: 15),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.greenAccent),
                                          borderRadius: BorderRadius.circular(8),
                                          image: DecorationImage(image: FileImage(_thumbnailFile!), fit: BoxFit.cover),
                                        ),
                                      ),
                                      if (_isCustomThumbnail)
                                        const Positioned(bottom: 0, right: 15, child: Icon(Icons.check_circle, size: 16, color: Colors.greenAccent)),
                                    ],
                                  ),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showCoverSelector(context),
                                    icon: const Icon(Icons.video_settings, color: Colors.white),
                                    label: const Text("Videodan Kapak Seç", style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[800],
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: TextField(
                            controller: _descriptionController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Bir şeyler yaz...",
                              hintStyle: const TextStyle(color: Colors.grey),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: Colors.grey[900],
                            ),
                            maxLines: 3,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}