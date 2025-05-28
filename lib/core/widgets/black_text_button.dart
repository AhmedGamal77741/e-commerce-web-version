import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:flutter/material.dart';

class BlackTextButton extends StatelessWidget {
  final String txt;
  final TextStyle style;
  final VoidCallback func;

  const BlackTextButton({
    super.key,
    required this.txt,
    required this.func,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: func,
      style: TextButton.styleFrom(
        backgroundColor: ColorsManager.primaryblack,
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(txt, style: style),
    );
  }
}
