import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:flutter/material.dart';

class DeliveryTextRow extends StatelessWidget {
  final String orderStatus;
  const DeliveryTextRow({super.key, required this.orderStatus});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double horizontalPadding = constraints.maxWidth * 0.11;
        final double fontSize = constraints.maxWidth * 0.045;
        TextStyle blackStyle = TextStyles.abeezee16px400wPblack.copyWith(
          fontSize: fontSize,
        );
        TextStyle boldStyle = TextStyles.abeezee16px400wP600.copyWith(
          fontSize: fontSize,
        );

        List<Widget> getRow(String status) {
          if (status == "OUT_FOR_DELIVERY") {
            return [
              Text('주문\n 완료', style: blackStyle, textAlign: TextAlign.center),
              Text('배송 중', style: blackStyle, textAlign: TextAlign.center),
              Text('배송\n 완료', style: boldStyle, textAlign: TextAlign.center),
            ];
          } else if (status == "DELIVERED") {
            return [
              Text('주문\n 완료', style: blackStyle, textAlign: TextAlign.center),
              Text('배송 중', style: blackStyle, textAlign: TextAlign.center),
              Text('배송\n 완료', style: blackStyle, textAlign: TextAlign.center),
            ];
          } else {
            return [
              Text('주문\n 완료', style: blackStyle, textAlign: TextAlign.center),
              Text('배송 중', style: boldStyle, textAlign: TextAlign.center),
              Text('배송\n 완료', style: boldStyle, textAlign: TextAlign.center),
            ];
          }
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: getRow(orderStatus),
          ),
        );
      },
    );
  }
}
