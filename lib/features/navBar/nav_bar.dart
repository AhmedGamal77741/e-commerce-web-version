import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/features/cart/cart.dart';
import 'package:ecommerece_app/features/cart/sub_screens/add_address_screen.dart';
import 'package:ecommerece_app/features/chat/models/chat_room_model.dart';
import 'package:ecommerece_app/features/chat/ui/chats_navbar.dart';
import 'package:ecommerece_app/features/home/home_screen.dart';
import 'package:ecommerece_app/features/mypage/ui/my_page_screen.dart';
import 'package:ecommerece_app/features/review/ui/review_screen.dart';
import 'package:ecommerece_app/features/shop/shop.dart';
import 'package:ecommerece_app/landing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ecommerece_app/core/widgets/deleted_account.dart';

class NavBar extends StatefulWidget {
  const NavBar({super.key});

  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> with TickerProviderStateMixin {
  final shopKey = GlobalKey<ShopState>();
  int _selectedIndex = 0;

  // Use a non-static controller and re-create HomeScreen on tab switch to ensure controller is always attached
  final ScrollController homeScrollController = ScrollController();
  late TabController homeTabController;
  List<Widget> widgetOptions = [];

  @override
  void initState() {
    super.initState();
    homeTabController = TabController(length: 2, vsync: this);
    widgetOptions = [
      _buildMainWidget(() => Center(child: Text('home'))),
      _buildMainWidget(() => Shop(key: shopKey)),
      _buildMainWidget(
        () => HomeScreen(
          scrollController: homeScrollController,
          tabController: homeTabController,
        ),
      ),
      _buildMainWidget(() => ChatsNavbar()),
      _buildMainWidget(() => LandingScreen()),
    ];
  }

  @override
  void dispose() {
    homeTabController.dispose();
    homeScrollController.dispose();
    super.dispose();
  }

  Widget _buildMainWidget(Widget Function() builder) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (user == null) {
          // Not authenticated, show normal widget
          return builder();
        }
        return StreamBuilder<DocumentSnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(color: Colors.black),
              );
            }
            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
            if (userData == null) {
              return Center(child: Text('User profile not found'));
            }
            if (userData['deleted'] == true) {
              // Show deleted account screen with real recovery logic
              return DeletedAccount(
                deletedAt: userData['deletedAt']?.toString() ?? '',
                onRecover: () async {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .update({'deleted': false, 'deletedAt': null});
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('계정이 복구되었습니다.')));
                  }
                },
                onSignOut: () async {
                  await FirebaseAuth.instance.signOut();
                },
              );
            }
            // Not deleted, show normal widget
            return builder();
          },
        );
      },
    );
  }

  Future<void> _onItemTapped(int index) async {
    if (_selectedIndex == index && index == 1) {
      // Reset Shop tab to first category
      WidgetsBinding.instance.addPostFrameCallback((_) {
        shopKey.currentState?.resetToFirstCategory();
      });
      return;
    }
    if (_selectedIndex == index && index == 2) {
      // Reset to first tab (추천) and scroll to top
      homeTabController.animateTo(0);
      if (homeScrollController.hasClients) {
        homeScrollController.animateTo(
          0,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else if (index == 1) {
      // Shop tab tapped
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
        final data = userDoc.data();
        // If user is deleted, do not navigate to AddAddressScreen
        if (data != null && data['deleted'] == true) {
          setState(() {
            _selectedIndex = index;
          });
          return;
        }
        if (data == null ||
            (data['defaultAddressId'] == null ||
                data['defaultAddressId'] == '')) {
          // No default address, navigate to AddAddressScreen
          final result = await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => AddAddressScreen()));
          // If address was added, you may want to refresh or proceed to Shop
          if (result == true) {
            setState(() {
              _selectedIndex = index;
            });
          }
          return;
        }
      }
      setState(() {
        _selectedIndex = index;
      });
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: widgetOptions),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: ColorsManager.primary,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black, // Same as unselected color
        unselectedItemColor: Colors.grey[400],
        selectedLabelStyle: TextStyle(fontSize: 10),
        unselectedLabelStyle: TextStyle(fontSize: 10),
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: ImageIcon(
              AssetImage(
                _selectedIndex == 0
                    ? 'assets/001m.png'
                    : 'assets/grey_001m.png',
              ),
              size: 30,
            ),
            label: '상점',
          ),
          BottomNavigationBarItem(
            icon: ImageIcon(
              AssetImage(
                _selectedIndex == 1
                    ? 'assets/002m.png'
                    : 'assets/grey_002m.png',
              ),
              size: 30,
            ),
            label: '장바구니',
          ),
          BottomNavigationBarItem(
            icon: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.transparent,
              backgroundImage: AssetImage('assets/mypage_avatar_grey.png'),
            ),
            activeIcon: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.transparent,
              backgroundImage: AssetImage('assets/mypage_avatar.png'),
            ),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, authSnapshot) {
                final user = authSnapshot.data;
                if (user == null) {
                  return CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.transparent,
                    backgroundImage: AssetImage(
                      'assets/chat_with_seller_grey.png',
                    ),
                  );
                }
                return StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection('chatRooms')
                      .where('participants', arrayContains: user.uid)
                      .orderBy('lastMessageTime', descending: true)
                      .snapshots()
                      .map(
                        (snapshot) =>
                            snapshot.docs
                                .map((doc) => ChatRoomModel.fromMap(doc.data()))
                                .toList(),
                      ),
                  builder: (context, snapshot) {
                    final currentUserId = user.uid;
                    bool hasUnread = false;
                    if (snapshot.hasData) {
                      final chatRooms = snapshot.data!;
                      hasUnread = chatRooms.any(
                        (room) => (room.unreadCount[currentUserId] ?? 0) > 0,
                      );
                    }
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.transparent,
                          backgroundImage: AssetImage(
                            'assets/chat_with_seller_grey.png',
                          ),
                        ),
                        if (hasUnread)
                          Positioned(
                            left: -10,
                            top: -5,
                            child: Image.asset(
                              'assets/notification.png',
                              width: 18,
                              height: 18,
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
            activeIcon: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, authSnapshot) {
                final user = authSnapshot.data;
                if (user == null) {
                  return CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.transparent,
                    backgroundImage: AssetImage('assets/chat_with_seller.png'),
                  );
                }
                return StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection('chatRooms')
                      .where('participants', arrayContains: user.uid)
                      .orderBy('lastMessageTime', descending: true)
                      .snapshots()
                      .map(
                        (snapshot) =>
                            snapshot.docs
                                .map((doc) => ChatRoomModel.fromMap(doc.data()))
                                .toList(),
                      ),
                  builder: (context, snapshot) {
                    final currentUserId = user.uid;
                    bool hasUnread = false;
                    if (snapshot.hasData) {
                      final chatRooms = snapshot.data!;
                      hasUnread = chatRooms.any(
                        (room) => (room.unreadCount[currentUserId] ?? 0) > 0,
                      );
                    }
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.transparent,
                          backgroundImage: AssetImage(
                            'assets/chat_with_seller.png',
                          ),
                        ),
                        if (hasUnread)
                          Positioned(
                            left: -10,
                            top: -5,
                            child: Image.asset(
                              'assets/notification.png',
                              width: 18,
                              height: 18,
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
            label: '채팅',
          ),
          BottomNavigationBarItem(
            icon: ImageIcon(
              AssetImage(
                _selectedIndex == 4
                    ? 'assets/005m.png'
                    : 'assets/grey_005m.png',
              ),
              size: 30,
            ),
            label: '내페이지',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: (_onItemTapped),
      ),
    );
  }
}
