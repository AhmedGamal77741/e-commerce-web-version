import 'package:ecommerece_app/features/chat/ui/direct_chats_screen.dart';
import 'package:ecommerece_app/features/chat/ui/friends_screen.dart';
import 'package:ecommerece_app/features/chat/ui/group_chats_screen.dart';
import 'package:ecommerece_app/features/chat/widgets/expandable_FAB.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatsNavbar extends StatefulWidget {
  const ChatsNavbar({super.key});

  @override
  State<ChatsNavbar> createState() => _ChatsNavbarState();
}

class _ChatsNavbarState extends State<ChatsNavbar> {
  int _selectedIndex = 0;

  final String supportUserId = '4hSVptbp63W7Ctl05FjbVUkOO9u1';

  List<Widget> get widgetOptions {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.uid == supportUserId) {
      // Support account: only direct chats
      return [DirectChatsScreen()];
    }
    // Normal users: all tabs
    return [FriendsScreen(), DirectChatsScreen(), GroupChatsScreen()];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isSupport = user != null && user.uid == supportUserId;
    if (isSupport) {
      // Support: only direct chats, no nav bar
      return Scaffold(
        body: DirectChatsScreen(),
        floatingActionButton: null,
        bottomNavigationBar: null,
      );
    }
    // Normal users: full nav bar
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: widgetOptions),
      floatingActionButton: ExpandableFAB(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey[400],
        selectedLabelStyle: TextStyle(fontSize: 10),
        unselectedLabelStyle: TextStyle(fontSize: 10),
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Image.asset(
              height: 35,
              width: 35,
              _selectedIndex == 0
                  ? 'assets/contacts (1).png'
                  : 'assets/contacts inactive (1).png',
            ),
            label: '친구톡톡',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              _selectedIndex == 1
                  ? 'assets/direct (1).png'
                  : 'assets/direct inactive (1).png',
              height: 35,
              width: 35,
            ),
            label: '1:1 채팅',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              _selectedIndex == 2
                  ? 'assets/group_active_1.png'
                  : 'assets/group inactive (1).png',
              height: 35,
              width: 35,
            ),
            label: '그룹채팅',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: (_onItemTapped),
      ),
    );
  }
}
