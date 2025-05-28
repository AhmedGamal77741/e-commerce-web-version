import 'package:ecommerece_app/features/cart/cart.dart';
import 'package:ecommerece_app/features/home/home_screen.dart';
import 'package:ecommerece_app/features/review/ui/review_screen.dart';
import 'package:ecommerece_app/features/shop/shop.dart';
import 'package:ecommerece_app/landing.dart';
import 'package:flutter/material.dart';

class NavBar extends StatefulWidget {
  const NavBar({super.key});

  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> {
  int _selectedIndex = 0;

  final List<Widget> widgetOptions = [
    HomeScreen(),
    Shop(),
    Cart(),
    ReviewScreen(),
    LandingScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widgetOptions.elementAt(_selectedIndex),
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
