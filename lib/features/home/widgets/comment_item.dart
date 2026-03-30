import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/cart/services/cart_service.dart';
import 'package:ecommerece_app/features/chat/services/contacts_service.dart';
import 'package:ecommerece_app/features/chat/widgets/chat_post_share.dart';
import 'package:ecommerece_app/features/home/comments.dart';
import 'package:ecommerece_app/features/home/data/post_provider.dart';
import 'package:ecommerece_app/features/home/follow_feed_screen.dart';
import 'package:ecommerece_app/features/home/models/comment_model.dart';
import 'package:ecommerece_app/features/shop/item_details.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CommentItem extends StatefulWidget {
  final Comment comment;
  final String postId;
  const CommentItem({super.key, required this.comment, required this.postId});

  @override
  State<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey _commentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    List<String> likedBy = List<String>.from(widget.comment.likedBy ?? []);
    bool isLiked = likedBy.contains(currentUser!.uid);

    return Padding(
      key: _commentKey,
      padding: EdgeInsets.only(left: 10),
      child: InkWell(
        onLongPress: () {
          print('Long press detected!'); // Debug
          _showCommentMenu(widget.comment.userId);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => SafeArea(
                          child: Scaffold(
                            body: FollowingTab(
                              firebaseUser: FirebaseAuth.instance.currentUser,
                              preselectedUser: widget.comment.userId,
                            ),
                          ),
                        ),
                  ),
                );
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: ShapeDecoration(
                  image: DecorationImage(
                    image: NetworkImage(widget.comment.userImage.toString()),
                    fit: BoxFit.cover,
                  ),
                  shape: OvalBorder(),
                ),
              ),
            ),
            horizontalSpace(4),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    verticalSpace(3),
                    Text(
                      widget.comment.userName ?? '',
                      style: TextStyles.abeezee16px400wPblack,
                    ),
                    FutureBuilder<String?>(
                      future: ContactService().getContactNickname(
                        widget.comment.userId,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox.shrink(); // Or a small CircularProgressIndicator
                        }

                        if (snapshot.hasError ||
                            !snapshot.hasData ||
                            snapshot.data == null) {
                          return const SizedBox.shrink();
                        }

                        final nickname = snapshot.data!;
                        return Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            '@$nickname',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: [
                        Flexible(
                          fit: FlexFit.loose,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.comment.text.isNotEmpty) ...[
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: Colors.white,
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    child: Text(
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
                                  ),
                                ),
                              ],
                              if (widget.comment.postData != null) ...[
                                if (widget.comment.text.isNotEmpty)
                                  SizedBox(height: 6),
                                ChatPostShareWidget(
                                  type: 'post',
                                  imageUrl: widget.comment.postData!['imgUrl'],
                                  authorName:
                                      widget.comment.postData!['userId'],
                                  postTitle: widget.comment.postData!['text'],
                                  onTap:
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => Comments(
                                                postId:
                                                    widget
                                                        .comment
                                                        .postData!['postId'],
                                              ),
                                        ),
                                      ),
                                ),
                              ],
                              if (widget.comment.productData != null) ...[
                                if (widget.comment.text.isNotEmpty)
                                  SizedBox(height: 6),
                                ChatPostShareWidget(
                                  type: 'product',
                                  imageUrl: widget.comment.productData!.imgUrl!,
                                  postTitle:
                                      '${widget.comment.productData!.pricePoints[0].price.toString()} 원',
                                  authorName:
                                      widget.comment.productData!.productName,
                                  onTap: () async {
                                    bool isSub = await isUserSubscribed();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => ItemDetails(
                                              product:
                                                  widget.comment.productData!,
                                              isSub: isSub,
                                              arrivalDay:
                                                  widget
                                                      .comment
                                                      .productData!
                                                      .arrivalDate!,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                              if (widget.comment.imageUrl != null &&
                                  widget.comment.imageUrl!.isNotEmpty) ...[
                                if (widget.comment.text.isNotEmpty)
                                  SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    widget.comment.imageUrl!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 4,
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
                                color:
                                    isLiked ? Color(0xFF280404) : Colors.black,
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
        ),
      ),
    );
  }

  void _showCommentMenu(String commentUserId) {
    print('Showing menu for user: $commentUserId'); // Debug

    // Don't show menu if it's the current user's own comment
    if (commentUserId == currentUser!.uid) {
      print('Cannot show menu for own comment');
      return;
    }

    final RenderBox? renderBox =
        _commentKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      print('RenderBox is null');
      return;
    }

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        renderBox.localToGlobal(
          renderBox.size.centerLeft(Offset.zero),
          ancestor: overlay,
        ),
        renderBox.localToGlobal(
          renderBox.size.centerRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      items: [
        // Follow/Unfollow/Request Option
        PopupMenuItem<String>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: StreamBuilder<DocumentSnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(commentUserId)
                    .snapshots(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) {
                return SizedBox(
                  height: 50,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final commentUserData =
                  userSnapshot.data!.data() as Map<String, dynamic>?;

              if (commentUserData == null) {
                return SizedBox.shrink();
              }

              final isPrivate = commentUserData['isPrivate'] ?? false;
              final currentUserId = currentUser!.uid;

              return StreamBuilder<DocumentSnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUserId)
                        .collection('following')
                        .doc(commentUserId)
                        .snapshots(),
                builder: (context, followingSnapshot) {
                  final isFollowing =
                      followingSnapshot.hasData &&
                      followingSnapshot.data!.exists;

                  return StreamBuilder<DocumentSnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(commentUserId)
                            .collection('followRequests')
                            .doc(currentUserId)
                            .snapshots(),
                    builder: (context, requestSnapshot) {
                      final hasRequest =
                          requestSnapshot.hasData &&
                          requestSnapshot.data!.exists;

                      String buttonText = '구독';

                      if (isFollowing) {
                        buttonText = '구독 취소';
                      } else if (isPrivate && hasRequest) {
                        buttonText = '요청 취소';
                      } else if (isPrivate) {
                        buttonText = '구독 요청';
                      }

                      return InkWell(
                        onTap: () async {
                          Navigator.pop(context);
                          await _handleFollowAction(
                            context,
                            commentUserId,
                            currentUserId,
                            isPrivate,
                            isFollowing,
                            hasRequest,
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Text(
                            buttonText,
                            style: TextStyle(
                              color: const Color(0xFF343434),
                              fontSize: 13,
                              fontFamily: 'NotoSans',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        // Divider

        // Block Option
        PopupMenuItem<String>(
          value: 'block',

          child: Text(
            '차단',
            style: TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontFamily: 'NotoSans',
              fontWeight: FontWeight.w400,
            ),
          ),
        ),

        // Report and Block Option
        PopupMenuItem<String>(
          value: 'report',

          child: Text(
            '신고 및 차단',
            style: TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontFamily: 'NotoSans',
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    ).then((value) async {
      if (value == 'block') {
        await _blockUser(context, commentUserId);
      } else if (value == 'report') {
        await _reportAndBlockUser(context, commentUserId);
      }
    });
  }

  Future<void> _handleFollowAction(
    BuildContext context,
    String targetUserId,
    String currentUserId,
    bool isPrivate,
    bool isFollowing,
    bool hasRequest,
  ) async {
    try {
      if (isFollowing) {
        // Unfollow
        final batch = FirebaseFirestore.instance.batch();

        final followerRef = FirebaseFirestore.instance
            .collection('users')
            .doc(targetUserId)
            .collection('followers')
            .doc(currentUserId);

        final followingRef = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('following')
            .doc(targetUserId);

        batch.delete(followerRef);
        batch.delete(followingRef);

        await batch.commit();
      } else if (isPrivate && !hasRequest) {
        // Send follow request
        await FirebaseFirestore.instance
            .collection('users')
            .doc(targetUserId)
            .collection('followRequests')
            .doc(currentUserId)
            .set({'createdAt': FieldValue.serverTimestamp()});
      } else if (isPrivate && hasRequest) {
        // Cancel follow request
        await FirebaseFirestore.instance
            .collection('users')
            .doc(targetUserId)
            .collection('followRequests')
            .doc(currentUserId)
            .delete();
      } else {
        // Direct follow (public user)
        final batch = FirebaseFirestore.instance.batch();

        final followerRef = FirebaseFirestore.instance
            .collection('users')
            .doc(targetUserId)
            .collection('followers')
            .doc(currentUserId);

        final followingRef = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('following')
            .doc(targetUserId);

        batch.set(followerRef, {
          'userId': currentUserId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.set(followingRef, {
          'userId': targetUserId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await batch.commit();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('작업이 완료되었습니다')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  Future<void> _blockUser(BuildContext context, String userToBlockId) async {
    try {
      final currentUserId = currentUser!.uid;
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId);

      // Get current blocked list
      final currentUserData = await userDoc.get();
      List<String> blockedList = List<String>.from(
        currentUserData.data()?['blocked'] ?? [],
      );

      // Add to blocked list if not already blocked
      if (!blockedList.contains(userToBlockId)) {
        blockedList.add(userToBlockId);
        await userDoc.update({'blocked': blockedList});
      }

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('사용자가 차단되었습니다')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  Future<void> _reportAndBlockUser(
    BuildContext context,
    String userToReportId,
  ) async {
    try {
      final currentUserId = currentUser!.uid;

      // Report the user
      await FirebaseFirestore.instance.collection('reports').add({
        'reportedUserId': userToReportId,
        'reportingUserId': currentUserId,
        'postId': widget.postId,
        'commentId': widget.comment.id,
        'reason': 'Reported from comment',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Block the user
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId);

      final currentUserData = await userDoc.get();
      List<String> blockedList = List<String>.from(
        currentUserData.data()?['blocked'] ?? [],
      );

      if (!blockedList.contains(userToReportId)) {
        blockedList.add(userToReportId);
        await userDoc.update({'blocked': blockedList});
      }

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('사용자가 신고되고 차단되었습니다')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }
}
