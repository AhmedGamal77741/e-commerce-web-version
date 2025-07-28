import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/features/cart/cart.dart';
import 'package:ecommerece_app/features/cart/sub_screens/add_address_screen.dart';
import 'package:ecommerece_app/features/home/home_screen.dart';
import 'package:ecommerece_app/features/mypage/ui/my_page_screen.dart';
import 'package:ecommerece_app/features/review/ui/review_screen.dart';
import 'package:ecommerece_app/features/shop/shop.dart';
import 'package:ecommerece_app/landing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NavBar extends StatefulWidget {
  const NavBar({super.key});

  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> {
  int _selectedIndex = 0;

  // Use a non-static controller and re-create HomeScreen on tab switch to ensure controller is always attached
  final ScrollController homeScrollController = ScrollController();
  List<Widget> widgetOptions = [];

  @override
  void initState() {
    super.initState();
    widgetOptions = [
      HomeScreen(scrollController: homeScrollController),
      Shop(),
      Cart(),
      ReviewScreen(),
      LandingScreen(),
    ];
  }

  Future<void> _onItemTapped(int index) async {
    if (_selectedIndex == index && index == 0) {
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
        backgroundColor: Colors.white,
        showSelectedLabels: true,
        showUnselectedLabels: true,
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
              size: 21,
            ),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: ImageIcon(
              AssetImage(
                _selectedIndex == 1
                    ? 'assets/002m.png'
                    : 'assets/grey_002m.png',
              ),
              size: 21,
            ),
            label: '상점',
          ),
          BottomNavigationBarItem(
            icon: ImageIcon(
              AssetImage(
                _selectedIndex == 2
                    ? 'assets/003m.png'
                    : 'assets/grey_003m.png',
              ),
              size: 21,
            ),
            label: '장바구니',
          ),
          BottomNavigationBarItem(
            icon: ImageIcon(
              AssetImage(
                _selectedIndex == 3
                    ? 'assets/004m.png'
                    : 'assets/grey_004m.png',
              ),
              size: 21,
            ),
            label: '주문내역',
          ),
          BottomNavigationBarItem(
            icon: ImageIcon(
              AssetImage(
                _selectedIndex == 4
                    ? 'assets/005m.png'
                    : 'assets/grey_005m.png',
              ),
              size: 21,
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
