import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:flutter/material.dart';

class ImgAndTxt extends StatelessWidget {
  const ImgAndTxt({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset('assets/image_icon.png', width: 17, height: 17),
        horizontalSpace(3),
        Text('사진 첨부', style: TextStyles.abeezee16px400wP600),
      ],
    );
  }
}
