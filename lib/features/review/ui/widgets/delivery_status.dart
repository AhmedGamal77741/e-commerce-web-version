import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:flutter/material.dart';

class DeliveryStatus extends StatelessWidget {
  final String orderStatus;
  const DeliveryStatus({super.key, required this.orderStatus});

  @override
  Widget build(BuildContext context) {
    return orderStatus == 'OUT_FOR_DELIVERY'
        ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: ColorsManager.primaryblack,
              ),
              child: Icon(
                Icons.dashboard_customize_rounded,
                size: 50,
                color: ColorsManager.white,
              ),
            ),
            Container(
              width: 50,
              height: 15,
              decoration: BoxDecoration(color: ColorsManager.primaryblack),
            ),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: ColorsManager.primaryblack,
              ),
              child: Icon(
                Icons.local_shipping,
                size: 50,
                color: ColorsManager.white,
              ),
            ),
            Container(
              width: 50,
              height: 15,
              decoration: BoxDecoration(color: ColorsManager.primary300),
            ),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: ColorsManager.primary300,
              ),
              child: Icon(
                Icons.checklist_rounded,
                size: 50,
                color: ColorsManager.white,
              ),
            ),
          ],
        )
        : orderStatus == 'DELIVERED'
        ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: ColorsManager.primaryblack,
              ),
              child: Icon(
                Icons.dashboard_customize_rounded,
                size: 50,
                color: ColorsManager.white,
              ),
            ),
            Container(
              width: 50,
              height: 15,
              decoration: BoxDecoration(color: ColorsManager.primaryblack),
            ),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: ColorsManager.primaryblack,
              ),
              child: Icon(
                Icons.local_shipping,
                size: 50,
                color: ColorsManager.white,
              ),
            ),
            Container(
              width: 50,
              height: 15,
              decoration: BoxDecoration(color: ColorsManager.primaryblack),
            ),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: ColorsManager.primaryblack,
              ),
              child: Icon(
                Icons.checklist_rounded,
                size: 50,
                color: ColorsManager.white,
              ),
            ),
          ],
        )
        : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: ColorsManager.primaryblack,
              ),
              child: Icon(
                Icons.dashboard_customize_rounded,
                size: 50,
                color: ColorsManager.white,
              ),
            ),
            Container(
              width: 50,
              height: 15,
              decoration: BoxDecoration(color: ColorsManager.primary300),
            ),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: ColorsManager.primary300,
              ),
              child: Icon(
                Icons.local_shipping,
                size: 50,
                color: ColorsManager.white,
              ),
            ),
            Container(
              width: 50,
              height: 15,
              decoration: BoxDecoration(color: ColorsManager.primary300),
            ),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: ColorsManager.primary300,
              ),
              child: Icon(
                Icons.checklist_rounded,
                size: 50,
                color: ColorsManager.white,
              ),
            ),
          ],
        );
  }
}
