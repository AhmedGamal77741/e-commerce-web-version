import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/core/services/share_service.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_entity.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/home/comments.dart';
import 'package:ecommerece_app/features/home/data/follow_service.dart';
import 'package:ecommerece_app/features/home/data/home_functions.dart';
import 'package:ecommerece_app/features/home/data/post_provider.dart';
import 'package:ecommerece_app/features/home/widgets/post_actions.dart';
import 'package:ecommerece_app/features/home/widgets/share_dialog.dart';
import 'package:ecommerece_app/features/home/widgets/show_post_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
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

  // ── helpers ────────────────────────────────────────────────────────────────

  /// Shows the edit dialog for the current user's post.
  Future<void> _showEditDialog(BuildContext context, String currentText) async {
    final controller = TextEditingController(text: currentText);
    await showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '게시글 수정',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    maxLines: 12,
                    style: TextStyle(color: Colors.black, fontSize: 16),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          '취소',
                          style: TextStyle(color: Colors.black, fontSize: 16),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('posts')
                              .doc(postId)
                              .update({'text': controller.text});
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('게시글이 수정되었습니다.')),
                          );
                        },
                        child: Text('수정'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  /// Shows the delete confirmation dialog for the current user's post.
  Future<void> _showDeleteDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '게시글 삭제',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '정말로 이 게시글을 삭제하시겠습니까?',
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          '취소',
                          style: TextStyle(color: Colors.black, fontSize: 16),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('posts')
                              .doc(postId)
                              .delete();
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('게시물이 삭제되었습니다.')),
                          );
                        },
                        child: Text('삭제'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  /// Runs [action] while showing a loading dialog, then cleans up safely.
  Future<void> _runWithLoading(
    BuildContext context,
    Future<void> Function() action,
    String successMsg,
    String errorPrefix,
  ) async {
    // Capture navigator/messenger BEFORE any async gap
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    // Show loading
    nav.push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        barrierColor: Colors.black26,
        pageBuilder:
            (_, __, ___) => AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('신고 처리 중...'),
                ],
              ),
            ),
      ),
    );

    try {
      await action();
      nav.pop(); // dismiss loading
      messenger.showSnackBar(SnackBar(content: Text(successMsg)));
    } catch (e) {
      nav.pop(); // dismiss loading even on error
      messenger.showSnackBar(
        SnackBar(
          content: Text('$errorPrefix: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ScreenshotController _fromCommentsScreenshotController =
        ScreenshotController();
    final ScreenshotController _notFromCommentsScreenshotController =
        ScreenshotController();
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);
    if (postsProvider.getComments(postId).isEmpty &&
        !postsProvider.isLoadingComments(postId)) {
      postsProvider.listenToComments(postId);
    }

    return Selector<PostsProvider, Map<String, dynamic>?>(
      selector: (_, provider) => provider.getPost(postId),
      builder: (context, postData, child) {
        if (postData == null) return SizedBox.shrink();

        return FutureBuilder<MyUser>(
          future: getUser(postData['userId']),
          builder: (context, snapshot) {
            final bool userMissing =
                snapshot.hasError ||
                !snapshot.hasData ||
                (snapshot.data?.userId ?? '').isEmpty;
            final myuser = snapshot.data;
            final displayName =
                myuser?.name.isNotEmpty == true ? myuser!.name : '삭제된 사용자';
            final String profileUrl = !userMissing ? (myuser?.url ?? '') : '';
            final bool isMyPost =
                !userMissing &&
                myuser!.userId == FirebaseAuth.instance.currentUser?.uid;

            return Column(
              children: [
                // ── fromComments branch (unchanged) ───────────────────────
                if (fromComments)
                  Screenshot(
                    controller: _fromCommentsScreenshotController,
                    child: Padding(
                      padding: EdgeInsets.only(top: 5, left: 10, right: 10),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: ShapeDecoration(
                                  image: DecorationImage(
                                    image:
                                        profileUrl.isNotEmpty
                                            ? NetworkImage(profileUrl)
                                            : AssetImage('assets/avatar.png')
                                                as ImageProvider,
                                    fit: BoxFit.cover,
                                  ),
                                  shape: OvalBorder(),
                                ),
                              ),
                              horizontalSpace(5),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    verticalSpace(5),
                                    Text(
                                      displayName,
                                      style: TextStyles.abeezee16px400wPblack
                                          .copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    if (!userMissing &&
                                        myuser!.userId.isNotEmpty)
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
                                  ],
                                ),
                              ),
                              Spacer(),
                              if (!userMissing &&
                                  myuser!.userId !=
                                      FirebaseAuth.instance.currentUser?.uid)
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
                                    final isPrivate =
                                        myuser?.isPrivate ?? false;

                                    if (isFollowing) {
                                      return PopupMenuButton<String>(
                                        onSelected: (value) async {
                                          if (value == 'share') {
                                            showShareDialog(
                                              context,
                                              'post',
                                              'https://app.pang2chocolate.com/comment?postId=$postId',
                                              postId,
                                              myuser.name,
                                              myuser.url,
                                              postData,
                                            );
                                            /*                                           ShareService.sharePost(postId);
                     */
                                          } else if (value == 'unfollow') {
                                            FollowService().toggleFollow(
                                              myuser.userId,
                                            );
                                          }
                                        },
                                        color: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        itemBuilder:
                                            (BuildContext context) => [
                                              PopupMenuItem<String>(
                                                value: 'share',
                                                child: Text(
                                                  '공유',
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              PopupMenuItem<String>(
                                                value: 'unfollow',
                                                child: Text(
                                                  '구독 취소',
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ],
                                        child: Icon(
                                          Icons.more_horiz,
                                          color: Colors.black,
                                          size: 22,
                                        ),
                                      );
                                    }

                                    if (isPrivate) {
                                      return StreamBuilder<DocumentSnapshot>(
                                        stream:
                                            FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(myuser.userId)
                                                .collection('followRequests')
                                                .doc(
                                                  FirebaseAuth
                                                      .instance
                                                      .currentUser
                                                      ?.uid,
                                                )
                                                .snapshots(),
                                        builder: (context, requestSnapshot) {
                                          final hasRequest =
                                              requestSnapshot.hasData &&
                                              requestSnapshot.data!.exists;
                                          return ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  hasRequest
                                                      ? Colors.grey[300]
                                                      : Colors.black,
                                              foregroundColor:
                                                  hasRequest
                                                      ? Colors.black
                                                      : Colors.white,
                                              minimumSize: Size(35, 33),
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
                                              if (hasRequest) {
                                                await FirebaseFirestore.instance
                                                    .collection('users')
                                                    .doc(myuser.userId)
                                                    .collection(
                                                      'followRequests',
                                                    )
                                                    .doc(
                                                      FirebaseAuth
                                                          .instance
                                                          .currentUser
                                                          ?.uid,
                                                    )
                                                    .delete();
                                              } else {
                                                await FirebaseFirestore.instance
                                                    .collection('users')
                                                    .doc(myuser.userId)
                                                    .collection(
                                                      'followRequests',
                                                    )
                                                    .doc(
                                                      FirebaseAuth
                                                          .instance
                                                          .currentUser
                                                          ?.uid,
                                                    )
                                                    .set({
                                                      'timestamp':
                                                          FieldValue.serverTimestamp(),
                                                    });
                                              }
                                            },
                                            child: Text(
                                              hasRequest ? '요청 취소' : '구독 신청',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontFamily: 'NotoSans',
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    }

                                    return ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        foregroundColor: Colors.white,
                                        minimumSize: Size(40, 28),
                                        textStyle: TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'NotoSans',
                                          fontWeight: FontWeight.w500,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                      ),
                                      onPressed: () async {
                                        FollowService().toggleFollow(
                                          myuser.userId,
                                        );
                                      },
                                      child: Text(
                                        '구독',
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
                          if (postData['text'].toString().isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 15),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      postData['text'],
                                      style: TextStyle(
                                        color: const Color(0xFF343434),
                                        fontSize: 18,
                                        fontFamily: 'NotoSans',
                                        fontWeight: FontWeight.w500,
                                        height: 1.40,
                                        letterSpacing: -0.09,
                                      ),
                                    ),
                                  ),
                                  if (showMoreButton) ...[
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
                                          myuser?.userId ?? '',
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
                              borderRadius: BorderRadius.circular(30),
                              child: Image.network(
                                postData['imgUrl'],
                                fit: BoxFit.fitWidth,
                                width: double.infinity,
                              ),
                            ),
                          verticalSpace(30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              PostActions(postId: postId, postData: postData),
                              horizontalSpace(4),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: Colors.grey[600],
                                ),
                              ),
                              InkWell(
                                onTap: () => context.pop(),
                                child: Icon(Icons.close),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── !fromComments branch ──────────────────────────────────
                if (!fromComments)
                  Screenshot(
                    controller: _notFromCommentsScreenshotController,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                            // Avatar
                            Container(
                              width: 65,
                              height: 65,
                              decoration: ShapeDecoration(
                                image: DecorationImage(
                                  image:
                                      (myuser?.url != null &&
                                              myuser!.url.isNotEmpty)
                                          ? NetworkImage(myuser.url)
                                          : AssetImage('assets/avatar.png')
                                              as ImageProvider,
                                  fit: BoxFit.cover,
                                ),
                                shape: OvalBorder(),
                              ),
                            ),
                            horizontalSpace(8),

                            // Body
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  verticalSpace(10),
                                  Text(
                                    displayName,
                                    style: TextStyles.abeezee16px400wPblack
                                        .copyWith(fontWeight: FontWeight.bold),
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
                                      borderRadius: BorderRadius.circular(20),
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

                            // ── More button (popup menu) ──────────────────
                            if (showMoreButton)
                              isMyPost
                                  ? _OwnPostMenu(
                                    postId: postId,
                                    currentText: postData['text'] ?? '',
                                    onEdit:
                                        () => _showEditDialog(
                                          context,
                                          postData['text'] ?? '',
                                        ),
                                    onDelete: () => _showDeleteDialog(context),
                                  )
                                  : _OtherPostMenu(
                                    postId: postId,
                                    userId: myuser?.userId ?? '',
                                    onRunWithLoading: _runWithLoading,
                                    displayName: displayName,
                                    profileUrl: profileUrl,
                                    postData: postData,
                                  ),
                          ],
                        ),
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

// ── Own-post popup menu (edit / delete) ──────────────────────────────────────

class _OwnPostMenu extends StatelessWidget {
  final String postId;
  final String currentText;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _OwnPostMenu({
    required this.postId,
    required this.currentText,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'delete') onDelete();
      },
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder:
          (_) => [
            PopupMenuItem<String>(
              value: 'edit',
              child: Text(
                '수정하기',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontFamily: 'NotoSans',
                ),
              ),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              child: Text(
                '삭제하기',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontFamily: 'NotoSans',
                ),
              ),
            ),
          ],
      child: Icon(Icons.more_horiz, color: Colors.black, size: 22),
    );
  }
}

// ── Other user's post popup menu (구독 / 차단 / 신고 및 차단) ──────────────────────

class _OtherPostMenu extends StatelessWidget {
  final String postId;
  final String userId;
  final Future<void> Function(
    BuildContext,
    Future<void> Function(),
    String,
    String,
  )
  onRunWithLoading;

  final String displayName;
  final String profileUrl;
  final Map<String, dynamic> postData;
  const _OtherPostMenu({
    required this.postId,
    required this.userId,
    required this.onRunWithLoading,
    required this.displayName,
    required this.profileUrl,
    required this.postData,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        switch (value) {
          case 'share':
            showShareDialog(
              context,
              'post',
              'https://app.pang2chocolate.com/comment?postId=$postId',
              postId,
              displayName,
              profileUrl,
              postData,
            );
            /*             ShareService.sharePost(postId); */
            break;

          case 'block':
            await onRunWithLoading(
              context,
              () => blockUser(userIdToBlock: userId),
              '차단되었습니다.',
              '오류 발생',
            );
            break;

          case 'report_and_block':
            await onRunWithLoading(
              context,
              () async {
                await reportUser(reportedUserId: userId, postId: postId);
                await blockUser(userIdToBlock: userId);
              },
              '신고가 접수되었습니다.',
              '신고 처리 중 오류가 발생했습니다',
            );
            break;
        }
      },
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder:
          (_) => [
            // Share
            PopupMenuItem<String>(
              value: 'share',
              child: Text(
                '공유',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontFamily: 'NotoSans',
                ),
              ),
            ),
            // Block only
            PopupMenuItem<String>(
              value: 'block',
              child: Text(
                '차단',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontFamily: 'NotoSans',
                ),
              ),
            ),
            // Report + Block combined
            PopupMenuItem<String>(
              value: 'report_and_block',
              child: Text(
                '신고 및 차단',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontFamily: 'NotoSans',
                ),
              ),
            ),
          ],
      child: Icon(Icons.more_horiz, color: Colors.black, size: 22),
    );
  }
}
