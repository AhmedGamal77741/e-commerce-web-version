import 'package:ecommerece_app/core/widgets/tab_app_bar.dart';

import 'package:ecommerece_app/features/review/ui/leave_review.dart';
import 'package:ecommerece_app/features/review/ui/order_history.dart';
import 'package:flutter/material.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: TabAppBar(imgUrl: 'rev_icon.png', firstTab: '주문목록'),
        body: TabBarView(children: [OrderHistory()]),
      ),
    );
  }
}
