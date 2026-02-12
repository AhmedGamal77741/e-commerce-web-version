import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:flutter/material.dart';

class GuestCommentItem extends StatelessWidget {
  final Map<String, dynamic> comment;
  const GuestCommentItem({Key? key, required this.comment}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              width: 40,
              height: 40,
              decoration: ShapeDecoration(
                image: DecorationImage(
                  image: NetworkImage(comment['userImage'] ?? ''),
                  fit: BoxFit.cover,
                ),
                shape: OvalBorder(),
              ),
            ),
          ),
          horizontalSpace(4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment['userName'] ?? '',
                  style: TextStyles.abeezee16px400wPblack,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    Flexible(
                      fit: FlexFit.loose,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.white,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          child: Text(
                            comment['text'],
                            style: TextStyle(
                              color: const Color(0xFF343434),
                              fontSize: 16,
                              fontFamily: 'NotoSans',
                              fontWeight: FontWeight.w400,
                              height: 1.40,
                              letterSpacing: -0.09,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: [
                        Icon(
                          Icons.favorite_border,
                          color: Colors.grey,
                          size: 18,
                        ),
                        SizedBox(width: 4),
                        Text(
                          (comment['likes'] ?? 0).toString(),
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontFamily: 'NotoSans',
                            fontWeight: FontWeight.w400,
                            height: 1.40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
