import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:flutter/material.dart';

class DeliveryStatus extends StatelessWidget {
  final String orderStatus;
  const DeliveryStatus({super.key, required this.orderStatus});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double iconSize = constraints.maxWidth * 0.12;
        final double boxSize = constraints.maxWidth * 0.22;
        final double connectorWidth = constraints.maxWidth * 0.11;
        final double connectorHeight = constraints.maxWidth * 0.03;
        final double borderRadius = boxSize * 0.2;

        Widget statusRow(
          Color firstColor,
          Color secondColor,
          Color thirdColor,
          Color firstConnector,
          Color secondConnector,
        ) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: boxSize,
                height: boxSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  color: firstColor,
                ),
                child: Icon(
                  Icons.dashboard_customize_rounded,
                  size: iconSize,
                  color: ColorsManager.white,
                ),
              ),
              Container(
                width: connectorWidth,
                height: connectorHeight,
                decoration: BoxDecoration(color: firstConnector),
              ),
              Container(
                width: boxSize,
                height: boxSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  color: secondColor,
                ),
                child: Icon(
                  Icons.local_shipping,
                  size: iconSize,
                  color: ColorsManager.white,
                ),
              ),
              Container(
                width: connectorWidth,
                height: connectorHeight,
                decoration: BoxDecoration(color: secondConnector),
              ),
              Container(
                width: boxSize,
                height: boxSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  color: thirdColor,
                ),
                child: Icon(
                  Icons.checklist_rounded,
                  size: iconSize,
                  color: ColorsManager.white,
                ),
              ),
            ],
          );
        }

        if (orderStatus == 'OUT_FOR_DELIVERY') {
          return statusRow(
            ColorsManager.primaryblack,
            ColorsManager.primaryblack,
            ColorsManager.primary300,
            ColorsManager.primaryblack,
            ColorsManager.primary300,
          );
        } else if (orderStatus == 'DELIVERED') {
          return statusRow(
            ColorsManager.primaryblack,
            ColorsManager.primaryblack,
            ColorsManager.primaryblack,
            ColorsManager.primaryblack,
            ColorsManager.primaryblack,
          );
        } else {
          return statusRow(
            ColorsManager.primaryblack,
            ColorsManager.primary300,
            ColorsManager.primary300,
            ColorsManager.primary300,
            ColorsManager.primary300,
          );
        }
      },
    );
  }
}
