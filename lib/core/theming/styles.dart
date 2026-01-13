import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:flutter/material.dart';

class TextStyles {
  static TextStyle _textStyle({
    required double fontSize,
    required FontWeight fontWeight,
    required color,
    double letterSpacing = 0,
    String fontFamily = 'NotoSans',
  }) {
    return TextStyle(
      fontSize: fontSize,
      decoration: TextDecoration.none,
      fontFamily: fontFamily,
      fontStyle: FontStyle.normal,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static final TextStyle abeezee14px400wP600 = _textStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: ColorsManager.primary600,
  );
  static final TextStyle abeezee16px400wPblack = _textStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: ColorsManager.primaryblack,
  );
  static final TextStyle abeezee14px400wW = _textStyle(
    color: ColorsManager.white,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );
  static final TextStyle abeezee16px400wP600 = _textStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: ColorsManager.primary600,
  );
  static final TextStyle abeezee11px400wP600 = _textStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: ColorsManager.primary600,
  );
  static final TextStyle abeezee13px400wPblack = _textStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: ColorsManager.primaryblack,
  );
  static final TextStyle abeezee12px400wW = _textStyle(
    color: ColorsManager.white,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );
  static final TextStyle abeezee20px400wPblack = _textStyle(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    color: ColorsManager.primaryblack,
  );
  static final TextStyle abeezee23px400wW = _textStyle(
    color: ColorsManager.white,
    fontSize: 23,
    fontWeight: FontWeight.w400,
  );
  static final TextStyle abeezee16px400wPred = _textStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: ColorsManager.red,
  );
  static final TextStyle abeezee13px400wP600 = _textStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: ColorsManager.primary600,
  );
  static final TextStyle abeezee18px400wPblack = _textStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: ColorsManager.primaryblack,
  );
  static final TextStyle abeezee17px800wPblack = _textStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    color: ColorsManager.primaryblack,
  );
  static final TextStyle abeezee16px400wW = _textStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: ColorsManager.white,
  );
  static final TextStyle abeezee30px800wW = _textStyle(
    color: ColorsManager.white,
    fontSize: 30,
    fontWeight: FontWeight.w900,
  );
  static final TextStyle abeezee23px800wW = _textStyle(
    color: ColorsManager.white,
    fontSize: 23,
    fontWeight: FontWeight.w800,
  );
}
