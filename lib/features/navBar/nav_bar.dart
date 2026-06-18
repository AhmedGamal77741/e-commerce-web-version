import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/widgets/no_account_screen.dart';
import 'package:ecommerece_app/core/widgets/receipt_setup_screen.dart';
import 'package:ecommerece_app/features/cart/sub_screens/add_address_screen.dart';
import 'package:ecommerece_app/features/chat/models/chat_room_model.dart';
import 'package:ecommerece_app/features/chat/ui/chats_navbar.dart';
import 'package:ecommerece_app/features/home/home_screen.dart';
import 'package:ecommerece_app/features/shop/shop.dart';
import 'package:ecommerece_app/landing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ecommerece_app/core/widgets/deleted_account.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavBar extends StatefulWidget {
  const NavBar({super.key});

  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> with TickerProviderStateMixin {
  final shopKey = GlobalKey<ShopState>();
  final homeKey = GlobalKey<HomeScreenState>();
  int _selectedIndex = 0;

  final ScrollController homeScrollController = ScrollController();
  late TabController homeTabController;
  List<Widget> widgetOptions = [];
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<QuerySnapshot>? _chatRoomsSubscription;

  Map<String, dynamic>? _currentUserData;
  bool _hasUnreadMessages = false;
  @override
  void initState() {
    super.initState();
    homeTabController = TabController(length: 2, vsync: this);
    widgetOptions = [
      HomeScreen(
        key: homeKey,
        scrollController: homeScrollController,
        tabController: homeTabController,
      ),
      ChatsNavbar(),
      const Center(child: Text('home')),
      Shop(key: shopKey),
      LandingScreen(),
    ];

    _initSubscriptions();

    // Check if we need to resume a pending navigation after bank registration
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingNavigation();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/001m.png'), context);
    precacheImage(const AssetImage('assets/grey_001m.png'), context);
    precacheImage(const AssetImage('assets/chat_with_seller.png'), context);
    precacheImage(
      const AssetImage('assets/chat_with_seller_grey.png'),
      context,
    );
    precacheImage(const AssetImage('assets/notification.png'), context);
    precacheImage(const AssetImage('assets/mypage_avatar.png'), context);
    precacheImage(const AssetImage('assets/mypage_avatar_grey.png'), context);
    precacheImage(const AssetImage('assets/002m.png'), context);
    precacheImage(const AssetImage('assets/grey_002m.png'), context);
    precacheImage(const AssetImage('assets/005m.png'), context);
    precacheImage(const AssetImage('assets/grey_005m.png'), context);
  }

  void _initSubscriptions() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      _userSubscription?.cancel();
      _chatRoomsSubscription?.cancel();

      if (user != null) {
        // Listen to user document updates
        _userSubscription = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((snapshot) {
              if (mounted) {
                setState(() {
                  _currentUserData = snapshot.data();
                });
              }
            });

        // Listen to chat rooms updates for unread notifications
        _chatRoomsSubscription = FirebaseFirestore.instance
            .collection('chatRooms')
            .where('participants', arrayContains: user.uid)
            .snapshots()
            .listen((snapshot) {
              final currentUserId = user.uid;
              bool unreadFound = false;
              for (var doc in snapshot.docs) {
                final room = ChatRoomModel.fromMap(doc.data());
                if (!room.deletedBy.contains(currentUserId) &&
                    (room.unreadCount[currentUserId] ?? 0) > 0) {
                  unreadFound = true;
                  break;
                }
              }
              if (mounted) {
                setState(() {
                  _hasUnreadMessages = unreadFound;
                });
              }
            });
      } else {
        if (mounted) {
          setState(() {
            _currentUserData = null;
            _hasUnreadMessages = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    homeTabController.dispose();
    homeScrollController.dispose();
    _authSubscription?.cancel();
    _userSubscription?.cancel();
    _chatRoomsSubscription?.cancel();
    super.dispose();
  }

  // ── Resume navigation after bank registration deep link ───────────────────
  Future<void> _checkPendingNavigation() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingSource = prefs.getString('pending_nav_source');
    if (pendingSource == null) return;
    await prefs.remove('pending_nav_source');
    if (!mounted) return;

    if (pendingSource == 'sub') {
      await _navigateToSubscription(context);
    } else if (pendingSource == 'shop') {
      await _onItemTapped(3);
    }
  }

  // ── Subscription gate helper ──────────────────────────────────────────────
  Future<void> _navigateToSubscription(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final data =
        _currentUserData ??
        (await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get())
            .data();

    final accounts = data?['bankAccounts'];
    final hasBankAccount =
        accounts != null && accounts is List && accounts.isNotEmpty;

    if (!hasBankAccount) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const NoBankAccountScreen(source: 'sub'),
        ),
      );
      final refreshed =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final refreshedAccounts = refreshed.data()?['bankAccounts'];
      final nowHasAccount =
          refreshedAccounts != null &&
          refreshedAccounts is List &&
          refreshedAccounts.isNotEmpty;
      if (!nowHasAccount) return;
    }

    // ── Gate 2: receipt / invoice data ──────────────────────────────────
    final cacheDoc =
        await FirebaseFirestore.instance
            .collection('usercached_values')
            .doc(user.uid)
            .get();
    final cacheData = cacheDoc.data();
    final hasReceiptData =
        cacheData != null &&
        (cacheData['selectedOption'] == 1 ||
            cacheData['selectedOption'] == 2) &&
        (cacheData['name'] as String? ?? '').isNotEmpty &&
        (cacheData['email'] as String? ?? '').isNotEmpty &&
        (cacheData['phone'] as String? ?? '').isNotEmpty;

    if (!hasReceiptData) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const ReceiptSetupScreen(source: 'sub'),
        ),
      );
      if (result != true) return;
    }

    if (context.mounted) {
      context.push(Routes.subscriptionScreen);
    }
  }

  Future<void> _onItemTapped(int index) async {
    if (_selectedIndex == index && index == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        shopKey.currentState?.resetToFirstCategory();
      });
      return;
    }
    if (index == 0) {
      if (_selectedIndex == 0) {
        // Already on home — reset inner tab and scroll to top
        homeKey.currentState?.resetToTop();
      }
      setState(() => _selectedIndex = 0);
      return;
    } else if (index == 3) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final data =
            _currentUserData ??
            (await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get())
                .data();

        // Deleted account — just navigate
        if (data != null && data['deleted'] == true) {
          setState(() => _selectedIndex = index);
          return;
        }

        // ── Gate 1: bank account ────────────────────────────────────────
        final accounts = data?['bankAccounts'];
        final hasBankAccount =
            accounts != null && accounts is List && accounts.isNotEmpty;

        if (!hasBankAccount) {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => const NoBankAccountScreen(source: 'shop'),
            ),
          );
          if (result != true) {
            final refreshed =
                _currentUserData ??
                (await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .get())
                    .data();
            final refreshedAccounts = refreshed?['bankAccounts'];
            final nowHasAccount =
                refreshedAccounts != null &&
                refreshedAccounts is List &&
                refreshedAccounts.isNotEmpty;
            if (!nowHasAccount) return;
          }
        }

        // ── Gate 2: receipt / invoice data ──────────────────────────────
        final cacheDoc =
            await FirebaseFirestore.instance
                .collection('usercached_values')
                .doc(user.uid)
                .get();
        final cacheData = cacheDoc.data();
        final hasReceiptData =
            cacheData != null &&
            (cacheData['selectedOption'] == 1 ||
                cacheData['selectedOption'] == 2) &&
            (cacheData['name'] as String? ?? '').isNotEmpty &&
            (cacheData['email'] as String? ?? '').isNotEmpty &&
            (cacheData['phone'] as String? ?? '').isNotEmpty;

        if (!hasReceiptData) {
          final result = await Navigator.of(context).push<dynamic>(
            MaterialPageRoute(
              builder: (_) => const ReceiptSetupScreen(source: 'shop'),
            ),
          );
          if (result != true && result != 'skip') return;
        }

        // ── Gate 3: default address ─────────────────────────────────────
        final freshData =
            _currentUserData ??
            (await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get())
                .data();
        if (freshData == null ||
            (freshData['defaultAddressId'] == null ||
                freshData['defaultAddressId'] == '')) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddAddressScreen(showSkip: true),
            ),
          );
        }
      }
      setState(() => _selectedIndex = index);
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user account is deleted
    final isDeleted =
        _currentUserData != null && _currentUserData!['deleted'] == true;
    if (isDeleted) {
      return DeletedAccount(
        deletedAt: _currentUserData!['deletedAt']?.toString() ?? '',
        onRecover: () async {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .update({'deleted': false, 'deletedAt': null});
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('계정이 복구되었습니다.')));
          }
        },
        onSignOut: () async {
          await FirebaseAuth.instance.signOut();
        },
      );
    }
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: widgetOptions),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: ColorsManager.primary,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey[400],
        selectedLabelStyle: TextStyle(fontSize: 10),
        unselectedLabelStyle: TextStyle(fontSize: 10),
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Image.asset('assets/grey_001m.png', width: 30, height: 30),
            activeIcon: Image.asset('assets/001m.png', width: 30, height: 30),
            label: '상점',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Image.asset(
                  'assets/chat_with_seller_grey.png',
                  width: 30,
                  height: 30,
                ),
                if (_hasUnreadMessages)
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
            ),
            activeIcon: Stack(
              clipBehavior: Clip.none,
              children: [
                Image.asset(
                  'assets/chat_with_seller.png',
                  width: 30,
                  height: 30,
                ),
                if (_hasUnreadMessages)
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
            ),
            label: '채팅',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/mypage_avatar_grey.png',
              width: 30,
              height: 30,
            ),
            activeIcon: Image.asset(
              'assets/mypage_avatar.png',
              width: 30,
              height: 30,
            ),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/grey_002m.png', width: 30, height: 30),
            activeIcon: Image.asset('assets/002m.png', width: 30, height: 30),
            label: '장바구니',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/grey_005m.png', width: 30, height: 30),
            activeIcon: Image.asset('assets/005m.png', width: 30, height: 30),
            label: '내페이지',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
