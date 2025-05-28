import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:flutter/material.dart';

class AvatarAndTitle extends StatelessWidget {
  const AvatarAndTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset('assets/product_image_rev.png', width: 48, height: 48),
        horizontalSpace(5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pang2Chocolate', style: TextStyles.abeezee14px400wP600),
            Text('다크 마시멜로 6개', style: TextStyles.abeezee16px400wPblack),
          ],
        ),
      ],
    );
  }
}
