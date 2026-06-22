import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'saved_posts_screen.dart';
import 'change_password_screen.dart';

// ARTIK STATEFUL WIDGET (Durum değiştirebilmek için)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Güvenlik menüsü açık mı kapalı mı?
  bool _isSecurityExpanded = false;

  void _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _showComingSoon(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: const Text("Bu özellik yakında eklenecek! 🛠️", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tamam", style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Ayarlar", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          // --- PROFİL ÖZETİ ---
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox(); 
              
              var data = snapshot.data!.data() as Map<String, dynamic>;
              String name = data['name'] ?? 'Kullanıcı';
              String? image = data['profileImage'];
              bool isVerified = data['isVerified'] ?? false; 

              return Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey[800],
                      backgroundImage: const AssetImage('assets/logo.jpg'),
                      foregroundImage: (image != null) ? NetworkImage(image) : null,
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name, 
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                            ),
                            if (isVerified)
                              const Padding(
                                padding: EdgeInsets.only(left: 5),
                                child: Icon(Icons.verified, color: Colors.greenAccent, size: 18),
                              ),
                          ],
                        ),
                        const Text("Hesap Ayarları", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    )
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 10),

          // BİLDİRİMLER
          _buildSettingsItem(context, Icons.notifications_none, "Bildirimler", () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()));
          }),
          
          // KAYDEDİLENLER
          _buildSettingsItem(context, Icons.bookmark_border, "Kaydedilenler", () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedPostsScreen()));
          }),

          // GİZLİLİK
          _buildSettingsItem(context, Icons.privacy_tip_outlined, "Gizlilik", () => _showComingSoon(context, "Gizlilik Ayarları")),
          
          // --- GÜVENLİK (DÜZELTİLDİ: OK HAREKET EDİYOR) ---
          Theme(
            // Divider çizgisini kaldırmak için tema ayarı
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: const Icon(Icons.security, color: Colors.white),
              title: const Text("Güvenlik", style: TextStyle(color: Colors.white)),
              iconColor: Colors.greenAccent,
              collapsedIconColor: Colors.grey,
              
              // İŞTE SİHİR BURADA: Duruma göre ikon değişiyor
              trailing: Icon(
                _isSecurityExpanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
                color: _isSecurityExpanded ? Colors.greenAccent : Colors.grey,
              ),
              
              // Açılıp kapandığında durumu güncelle
              onExpansionChanged: (bool expanded) {
                setState(() {
                  _isSecurityExpanded = expanded;
                });
              },

              children: [
                ListTile(
                  leading: const SizedBox(), 
                  title: const Text("Şifre Değiştir", style: TextStyle(color: Colors.white70)),
                  trailing: const Icon(Icons.lock_reset, color: Colors.greenAccent, size: 20),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ChangePasswordScreen()));
                  },
                ),
              ],
            ),
          ),

          // YARDIM
          _buildSettingsItem(context, Icons.help_outline, "Yardım", () => _showComingSoon(context, "Yardım Merkezi")),
          
          const Divider(color: Colors.grey),
          
          // ÇIKIŞ YAP
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Çıkış Yap", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () => _signOut(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}