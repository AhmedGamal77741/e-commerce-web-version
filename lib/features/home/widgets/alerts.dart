import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/features/home/notifications.dart';
import 'package:ecommerece_app/features/home/widgets/requests.dart';
import 'package:flutter/material.dart';

class Alerts extends StatelessWidget {
  const Alerts({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.close,
              color: ColorsManager.primaryblack,
              size: 24,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: SizedBox(
            width: 300,
            child: TabBar(
              tabs: [Tab(text: '알림'), Tab(text: '친구관리')],
              labelStyle: TextStyle(
                fontSize: 16,
                decoration: TextDecoration.none,
                fontFamily: 'NotoSans',
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
                color: ColorsManager.primaryblack,
              ),
              unselectedLabelColor: ColorsManager.primary600,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorColor: ColorsManager.primaryblack,
            ),
          ),
        ),
        body: const TabBarView(children: [Notifications(), Requests()]),
      ),
    );
  }
}
