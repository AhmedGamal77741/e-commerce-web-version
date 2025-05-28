import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:flutter/material.dart';

class WideTextButton extends StatelessWidget {
  final String txt;
  final Color txtColor;
  final VoidCallback func;
  final Color color;

  const WideTextButton({
    super.key,
    required this.txt,
    required this.func,
    required this.color,
    required this.txtColor,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: func,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(color),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: WidgetStateProperty.all(Size(double.infinity, 45)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.black, width: 0.6),
          ),
        ),
      ),
      child: Text(
        txt,
        style: TextStyles.abeezee23px400wW.copyWith(color: txtColor),
      ),
    );
  }
}
