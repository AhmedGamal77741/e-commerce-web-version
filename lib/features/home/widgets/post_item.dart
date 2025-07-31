import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_entity.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/home/comments.dart';
import 'package:ecommerece_app/features/home/data/follow_service.dart';
import 'package:ecommerece_app/features/home/data/home_functions.dart';
import 'package:ecommerece_app/features/home/data/post_provider.dart';
import 'package:ecommerece_app/features/home/widgets/post_actions.dart';
import 'package:ecommerece_app/features/home/widgets/show_post_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class PostItem extends StatelessWidget {
  final String postId;
  final bool fromComments;
  final bool showMoreButton;
  const PostItem({
    Key? key,
    required this.postId,
    required this.fromComments,
    this.showMoreButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);
    // Load comments if not already loaded
    if (postsProvider.getComments(postId).isEmpty &&
        !postsProvider.isLoadingComments(postId)) {
      // Start listening to comments for this post
      postsProvider.listenToComments(postId);
    }

    // Use Selector to only rebuild this widget when this specific post changes
    return Selector<PostsProvider, Map<String, dynamic>?>(
      selector: (_, provider) => provider.getPost(postId),
      builder: (context, postData, child) {
        if (postData == null) {
          return SizedBox.shrink(); // Post doesn't exist
        }

        return FutureBuilder<MyUser>(
          future: getUser(postData['userId']),
          builder: (context, snapshot) {
            final bool isDeleted = snapshot.hasError || !snapshot.hasData;
            final String avatarUrl =
                isDeleted ? 'assets/avatar.png' : snapshot.data!.url.toString();
            final String displayName =
                isDeleted ? '삭제된 계정' : snapshot.data!.name;
            final myuser = isDeleted ? null : snapshot.data!;
            final isMyPost =
                myuser != null &&
                myuser.userId == FirebaseAuth.instance.currentUser?.uid;

            return Column(
              children: [
                if (fromComments)
                  Padding(
                    padding: EdgeInsets.only(top: 20, left: 10, right: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
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
                                      image: NetworkImage(avatarUrl),
                                      fit: BoxFit.cover,
                                    ),
                            shape: OvalBorder(),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    displayName,
                                    style: TextStyles.abeezee16px400wPblack,
                                  ),
                                  Spacer(),
                                  if (myuser != null &&
                                      myuser.userId !=
                                          FirebaseAuth
                                              .instance
                                              .currentUser
                                              ?.uid)
                                    StreamBuilder<DocumentSnapshot>(
                                      stream:
                                          FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(
                                                FirebaseAuth
                                                    .instance
                                                    .currentUser
                                                    ?.uid,
                                              )
                                              .collection('following')
                                              .doc(myuser.userId)
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
                                                    : ColorsManager.primary600,
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
                                            FollowService().toggleFollow(
                                              myuser.userId,
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
                                    ),
                                ],
                              ),
                              if (myuser != null)
                                StreamBuilder<QuerySnapshot>(
                                  stream:
                                      FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(myuser.userId)
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
                                    return Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: Text(
                                        '구독자 $formatted명',
                                        style: TextStyle(
                                          color: const Color(0xFF787878),
                                          fontSize: 16,
                                          fontFamily: 'NotoSans',
                                          fontWeight: FontWeight.w400,
                                          height: 1.40,
                                          letterSpacing: -0.09,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              if (postData['text'].toString().isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: 5),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          postData['text'],
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
                                      if (showMoreButton && myuser != null) ...[
                                        IconButton(
                                          icon: Icon(
                                            Icons.more_vert,
                                            color: Colors.black,
                                            size: 22,
                                          ),
                                          onPressed: () {
                                            showPostMenu(
                                              context,
                                              postId,
                                              myuser.userId,
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              verticalSpace(5),
                              if (postData['imgUrl'].isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    postData['imgUrl'],
                                    fit: BoxFit.fitWidth,
                                    width: double.infinity,
                                  ),
                                ),
                              verticalSpace(5),
                              Row(
                                children: [
                                  PostActions(
                                    postId: postId,
                                    postData: postData,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!fromComments)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => Comments(postId: postId),
                          ),
                        );
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
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
                                        image: NetworkImage(avatarUrl),
                                        fit: BoxFit.cover,
                                      ),
                              shape: OvalBorder(),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: TextStyles.abeezee16px400wPblack,
                                      ),
                                    ),
                                    if (showMoreButton && myuser != null) ...[
                                      IconButton(
                                        icon: Icon(
                                          Icons.more_horiz,
                                          color: Colors.black,
                                          size: 22,
                                        ),
                                        onPressed: () {
                                          if (isMyPost) {
                                            showModalBottomSheet(
                                              context: context,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.only(
                                                  topLeft: Radius.circular(16),
                                                  topRight: Radius.circular(16),
                                                ),
                                              ),
                                              backgroundColor:
                                                  ColorsManager.primary50,
                                              builder: (context) {
                                                return Padding(
                                                  padding: EdgeInsets.all(16),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      // Edit Option
                                                      InkWell(
                                                        onTap: () async {
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                          TextEditingController
                                                          _controller =
                                                              TextEditingController(
                                                                text:
                                                                    postData['text'],
                                                              );
                                                          await showDialog(
                                                            context: context,
                                                            builder: (context) {
                                                              return Dialog(
                                                                backgroundColor:
                                                                    Colors
                                                                        .white,
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        16,
                                                                      ),
                                                                ),
                                                                child: Padding(
                                                                  padding:
                                                                      EdgeInsets.all(
                                                                        20,
                                                                      ),
                                                                  child: Column(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Text(
                                                                        '게시글 수정',
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              18,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          color:
                                                                              Colors.black,
                                                                        ),
                                                                      ),
                                                                      SizedBox(
                                                                        height:
                                                                            16,
                                                                      ),
                                                                      TextField(
                                                                        controller:
                                                                            _controller,
                                                                        maxLines:
                                                                            4,
                                                                        style: TextStyle(
                                                                          color:
                                                                              Colors.black,
                                                                          fontSize:
                                                                              16,
                                                                        ),
                                                                        decoration: InputDecoration(
                                                                          filled:
                                                                              true,
                                                                          fillColor:
                                                                              Colors.white,
                                                                          border: OutlineInputBorder(
                                                                            borderRadius: BorderRadius.circular(
                                                                              8,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      SizedBox(
                                                                        height:
                                                                            20,
                                                                      ),
                                                                      Row(
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment.end,
                                                                        children: [
                                                                          TextButton(
                                                                            onPressed:
                                                                                () => Navigator.pop(
                                                                                  context,
                                                                                ),
                                                                            child: Text(
                                                                              '취소',
                                                                              style: TextStyle(
                                                                                color:
                                                                                    Colors.black,
                                                                                fontSize:
                                                                                    16,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          SizedBox(
                                                                            width:
                                                                                12,
                                                                          ),
                                                                          ElevatedButton(
                                                                            style: ElevatedButton.styleFrom(
                                                                              backgroundColor:
                                                                                  Colors.black,
                                                                              foregroundColor:
                                                                                  Colors.white,
                                                                              shape: RoundedRectangleBorder(
                                                                                borderRadius: BorderRadius.circular(
                                                                                  8,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            onPressed: () async {
                                                                              await FirebaseFirestore.instance
                                                                                  .collection(
                                                                                    'posts',
                                                                                  )
                                                                                  .doc(
                                                                                    postId,
                                                                                  )
                                                                                  .update(
                                                                                    {
                                                                                      'text':
                                                                                          _controller.text,
                                                                                    },
                                                                                  );
                                                                              Navigator.pop(
                                                                                context,
                                                                              );
                                                                              ScaffoldMessenger.of(
                                                                                context,
                                                                              ).showSnackBar(
                                                                                SnackBar(
                                                                                  content: Text(
                                                                                    '게시글이 수정되었습니다.',
                                                                                  ),
                                                                                ),
                                                                              );
                                                                            },
                                                                            child: Text(
                                                                              '수정',
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          );
                                                        },
                                                        child: Container(
                                                          width:
                                                              double.infinity,
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: 14,
                                                                vertical: 8,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Text(
                                                                '수정하기',
                                                                style: TextStyle(
                                                                  color: const Color(
                                                                    0xFF343434,
                                                                  ),
                                                                  fontSize: 16,
                                                                  fontFamily:
                                                                      'NotoSans',
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w400,
                                                                  height: 1.40,
                                                                ),
                                                              ),
                                                              Icon(
                                                                Icons.edit,
                                                                color:
                                                                    ColorsManager
                                                                        .primary600,
                                                                size: 20,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(height: 8),
                                                      // Delete Option
                                                      InkWell(
                                                        onTap: () async {
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                          await showDialog(
                                                            context: context,
                                                            builder: (context) {
                                                              return Dialog(
                                                                backgroundColor:
                                                                    Colors
                                                                        .white,
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        16,
                                                                      ),
                                                                ),
                                                                child: Padding(
                                                                  padding:
                                                                      EdgeInsets.all(
                                                                        20,
                                                                      ),
                                                                  child: Column(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Text(
                                                                        '게시글 삭제',
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              18,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          color:
                                                                              Colors.black,
                                                                        ),
                                                                      ),
                                                                      SizedBox(
                                                                        height:
                                                                            16,
                                                                      ),
                                                                      Text(
                                                                        '정말로 이 게시글을 삭제하시겠습니까?',
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              16,
                                                                          color:
                                                                              Colors.black,
                                                                        ),
                                                                      ),
                                                                      SizedBox(
                                                                        height:
                                                                            20,
                                                                      ),
                                                                      Row(
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment.end,
                                                                        children: [
                                                                          TextButton(
                                                                            onPressed:
                                                                                () => Navigator.pop(
                                                                                  context,
                                                                                ),
                                                                            child: Text(
                                                                              '취소',
                                                                              style: TextStyle(
                                                                                color:
                                                                                    Colors.black,
                                                                                fontSize:
                                                                                    16,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          SizedBox(
                                                                            width:
                                                                                12,
                                                                          ),
                                                                          ElevatedButton(
                                                                            style: ElevatedButton.styleFrom(
                                                                              backgroundColor:
                                                                                  Colors.black,
                                                                              foregroundColor:
                                                                                  Colors.white,
                                                                              shape: RoundedRectangleBorder(
                                                                                borderRadius: BorderRadius.circular(
                                                                                  8,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            onPressed: () async {
                                                                              await FirebaseFirestore.instance
                                                                                  .collection(
                                                                                    'posts',
                                                                                  )
                                                                                  .doc(
                                                                                    postId,
                                                                                  )
                                                                                  .delete();
                                                                              Navigator.pop(
                                                                                context,
                                                                              );
                                                                              ScaffoldMessenger.of(
                                                                                context,
                                                                              ).showSnackBar(
                                                                                SnackBar(
                                                                                  content: Text(
                                                                                    '게시물이 삭제되었습니다.',
                                                                                  ),
                                                                                ),
                                                                              );
                                                                            },
                                                                            child: Text(
                                                                              '삭제',
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          );
                                                        },
                                                        child: Container(
                                                          width:
                                                              double.infinity,
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: 14,
                                                                vertical: 8,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Text(
                                                                '삭제하기',
                                                                style: TextStyle(
                                                                  color: const Color(
                                                                    0xFFDA3A48,
                                                                  ),
                                                                  fontSize: 16,
                                                                  fontFamily:
                                                                      'NotoSans',
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w400,
                                                                  height: 1.40,
                                                                ),
                                                              ),
                                                              Icon(
                                                                Icons.delete,
                                                                color:
                                                                    const Color(
                                                                      0xFFDA3A48,
                                                                    ),
                                                                size: 20,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            );
                                          } else if (myuser == null) {
                                            showPostMenu(context, postId, '');
                                          }
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                                if (postData['text'].toString().isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(top: 5),
                                    child: Text(
                                      postData['text'],
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
                                if (postData['imgUrl'].isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      postData['imgUrl'],
                                      fit: BoxFit.fitWidth,
                                      width: double.infinity,
                                    ),
                                  ),
                                verticalSpace(5),
                                Row(
                                  children: [
                                    PostActions(
                                      postId: postId,
                                      postData: postData,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
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
    child: Text('Failed to load user', style: TextStyle(color: Colors.red)),
  );
}
