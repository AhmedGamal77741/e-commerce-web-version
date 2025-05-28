import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:flutter/material.dart';

class ReqButton extends StatelessWidget {
  final String txt;
  final VoidCallback func;
  final Color color;
  const ReqButton({
    super.key,
    required this.txt,
    required this.color,
    required this.func,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: func,
      style: TextButton.styleFrom(
        backgroundColor: color,
        fixedSize: Size(177, 83),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(txt, style: TextStyles.abeezee23px400wW),
    );
  }
}
