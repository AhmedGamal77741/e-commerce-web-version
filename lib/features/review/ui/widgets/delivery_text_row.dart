import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:flutter/material.dart';

class DeliveryTextRow extends StatelessWidget {
  final String orderStatus;
  const DeliveryTextRow({super.key, required this.orderStatus});

  @override
  Widget build(BuildContext context) {
    return orderStatus == "OUT_FOR_DELIVERY"
        ? Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '주문\n 완료',
                style: TextStyles.abeezee16px400wPblack,
                textAlign: TextAlign.center,
              ),
              Text(
                '배송 중',
                style: TextStyles.abeezee16px400wPblack,
                textAlign: TextAlign.center,
              ),
              Text(
                '배송\n 완료',
                style: TextStyles.abeezee16px400wP600,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )
        : orderStatus == 'DELIVERED'
        ? Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '주문\n 완료',
                style: TextStyles.abeezee16px400wPblack,
                textAlign: TextAlign.center,
              ),
              Text(
                '배송 중',
                style: TextStyles.abeezee16px400wPblack,
                textAlign: TextAlign.center,
              ),
              Text(
                '배송\n 완료',
                style: TextStyles.abeezee16px400wPblack,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )
        : Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '주문\n 완료',
                style: TextStyles.abeezee16px400wPblack,
                textAlign: TextAlign.center,
              ),
              Text(
                '배송 중',
                style: TextStyles.abeezee16px400wP600,
                textAlign: TextAlign.center,
              ),
              Text(
                '배송\n 완료',
                style: TextStyles.abeezee16px400wP600,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
  }
}
