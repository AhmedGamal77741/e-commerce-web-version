import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_entity.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ecommerece_app/features/home/data/follow_service.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/home/data/home_functions.dart';
import 'package:ecommerece_app/features/home/widgets/guest_preview.dart/guest_post_actions.dart';
import 'package:flutter/material.dart';

import 'package:shimmer/shimmer.dart';

import '../../../../../features/home/widgets/guest_preview.dart/guest_comments.dart';

class GuestPostItem extends StatelessWidget {
  final Map<String, dynamic> post;
  const GuestPostItem({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (post['fromComments'] != true) {
          final postId = post['postId'];
          GoRouter.of(context).push('/guest_comment?postId=$postId');
        }
      },
      child: FutureBuilder<MyUser>(
        future: getUser(post['userId']),
        builder: (context, snapshot) {
          final bool isDeleted = snapshot.hasError || !snapshot.hasData;
          final String avatarUrl =
              isDeleted ? 'assets/avatar.png' : snapshot.data!.url.toString();
          final String displayName = isDeleted ? '삭제된 계정' : snapshot.data!.name;
          final myuser = isDeleted ? null : snapshot.data!;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildPostSkeleton();
          }
          if (isDeleted) {
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 10),
                    Flexible(
                      child: Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Container(
                          width: 56,
                          height: 55,
                          decoration: ShapeDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/avatar.png'),
                              fit: BoxFit.cover,
                            ),
                            shape: OvalBorder(),
                          ),
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
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: TextStyles.abeezee16px400wPblack,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (post['text'] != null &&
                                post['text'].toString().isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: 5),
                                child: Text(
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
                              ),
                            verticalSpace(5),
                            if (post['imgUrl'] != null &&
                                post['imgUrl'].toString().isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  post['imgUrl'],
                                  fit: BoxFit.fitWidth,
                                  width: double.infinity,
                                ),
                              ),
                            verticalSpace(5),
                            GuestPostActions(post: post),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
          // ...existing code for non-deleted user...
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 10),
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Container(
                        width: 56,
                        height: 55,
                        decoration: ShapeDecoration(
                          image: DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          ),
                          shape: OvalBorder(),
                        ),
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: TextStyles.abeezee16px400wPblack,
                                    ),
                                    if (post['fromComments'] == true)
                                      StreamBuilder<QuerySnapshot>(
                                        stream:
                                            FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(
                                                  myuser != null
                                                      ? myuser.userId
                                                      : '',
                                                )
                                                .collection('followers')
                                                .snapshots(),
                                        builder: (context, subSnap) {
                                          if (subSnap.connectionState ==
                                              ConnectionState.waiting) {
                                            return SizedBox(height: 16);
                                          }
                                          if (subSnap.hasError) {
                                            return Text(
                                              '구독자 오류',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 16,
                                              ),
                                            );
                                          }
                                          final count =
                                              subSnap.data?.docs.length ?? 0;
                                          final formatted = count
                                              .toString()
                                              .replaceAllMapped(
                                                RegExp(r'\B(?=(\d{3})+(?!\d))'),
                                                (match) => ',',
                                              );
                                          return Text(
                                            '구독자 $formatted명',
                                            style: TextStyle(
                                              color: const Color(0xFF787878),
                                              fontSize: 16,
                                              fontFamily: 'NotoSans',
                                              fontWeight: FontWeight.w400,
                                              height: 1.40,
                                              letterSpacing: -0.09,
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (post['fromComments'] == true)
                                Builder(
                                  builder: (context) {
                                    final currentUserId =
                                        FirebaseAuth.instance.currentUser?.uid;
                                    if (myuser != null &&
                                        myuser.userId != currentUserId &&
                                        currentUserId != null) {
                                      return StreamBuilder<DocumentSnapshot>(
                                        stream:
                                            FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(currentUserId)
                                                .collection('following')
                                                .doc(
                                                  myuser != null
                                                      ? myuser.userId
                                                      : '',
                                                )
                                                .snapshots(),
                                        builder: (context, snapshot) {
                                          final isFollowing =
                                              snapshot.hasData &&
                                              snapshot.data!.exists;
                                          return ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  isFollowing
                                                      ? Colors.grey[300]
                                                      : ColorsManager
                                                          .primary600,
                                              foregroundColor:
                                                  isFollowing
                                                      ? Colors.black
                                                      : Colors.white,
                                              minimumSize: Size(47, 33),
                                              textStyle: TextStyle(
                                                fontSize: 12,
                                                fontFamily: 'NotoSans',
                                                fontWeight: FontWeight.w500,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                            onPressed: () async {
                                              await FollowService()
                                                  .toggleFollow(
                                                    myuser != null
                                                        ? myuser.userId
                                                        : '',
                                                  );
                                            },
                                            child: Text(
                                              isFollowing ? '구독 취소' : '구독',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontFamily: 'NotoSans',
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    } else {
                                      return const SizedBox.shrink();
                                    }
                                  },
                                ),
                            ],
                          ),
                          if (post['text'] != null &&
                              post['text'].toString().isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 5),
                              child: Text(
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
                            ),
                          verticalSpace(5),
                          if (post['imgUrl'] != null &&
                              post['imgUrl'].toString().isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                post['imgUrl'],
                                fit: BoxFit.fitWidth,
                                width: double.infinity,
                              ),
                            ),
                          verticalSpace(5),
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
      ),
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
