import 'package:ecommerece_app/features/home/comments.dart';
import 'package:ecommerece_app/features/home/data/post_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

class PostActions extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;

  const PostActions({Key? key, required this.postId, required this.postData})
    : super(key: key);

  @override
  State<PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<PostActions> {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    var isLiked =
        currentUser != null
            ? (widget.postData['likedBy']?.contains(currentUser!.uid) ?? false)
            : false;
    final likeCount = widget.postData['likes'] ?? 0;
    final commentCount = widget.postData['comments'] ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              isLiked = !isLiked;
            });
            // Use provider to toggle like
            Provider.of<PostsProvider>(
              context,
              listen: false,
            ).togglePostLike(widget.postId);
          },
          child: SizedBox(
            width: 22,
            height: 22,
            child: ImageIcon(
              AssetImage(
                isLiked
                    ? "assets/icon=like,status=off (1).png"
                    : "assets/icon=like,status=off.png",
              ),
              color: isLiked ? Color(0xFF280404) : Colors.black,
            ),
          ),
        ),
        Text(
          likeCount.toString(),
          style: TextStyle(
            color: const Color(0xFF343434),
            fontSize: 14,
            fontFamily: 'NotoSans',
            fontWeight: FontWeight.w400,
            height: 1.40,
          ),
        ),

        // Comment section remains the same
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Comments(postId: widget.postId),
              ),
            );
          },
          child: SizedBox(
            width: 22,
            height: 22,
            child: ImageIcon(AssetImage("assets/icon=comment.png")),
          ),
        ),
        Text(
          commentCount.toString(),
          style: TextStyle(
            color: const Color(0xFF343434),
            fontSize: 14,
            fontFamily: 'NotoSans',
            fontWeight: FontWeight.w400,
            height: 1.40,
          ),
        ),
      ],
    );
  }
}
