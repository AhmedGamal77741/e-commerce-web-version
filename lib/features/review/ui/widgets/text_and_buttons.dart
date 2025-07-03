import 'package:ecommerece_app/core/helpers/basetime.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TextAndButtons extends StatelessWidget {
  final String sellerName;
  final String productName;
  final String qunatity;
  final int orderPrice;
  final int baselineTime;
  final String meridiem;
  final formatCurrency = NumberFormat('#,###');
  TextAndButtons({
    super.key,
    required this.sellerName,
    required this.productName,
    required this.qunatity,
    required this.orderPrice,
    required this.baselineTime,
    required this.meridiem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(sellerName, style: TextStyles.abeezee14px400wP600),
        Text(productName, style: TextStyles.abeezee16px400wPblack),
        Row(
          children: [
            Text('옵션 : $qunatity 개 ', style: TextStyles.abeezee14px400wP600),
            FutureBuilder<String>(
              future: getArrivalDay(meridiem, baselineTime),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Text('로딩 중...', style: TextStyles.abeezee14px400wP600);
                }
                if (snapshot.hasError) {
                  return Text('오류 발생', style: TextStyles.abeezee14px400wP600);
                }

                return Text(
                  '${snapshot.data} 도착예정',
                  style: TextStyles.abeezee14px400wP600,
                );
              },
            ),
          ],
        ),

        Text(
          '${formatCurrency.format(orderPrice)} 원',
          style: TextStyles.abeezee18px400wPblack,
        ),
      ],
    );
  }
}
