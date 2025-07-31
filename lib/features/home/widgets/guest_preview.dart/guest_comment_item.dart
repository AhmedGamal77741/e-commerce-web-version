import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:flutter/material.dart';

class GuestCommentItem extends StatelessWidget {
  final Map<String, dynamic> comment;
  const GuestCommentItem({Key? key, required this.comment}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDeleted =
        comment['userImage'] == null || comment['userImage'].toString().isEmpty;
    final String displayName =
        (comment['userName'] == null || comment['userName'].toString().isEmpty)
            ? '삭제된 계정'
            : comment['userName'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            width: 56,
            height: 55,
            decoration: ShapeDecoration(
              image:
                  isDeleted
                      ? DecorationImage(
                        image: AssetImage('assets/avatar.png'),
                        fit: BoxFit.cover,
                      )
                      : DecorationImage(
                        image: NetworkImage(comment['userImage'] ?? ''),
                        fit: BoxFit.cover,
                      ),
              shape: OvalBorder(),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Padding(
            padding: EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@$displayName', style: TextStyles.abeezee16px400wPblack),
                Text(
                  comment['text'] ?? '',
                  style: TextStyle(
                    color: const Color(0xFF343434),
                    fontSize: 16,
                    fontFamily: 'NotoSans',
                    fontWeight: FontWeight.w400,
                    height: 1.40,
                    letterSpacing: -0.09,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.favorite_border, color: Colors.grey, size: 18),
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
          ),
        ),
      ],
    );
  }
}
