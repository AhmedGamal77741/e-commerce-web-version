import 'package:flutter/material.dart';

class TbaleTextRow extends StatelessWidget {
  final String firstElment;
  final String secondElment;
  final String thirdElment;
  final TextStyle style;
  const TbaleTextRow({
    super.key,
    required this.firstElment,
    required this.secondElment,
    required this.thirdElment,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(firstElment, style: style, textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(
              secondElment,
              style: style,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(thirdElment, style: style, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
