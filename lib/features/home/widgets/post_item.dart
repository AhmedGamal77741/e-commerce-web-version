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
            if (snapshot.hasError || !snapshot.hasData) {
              return _buildPostSkeleton();
            }

            final myuser = snapshot.data!;
            final isMyPost =
                myuser.userId == FirebaseAuth.instance.currentUser?.uid;

            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!fromComments) ...{
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
                    },

                    // Post Content
                    Expanded(
                      flex: 4,
                      child: InkWell(
                        onTap: () {
                          if (!fromComments) {
                            context.push(
                              '/${Routes.commentsScreen}?postId=$postId',
                            );
                          }
                        },
                        child: Padding(
                          padding:
                              fromComments
                                  ? EdgeInsets.only(right: 30, left: 30)
                                  : EdgeInsets.only(right: 10, left: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with menu
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  if (fromComments) ...{
                                    // User Avatar
                                    Container(
                                      width: 35,
                                      height: 35,
                                      decoration: ShapeDecoration(
                                        image: DecorationImage(
                                          image: NetworkImage(
                                            myuser.url.toString(),
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                        shape: OvalBorder(),
                                      ),
                                    ),
                                  },
                                  Column(
                                    children: [
                                      Text(
                                        myuser.name,
                                        style: TextStyles.abeezee16px400wPblack,
                                      ),
                                      if (fromComments) ...{
                                        Text(
                                          "구독자 ${myuser.followerCount}명",
                                          style: TextStyle(
                                            color: const Color(0xFF787878),
                                            fontSize: 16,
                                            fontFamily: 'NotoSans',
                                            fontWeight: FontWeight.w400,
                                            height: 1.40,
                                            letterSpacing: -0.09,
                                          ),
                                        ),
                                      },
                                    ],
                                  ),
                                  Spacer(),

                                  if (myuser.userId !=
                                          FirebaseAuth
                                              .instance
                                              .currentUser
                                              ?.uid &&
                                      fromComments)
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
                                            /* final batch =
                                                FirebaseFirestore.instance
                                                    .batch();

                                            final followingRef =
                                                FirebaseFirestore.instance
                                                    .collection('users')
                                                    .doc(
                                                      FirebaseAuth
                                                          .instance
                                                          .currentUser
                                                          ?.uid,
                                                    )
                                                    .collection('following')
                                                    .doc(myuser.userId);
                                            final followerRef =
                                                FirebaseFirestore.instance
                                                    .collection('users')
                                                    .doc(myuser.userId)
                                                    .collection('followers')
                                                    .doc(
                                                      FirebaseAuth
                                                          .instance
                                                          .currentUser
                                                          ?.uid,
                                                    );
                                            if (isFollowing) {
                                              batch.delete(followingRef);
                                              batch.delete(followerRef);
                                            } else {
                                              batch.set(followingRef, {
                                                'createdAt':
                                                    FieldValue.serverTimestamp(),
                                              });
                                              batch.set(followerRef, {
                                                'createdAt':
                                                    FieldValue.serverTimestamp(),
                                              });
                                            }

                                            await batch.commit(); */
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
                                  if (showMoreButton)
                                    Builder(
                                      builder:
                                          (parentContext) =>
                                              isMyPost
                                                  ? IconButton(
                                                    icon: Icon(
                                                      Icons.more_horiz,
                                                    ),
                                                    onPressed: () {
                                                      showModalBottomSheet(
                                                        context: parentContext,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.vertical(
                                                                top:
                                                                    Radius.circular(
                                                                      16,
                                                                    ),
                                                              ),
                                                        ),
                                                        backgroundColor:
                                                            Colors.white,
                                                        builder:
                                                            (
                                                              context,
                                                            ) => SafeArea(
                                                              child: Padding(
                                                                padding:
                                                                    EdgeInsets.symmetric(
                                                                      vertical:
                                                                          12,
                                                                      horizontal:
                                                                          8,
                                                                    ),
                                                                child: Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    ListTile(
                                                                      leading: Icon(
                                                                        Icons
                                                                            .edit,
                                                                        color:
                                                                            Colors.black87,
                                                                      ),
                                                                      title: Text(
                                                                        '수정',
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              16,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                        ),
                                                                      ),
                                                                      onTap: () async {
                                                                        Navigator.pop(
                                                                          context,
                                                                        );
                                                                        final controller = TextEditingController(
                                                                          text:
                                                                              postData['text'] ??
                                                                              '',
                                                                        );
                                                                        final result = await showDialog<
                                                                          bool
                                                                        >(
                                                                          context:
                                                                              parentContext,
                                                                          builder:
                                                                              (
                                                                                context,
                                                                              ) => AlertDialog(
                                                                                title: Text(
                                                                                  '게시글 수정',
                                                                                ),
                                                                                content: TextField(
                                                                                  controller:
                                                                                      controller,
                                                                                  maxLines:
                                                                                      5,
                                                                                  decoration: InputDecoration(
                                                                                    labelText:
                                                                                        '게시글을 수정하세요',
                                                                                    border:
                                                                                        OutlineInputBorder(),
                                                                                  ),
                                                                                ),
                                                                                actions: [
                                                                                  TextButton(
                                                                                    onPressed:
                                                                                        () => Navigator.pop(
                                                                                          context,
                                                                                          false,
                                                                                        ),
                                                                                    child: Text(
                                                                                      '취소',
                                                                                      style: TextStyle(
                                                                                        color:
                                                                                            Colors.black,
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                  TextButton(
                                                                                    onPressed: () async {
                                                                                      final newText =
                                                                                          controller.text.trim();
                                                                                      if (newText.isNotEmpty) {
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
                                                                                                    newText,
                                                                                              },
                                                                                            );
                                                                                      }
                                                                                      Navigator.pop(
                                                                                        context,
                                                                                        true,
                                                                                      );
                                                                                    },
                                                                                    child: Text(
                                                                                      '수정',
                                                                                      style: TextStyle(
                                                                                        color:
                                                                                            Colors.black,
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                ],
                                                                              ),
                                                                        );
                                                                        if (result ==
                                                                            true) {
                                                                          ScaffoldMessenger.of(
                                                                            parentContext,
                                                                          ).showSnackBar(
                                                                            SnackBar(
                                                                              content: Text(
                                                                                '게시글이 수정되었습니다.',
                                                                              ),
                                                                            ),
                                                                          );
                                                                        }
                                                                      },
                                                                    ),
                                                                    Divider(
                                                                      height: 1,
                                                                    ),
                                                                    ListTile(
                                                                      leading: Icon(
                                                                        Icons
                                                                            .delete,
                                                                        color:
                                                                            Colors.red,
                                                                      ),
                                                                      title: Text(
                                                                        '삭제',
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              16,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          color:
                                                                              Colors.red,
                                                                        ),
                                                                      ),
                                                                      onTap: () async {
                                                                        Navigator.pop(
                                                                          context,
                                                                        );
                                                                        final confirm = await showDialog<
                                                                          bool
                                                                        >(
                                                                          context:
                                                                              parentContext,
                                                                          builder:
                                                                              (
                                                                                context,
                                                                              ) => AlertDialog(
                                                                                title: Text(
                                                                                  '게시글 삭제',
                                                                                ),
                                                                                content: Text(
                                                                                  '정말로 이 게시글을 삭제하시겠습니까?',
                                                                                ),
                                                                                actions: [
                                                                                  TextButton(
                                                                                    onPressed:
                                                                                        () => Navigator.pop(
                                                                                          context,
                                                                                          false,
                                                                                        ),
                                                                                    child: Text(
                                                                                      '취소',
                                                                                      style: TextStyle(
                                                                                        color:
                                                                                            Colors.black,
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                  TextButton(
                                                                                    onPressed:
                                                                                        () => Navigator.pop(
                                                                                          context,
                                                                                          true,
                                                                                        ),
                                                                                    child: Text(
                                                                                      '삭제',
                                                                                      style: TextStyle(
                                                                                        color:
                                                                                            Colors.red,
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                ],
                                                                              ),
                                                                        );
                                                                        if (confirm ==
                                                                            true) {
                                                                          await FirebaseFirestore
                                                                              .instance
                                                                              .collection(
                                                                                'posts',
                                                                              )
                                                                              .doc(
                                                                                postId,
                                                                              )
                                                                              .delete();
                                                                          ScaffoldMessenger.of(
                                                                            parentContext,
                                                                          ).showSnackBar(
                                                                            SnackBar(
                                                                              content: Text(
                                                                                '게시글이 삭제되었습니다.',
                                                                              ),
                                                                            ),
                                                                          );
                                                                        }
                                                                      },
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                      );
                                                    },
                                                  )
                                                  : IconButton(
                                                    icon: Icon(
                                                      Icons.more_horiz,
                                                    ),
                                                    onPressed: () {
                                                      showPostMenu(
                                                        parentContext,
                                                        postId,
                                                        myuser.userId,
                                                      );
                                                    },
                                                  ),
                                    ),
                                ],
                              ),

                              // Post Text
                              if (postData['text'].toString().isNotEmpty)
                                Text(
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
                              verticalSpace(5),
                              // Post Image
                              if (postData['imgUrl'].isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    postData['imgUrl'],
                                    width: fromComments ? 377 : 200,
                                    height: 272,
                                    scale: fromComments ? 16 / 9 : 1,
                                  ),
                                ),
                              verticalSpace(5),
                              // Like/Comment Buttons
                              PostActions(postId: postId, postData: postData),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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
