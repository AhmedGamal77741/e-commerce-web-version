import 'package:ecommerece_app/core/widgets/tab_app_bar.dart';
import 'package:ecommerece_app/features/cart/favorites.dart';
import 'package:ecommerece_app/features/cart/shopping_cart.dart';
import 'package:flutter/material.dart';

class Cart extends StatefulWidget {
  const Cart({super.key});

  @override
  State<Cart> createState() => _CartState();
}

class _CartState extends State<Cart> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: TabAppBar(
          imgUrl: '003m.png',
          firstTab: '장바구니',
          secondTab: '즐겨찾기',
        ),
        body: SafeArea(
          child: TabBarView(children: [ShoppingCart(), FavoritesScreen()]),
        ),
      ),
    );
  }
}
