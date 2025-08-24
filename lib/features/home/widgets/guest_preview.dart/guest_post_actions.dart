import 'package:flutter/material.dart';

class GuestPostActions extends StatelessWidget {
  final Map<String, dynamic> post;

  const GuestPostActions({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final likeCount = post['likes'] ?? 0;
    final commentCount = post['comments'] ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Like count display
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("프리미엄 회원 가입 후 게시글 작성, 좋아요, 댓글 사용할 수 있습니다!"),
                    ),
                  );
                },
                child: ImageIcon(
                  AssetImage("assets/icon=like,status=off.png"),
                  color: Colors.grey,
                ),
              ),
            ),
            SizedBox(width: 4),
            SizedBox(
              width: 25,
              height: 22,
              child: Text(
                likeCount.toString(),
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontFamily: 'NotoSans',
                  fontWeight: FontWeight.w400,
                  height: 1.40,
                ),
              ),
            ),
          ],
        ),
        SizedBox(width: 10),

        // Comment count display
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: ImageIcon(
                AssetImage("assets/icon=comment.png"),
                color: Colors.grey,
              ),
            ),
            SizedBox(width: 4),
            SizedBox(
              width: 25,
              height: 22,
              child: Text(
                commentCount.toString(),
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontFamily: 'NotoSans',
                  fontWeight: FontWeight.w400,
                  height: 1.40,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
