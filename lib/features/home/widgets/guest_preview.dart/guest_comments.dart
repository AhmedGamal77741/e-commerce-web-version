import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/features/home/widgets/guest_preview.dart/guest_comment_item.dart';
import 'package:ecommerece_app/features/home/widgets/guest_preview.dart/guest_post_item.dart';
import 'package:flutter/material.dart';

class GuestComments extends StatelessWidget {
  final Map<String, dynamic> post;
  const GuestComments({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Post preview styled like Comments screen
            Padding(
              padding: EdgeInsets.only(right: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: GuestPostItem(post: post))],
              ),
            ),

            verticalSpace(30),
            // Comments list
            Expanded(
              child: SingleChildScrollView(
                child: StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('posts')
                          .doc(post['postId'])
                          .collection('comments')
                          .orderBy('createdAt', descending: false)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('댓글을 불러올 수 없습니다'));
                    }
                    final comments = snapshot.data?.docs ?? [];
                    if (comments.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            '아직 댓글이 없습니다. 첫 번째 댓글을 남겨보세요!',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                              fontFamily: 'NotoSans',
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment =
                            comments[index].data() as Map<String, dynamic>;
                        return Column(
                          children: [
                            GuestCommentItem(comment: comment),
                            SizedBox(
                              height: 16,
                            ), // Add spacing between comments
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            // No input field for guests
          ],
        ),
      ),
    );
  }
}
