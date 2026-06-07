import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/chat/services/contacts_service.dart';
import 'package:ecommerece_app/features/home/comments.dart';
import 'package:ecommerece_app/features/home/data/follow_service.dart';
import 'package:ecommerece_app/features/home/data/home_functions.dart';
import 'package:ecommerece_app/features/home/data/post_provider.dart';
import 'package:ecommerece_app/features/home/profile_tab.dart';
import 'package:ecommerece_app/features/home/widgets/edit_post_dialog.dart';
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
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';

// =============================================================================
// NaturalAspectPageView
// =============================================================================
class NaturalAspectPageView extends StatefulWidget {
  final List imgUrls;
  final PageController pageController;
  final double? explicitWidth;

  const NaturalAspectPageView({
    required this.imgUrls,
    required this.pageController,
    this.explicitWidth,
  });

  @override
  State<NaturalAspectPageView> createState() => NaturalAspectPageViewState();
}

class NaturalAspectPageViewState extends State<NaturalAspectPageView> {
  List<double?> _ratios = [];
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _ratios = List<double?>.filled(widget.imgUrls.length, null);
    for (int i = 0; i < widget.imgUrls.length; i++) {
      _resolveRatio(i);
    }
    widget.pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_onPageChanged);
    super.dispose();
  }

  void _onPageChanged() {
    final page = widget.pageController.page?.round() ?? 0;
    if (page != _currentPage && mounted) {
      setState(() => _currentPage = page);
    }
  }

  void _resolveRatio(int index) {
    final image = NetworkImage(widget.imgUrls[index] as String);
    final stream = image.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        if (mounted) {
          setState(() {
            _ratios[index] =
                info.image.width.toDouble() / info.image.height.toDouble();
          });
        }
      },
      onError: (_, __) {
        stream.removeListener(listener);
        if (mounted) setState(() => _ratios[index] = 1.0);
      },
    );
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    // If explicitWidth is provided, bypass LayoutBuilder completely.
    if (widget.explicitWidth != null) {
      debugPrint(
        '✅ NaturalAspectPageView using explicitWidth=${widget.explicitWidth}',
      );
      return _buildWithWidth(widget.explicitWidth!);
    }

    debugPrint('⚠️ NaturalAspectPageView falling back to LayoutBuilder');
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth =
            constraints.hasBoundedWidth
                ? constraints.maxWidth
                : MediaQuery.of(context).size.width - 20;
        return _buildWithWidth(availableWidth);
      },
    );
  }

  Widget _buildWithWidth(double availableWidth) {
    debugPrint(
      '🟢 _buildWithWidth availableWidth=$availableWidth  ratio=${_ratios.isNotEmpty ? _ratios[0] : "empty"}',
    );

    final int safePage =
        (_ratios.isNotEmpty && _currentPage < _ratios.length)
            ? _currentPage
            : 0;

    final double? currentRatio = _ratios.isNotEmpty ? _ratios[safePage] : null;

    if (currentRatio == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Container(
          width: availableWidth,
          height: availableWidth * 0.75,
          color: Colors.grey[200],
        ),
      );
    }

    final double currentHeight = availableWidth / currentRatio;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: availableWidth,
          height: currentHeight,
          child: PageView.builder(
            controller: widget.pageController,
            itemCount: widget.imgUrls.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final double? ratio =
                  index < _ratios.length ? _ratios[index] : null;

              if (ratio == null) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    width: availableWidth,
                    height: currentHeight,
                    color: Colors.grey[200],
                  ),
                );
              }

              final double itemHeight = availableWidth / ratio;

              return ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: SizedBox(
                  width: availableWidth,
                  height: itemHeight,
                  child: CachedNetworkImage(
                    imageUrl: widget.imgUrls[index] as String,
                    width: availableWidth,
                    height: itemHeight,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder:
                        (context, url) => Container(
                          width: availableWidth,
                          height: itemHeight,
                          color: Colors.grey[200],
                        ),
                    errorWidget:
                        (context, url, error) => Container(
                          width: availableWidth,
                          height: itemHeight,
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 48,
                            ),
                          ),
                        ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.imgUrls.length > 1)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: SmoothPageIndicator(
              controller: widget.pageController,
              count: widget.imgUrls.length,
              effect: const ScrollingDotsEffect(
                activeDotColor: Colors.black,
                dotColor: Colors.grey,
                dotHeight: 8,
                dotWidth: 8,
              ),
              onDotClicked: (index) {
                widget.pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// PostItem — converted to StatefulWidget so PageController is stable
// =============================================================================
class PostItem extends StatefulWidget {
  final String postId;
  final bool fromComments;
  final bool showMoreButton;
  final double? imageWidth;
  final String? currentProfileUserId;

  const PostItem({
    Key? key,
    required this.postId,
    required this.fromComments,
    this.showMoreButton = true,
    this.imageWidth,
    this.currentProfileUserId,
  }) : super(key: key);

  @override
  State<PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> {
  // Stable PageController that survives rebuilds
  final PageController _pageController = PageController();
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _showEditDialog(
    BuildContext context,
    String currentText,
    List<String> currentImgUrls,
  ) async {
    final result = await showDialog<EditPostDialogResult>(
      context: context,
      builder:
          (ctx) => EditPostDialog(
            currentText: currentText,
            currentImgUrls: currentImgUrls,
          ),
    );

    if (result != null) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (ctx) => AlertDialog(
                content: Row(
                  children: [
                    SizedBox.shrink(),
                    SizedBox(width: 16),
                    Text('게시글 수정 중...'),
                  ],
                ),
              ),
        );

        await updatePost(
          postId: widget.postId,
          text: result.text,
          networkImgUrls: result.imgUrls,
          newImages: result.newImages,
        );

        Navigator.pop(context); // Close loading dialog
        /* Navigator.pop(context); // Close this screen if needed */
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('게시글이 수정되었습니다.')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('수정 실패: $e'), backgroundColor: Colors.red),
        );
        /*         Navigator.pop(context); // Close loading dialog
 */
      }
    }
  }

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
                              .doc(widget.postId)
                              .delete();
                          Navigator.pop(ctx);
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

  Future<void> _runWithLoading(
    BuildContext context,
    Future<void> Function() action,
    String successMsg,
    String errorPrefix,
  ) async {
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    nav.push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        barrierColor: Colors.black26,
        pageBuilder:
            (_, __, ___) => AlertDialog(
              content: Row(
                children: [
                  SizedBox.shrink(),
                  SizedBox(width: 16),
                  Text('신고 처리 중...'),
                ],
              ),
            ),
      ),
    );
    try {
      await action();
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text(successMsg)));
    } catch (e) {
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('$errorPrefix: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);
    if (postsProvider.getComments(widget.postId).isEmpty &&
        !postsProvider.isLoadingComments(widget.postId)) {
      postsProvider.listenToComments(widget.postId);
    }

    // Compute image width for fromComments here, in this widget's context.
    // PostItem padding in fromComments: left:10 + right:10
    final double fromCommentsImageWidth =
        MediaQuery.of(context).size.width - 10 - 10;

    debugPrint(
      '📐 PostItem.build fromComments=${widget.fromComments} '
      'widget.imageWidth=${widget.imageWidth} '
      'fromCommentsImageWidth=$fromCommentsImageWidth',
    );

    return Selector<PostsProvider, Map<String, dynamic>?>(
      selector: (_, provider) => provider.getPost(widget.postId),
      builder: (context, postData, child) {
        if (postData == null) return SizedBox.shrink();

        final cachedUser = postsProvider.getUser(postData['userId']);
        return FutureBuilder<MyUser>(
          future:
              cachedUser != null
                  ? Future.value(cachedUser)
                  : postsProvider.loadUser(postData['userId']),
          initialData: cachedUser,
          builder: (context, snapshot) {
            final isWaiting =
                snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData;
            final bool userMissing =
                !isWaiting &&
                (snapshot.hasError ||
                    !snapshot.hasData ||
                    (snapshot.data?.userId ?? '').isEmpty);
            final myuser = snapshot.data;
            final displayName =
                isWaiting
                    ? '로딩 중...'
                    : (myuser?.name.isNotEmpty == true
                        ? myuser!.name
                        : '삭제된 사용자');
            final String profileUrl =
                !userMissing && !isWaiting ? (myuser?.url ?? '') : '';
            final bool isMyPost =
                !userMissing &&
                !isWaiting &&
                myuser!.userId == FirebaseAuth.instance.currentUser?.uid;
            final List imgUrls =
                (postData['imgUrls'] != null &&
                        (postData['imgUrls'] as List).isNotEmpty)
                    ? postData['imgUrls'] as List
                    : [];

            Widget content = IgnorePointer(
              ignoring: isWaiting,
              child: Column(
                children: [
                  // ── fromComments branch ───────────────────────────────────
                  if (widget.fromComments)
                    Padding(
                      padding: EdgeInsets.only(top: 5, left: 10, right: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () {
                                  if (myuser != null &&
                                      widget.currentProfileUserId !=
                                          myuser.userId) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => Scaffold(
                                              body: ProfileTab(
                                                userId: myuser.userId,
                                              ),
                                            ),
                                      ),
                                    );
                                  }
                                },
                                child: Container(
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
                              ),
                              horizontalSpace(5),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    verticalSpace(5),
                                    isWaiting
                                        ? Shimmer.fromColors(
                                          baseColor: Colors.grey[300]!,
                                          highlightColor: Colors.grey[100]!,
                                          child: Container(
                                            width: 80,
                                            height: 16,
                                            color: Colors.white,
                                            margin: EdgeInsets.only(bottom: 2),
                                          ),
                                        )
                                        : Text(
                                          displayName,
                                          style: TextStyles
                                              .abeezee16px400wPblack
                                              .copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                    FutureBuilder<String?>(
                                      future: ContactService()
                                          .getContactNickname(
                                            myuser == null ? "" : myuser.userId,
                                          ),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const SizedBox.shrink();
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
                                    final isPrivate = myuser.isPrivate;

                                    if (isFollowing) {
                                      return PopupMenuButton<String>(
                                        onSelected: (value) async {
                                          if (value == 'share') {
                                            showShareDialog(
                                              context,
                                              'post',
                                              'https://app.pang2chocolate.com/comment?postId=${widget.postId}',
                                              widget.postId,
                                              myuser.name,
                                              myuser.url,
                                              postData,
                                            );
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
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                            onPressed: () async {
                                              final ref = FirebaseFirestore
                                                  .instance
                                                  .collection('users')
                                                  .doc(myuser.userId)
                                                  .collection('followRequests')
                                                  .doc(
                                                    FirebaseAuth
                                                        .instance
                                                        .currentUser
                                                        ?.uid,
                                                  );
                                              hasRequest
                                                  ? await ref.delete()
                                                  : await ref.set({
                                                    'timestamp':
                                                        FieldValue.serverTimestamp(),
                                                  });
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
                                  if (widget.showMoreButton)
                                    IconButton(
                                      icon: Icon(
                                        Icons.more_vert,
                                        color: Colors.black,
                                        size: 22,
                                      ),
                                      onPressed:
                                          () => showPostMenu(
                                            context,
                                            widget.postId,
                                            myuser?.userId ?? '',
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          verticalSpace(5),
                          if (imgUrls.isNotEmpty)
                            NaturalAspectPageView(
                              imgUrls: imgUrls,
                              pageController: _pageController,
                              // Use locally computed width — most reliable
                              explicitWidth: fromCommentsImageWidth,
                            ),
                          verticalSpace(30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              PostActions(
                                postId: widget.postId,
                                postData: postData,
                              ),
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

                  // ── !fromComments branch ──────────────────────────────────
                  if (!widget.fromComments)
                    Screenshot(
                      controller: _screenshotController,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () {
                                if (myuser != null &&
                                    widget.currentProfileUserId !=
                                        myuser.userId) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => Scaffold(
                                            body: ProfileTab(
                                              userId: myuser.userId,
                                            ),
                                          ),
                                    ),
                                  );
                                }
                              },
                              child: Container(
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
                            ),
                            horizontalSpace(8),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder:
                                        (context) => Container(
                                          height:
                                              MediaQuery.of(
                                                context,
                                              ).size.height *
                                              0.95,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFF2F2F2),
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(20),
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(20),
                                                ),
                                            child: Comments(
                                              postId: widget.postId,
                                            ),
                                          ),
                                        ),
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    verticalSpace(10),
                                    isWaiting
                                        ? Shimmer.fromColors(
                                          baseColor: Colors.grey[300]!,
                                          highlightColor: Colors.grey[100]!,
                                          child: Container(
                                            width: 80,
                                            height: 16,
                                            color: Colors.white,
                                            margin: EdgeInsets.only(bottom: 2),
                                          ),
                                        )
                                        : Text(
                                          displayName,
                                          style: TextStyles
                                              .abeezee16px400wPblack
                                              .copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                    FutureBuilder<String?>(
                                      future: ContactService()
                                          .getContactNickname(
                                            myuser == null ? "" : myuser.userId,
                                          ),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const SizedBox.shrink();
                                        }
                                        if (snapshot.hasError ||
                                            !snapshot.hasData ||
                                            snapshot.data == null) {
                                          return const SizedBox.shrink();
                                        }
                                        return Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Text(
                                            '@${snapshot.data!}',
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
                                    if (imgUrls.isNotEmpty)
                                      NaturalAspectPageView(
                                        imgUrls: imgUrls,
                                        pageController: _pageController,
                                        // No explicitWidth — Expanded provides
                                        // bounded width to LayoutBuilder.
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (widget.showMoreButton)
                              isMyPost
                                  ? _OwnPostMenu(
                                    postId: widget.postId,
                                    currentText: postData['text'] ?? '',
                                    onEdit:
                                        () => _showEditDialog(
                                          context,
                                          postData['text'] ?? '',
                                          imgUrls.cast<String>(),
                                        ),
                                    onDelete: () => _showDeleteDialog(context),
                                  )
                                  : OtherPostMenu(
                                    postId: widget.postId,
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
                ],
              ),
            );

            return isWaiting
                ? Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: content,
                )
                : content;
          },
        );
      },
    );
  }
}

// ── Own-post popup menu ───────────────────────────────────────────────────────

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

// ── Other user's post popup menu ──────────────────────────────────────────────

class OtherPostMenu extends StatelessWidget {
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

  const OtherPostMenu({
    super.key,
    required this.postId,
    required this.userId,
    required this.onRunWithLoading,
    required this.displayName,
    required this.profileUrl,
    required this.postData,
  });

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid)
              .collection('following')
              .doc(userId.isEmpty ? 's' : userId)
              .snapshots(),
      builder: (context, asyncSnapshot) {
        final isFollowing = asyncSnapshot.hasData && asyncSnapshot.data!.exists;

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
                break;
              case 'follow_unfollow':
                await FollowService().toggleFollow(userId);
                break;
              case 'block':
                await onRunWithLoading(
                  context,
                  () => blockUser(userIdToBlock: userId),
                  '차단되었습니다.',
                  '오류 발생',
                );
                break;
              case 'report':
                await onRunWithLoading(
                  context,
                  () async =>
                      await reportUser(reportedUserId: userId, postId: postId),
                  '신고가 접수되었습니다.',
                  '신고 처리 중 오류가 발생했습니다',
                );
                break;
            }
          },
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder:
              (_) => [
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
                PopupMenuItem<String>(
                  value: 'follow_unfollow',
                  child: Text(
                    isFollowing ? '구독취소' : '구독하기',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontFamily: 'NotoSans',
                    ),
                  ),
                ),
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
                PopupMenuItem<String>(
                  value: 'report',
                  child: Text(
                    '신고하기',
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
      },
    );
  }
}
