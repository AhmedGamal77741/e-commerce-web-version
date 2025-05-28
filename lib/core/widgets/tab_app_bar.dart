import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:flutter/material.dart';

class TabAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? imgUrl;
  final String firstTab;
  final String? secondTab;
  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + 48);
  const TabAppBar({
    super.key,
    this.imgUrl,
    required this.firstTab,
    this.secondTab,
  });

  @override
  Widget build(BuildContext context) {
    return imgUrl == null
        ? AppBar(
          toolbarHeight: 130,
          backgroundColor: ColorsManager.white,
          title: TabBar(
            labelStyle: TextStyle(
              fontSize: 16,
              decoration: TextDecoration.none,
              fontFamily: 'NotoSans',
              fontStyle: FontStyle.normal,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              color: ColorsManager.primaryblack,
            ),
            unselectedLabelColor: ColorsManager.primary600,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorColor: ColorsManager.primaryblack,
            tabs:
                secondTab == null
                    ? [Tab(text: firstTab)]
                    : [Tab(text: firstTab), Tab(text: secondTab)],
          ),
        )
        : AppBar(
          backgroundColor: ColorsManager.white,
          title: Image.asset('assets/$imgUrl', width: 39, height: 39),
          centerTitle: true,
          bottom: TabBar(
            labelStyle: TextStyle(
              fontSize: 16,
              decoration: TextDecoration.none,
              fontFamily: 'NotoSans',
              fontStyle: FontStyle.normal,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              color: ColorsManager.primaryblack,
            ),
            unselectedLabelColor: ColorsManager.primary600,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorColor: ColorsManager.primaryblack,
            tabs:
                secondTab == null
                    ? [Tab(text: firstTab)]
                    : [Tab(text: firstTab), Tab(text: secondTab)],
          ),
        );
  }
}
