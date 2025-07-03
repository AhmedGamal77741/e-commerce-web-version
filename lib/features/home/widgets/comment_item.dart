import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/home/data/post_provider.dart';
import 'package:ecommerece_app/features/home/models/comment_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

class CommentItem extends StatefulWidget {
  final Comment comment;
  final String postId;
  CommentItem({super.key, required this.comment, required this.postId});

  @override
  State<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem> {
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    List<String> likedBy = List<String>.from(widget.comment.likedBy ?? []);
    bool isLiked = likedBy.contains(currentUser!.uid);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            width: 56,
            height: 55,
            decoration: ShapeDecoration(
              image: DecorationImage(
                image: NetworkImage(widget.comment.userImage.toString()),
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
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              // spacing: 10.h, // Remove if not supported by Column
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '@${widget.comment.userName}',
                      style: TextStyles.abeezee16px400wPblack,
                    ),
                  ],
                ),
                Text(
                  widget.comment.text,
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
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  // spacing: 10.w, // Remove if not supported by Row
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      // spacing: 4.w, // Remove if not supported by Row
                      children: [
                        InkWell(
                          onTap: () {
                            Provider.of<PostsProvider>(
                              context,
                              listen: false,
                            ).toggleCommentLike(
                              widget.postId,
                              widget.comment.id,
                            );
                            setState(() {
                              isLiked = !isLiked;
                            });
                          },
                          child: ImageIcon(
                            AssetImage(
                              isLiked
                                  ? "assets/icon=like,status=off (1).png"
                                  : "assets/icon=like,status=off.png",
                            ),
                            color: isLiked ? Color(0xFF280404) : Colors.black,
                          ),
                        ),
                        Text(
                          widget.comment.likes.toString(),
                          style: TextStyle(
                            color: const Color(0xFF343434),
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
        ),
      ],
    );
  }
}
