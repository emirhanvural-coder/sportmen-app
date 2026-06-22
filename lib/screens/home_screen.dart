import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../widgets/post_card.dart';
import '../widgets/story_avatar.dart';
import '../widgets/unread_badge.dart'; 

import 'explore_screen.dart';    
import 'chat_list_screen.dart';   
import 'search_screen.dart';      
import 'profile_screen.dart';     
import 'add_post_screen.dart';    
import 'notifications_screen.dart'; 
import 'add_story_screen.dart';   
import 'login_screen.dart'; // Çıkış yapmak gerekirse diye

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; 
  late final List<Widget> _pages;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    
    _pages = [
      const _HomeFeed(),       // 0: Ana Sayfa
      const ExploreScreen(),   // 1: Keşfet
      const ChatListScreen(),  // 2: DM
      const SearchScreen(),    // 3: Arama
      const ProfileScreen(),   // 4: Profil
    ];
    _deleteExpiredStories();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _deleteExpiredStories() async {
    try {
      var expiredSnapshots = await FirebaseFirestore.instance
          .collection('stories')
          .where('expiresAt', isLessThan: DateTime.now())
          .get();

      if (expiredSnapshots.docs.isNotEmpty) {
        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (var doc in expiredSnapshots.docs) {
          batch.delete(doc.reference);
          try {
            await FirebaseStorage.instance.refFromURL(doc['imageUrl']).delete();
          } catch (e) {}
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint("Temizlik hatası: $e");
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.jumpToPage(index); 
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const ClampingScrollPhysics(),
        children: _pages,
      ),
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        selectedItemColor: Colors.greenAccent,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false, 
        showUnselectedLabels: false,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Ev'),
          const BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Keşfet'),
          BottomNavigationBarItem(
            icon: _buildDmIconWithBadge(),
            label: 'DM',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Arama'),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  Widget _buildDmIconWithBadge() {
    String? currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return const Icon(Icons.send); // Güvenlik önlemi

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('users', arrayContains: currentUid)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['lastSenderId'] != currentUid) {
               Timestamp? lastMsgTime = data['lastMessageTime'];
               Timestamp? myLastRead = data['lastRead_$currentUid'];
               if (lastMsgTime != null) {
                 if (myLastRead == null || lastMsgTime.compareTo(myLastRead) > 0) {
                   unreadCount++;
                 }
               }
            }
          }
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.send),
            if (unreadCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: UnreadBadge(count: unreadCount),
              ),
          ],
        );
      },
    );
  }
}

// --- ANA AKIŞ SAYFASI (GÜNCELLENDİ VE KORUMALI) ---
class _HomeFeed extends StatefulWidget {
  const _HomeFeed();

  @override
  State<_HomeFeed> createState() => _HomeFeedState();
}

class _HomeFeedState extends State<_HomeFeed> {
  Future<void> _refreshFeed() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // Eğer oturum yoksa Giriş ekranına at (Güvenlik)
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final String currentUid = user.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Image.asset('assets/yeni_logo.png', height: 32),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid)
              .collection('notifications')
              .snapshots(), 
          builder: (context, snapshot) {
            int notificationCount = 0;
            if (snapshot.hasData) {
              for (var doc in snapshot.data!.docs) {
                var data = doc.data() as Map<String, dynamic>;
                bool isRead = data.containsKey('isRead') ? data['isRead'] : false;
                if (!isRead) notificationCount++;
              }
            }
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.favorite_border, color: Colors.white, size: 28),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
                ),
                if (notificationCount > 0)
                  Positioned(
                    right: 8, top: 12,
                    child: Container(
                      width: 10, height: 10,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                  ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined, color: Colors.white, size: 28), 
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddPostScreen())),
          ),
          const SizedBox(width: 5),
        ],
      ),
      
      body: Column(
        children: [
          // --- HİKAYELER ÇUBUĞU ---
          SizedBox(
            height: 100,
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
              builder: (context, userSnapshot) {
                // --- ÇÖKME ÖNLEYİCİ KONTROL BURADA ---
                if (!userSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
                }
                
                // Eğer doküman yoksa veya verisi boşsa güvenli çıkış yap
                if (!userSnapshot.data!.exists || userSnapshot.data!.data() == null) {
                  return Center(
                    child: TextButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                      },
                      child: const Text("Profil Hatası - Çıkış Yap", style: TextStyle(color: Colors.red)),
                    ),
                  );
                }

                // Artık güvenle veriyi alabiliriz
                var myData = userSnapshot.data!.data() as Map<String, dynamic>;
                String myImage = myData['profileImage'] ?? '';

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('stories')
                      .where('expiresAt', isGreaterThan: DateTime.now())
                      .orderBy('expiresAt', descending: true)
                      .snapshots(),
                  builder: (context, storySnapshot) {
                    List<Widget> storyWidgets = [];

                    // 1. EKLE BUTONU
                    storyWidgets.add(
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddStoryScreen())),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    child: CircleAvatar(
                                      radius: 30,
                                      backgroundColor: Colors.grey[800],
                                      backgroundImage: const AssetImage('assets/logo.jpg'),
                                      foregroundImage: (myImage.isNotEmpty) ? NetworkImage(myImage) : null,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0, right: 0,
                                    child: Container(
                                      decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                                      padding: const EdgeInsets.all(2),
                                      child: const CircleAvatar(radius: 10, backgroundColor: Colors.greenAccent, child: Icon(Icons.add, size: 15, color: Colors.black)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              const Text("Ekle", style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    );

                    // 2. DİĞER HİKAYELER
                    if (storySnapshot.hasData) {
                      var allStories = storySnapshot.data!.docs;
                      bool doIHaveStory = allStories.any((doc) => doc['uid'] == currentUid);
                      if (doIHaveStory) {
                        storyWidgets.add(
                          Padding(
                            padding: const EdgeInsets.only(right: 15.0),
                            child: Column(
                              children: [
                                StoryAvatar(userId: currentUid, imageUrl: myImage, radius: 30),
                                const SizedBox(height: 5),
                                const Text("Hikayen", style: TextStyle(color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      Map<String, List<DocumentSnapshot>> userStoriesMap = {};
                      for (var doc in allStories) {
                        String uid = doc['uid'];
                        if (uid == currentUid) continue;
                        if (!userStoriesMap.containsKey(uid)) userStoriesMap[uid] = [];
                        userStoriesMap[uid]!.add(doc);
                      }
                      
                      List<MapEntry<String, List<DocumentSnapshot>>> sortedUsers = userStoriesMap.entries.toList();
                      sortedUsers.sort((a, b) {
                        bool aHasUnseen = a.value.any((doc) => !(doc['viewers'] as List).contains(currentUid));
                        bool bHasUnseen = b.value.any((doc) => !(doc['viewers'] as List).contains(currentUid));
                        if (aHasUnseen && !bHasUnseen) return -1;
                        if (!aHasUnseen && bHasUnseen) return 1;
                        return 0;
                      });

                      for (var entry in sortedUsers) {
                        var firstStory = entry.value.first;
                        var data = firstStory.data() as Map<String, dynamic>;
                        
                        storyWidgets.add(
                          Padding(
                            padding: const EdgeInsets.only(right: 15.0),
                            child: Column(
                              children: [
                                StoryAvatar(userId: entry.key, imageUrl: data['userImage'], radius: 30),
                                const SizedBox(height: 5),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    data['userName'] ?? 'Kullanıcı',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    }
                    return ListView(
                      scrollDirection: Axis.horizontal,
                      children: storyWidgets,
                    );
                  },
                );
              },
            ),
          ),
          
          const Divider(color: Colors.grey, height: 1),

          // --- GÖNDERİ LİSTESİ ---
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
              builder: (context, userSnapshot) {
                // --- BURADA DA KONTROL EKLİYORUZ ---
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
                }

                if (!userSnapshot.hasData || !userSnapshot.data!.exists || userSnapshot.data!.data() == null) {
                   return const Center(child: Text("Profil verisi alınamadı.", style: TextStyle(color: Colors.grey)));
                }

                var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                List followingList = List.from(userData['following'] ?? []);
                
                if (!followingList.contains(currentUid)) {
                  followingList.add(currentUid);
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, postSnapshot) {
                    if (postSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
                    }

                    if (!postSnapshot.hasData || postSnapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("Henüz gönderi yok.", style: TextStyle(color: Colors.grey)));
                    }

                    var allPosts = postSnapshot.data!.docs;
                    var filteredPosts = allPosts.where((doc) {
                      String ownerId = doc['uid'];
                      return followingList.contains(ownerId);
                    }).toList();

                    if (filteredPosts.isEmpty) {
                      return const Center(
                        child: Text(
                          "Takip ettiğin kimse gönderi paylaşmamış.\nKeşfet'e gidip yeni insanlar bulabilirsin!", 
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)
                        )
                      );
                    }

                    return RefreshIndicator(
                      color: Colors.greenAccent,
                      backgroundColor: Colors.grey[900],
                      onRefresh: _refreshFeed,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: filteredPosts.length,
                        itemBuilder: (context, index) {
                          return PostCard(post: filteredPosts[index]);
                        },
                      ),
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