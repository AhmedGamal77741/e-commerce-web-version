import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_entity.dart';
import 'package:ecommerece_app/features/home/data/home_functions.dart';
import 'package:ecommerece_app/features/home/widgets/guest_preview.dart/guest_post_actions.dart';
import 'package:flutter/material.dart';

import 'package:shimmer/shimmer.dart';

class GuestPostItem extends StatelessWidget {
  final Map<String, dynamic> post;

  const GuestPostItem({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MyUserEntity>(
      future: getUser(post['userId']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildPostSkeleton();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildErrorPost();
        }

        final myuser = snapshot.data!;

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Avatar
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Container(
                      width: 56,
                      height: 55,
                      decoration: ShapeDecoration(
                        image: DecorationImage(
                          image: NetworkImage(myuser.url.toString()),
                          fit: BoxFit.cover,
                        ),
                        shape: OvalBorder(),
                      ),
                    ),
                  ),
                ),

                // Post Content
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header - simpler for guests
                        Text(
                          myuser.name,
                          style: TextStyles.abeezee16px400wPblack,
                        ),

                        // Post Text
                        if (post['text'] != null &&
                            post['text'].toString().isNotEmpty)
                          Text(
                            post['text'],
                            style: TextStyle(
                              color: const Color(0xFF343434),
                              fontSize: 16,
                              fontFamily: 'NotoSans',
                              fontWeight: FontWeight.w400,
                              height: 1.40,
                              letterSpacing: -0.09,
                            ),
                          ),
                        verticalSpace(5),

                        // Post Image
                        if (post['imgUrl'] != null &&
                            post['imgUrl'].toString().isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              post['imgUrl'],
                              width: 200,
                              height: 272,
                              fit: BoxFit.cover,
                            ),
                          ),
                        verticalSpace(5),

                        // Guest-specific actions
                        GuestPostActions(post: post),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPostSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 100,
        margin: EdgeInsets.all(8),
        color: Colors.white,
      ),
    );
  }

  Widget _buildErrorPost() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Text('게시물을 불러오지 못했습니다.', style: TextStyle(color: Colors.red)),
    );
  }
}
