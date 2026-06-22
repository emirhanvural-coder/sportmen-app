import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  // --- ONAYLAMA İŞLEMİ ---
  void _approveRequest(BuildContext context, String uid) async {
    try {
      // 1. Kullanıcının profilindeki 'isApproved' değerini true yapıp yetki veriyoruz.
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isApproved': true,
      });

      // 2. İsteğin durumunu 'approved' (onaylandı) olarak güncelliyoruz ki listeden düşsün.
      await FirebaseFirestore.instance.collection('verification_requests').doc(uid).update({
        'status': 'approved',
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hesap başarıyla onaylandı! ✅", style: TextStyle(color: Colors.greenAccent))));
      }
    } catch (e) {
      debugPrint("Onay hatası: $e");
    }
  }

  // --- REDDETME İŞLEMİ ---
  void _rejectRequest(BuildContext context, String uid) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("İsteği Reddet", style: TextStyle(color: Colors.white)),
        content: const Text("Bu doğrulama isteğini reddedip silmek istediğine emin misin?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("İptal", style: TextStyle(color: Colors.white))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("REDDET", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // İsteği veritabanından tamamen siliyoruz
        await FirebaseFirestore.instance.collection('verification_requests').doc(uid).delete();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İstek reddedildi ve listeden silindi. ❌")));
        }
      } catch (e) {
        debugPrint("Reddetme hatası: $e");
      }
    }
  }

  // --- BELGEYİ TAM EKRAN GÖSTERME ---
  void _showDocument(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer( // Yakınlaştırma (Zoom) özelliği ekler
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
            IconButton(
              icon: const Icon(Icons.close_fullscreen, color: Colors.white, size: 35),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Onay Bekleyenler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // Sadece 'pending' (bekleyen) istekleri canlı olarak çekiyoruz
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('verification_requests')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("Bekleyen doğrulama isteği yok.", style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var requestDoc = snapshot.data!.docs[index];
              var requestData = requestDoc.data() as Map<String, dynamic>;
              String userId = requestData['uid'];
              String documentUrl = requestData['documentUrl'];
              String note = requestData['note'] ?? '';

              // İsteği atan kişinin adını ve rolünü 'users' tablosundan buluyoruz
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) return const SizedBox.shrink();
                  
                  var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  String userName = userData['name'] ?? 'Bilinmeyen Kullanıcı';
                  String userRole = userData['role'] ?? 'Bilinmiyor';

                  return Card(
                    color: Colors.grey[900],
                    margin: const EdgeInsets.only(bottom: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person, color: Colors.greenAccent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(userName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(5)),
                                child: Text(userRole.toUpperCase(), style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.grey),
                          if (note.isNotEmpty) ...[
                            const Text("Not:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Text(note, style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 10),
                          ],
                          
                          // BELGE ÖNİZLEME
                          GestureDetector(
                            onTap: () => _showDocument(context, documentUrl),
                            child: Container(
                              height: 150,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                image: DecorationImage(image: NetworkImage(documentUrl), fit: BoxFit.cover),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.black.withOpacity(0.4),
                                ),
                                child: const Center(
                                  child: Icon(Icons.zoom_in, color: Colors.white, size: 40),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          
                          // BUTONLAR
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _rejectRequest(context, userId),
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  label: const Text("Reddet", style: TextStyle(color: Colors.red)),
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _approveRequest(context, userId),
                                  icon: const Icon(Icons.check, color: Colors.black),
                                  label: const Text("ONAYLA", style: TextStyle(fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}